import AVFoundation
import AudioToolbox
import OSLog

final class AudioRecordingCoordinator: AudioRecordingCoordinatorType {
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: AudioRecordingCoordinator.self))
    
    private let configuration: RecordingConfiguration
    private let microphoneCapture: MicrophoneCaptureType?
    private let processTap: ProcessTap?
    
    private var isRunning = false
    private var tapRecorder: ProcessTapRecorder?
    private var combinedWriter: CombinedAudioWriter?
    
    init(
        configuration: RecordingConfiguration,
        microphoneCapture: MicrophoneCaptureType?,
        processTap: ProcessTap?
    ) {
        self.configuration = configuration
        self.microphoneCapture = microphoneCapture
        self.processTap = processTap
    }
    
    func start() async throws {
        guard !isRunning else { return }
        let sessionDirectory = configuration.baseURL
        var didCreateDirectory = false
        
        do {
            try FileManager.default.createDirectory(
                at: sessionDirectory,
                withIntermediateDirectories: true
            )
            didCreateDirectory = true
            
        let expectedFiles = configuration.expectedFiles
        
        if let systemAudioURL = expectedFiles.systemAudioURL, let processTap = processTap {
            let targetFormat: AudioStreamBasicDescription?
            await MainActor.run { processTap.activate() }
            targetFormat = processTap.tapStreamDescription

            if configuration.enableMicrophone,
               let microphoneCapture = microphoneCapture,
               let floatFormat = AVAudioFormat(
                   commonFormat: .pcmFormatFloat32,
                   sampleRate: 16_000,
                   channels: 1,
                   interleaved: false
               ) {
                let writer = try CombinedAudioWriter(outputURL: systemAudioURL, targetFormat: floatFormat)
                combinedWriter = writer

                let recorder = ProcessTapRecorder(
                    fileURL: nil,
                    tap: processTap,
                    onBuffer: { [weak self] buffer in
                        self?.combinedWriter?.handleSystemBuffer(buffer)
                    }
                )
                self.tapRecorder = recorder
                try await MainActor.run { try recorder.start() }

                var floatDesc = floatFormat.streamDescription.pointee
                try microphoneCapture.start(
                    outputURL: nil,
                    targetFormat: floatDesc,
                    onBuffer: { [weak self] buffer in
                        self?.combinedWriter?.handleMicBuffer(buffer)
                    }
                )
                logger.info("Combined system+microphone recording started: \(systemAudioURL.lastPathComponent)")
            } else {
                let recorder = ProcessTapRecorder(fileURL: systemAudioURL, tap: processTap)
                self.tapRecorder = recorder
                try await MainActor.run { try recorder.start() }
                logger.info("System audio recording started: \(systemAudioURL.lastPathComponent)")
            }
        }
        
        if let microphoneURL = expectedFiles.microphoneURL,
           let microphoneCapture = microphoneCapture {
            let targetFormat: AudioStreamBasicDescription?
            if let tap = processTap {
                await MainActor.run { tap.activate() }
                targetFormat = tap.tapStreamDescription
            } else {
                targetFormat = nil
            }
            
            try microphoneCapture.start(
                outputURL: microphoneURL,
                targetFormat: targetFormat,
                onBuffer: nil
            )
            logger.info("Microphone recording started: \(microphoneURL.lastPathComponent)")
        }
        
        isRunning = true
        logger.info("Recording started with configuration: \(self.configuration.id)")
        } catch {
            if didCreateDirectory {
                try? FileManager.default.removeItem(at: sessionDirectory)
            }
            throw error
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        microphoneCapture?.stop()
        tapRecorder?.stop()
        processTap?.invalidate()

        isRunning = false
        tapRecorder = nil
        combinedWriter = nil
        
        logger.info("Recording stopped for configuration: \(self.configuration.id)")
    }
    
    var currentMicrophoneLevel: Float {
        microphoneCapture?.audioLevel ?? 0.0
    }
    
    var currentSystemAudioLevel: Float {
        processTap?.audioLevel ?? 0.0
    }
    
    var hasDualAudio: Bool {
        configuration.enableMicrophone && microphoneCapture != nil
    }
    
    var recordedFiles: RecordedFiles {
        configuration.expectedFiles
    }
}
