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
            let systemPrompt = "Sei un assistente utile. Rispondi alla domanda usando solo il contesto fornito. Se l'informazione non è presente, dillo chiaramente."
            let userPrompt = "Domanda:\n\(trimmedQuestion)\n\nContesto:\n\(contextText)"
            let answer = try await llmService.generateChat(
                messages: [
                    LLMMessage(role: .system, content: systemPrompt),
                    LLMMessage(role: .user, content: userPrompt)
                ],
                options: nil
            )
            response = answer

            if saveResponseToFile {
                try saveResponse(answer, question: trimmedQuestion, recordings: selectedRecordings)
            }
        } catch {
            errorMessage = "Errore LLM: \(error.localizedDescription)"
        }
    }

    private func buildContext(from recordings: [RecordingInfo]) -> String {
        recordings.compactMap { recording in
            let text = recording.transcriptionText?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let text, !text.isEmpty else { return nil }
            let title = recording.applicationName ?? "Recording"
            let date = DateFormatter.localizedString(from: recording.startDate, dateStyle: .medium, timeStyle: .short)
            return "[\(title) • \(date)]\n\(text)"
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
}
