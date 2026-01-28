import Foundation

struct AppleIntelligenceModel: LLMModelType {
    let id: String
    let name: String
    let provider: String
    let contextLength: Int32?
    
    static let single = AppleIntelligenceModel(
        id: "apple-intelligence-default",
        name: "Apple Intelligence",
        provider: "Apple Intelligence",
        contextLength: 8192
    )
    
    init(id: String = "apple-intelligence-default",
         name: String = "Apple Intelligence",
         provider: String = "Apple Intelligence",
         contextLength: Int32? = 8192) {
        self.id = id
        self.name = name
        self.provider = provider
        self.contextLength = contextLength
    }
}
