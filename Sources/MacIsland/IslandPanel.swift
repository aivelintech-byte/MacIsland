import AppKit
import SwiftUI

final class IslandPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = false
        isMovable = false

        let host = NSHostingView(rootView: IslandView())
        host.frame = NSRect(x: 0, y: 0, width: 420, height: 80)
        contentView = host

        positionAtTopCenter()
    }

    private func positionAtTopCenter() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let panelWidth: CGFloat = 420
        let panelHeight: CGFloat = 80
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.maxY - panelHeight
        setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: false)
    }
}
