import Foundation
import Combine

@MainActor
final class AskViewModel: ObservableObject {
    @Published private(set) var recordings: [RecordingInfo] = []
    @Published var selectedRecordingIDs = Set<String>()
    @Published var question = ""
    @Published var response: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var saveResponseToFile = false

    private let recordingRepository: RecordingRepositoryType
    private let llmService: LLMServiceType

    init(recordingRepository: RecordingRepositoryType, llmService: LLMServiceType) {
        self.recordingRepository = recordingRepository
        self.llmService = llmService
    }

    func loadRecordings(preselect recordingID: String? = nil) async {
        do {
            recordings = try await recordingRepository.fetchAllRecordings()
            if let recordingID = recordingID {
                selectedRecordingIDs.insert(recordingID)
            } else if let first = recordings.first {
                selectedRecordingIDs.insert(first.id)
            }
        } catch {
            errorMessage = "Failed to load recordings: \(error.localizedDescription)"
        }
    }

    func toggleSelection(for recording: RecordingInfo) {
        if selectedRecordingIDs.contains(recording.id) {
            selectedRecordingIDs.remove(recording.id)
        } else {
            selectedRecordingIDs.insert(recording.id)
        }
    }

    func ask() async {
        errorMessage = nil
        response = nil
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            errorMessage = "Inserisci una domanda."
            return
        }

        let selectedRecordings = recordings.filter { selectedRecordingIDs.contains($0.id) }
        guard !selectedRecordings.isEmpty else {
            errorMessage = "Seleziona almeno una registrazione."
            return
        }

        let contextText = buildContext(from: selectedRecordings)
        guard !contextText.isEmpty else {
            errorMessage = "Le registrazioni selezionate non hanno trascrizioni disponibili."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let systemPrompt = "Sei un assistente utile. Rispondi alla domanda usando solo il contesto fornito e la cronologia chat. Se l'informazione non è presente, dillo chiaramente."
            let history = buildChatHistory(from: selectedRecordings)
            let userPrompt = """
            Domanda:
            \(trimmedQuestion)

            Contesto:
            \(contextText)

            Cronologia:
            \(history)
            """
            let answer = try await llmService.generateChat(
                messages: [
                    LLMMessage(role: .system, content: systemPrompt),
                    LLMMessage(role: .user, content: userPrompt)
                ],
                options: nil
            )
            response = answer

            try appendChat(answer: answer, question: trimmedQuestion, recordings: selectedRecordings)
            if saveResponseToFile {
                try saveResponse(answer, question: trimmedQuestion, recordings: selectedRecordings)
            }
        } catch {
            errorMessage = "Errore LLM: \(error.localizedDescription)"
        }
    }

    private func buildContext(from recordings: [RecordingInfo]) -> String {
        recordings.compactMap { recording in
            let transcript = recording.transcriptionText?.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = recording.summaryText?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (transcript?.isEmpty == false) || (summary?.isEmpty == false) else { return nil }
            let title = recording.applicationName ?? "Recording"
            let date = DateFormatter.localizedString(from: recording.startDate, dateStyle: .medium, timeStyle: .short)
            var block = "[\(title) • \(date)]\n"
            if let summary, !summary.isEmpty {
                block += "Summary:\n\(summary)\n"
            }
            if let transcript, !transcript.isEmpty {
                block += "\nTranscript:\n\(transcript)"
            }
            return block
        }.joined(separator: "\n\n---\n\n")
    }

    private func buildChatHistory(from recordings: [RecordingInfo]) -> String {
        recordings.compactMap { recording in
            let fileURL = chatFileURL(for: recording)
            guard let content = try? String(contentsOf: fileURL), !content.isEmpty else { return nil }
            let title = recording.applicationName ?? "Recording"
            let date = DateFormatter.localizedString(from: recording.startDate, dateStyle: .medium, timeStyle: .short)
            return "[\(title) • \(date)]\n\(content)"
        }.joined(separator: "\n\n---\n\n")
    }

    private func saveResponse(_ answer: String, question: String, recordings: [RecordingInfo]) throws {
        guard let first = recordings.first else { return }
        let directory = first.recordingURL.deletingLastPathComponent()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "ask_\(formatter.string(from: Date())).md"
        let fileURL = directory.appendingPathComponent(filename)

        let content = """
        # Ask LLM

        ## Domanda
        \(question)

        ## Risposta
        \(answer)
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func appendChat(answer: String, question: String, recordings: [RecordingInfo]) throws {
        guard let first = recordings.first else { return }
        let fileURL = chatFileURL(for: first)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let entry = """

        ### \(timestamp)
        **Q:** \(question)

        **A:** \(answer)

        """
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            if let data = entry.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
            try handle.close()
        } else {
            let header = "# Chat\n"
            try (header + entry).write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    private func chatFileURL(for recording: RecordingInfo) -> URL {
        let directory = recording.recordingURL.deletingLastPathComponent()
        return directory.appendingPathComponent("chat.md")
    }
}
