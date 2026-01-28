import Foundation
import CoreData

struct UserPreferencesInfo: Identifiable {
    let id: String
    let selectedLLMModelID: String?
    let selectedMicrophoneUID: String?
    let selectedProvider: LLMProvider
    let autoSummarizeEnabled: Bool
    let autoDetectMeetings: Bool
    let autoStopRecording: Bool
    let onboarded: Bool
    let summaryPromptTemplate: String?
    let createdAt: Date
    let modifiedAt: Date

    init(from managedObject: UserPreferences) {
        self.id = managedObject.id ?? UUID().uuidString
        self.selectedLLMModelID = managedObject.selectedLLMModelID
        self.selectedMicrophoneUID = managedObject.selectedMicrophoneUID
        self.selectedProvider = LLMProvider(rawValue: managedObject.selectedProvider ?? LLMProvider.default.rawValue) ?? LLMProvider.default
        self.autoSummarizeEnabled = managedObject.autoSummarizeEnabled
        self.autoDetectMeetings = managedObject.autoDetectMeetings
        self.autoStopRecording = managedObject.autoStopRecording
        self.onboarded = managedObject.onboarded
        self.summaryPromptTemplate = managedObject.summaryPromptTemplate
        self.createdAt = managedObject.createdAt ?? Date()
        self.modifiedAt = managedObject.modifiedAt ?? Date()
    }

    
    init(
        id: String = UUID().uuidString,
        selectedLLMModelID: String? = nil,
        selectedMicrophoneUID: String? = nil,
        selectedProvider: LLMProvider = .default,
        autoSummarizeEnabled: Bool = true,
        autoDetectMeetings: Bool = false,
        autoStopRecording: Bool = false,
        onboarded: Bool = false,
        summaryPromptTemplate: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.selectedLLMModelID = selectedLLMModelID
        self.selectedMicrophoneUID = selectedMicrophoneUID
        self.selectedProvider = selectedProvider
        self.autoSummarizeEnabled = autoSummarizeEnabled
        self.autoDetectMeetings = autoDetectMeetings
        self.autoStopRecording = autoStopRecording
        self.onboarded = onboarded
        self.summaryPromptTemplate = summaryPromptTemplate
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    static var defaultPromptTemplate: String {
        """
        Sei un assistente che riassume riunioni. Produci un riassunto dettagliato in Markdown della trascrizione sotto.

        Regole:
        - Rispondi sempre in italiano.
        - Usa solo Markdown: titoli (##), elenchi puntati, grassetto per i termini chiave.
        - Sii conciso ma completo: nessun fronzio, solo contenuto utile.

        Struttura obbligatoria del riassunto (usa esattamente questi titoli di sezione):

        ## Argomenti principali
        Elenco dei temi affrontati, in ordine di rilevanza. Per ciascuno: 1–2 righe di contesto.

        ## Decisioni prese
        Ogni decisione in un punto elenco, in forma chiara e assertiva (es. "Si è deciso di...").

        ## Azioni da intraprendere
        Per ogni action item indica: chi (se menzionato), cosa fare, eventuale scadenza. Usa elenco puntato.

        ## Prossimi step (opzionale)
        Solo se emergono impegni o follow-up senza responsabile esplicito.

        Trascrizione da riassumere:
        """
    }
}
