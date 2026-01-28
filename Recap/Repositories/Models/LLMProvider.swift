import Foundation

enum LLMProvider: String, CaseIterable, Identifiable {
    case ollama = "ollama"
    case openRouter = "openrouter"
    case appleIntelligence = "appleintelligence"
    
    var id: String { rawValue }
    
    var providerName: String {
        switch self {
        case .ollama:
            return "Ollama"
        case .openRouter:
            return "OpenRouter"
        case .appleIntelligence:
            return "Apple Intelligence"
        }
    }
    
    static var `default`: LLMProvider {
        .ollama
    }
}
