import SwiftUI
import AudioToolbox
import OSLog
import AVFoundation

extension String: @retroactive LocalizedError {
    public var errorDescription: String? { self }
}

final class ProcessTap: ObservableObject {
    typealias InvalidationHandler = (ProcessTap) -> Void
    
    let process: AudioProcess
    let muteWhenRunning: Bool
    private let logger: Logger
    private let processObjectIDs: [AudioObjectID]
    
    private(set) var errorMessage: String?
    @Published private(set) var audioLevel: Float = 0.0
    
    fileprivate func setAudioLevel(_ level: Float) {
        audioLevel = level
    }

    @MainActor
    func setError(_ message: String) {
        errorMessage = message
    }
    
    init(process: AudioProcess, muteWhenRunning: Bool = false) {
        self.process = process
        self.muteWhenRunning = muteWhenRunning
        self.processObjectIDs = [process.objectID]
        self.logger = Logger(subsystem: AppConstants.Logging.subsystem, category: "\(String(describing: ProcessTap.self))(\(process.name))")
    }

    init(processObjectIDs: [AudioObjectID], muteWhenRunning: Bool = false) {
        let systemProcess = AudioProcess.systemAudio()
        self.process = systemProcess
        self.muteWhenRunning = muteWhenRunning
        self.processObjectIDs = processObjectIDs
        self.logger = Logger(subsystem: AppConstants.Logging.subsystem, category: "\(String(describing: ProcessTap.self))(\(systemProcess.name))")
    }
    
    @ObservationIgnored
    private var processTapID: AudioObjectID = .unknown
    @ObservationIgnored
    private var aggregateDeviceID = AudioObjectID.unknown
    @ObservationIgnored
    private var deviceProcID: AudioDeviceIOProcID?
    @ObservationIgnored
    private(set) var tapStreamDescription: AudioStreamBasicDescription?
    @ObservationIgnored
    private var invalidationHandler: InvalidationHandler?
    
    @ObservationIgnored
    private(set) var activated = false
    
    @MainActor
    func activate() {
        guard !activated else { return }
        activated = true
        
        logger.debug(#function)
        
        self.errorMessage = nil
        
        do {
            try prepare()
        } catch {
            logger.error("\(error, privacy: .public)")
            self.errorMessage = error.localizedDescription
        }
    }
    
    func invalidate() {
        guard activated else { return }
        defer { activated = false }
        
        logger.debug(#function)
        
        invalidationHandler?(self)
        self.invalidationHandler = nil
        
        if aggregateDeviceID.isValid {
            var err = AudioDeviceStop(aggregateDeviceID, deviceProcID)
            if err != noErr { logger.warning("Failed to stop aggregate device: \(err, privacy: .public)") }
            
            if let deviceProcID = deviceProcID {
                err = AudioDeviceDestroyIOProcID(aggregateDeviceID, deviceProcID)
                if err != noErr { logger.warning("Failed to destroy device I/O proc: \(err, privacy: .public)") }
                self.deviceProcID = nil
            }
            
            err = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            if err != noErr {
                logger.warning("Failed to destroy aggregate device: \(err, privacy: .public)")
            }
            aggregateDeviceID = .unknown
        }
        
        if processTapID.isValid {
            let err = AudioHardwareDestroyProcessTap(processTapID)
            if err != noErr {
                logger.warning("Failed to destroy audio tap: \(err, privacy: .public)")
            }
            self.processTapID = .unknown
        }
    }
    
    private func prepare() throws {
        errorMessage = nil
        
        let tapDescription = CATapDescription(stereoMixdownOfProcesses: processObjectIDs)
        tapDescription.uuid = UUID()
        tapDescription.muteBehavior = muteWhenRunning ? .mutedWhenTapped : .unmuted
        
        var tapID: AUAudioObjectID = .unknown
        var err = AudioHardwareCreateProcessTap(tapDescription, &tapID)
        
        guard err == noErr else {
            let message = "Process tap creation failed with error \(osStatusMessage(err))"
            errorMessage = message
            throw message
        }
        
        logger.debug("Created process tap #\(tapID, privacy: .public)")
        
        self.processTapID = tapID
        
        let systemOutputID = try AudioDeviceID.readDefaultSystemOutputDevice()
        let outputUID = try systemOutputID.readDeviceUID()
        let aggregateUID = UUID().uuidString
        
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Tap-\(process.id)",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [
                    kAudioSubDeviceUIDKey: outputUID
                ]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: tapDescription.uuid.uuidString
                ]
            ]
        ]
        
        do {
            self.tapStreamDescription = try tapID.readAudioTapStreamBasicDescription()
        } catch {
            let message = "Failed to read tap stream description: \(error.localizedDescription)"
            errorMessage = message
            throw message
        }
        
        aggregateDeviceID = AudioObjectID.unknown
        err = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateDeviceID)
        guard err == noErr else {
            let message = "Failed to create aggregate device: \(osStatusMessage(err))"
            errorMessage = message
            throw message
        }
        
        logger.debug("Created aggregate device #\(self.aggregateDeviceID, privacy: .public)")
    }
    
    func run(on queue: DispatchQueue, ioBlock: @escaping AudioDeviceIOBlock, invalidationHandler: @escaping InvalidationHandler) throws {
        assert(activated, "\(#function) called with inactive tap!")
        assert(self.invalidationHandler == nil, "\(#function) called with tap already active!")
        
        errorMessage = nil
        
        logger.debug("Run tap!")
        
        self.invalidationHandler = invalidationHandler
        
        var err = AudioDeviceCreateIOProcIDWithBlock(&deviceProcID, aggregateDeviceID, queue, ioBlock)
        guard err == noErr else { throw "Failed to create device I/O proc: \(osStatusMessage(err))" }
        
        err = AudioDeviceStart(aggregateDeviceID, deviceProcID)
        guard err == noErr else { throw "Failed to start audio device: \(osStatusMessage(err))" }
    }
    
    deinit { 
        invalidate() 
    }
}

