import Foundation

@MainActor
protocol SummaryViewModelType: ObservableObject {
    var currentRecording: RecordingInfo? { get }
    var isLoadingRecording: Bool { get }
    var errorMessage: String? { get }
    var processingStage: ProcessingStatesCard.ProcessingStage? { get }
    var isProcessing: Bool { get }
    var hasSummary: Bool { get }
    var showingCopiedToast: Bool { get }
    var folders: [FolderInfo] { get }
    var selectedFolderID: String? { get }
    
    func loadRecording(withID recordingID: String)
    func loadLatestRecording()
    func loadFolders() async
    func selectFolder(_ folderID: String?) async
    func createFolder(name: String) async
    func retryProcessing() async
    func startAutoRefresh()
    func stopAutoRefresh()
    func copySummary()
    func openInFinder()
}