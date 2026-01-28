import SwiftUI
import AppKit

@MainActor
final class ExpandedWindowManager: NSObject, ObservableObject {
    private var expandedWindow: NSWindow?
    private let defaultWidth: CGFloat = 520
    private let defaultHeight: CGFloat = 640
    private let minWidth: CGFloat = 400
    private let minHeight: CGFloat = 500

    func showExpandedWindow(
        recapViewModel: RecapViewModel,
        onClose: @escaping () -> Void
    ) {
        if let existing = expandedWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = RecapHomeView(viewModel: recapViewModel)
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.wantsLayer = true

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.title = "Recap"
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: minWidth, height: minHeight)
        window.collectionBehavior = [.fullScreenPrimary, .fullScreenNone]
        window.delegate = self

        centeredFrame(for: window).map { window.setFrame($0, display: true) }

        expandedWindow = window
        self.onClose = onClose

        window.makeKeyAndOrderFront(nil)
    }

    private var onClose: (() -> Void)?

    private func centeredFrame(for window: NSWindow) -> NSRect? {
        guard let screen = NSScreen.main else { return nil }
        let screenFrame = screen.visibleFrame
        let w = min(defaultWidth, screenFrame.width)
        let h = min(defaultHeight, screenFrame.height)
        let x = screenFrame.midX - w / 2
        let y = screenFrame.midY - h / 2
        return NSRect(x: x, y: y, width: w, height: h)
    }

    func hideExpandedWindow() {
        expandedWindow?.close()
    }
}

extension ExpandedWindowManager: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            onClose?()
            onClose = nil
            expandedWindow = nil
        }
    }
}
