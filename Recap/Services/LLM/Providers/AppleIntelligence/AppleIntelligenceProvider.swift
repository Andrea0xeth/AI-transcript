import Foundation
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class AppleIntelligenceProvider: LLMProviderType, LLMTaskManageable {
    typealias Model = AppleIntelligenceModel
    
    let name = "Apple Intelligence"
    
    private let availabilitySubject = CurrentValueSubject<Bool, Never>(false)
    
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }
    
    var availabilityPublisher: AnyPublisher<Bool, Never> {
        availabilitySubject.eraseToAnyPublisher()
    }
    
    var currentTask: Task<Void, Never>?
    
    init() {
        Task { @MainActor in
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                let available = SystemLanguageModel.default.availability == .available
                availabilitySubject.send(available)
            }
            #endif
        }
    }
    
    func checkAvailability() async -> Bool {
        isAvailable
    }
    
    func listModels() async throws -> [AppleIntelligenceModel] {
        guard isAvailable else {
            throw LLMError.providerNotAvailable
        }
        return [AppleIntelligenceModel.single]
    }
    
    func generateChatCompletion(
        modelName: String,
        messages: [LLMMessage],
        options: LLMOptions
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await generateWithFoundationModels(messages: messages)
        }
        #endif
        throw LLMError.providerNotAvailable
    }
    
    func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
    }
    
    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func generateWithFoundationModels(messages: [LLMMessage]) async throws -> String {
        try await executeWithTaskManagement {
            let instructions = messages.first { $0.role == .system }?.content ?? ""
            let userContent = messages.first { $0.role == .user }?.content ?? messages.map(\.content).joined(separator: "\n\n")
            
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: userContent)
            return response.content
        }
    }
    #endif
}
