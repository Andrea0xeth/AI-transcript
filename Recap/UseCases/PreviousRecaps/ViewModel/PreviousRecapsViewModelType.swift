import Foundation

@MainActor
protocol PreviousRecapsViewModelType: ObservableObject {
    var groupedRecordings: GroupedRecordings { get }
    var folders: [FolderInfo] { get }
    var selectedFolderID: String? { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    
    func loadRecordings() async
    func selectFolder(_ folderID: String?)
    func createFolder(name: String) async
    func startAutoRefresh()
    func stopAutoRefresh()
}