private extension ProcessTap {
    func osStatusMessage(_ status: OSStatus) -> String {
        let hex = String(UInt32(bitPattern: status), radix: 16, uppercase: true)
        return "\(status) (0x\(hex))"
    }
}

final class ProcessTapRecorder: ObservableObject {
    let fileURL: URL?
    let process: AudioProcess
    private let queue = DispatchQueue(label: "ProcessTapRecorder", qos: .userInitiated)
    private let logger: Logger
    private let bufferHandler: ((AVAudioPCMBuffer) -> Void)?
    
    @ObservationIgnored
    private weak var _tap: ProcessTap?
    
    private(set) var isRecording = false
    
    init(fileURL: URL?, tap: ProcessTap, onBuffer: ((AVAudioPCMBuffer) -> Void)? = nil) {
        self.process = tap.process
        self.fileURL = fileURL
        self._tap = tap
        self.bufferHandler = onBuffer
        let fileName = fileURL?.lastPathComponent ?? "combined"
        self.logger = Logger(subsystem: AppConstants.Logging.subsystem, category: "\(String(describing: ProcessTapRecorder.self))(\(fileName))")
    }
    
    private var tap: ProcessTap {
        get throws {
            guard let _tap = _tap else { 
                throw AudioCaptureError.coreAudioError("Process tap unavailable") 
            }
            return _tap
        }
    }
    
    @ObservationIgnored
    private var currentFile: AVAudioFile?
    
    @MainActor
    func start() throws {
        logger.debug(#function)
        
        guard !isRecording else {
            logger.warning("\(#function, privacy: .public) while already recording")
            return
        }
        
        let tap = try tap
        
        if !tap.activated { 
            tap.activate() 
        }
        
        guard var streamDescription = tap.tapStreamDescription else {
            throw AudioCaptureError.coreAudioError("Tap stream description not available")
        }
        
        guard let format = AVAudioFormat(streamDescription: &streamDescription) else {
            throw AudioCaptureError.coreAudioError("Failed to create AVAudioFormat")
        }
        
        logger.info("Using audio format: \(format, privacy: .public)")
        
        let settings: [String: Any] = [
            AVFormatIDKey: streamDescription.mFormatID,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount, 
        ]
        
        if let fileURL = fileURL {
            let file = try AVAudioFile(forWriting: fileURL, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: format.isInterleaved)
            self.currentFile = file
        }
        
        try tap.run(on: queue) { [weak self] inNow, inInputData, inInputTime, outOutputData, inOutputTime in
            guard let self else { return }
            do {
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: inInputData, deallocator: nil) else {
                    throw "Failed to create PCM buffer"
                }
                if let handler = self.bufferHandler {
                    handler(buffer)
                } else if let currentFile = self.currentFile {
                    try currentFile.write(from: buffer)
                }
                self.updateAudioLevel(from: buffer)
            } catch {
                logger.error("\(error, privacy: .public)")
            }
        } invalidationHandler: { [weak self] tap in
            guard let self else { return }
            handleInvalidation()
        }
        
        isRecording = true
    }
    
    func stop() {
        do {
            logger.debug(#function)
            
            guard isRecording else { return }
            
            currentFile = nil
            isRecording = false
            
            try tap.invalidate()
        } catch {
            logger.error("Stop failed: \(error, privacy: .public)")
        }
    }
    
    private func handleInvalidation() {
        guard isRecording else { return }
        logger.debug(#function)
        isRecording = false
        currentFile = nil
        Task { @MainActor [weak self] in
            guard let self, let tap = try? self.tap else { return }
            tap.setError("Il tap dell'audio di sistema è stato invalidato. Riavvia la registrazione.")
        }
        NotificationCenter.default.post(name: .systemAudioTapInvalidated, object: nil)
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let floatData = buffer.floatChannelData else { return }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        var maxLevel: Float = 0.0
        
        for channel in 0..<channelCount {
            let channelData = floatData[channel]
            
            var channelLevel: Float = 0.0
            for frame in 0..<frameLength {
                let sample = abs(channelData[frame])
                channelLevel = max(channelLevel, sample)
            }
            
            maxLevel = max(maxLevel, channelLevel)
        }
        
        let decibels = 20 * log10(max(maxLevel, 0.00001))
        let normalizedLevel = (decibels + 60) / 60
        
        Task { @MainActor in
            self._tap?.setAudioLevel(min(max(normalizedLevel, 0), 1))
        }
    }
}
