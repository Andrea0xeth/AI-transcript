//
//  ReflectionCard.swift
//  Recap
//
//  Created by Rawand Ahmad on 25/07/2025.
//

import SwiftUI

struct CustomReflectionCard: View {
    let containerWidth: CGFloat
    let isRecording: Bool
    let recordingDuration: TimeInterval
    let canStartRecording: Bool
    let onToggleRecording: () -> Void
    
    init(
        containerWidth: CGFloat, 
        isRecording: Bool,
        recordingDuration: TimeInterval,
        canStartRecording: Bool,
        onToggleRecording: @escaping () -> Void
    ) {
        self.containerWidth = containerWidth
        self.isRecording = isRecording
        self.recordingDuration = recordingDuration
        self.canStartRecording = canStartRecording
        self.onToggleRecording = onToggleRecording
    }

    var body: some View {
        CardBackground(
            width: UIConstants.Layout.fullCardWidth(containerWidth: containerWidth),
            height: 60,
            backgroundColor: UIConstants.Colors.cardBackground2,
            borderGradient: isRecording ? UIConstants.Gradients.reflectionBorderRecording : UIConstants.Gradients.reflectionBorder
        )
        .overlay(
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(UIConstants.Colors.textPrimary)
                    Text("System Audio")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(UIConstants.Colors.textPrimary)
                    Text("ON")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(UIConstants.Colors.audioGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(UIConstants.Colors.cardSecondaryBackground)
                        .clipShape(Capsule())
                }
                .padding(.leading, UIConstants.Spacing.cardSpacing)
                
                Spacer()
                
                RecordingButton(
                    isRecording: isRecording,
                    recordingDuration: recordingDuration,
                    isEnabled: canStartRecording,
                    onToggleRecording: onToggleRecording
                )
                .padding(.trailing, UIConstants.Spacing.cardSpacing)
            }
        )
        .animation(.easeInOut(duration: 0.3), value: isRecording)
    }
}
