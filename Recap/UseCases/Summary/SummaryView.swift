import SwiftUI
import MarkdownUI

struct SummaryView<ViewModel: SummaryViewModelType>: View {
    let onClose: () -> Void
    @ObservedObject var viewModel: ViewModel
    @ObservedObject var askViewModel: AskViewModel
    let recordingID: String?
    @State private var showingAsk = false
    @State private var showingCreateFolder = false
    @State private var newFolderName = ""
    
    init(
        onClose: @escaping () -> Void,
        viewModel: ViewModel,
        askViewModel: AskViewModel,
        recordingID: String? = nil
    ) {
        self.onClose = onClose
        self.viewModel = viewModel
        self.askViewModel = askViewModel
        self.recordingID = recordingID
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                UIConstants.Gradients.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: UIConstants.Spacing.sectionSpacing) {
                    headerView
                    folderRow
                    
                    if viewModel.isLoadingRecording {
                        loadingView
                    } else if let errorMessage = viewModel.errorMessage {
                        errorView(errorMessage)
                    } else if viewModel.currentRecording == nil {
                        noRecordingView
                    } else if viewModel.isProcessing {
                        processingView(geometry: geometry)
                    } else if viewModel.hasSummary {
                        summaryView
                    } else {
                        errorView(viewModel.currentRecording?.errorMessage ?? "Recording is in an unexpected state")
                    }
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            if let recordingID = recordingID {
                viewModel.loadRecording(withID: recordingID)
            } else {
                viewModel.loadLatestRecording()
            }
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .toast(isPresenting: .init(
            get: { viewModel.showingCopiedToast },
            set: { _ in }
        )) {
            AlertToast(
                displayMode: .banner(.pop),
                type: .complete(UIConstants.Colors.audioGreen),
                title: "Copied to clipboard"
            )
        }
        .sheet(isPresented: $showingAsk) {
            AskView(
                viewModel: askViewModel,
                preselectedRecordingID: recordingID ?? viewModel.currentRecording?.id,
                onClose: { showingAsk = false }
            )
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Summary")
                .foregroundColor(UIConstants.Colors.textPrimary)
                .font(UIConstants.Typography.appTitle)
                .padding(.leading, UIConstants.Spacing.contentPadding)
                .padding(.top, UIConstants.Spacing.sectionSpacing)
            
            Spacer()
            
            closeButton
                .padding(.trailing, UIConstants.Spacing.contentPadding)
                .padding(.top, UIConstants.Spacing.sectionSpacing)
        }
    }
    
    private var closeButton: some View {
        PillButton(text: "Close", icon: "xmark") {
            onClose()
        }
    }

