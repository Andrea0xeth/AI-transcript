import Foundation
import OSLog
import AudioToolbox

protocol RecordingSessionManaging {
    func startSession(configuration: RecordingConfiguration) async throws -> AudioRecordingCoordinatorType
}

final class RecordingSessionManager: RecordingSessionManaging {
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: RecordingSessionManager.self))
    private let microphoneCapture: MicrophoneCaptureType
    private let permissionsHelper: PermissionsHelperType
    
    init(microphoneCapture: MicrophoneCaptureType, permissionsHelper: PermissionsHelperType) {
        self.microphoneCapture = microphoneCapture
        self.permissionsHelper = permissionsHelper
    }
    
    func startSession(configuration: RecordingConfiguration) async throws -> AudioRecordingCoordinatorType {
        var processTap: ProcessTap?
        if configuration.captureSystemAudio {
            let hasScreenCapture = await permissionsHelper.checkScreenCapturePermission()
            if !hasScreenCapture {
                _ = await permissionsHelper.requestScreenRecordingPermission()
                let recheck = await permissionsHelper.checkScreenCapturePermission()
                if !recheck {
                    throw AudioCaptureError.coreAudioError(
                        "Per catturare l'audio dell'app (voci in call) serve l'autorizzazione Registrazione schermo. " +
                        "Attivala in Impostazioni di sistema > Privacy e sicurezza > Registrazione schermo, poi riavvia Recap."
                    )
                }
            }
            let tap: ProcessTap
            if let audioProcess = configuration.audioProcess {
                if !audioProcess.audioActive {
                    throw AudioCaptureError.coreAudioError(
                        "L'app selezionata non sta riproducendo audio. " +
                        "Apri l'app, avvia la call o la riproduzione audio e riprova."
                    )
                }
                tap = ProcessTap(process: audioProcess)
            } else {
                let processIDs = try AudioObjectID.readProcessList()
                if processIDs.isEmpty {
                    throw AudioCaptureError.coreAudioError("Nessun processo audio trovato. Avvia una sorgente audio e riprova.")
                }
                tap = ProcessTap(processObjectIDs: processIDs)
            }

            await MainActor.run { tap.activate() }
            if let errorMessage = tap.errorMessage {
                logger.error("Process tap failed: \(errorMessage)")
                throw AudioCaptureError.coreAudioError(
                    "Impossibile catturare l'audio di sistema. " +
                    "Controlla che ci sia audio in riproduzione e che Registrazione schermo sia consentita per Recap. " +
                    "Dettagli tecnici: \(errorMessage)"
                )
            }
            processTap = tap
        }
        
        let microphoneCaptureToUse = configuration.enableMicrophone ? microphoneCapture : nil
        
        if configuration.enableMicrophone {
            let granted = await permissionsHelper.requestMicrophonePermission()
            let status = await permissionsHelper.checkMicrophonePermissionStatus()
            guard granted || status == .authorized else {
                logger.error("Microphone permission denied or not granted (status: \(String(describing: status), privacy: .public))")
                throw AudioCaptureError.microphonePermissionDenied
            }
        }
        
        let coordinator = AudioRecordingCoordinator(
            configuration: configuration,
            microphoneCapture: microphoneCaptureToUse,
            processTap: processTap
        )
        
        try await coordinator.start()
        
        let sourceDesc = configuration.audioProcess?.name ?? "solo microfono"
        logger.info("Recording started (\(sourceDesc), microphone: \(configuration.enableMicrophone))")
        return coordinator
    }
}
