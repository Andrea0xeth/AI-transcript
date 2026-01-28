import Foundation

struct RecordingConfiguration {
    let id: String
    /// Se nil, viene registrato l'audio di sistema in modalità globale (se abilitato).
    let audioProcess: AudioProcess?
    /// Se true registra tutto l'audio di sistema (non solo una singola app).
    let captureSystemAudio: Bool
    let enableMicrophone: Bool
    let baseURL: URL
    
    var expectedFiles: RecordedFiles {
        let systemURL = captureSystemAudio ? baseURL.appendingPathComponent("audio.wav") : nil
        let micURL = (captureSystemAudio ? nil : enableMicrophone ? baseURL.appendingPathComponent("microphone.wav") : nil)
        return RecordedFiles(
            microphoneURL: micURL,
            systemAudioURL: systemURL,
            applicationName: audioProcess?.name ?? (captureSystemAudio ? "System Audio" : nil)
        )
    }
}