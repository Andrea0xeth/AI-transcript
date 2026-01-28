import Foundation
import OSLog

extension RecapViewModel {
    func startRecording() async {
        syncRecordingStateWithCoordinator()
        guard !isRecording else { return }
        guard canStartRecording else { return }
        guard !isStartRecordingInProgress else {
            logger.debug("Start recording ignored: already in progress")
            return
        }
        isStartRecordingInProgress = true
        defer { isStartRecordingInProgress = false }

        do {
            errorMessage = nil

            let recordingID = generateRecordingID()
            currentRecordingID = recordingID

            let configuration = try await createRecordingConfiguration(
                recordingID: recordingID,
                audioProcess: nil,
                captureSystemAudio: true
            )

            let recordedFiles = try await recordingCoordinator.startRecording(configuration: configuration)

            try await createRecordingEntity(
                recordingID: recordingID,
                recordedFiles: recordedFiles
            )

            updateRecordingUIState(started: true)

            let systemLabel = recordedFiles.systemAudioURL != nil ? "on" : "off"
            logger.info("Recording started - system audio: \(systemLabel), microphone: \(recordedFiles.microphoneURL != nil ? "on" : "off")")
        } catch {
            handleRecordingStartError(error)
        }
    }
    
    private func generateRecordingID() -> String {
        UUID().uuidString
    }
    
    private func createRecordingConfiguration(
        recordingID: String,
        audioProcess: AudioProcess?,
        captureSystemAudio: Bool
    ) async throws -> RecordingConfiguration {
        try fileManager.ensureRecordingsDirectoryExists()
        
        let baseURL = fileManager.createRecordingBaseURL(for: recordingID)
        
        return RecordingConfiguration(
            id: recordingID,
            audioProcess: audioProcess,
            captureSystemAudio: captureSystemAudio,
            enableMicrophone: isMicrophoneEnabled,
            baseURL: baseURL
        )
    }
    
    private func createRecordingEntity(
        recordingID: String,
        recordedFiles: RecordedFiles
    ) async throws {
        let mainURL = recordedFiles.systemAudioURL ?? recordedFiles.microphoneURL ?? fileManager.createRecordingBaseURL(for: recordingID)
        let micURL = recordedFiles.systemAudioURL != nil ? recordedFiles.microphoneURL : nil
        let recordingInfo = try await recordingRepository.createRecording(
            id: recordingID,
            startDate: Date(),
            recordingURL: mainURL,
            microphoneURL: micURL,
            hasMicrophoneAudio: isMicrophoneEnabled,
            applicationName: recordedFiles.applicationName
        )
        currentRecordings.insert(recordingInfo, at: 0)
    }
    
    private func handleRecordingStartError(_ error: Error) {
        errorMessage = error.localizedDescription
        logger.error("Failed to start recording: \(error)")
        currentRecordingID = nil
        updateRecordingUIState(started: false)
        showErrorToast = true
    }
}