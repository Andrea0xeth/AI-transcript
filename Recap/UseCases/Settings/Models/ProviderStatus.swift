import Foundation

struct ProviderStatus {
    let name: String
    let isAvailable: Bool
    let statusMessage: String
    
    static func ollama(isAvailable: Bool) -> ProviderStatus {
        ProviderStatus(
            name: "Ollama",
            isAvailable: isAvailable,
            statusMessage: isAvailable 
                ? "Connected to Ollama at localhost:11434"
                : "Ollama not detected. Please install and run Ollama from https://ollama.ai"
        )
    }
    
    static func openRouter(isAvailable: Bool) -> ProviderStatus {
        ProviderStatus(
            name: "OpenRouter",
            isAvailable: isAvailable,
            statusMessage: isAvailable
                ? "Connected to OpenRouter"
                : "Cannot connect to OpenRouter. Check your internet connection and API key."
        )
    }
    
    static func appleIntelligence(isAvailable: Bool) -> ProviderStatus {
        ProviderStatus(
            name: "Apple Intelligence",
            isAvailable: isAvailable,
            statusMessage: isAvailable
                ? "Using on-device Apple Intelligence (macOS 26+)"
                : "Requires macOS 26+ and Apple Intelligence enabled in System Settings."
        )
    }
}