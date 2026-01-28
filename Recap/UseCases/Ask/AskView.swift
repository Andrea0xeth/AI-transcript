import SwiftUI

struct AskView: View {
    @ObservedObject var viewModel: AskViewModel
    let preselectedRecordingID: String?
    let onClose: () -> Void

    init(
        viewModel: AskViewModel,
        preselectedRecordingID: String? = nil,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.preselectedRecordingID = preselectedRecordingID
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: UIConstants.Spacing.sectionSpacing) {
            header

            recordingsSelector

            questionInput

            optionsRow

            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else if let response = viewModel.response {
                responseView(response)
            } else if let error = viewModel.errorMessage {
                errorView(error)
            }

            Spacer()
        }
        .padding(UIConstants.Spacing.contentPadding)
        .frame(width: 640, height: 600)
        .background(UIConstants.Gradients.backgroundGradient)
        .onAppear {
            Task { await viewModel.loadRecordings(preselect: preselectedRecordingID) }
        }
    }

    private var header: some View {
        HStack {
            Text("Ask LLM")
                .foregroundColor(UIConstants.Colors.textPrimary)
                .font(UIConstants.Typography.appTitle)
            Spacer()
            PillButton(text: "Close", icon: "xmark") {
                onClose()
            }
        }
    }

    private var recordingsSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seleziona registrazioni")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(UIConstants.Colors.textSecondary)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(viewModel.recordings) { recording in
                        Button {
                            viewModel.toggleSelection(for: recording)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: viewModel.selectedRecordingIDs.contains(recording.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(UIConstants.Colors.textPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recording.applicationName ?? "Recording")
                                        .foregroundColor(UIConstants.Colors.textPrimary)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(DateFormatter.localizedString(from: recording.startDate, dateStyle: .medium, timeStyle: .short))
                                        .foregroundColor(UIConstants.Colors.textSecondary)
                                        .font(.system(size: 11))
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(UIConstants.Colors.cardBackground2)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 160)
        }
    }

    private var questionInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Domanda")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(UIConstants.Colors.textSecondary)
            TextEditor(text: $viewModel.question)
                .font(.system(size: 12))
                .foregroundColor(UIConstants.Colors.textPrimary)
                .frame(height: 90)
                .padding(6)
                .background(UIConstants.Colors.cardBackground2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var optionsRow: some View {
        HStack {
            Toggle("Salva risposta in file", isOn: $viewModel.saveResponseToFile)
                .toggleStyle(.switch)
                .font(.system(size: 12))
                .foregroundColor(UIConstants.Colors.textSecondary)

            Spacer()

            PillButton(text: "Ask", icon: "sparkles") {
                Task { await viewModel.ask() }
            }
        }
    }

    private func responseView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Risposta")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(UIConstants.Colors.textSecondary)
            ScrollView {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(UIConstants.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 150)
            .padding(8)
            .background(UIConstants.Colors.cardBackground2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func errorView(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundColor(.red.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
