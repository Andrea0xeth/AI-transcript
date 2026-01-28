//
//  RecapView.swift
//  Recap
//
//  Created by Rawand Ahmad on 25/07/2025.
//

import SwiftUI

struct RecapHomeView: View {
    @ObservedObject private var viewModel: RecapViewModel
    
    init(viewModel: RecapViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                UIConstants.Gradients.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header sempre visibile in alto: titolo a sinistra, pulsante "Apri a schermo intero" a destra
                    HStack(alignment: .center, spacing: 12) {
                        Text("Recap")
                            .foregroundColor(UIConstants.Colors.textPrimary)
                            .font(UIConstants.Typography.appTitle)
                            .padding(.leading, UIConstants.Spacing.contentPadding)

                        Spacer(minLength: 0)

                        Button {
                            viewModel.openExpandedWindow()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Schermo intero")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(UIConstants.Colors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(UIConstants.Colors.cardBackground2)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Apri Recap in una finestra ridimensionabile o a schermo intero")
                        .padding(.trailing, UIConstants.Spacing.contentPadding)
                    }
                    .frame(height: 52)
                    .frame(maxWidth: .infinity)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: UIConstants.Spacing.sectionSpacing) {
                        ForEach(viewModel.activeWarnings, id: \.id) { warning in
                            WarningCard(warning: warning, containerWidth: geometry.size.width)
                                .padding(.horizontal, UIConstants.Spacing.contentPadding)
                        }
                        
                        Text("SORGENTI AUDIO")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(UIConstants.Colors.textSecondary)
                            .padding(.horizontal, UIConstants.Spacing.contentPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: UIConstants.Spacing.cardSpacing) {
                            HeatmapCard(
                                title: "System Audio",
                                containerWidth: geometry.size.width,
                                isSelected: true,
                                audioLevel: viewModel.systemAudioHeatmapLevel,
                                isInteractionEnabled: !viewModel.isRecording,
                                onToggle: { }
                            )
                            HeatmapCard(
                                title: "Microphone", 
                                containerWidth: geometry.size.width,
                                isSelected: viewModel.isMicrophoneEnabled,
                                audioLevel: viewModel.microphoneHeatmapLevel,
                                isInteractionEnabled: !viewModel.isRecording,
                                onToggle: { 
                                    viewModel.toggleMicrophone()
                                }
                            )
                        }
                        
                        Text("Recap registra l’audio di sistema (tutte le app) e, se attivo, anche il microfono.")
                            .font(.caption)
                            .foregroundColor(UIConstants.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, UIConstants.Spacing.contentPadding)
                            .padding(.top, 4)
                        
                        Text("REGISTRAZIONE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(UIConstants.Colors.textSecondary)
                            .padding(.horizontal, UIConstants.Spacing.contentPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: UIConstants.Spacing.cardSpacing) {
                            CustomReflectionCard(
                                containerWidth: geometry.size.width,
                                isRecording: viewModel.isRecording,
                                recordingDuration: viewModel.recordingDuration,
                                canStartRecording: viewModel.canStartRecording,
                                onToggleRecording: {
                                    Task {
                                        if viewModel.isRecording {
                                            await viewModel.stopRecording()
                                        } else {
                                            await viewModel.startRecording()
                                        }
                                    }
                                }
                            )

                            TranscriptionCard(containerWidth: geometry.size.width) {
                                viewModel.openView()
                            }
                            
                            Text("AZIONI RAPIDE")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(UIConstants.Colors.textSecondary)
                                .padding(.horizontal, UIConstants.Spacing.contentPadding)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: UIConstants.Spacing.cardSpacing) {
                                InformationCard(
                                    icon: "list.bullet.indent",
                                    title: "Previous Recaps", 
                                    description: "View past recordings",
                                    containerWidth: geometry.size.width
                                )
                                .onTapGesture {
                                    viewModel.openPreviousRecaps()
                                }
                                
                                InformationCard(
                                    icon: "gear",
                                    title: "Settings",
                                    description: "App preferences",
                                    containerWidth: geometry.size.width
                                )
                                .onTapGesture {
                                    viewModel.openSettings()
                                }
                            }
                        }
                        
                        Spacer(minLength: UIConstants.Spacing.sectionSpacing)
                        }
                    }
                }
            }
        }
        .toast(isPresenting: $viewModel.showErrorToast) {
            AlertToast(
                displayMode: .banner(.slide),
                type: .error(.red),
                title: "Recording Error",
                subTitle: viewModel.errorMessage
            )
        }
    }
}

#Preview {
    let viewModel = RecapViewModel.createForPreview()
    
    return RecapHomeView(viewModel: viewModel)
        .frame(width: 500, height: 500)
}
