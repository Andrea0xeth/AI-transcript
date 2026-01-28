import Foundation

protocol RecordingFileManaging {
    func createRecordingURL() -> URL
    func createRecordingBaseURL(for recordingID: String) -> URL
    func ensureRecordingsDirectoryExists() throws
}

final class RecordingFileManager: RecordingFileManaging {
    private let recordingsDirectoryName = "Recordings"
    private let appDirectoryName = "Recap"
    
    func createRecordingURL() -> URL {
        let timestamp = Date().timeIntervalSince1970
        let filename = "recap_recording_\(Int(timestamp))"
        
        return recordingsDirectory
            .appendingPathComponent(filename)
            .appendingPathExtension("wav")
    }
    
    func createRecordingBaseURL(for recordingID: String) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let folderName = "\(timestamp)_\(recordingID)"

        let sessionDirectory = recordingsDirectory
            .appendingPathComponent(folderName)

        try? FileManager.default.createDirectory(
            at: sessionDirectory,
            withIntermediateDirectories: true
        )

        return sessionDirectory
    }
    
    func ensureRecordingsDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: recordingsDirectory,
            withIntermediateDirectories: true
        )
    }
    
    private var recordingsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent(appDirectoryName)
            .appendingPathComponent(recordingsDirectoryName)
    }
}