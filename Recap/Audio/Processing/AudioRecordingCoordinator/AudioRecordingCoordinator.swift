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
        
        let expectedFiles = configuration.expectedFiles
        
        if let systemAudioURL = expectedFiles.systemAudioURL, let processTap = processTap {
            let recorder = ProcessTapRecorder(fileURL: systemAudioURL, tap: processTap)
            self.tapRecorder = recorder
            
            try await MainActor.run {
                try recorder.start()
            }
            logger.info("System audio recording started: \(systemAudioURL.lastPathComponent)")
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
            
            if let desc = targetFormat {
                try microphoneCapture.start(outputURL: microphoneURL, targetFormat: desc)
            } else {
                try microphoneCapture.start(outputURL: microphoneURL, targetFormat: nil)
            }
            logger.info("Microphone recording started: \(microphoneURL.lastPathComponent)")
        }
        
        isRunning = true
        logger.info("Recording started with configuration: \(self.configuration.id)")
    }
    
    func stop() {
        guard isRunning else { return }
        
        microphoneCapture?.stop()
        tapRecorder?.stop()
        processTap?.invalidate()

        isRunning = false
        tapRecorder = nil
        
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
