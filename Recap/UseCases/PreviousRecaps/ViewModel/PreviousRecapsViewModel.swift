import Foundation
import SwiftUI

struct GroupedRecordings {
    let todayRecordings: [RecordingInfo]
    let thisWeekRecordings: [RecordingInfo]
    let allRecordings: [RecordingInfo]
    
    var isEmpty: Bool {
        todayRecordings.isEmpty && thisWeekRecordings.isEmpty && allRecordings.isEmpty
    }
}

@MainActor
final class PreviousRecapsViewModel: PreviousRecapsViewModelType {
    @Published private(set) var groupedRecordings = GroupedRecordings(
        todayRecordings: [],
        thisWeekRecordings: [],
        allRecordings: []
    )
    @Published private(set) var folders: [FolderInfo] = []
    @Published private(set) var selectedFolderID: String?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let recordingRepository: RecordingRepositoryType
    private var refreshTimer: Timer?
    
    init(recordingRepository: RecordingRepositoryType) {
        self.recordingRepository = recordingRepository
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stopAutoRefresh()
        }
    }
    
    func loadRecordings() async {
        do {
            let allRecordings = try await recordingRepository.fetchAllRecordings()
            folders = try await recordingRepository.fetchFolders()
            let filteredRecordings = filterRecordings(allRecordings)
            withAnimation(.easeInOut(duration: 0.3)) {
                groupedRecordings = groupRecordingsByTimePeriod(filteredRecordings)
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = "Failed to load recordings: \(error.localizedDescription)"
            }
        }
    }

    func selectFolder(_ folderID: String?) {
        selectedFolderID = folderID
        Task { await loadRecordings() }
    }

    func createFolder(name: String) async {
        do {
            _ = try await recordingRepository.createFolder(name: name)
            await loadRecordings()
        } catch {
            errorMessage = "Failed to create folder: \(error.localizedDescription)"
        }
    }

    private func filterRecordings(_ recordings: [RecordingInfo]) -> [RecordingInfo] {
        guard let selectedFolderID = selectedFolderID else { return recordings }
        return recordings.filter { $0.folderID == selectedFolderID }
    }
    
    private func groupRecordingsByTimePeriod(_ recordings: [RecordingInfo]) -> GroupedRecordings {
        let calendar = Calendar.current
        let now = Date()
        
        let todayStart = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? todayStart
        
        var todayRecordings: [RecordingInfo] = []
        var thisWeekRecordings: [RecordingInfo] = []
        var allRecordings: [RecordingInfo] = []
        
        for recording in recordings {
            let recordingDate = recording.createdAt
            
            if calendar.isDate(recordingDate, inSameDayAs: now) {
                todayRecordings.append(recording)
            } else if recordingDate >= weekStart && recordingDate < todayStart {
                thisWeekRecordings.append(recording)
            } else {
                allRecordings.append(recording)
            }
        }
        
        return GroupedRecordings(
            todayRecordings: todayRecordings.sorted { $0.createdAt > $1.createdAt },
            thisWeekRecordings: thisWeekRecordings.sorted { $0.createdAt > $1.createdAt },
            allRecordings: allRecordings.sorted { $0.createdAt > $1.createdAt }
        )
    }
    
    func startAutoRefresh() {
        stopAutoRefresh()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.loadRecordings()
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
