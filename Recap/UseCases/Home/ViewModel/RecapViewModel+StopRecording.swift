import Foundation
import OSLog

extension RecapViewModel {
    func stopRecording() async {
        guard isRecording else { return }
        guard let recordingID = currentRecordingID else { return }
        
        stopTimers()
        
        if let recordedFiles = await recordingCoordinator.stopRecording() {
            await handleSuccessfulRecordingStop(
                recordingID: recordingID,
                recordedFiles: recordedFiles
            )
        } else {
            await handleRecordingFailure(
                recordingID: recordingID,
                error: RecordingError.failedToStop
            )
        }
        
        updateRecordingUIState(started: false)
        currentRecordingID = nil
    }
    
    private func handleSuccessfulRecordingStop(
        recordingID: String,
        recordedFiles: RecordedFiles
    ) async {
        logRecordedFiles(recordedFiles)
        
        do {
            let hadMicrophone = isMicrophoneEnabled
            let finalRecordedFiles = (try? mergeSystemAndMicrophoneIfNeeded(recordedFiles)) ?? recordedFiles
            try await updateRecordingInRepository(
                recordingID: recordingID,
                recordedFiles: finalRecordedFiles,
                hasMicrophoneAudio: hadMicrophone
            )
            
            if let updatedRecording = try await recordingRepository.fetchRecording(id: recordingID) {
                await processingCoordinator.startProcessing(recordingInfo: updatedRecording)
            }
        } catch {
            logger.error("Failed to update recording after stop: \(error)")
            await handleRecordingFailure(recordingID: recordingID, error: error)
        }
    }
    
    private func updateRecordingInRepository(
        recordingID: String,
        recordedFiles: RecordedFiles,
        hasMicrophoneAudio: Bool
    ) async throws {
        if let systemAudioURL = recordedFiles.systemAudioURL {
            try await recordingRepository.updateRecordingURLs(
                id: recordingID,
                recordingURL: systemAudioURL,
                microphoneURL: recordedFiles.microphoneURL,
                hasMicrophoneAudio: hasMicrophoneAudio
            )
        } else if let micURL = recordedFiles.microphoneURL {
            try await recordingRepository.updateRecordingURLs(
                id: recordingID,
                recordingURL: micURL,
                microphoneURL: nil,
                hasMicrophoneAudio: true
            )
        }
        
        try await recordingRepository.updateRecordingEndDate(
            id: recordingID,
            endDate: Date()
        )
        
        try await recordingRepository.updateRecordingState(
            id: recordingID,
            state: .recorded,
            errorMessage: nil
        )
    }
    
    private func logRecordedFiles(_ recordedFiles: RecordedFiles) {
        if let systemAudioURL = recordedFiles.systemAudioURL {
            logger.info("Recording stopped successfully - System audio: \(systemAudioURL.path)")
        }
        if let microphoneURL = recordedFiles.microphoneURL {
            logger.info("Recording stopped successfully - Microphone: \(microphoneURL.path)")
        }
    }

    private func mergeSystemAndMicrophoneIfNeeded(_ recordedFiles: RecordedFiles) throws -> RecordedFiles {
        guard let systemURL = recordedFiles.systemAudioURL,
              let micURL = recordedFiles.microphoneURL,
              FileManager.default.fileExists(atPath: systemURL.path),
              FileManager.default.fileExists(atPath: micURL.path) else {
            return recordedFiles
        }

        let tempURL = systemURL.deletingPathExtension().appendingPathExtension("merged.wav")
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try AudioMerger.mergeSystemAndMicrophone(
            systemURL: systemURL,
            microphoneURL: micURL,
            outputURL: tempURL
        )

        try? FileManager.default.removeItem(at: systemURL)
        try FileManager.default.moveItem(at: tempURL, to: systemURL)
        try? FileManager.default.removeItem(at: micURL)

        logger.info("Merged system+microphone audio into: \(systemURL.path)")

        return RecordedFiles(
            microphoneURL: nil,
            systemAudioURL: systemURL,
            applicationName: recordedFiles.applicationName
        )
    }
}