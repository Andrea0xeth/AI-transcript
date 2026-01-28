import Foundation

extension RecapViewModel {
    func startTimers() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 1
            }
        }

        let levelTick = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevels()
            }
        }
        RunLoop.main.add(levelTick, forMode: .common)
        levelTimer = levelTick
    }
    
    func stopTimers() {
        timer?.invalidate()
        timer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    func updateAudioLevels() {
        microphoneLevel = recordingCoordinator.currentAudioLevel
        
        if let currentCoordinator = recordingCoordinator.getCurrentRecordingCoordinator() {
            systemAudioLevel = currentCoordinator.currentSystemAudioLevel
        }
    }
}