    private var folderRow: some View {
        HStack {
            Menu {
                Button("No Folder") {
                    Task { await viewModel.selectFolder(nil) }
                }
                if !viewModel.folders.isEmpty {
                    Divider()
                }
                ForEach(viewModel.folders) { folder in
                    Button(folder.name) {
                        Task { await viewModel.selectFolder(folder.id) }
                    }
                }
                Divider()
                Button("New Folder…") {
                    showingCreateFolder = true
                }
            } label: {
                PillButton(text: folderLabel, icon: "folder") { }
            }
            Spacer()
        }
        .padding(.horizontal, UIConstants.Spacing.contentPadding)
        .alert("Create Folder", isPresented: $showingCreateFolder) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                Task { await viewModel.createFolder(name: trimmed) }
                newFolderName = ""
            }
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
        } message: {
            Text("Create a new folder to organize this recording.")
        }
    }

    private var folderLabel: String {
        if let selectedFolderID = viewModel.selectedFolderID,
           let folder = viewModel.folders.first(where: { $0.id == selectedFolderID }) {
            return folder.name
        }
        return "No Folder"
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text("Loading recording...")
                .font(UIConstants.Typography.bodyText)
                .foregroundColor(UIConstants.Colors.textSecondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.8))
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(UIConstants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, UIConstants.Spacing.contentPadding)

            if viewModel.currentRecording != nil {
                SummaryActionButton(
                    text: "Retry",
                    icon: "arrow.clockwise"
                ) {
                    Task {
                        await viewModel.retryProcessing()
                    }
                }
                .padding(.top, 6)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var noRecordingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash")
                .font(.system(size: 48))
                .foregroundColor(UIConstants.Colors.textTertiary)
            
            Text("No recordings found")
                .font(.system(size: 14))
                .foregroundColor(UIConstants.Colors.textSecondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func processingView(geometry: GeometryProxy) -> some View {
        VStack(spacing: UIConstants.Spacing.sectionSpacing) {
            if let stage = viewModel.processingStage {
                ProcessingStatesCard(
                    containerWidth: geometry.size.width,
                    currentStage: stage
                )
                .padding(.horizontal, UIConstants.Spacing.contentPadding)
            }
            
            Spacer()
        }
    }
    
    private var summaryView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: UIConstants.Spacing.cardSpacing) {
                    if let recording = viewModel.currentRecording,
                       let summaryText = recording.summaryText {
                        
                        VStack(alignment: .leading, spacing: UIConstants.Spacing.cardInternalSpacing) {
                            Text("Summary")
                                .font(UIConstants.Typography.infoCardTitle)
                                .foregroundColor(UIConstants.Colors.textPrimary)
                            
                            Markdown(summaryText)
                                .markdownTheme(.docC)
                                .markdownTextStyle {
                                    ForegroundColor(UIConstants.Colors.textSecondary)
                                    FontSize(12)
                                }
                                .markdownBlockStyle(\.heading1) { configuration in
                                    configuration.label
                                        .markdownTextStyle {
                                            FontWeight(.bold)
                                            FontSize(18)
                                            ForegroundColor(UIConstants.Colors.textPrimary)
                                        }
                                        .padding(.vertical, 8)
                                }
                                .markdownBlockStyle(\.heading2) { configuration in
                                    configuration.label
                                        .markdownTextStyle {
                                            FontWeight(.semibold)
                                            FontSize(16)
                                            ForegroundColor(UIConstants.Colors.textPrimary)
                                        }
                                        .padding(.vertical, 6)
                                }
                                .markdownBlockStyle(\.heading3) { configuration in
                                    configuration.label
                                        .markdownTextStyle {
                                            FontWeight(.medium)
                                            FontSize(14)
                                            ForegroundColor(UIConstants.Colors.textPrimary)
                                        }
                                        .padding(.vertical, 4)
                                }
                                .markdownBlockStyle(\.listItem) { configuration in
                                    configuration.label
                                        .markdownTextStyle {
                                            FontSize(12)
                                        }
                                }
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, UIConstants.Spacing.contentPadding)
                        .padding(.vertical, UIConstants.Spacing.cardSpacing)
                        .padding(.bottom, 80)
                    }

                    if let recording = viewModel.currentRecording,
                       let transcript = recording.transcriptionText,
                       !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: UIConstants.Spacing.cardInternalSpacing) {
                            Text("Transcript")
                                .font(UIConstants.Typography.infoCardTitle)
                                .foregroundColor(UIConstants.Colors.textPrimary)

                            Text(transcript)
                                .font(.system(size: 12))
                                .foregroundColor(UIConstants.Colors.textSecondary)
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, UIConstants.Spacing.contentPadding)
                        .padding(.bottom, 80)
                    }
                }
            }
            
            summaryActionButtons
        }
    }
    
    private var summaryActionButtons: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SummaryActionButton(
                    text: "Copy",
                    icon: "doc.on.doc"
                ) {
                    viewModel.copySummary()
                }
                
                SummaryActionButton(
                    text: "Ask",
                    icon: "sparkles"
                ) {
                    showingAsk = true
                }

                SummaryActionButton(
                    text: "Open in Finder",
                    icon: "folder"
                ) {
                    viewModel.openInFinder()
                }

                SummaryActionButton(
                    text: retryButtonText,
                    icon: "arrow.clockwise"
                ) {
                    Task {
                        await viewModel.retryProcessing()
                    }
                }
            }
            .padding(.horizontal, UIConstants.Spacing.cardPadding)
            .padding(.top, UIConstants.Spacing.cardPadding)
            .padding(.bottom, UIConstants.Spacing.cardInternalSpacing)
        }
        .background(UIConstants.Gradients.summaryButtonBackground)
        .cornerRadius(UIConstants.Sizing.cornerRadius)
    }
    
    private var retryButtonText: String {
        guard let recording = viewModel.currentRecording else { return "Retry Summarization" }
        
        switch recording.state {
        case .transcriptionFailed:
            return "Retry"
        default:
            return "Retry Summarization"
        }
    }
}
