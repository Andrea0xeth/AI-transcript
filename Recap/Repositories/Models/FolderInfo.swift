import Foundation

struct FolderInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let createdAt: Date
    let modifiedAt: Date
}

extension FolderInfo {
    init(from entity: Folder) {
        self.id = entity.id ?? UUID().uuidString
        self.name = entity.name ?? "Untitled"
        self.createdAt = entity.createdAt ?? Date()
        self.modifiedAt = entity.modifiedAt ?? Date()
    }
}
