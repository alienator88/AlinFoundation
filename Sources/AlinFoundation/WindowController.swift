//
//  WindowController.swift
//  AlinFoundation
//
//  Created by Alin Lupascu on 11/19/24.
//
import AppKit
import SwiftUI

public class WindowManager {
    private var window: NSWindow?

    public init() {}

    // Open a new window with the specified SwiftUI view and optional size
    public func open<Content: View>(with view: Content, width: CGFloat = 400, height: CGFloat = 300, material: NSVisualEffectView.Material? = nil) {
        // Close and nil out existing window
        window?.close()
        window = nil

        // Create a new window
        let hostingController = NSHostingController(rootView: view)
        window = NSWindow(contentViewController: hostingController)
        window?.setContentSize(NSSize(width: width, height: height))
        window?.styleMask = [.titled, .closable, .fullSizeContentView]
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.isReleasedWhenClosed = false
        window?.center()

        if let material = material {
            setVisualEffectBackground(for: window!, material: material)
        }

        window?.makeKeyAndOrderFront(nil)
    }

    // Close the window if it exists
    public func close() {
        window?.close()
        window = nil
    }

    // Helper to set a visual effect background
    private func setVisualEffectBackground(for window: NSWindow, material: NSVisualEffectView.Material) {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active

        // Create a container view to hold both the visual effect view and the content
        let containerView = NSView(frame: window.contentView?.bounds ?? .zero)
        containerView.autoresizingMask = [.width, .height]

        visualEffectView.frame = containerView.bounds
        visualEffectView.autoresizingMask = [.width, .height]
        containerView.addSubview(visualEffectView, positioned: .below, relativeTo: nil)

        // Add the existing content view on top of the visual effect view
        if let existingContentView = window.contentView {
            existingContentView.frame = containerView.bounds
            existingContentView.autoresizingMask = [.width, .height]
            containerView.addSubview(existingContentView, positioned: .above, relativeTo: visualEffectView)
        }

        // Set the container view as the new content view
        window.contentView = containerView
    }
}
