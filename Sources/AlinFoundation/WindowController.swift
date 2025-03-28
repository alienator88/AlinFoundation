//
//  WindowController.swift
//  AlinFoundation
//
//  Created by Alin Lupascu on 11/19/24.
//
import AppKit
import SwiftUI

public class WindowManager {
    public static let shared = WindowManager()
    private var windows: [String: NSWindow] = [:]

    public init() {}

    // Open a new window with the specified SwiftUI view and optional size
    public func open<Content: View>(id: String = "window", with view: Content, width: CGFloat = 400, height: CGFloat = 300, material: NSVisualEffectView.Material? = nil) {
        // Show current open if already open
        if let existingWindow = windows[id], existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Close and nil out existing window
        windows[id]?.close()
        windows[id] = nil

        // Create a new window
        let hostingController = NSHostingController(rootView: view)
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.setContentSize(NSSize(width: width, height: height))
        newWindow.styleMask = [.titled, .closable, .fullSizeContentView]
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.level = .normal
        newWindow.isReleasedWhenClosed = false
        newWindow.center()

        if let material = material {
            setVisualEffectBackground(for: newWindow, material: material)
        }
        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
        windows[id] = newWindow
    }

    // Close the window if it exists
    public func close(id: String = "window") {
        windows[id]?.close()
        windows[id] = nil
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
