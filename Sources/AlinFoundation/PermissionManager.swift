//
//  PermissionManager.swift
//  
//
//  Created by Alin Lupascu on 7/10/24.
//

import Foundation
import AppKit
import SwiftUI

//MARK: PermissionManager - check some permissions

/// PermissionManager.checkPermissions(types: [.fullDiskAccess, .accessibility]) { results in
///     if results.allCheckedPermissionsGranted {
///         print("All requested permissions are granted")
///     } else {
///         print("Some permissions are missing")
///         // Show the PermissionsNotificationView
///     }
/// }

public struct PermissionManager {
    public enum PermissionType {
        case fullDiskAccess
        case accessibility
        case automation
    }

    public struct PermissionsCheckResults {
        public var fullDiskAccess: Bool?
        public var accessibility: Bool?
        public var automation: Bool?

        public var allCheckedPermissionsGranted: Bool {
            return [fullDiskAccess, accessibility, automation].compactMap { $0 }.allSatisfy { $0 }
        }

        public var grantedPermissions: [PermissionType] {
            var granted: [PermissionType] = []
            if fullDiskAccess == true { granted.append(.fullDiskAccess) }
            if accessibility == true { granted.append(.accessibility) }
            if automation == true { granted.append(.automation) }
            return granted
        }

        public var checkedPermissions: [PermissionType] {
            var checked: [PermissionType] = []
            if fullDiskAccess != nil { checked.append(.fullDiskAccess) }
            if accessibility != nil { checked.append(.accessibility) }
            if automation != nil { checked.append(.automation) }
            return checked
        }
    }

    private static var appBundleIdentifier: String {
        return Bundle.main.bundleId
    }

    public static func checkPermissions(types: [PermissionType], completion: @escaping (PermissionsCheckResults) -> Void) {
        let dispatchGroup = DispatchGroup()
        var results = PermissionsCheckResults()

        for type in types {
            switch type {
            case .fullDiskAccess:
                dispatchGroup.enter()
                checkFullDiskAccess { success in
                    results.fullDiskAccess = success
                    dispatchGroup.leave()
                }
            case .accessibility:
                results.accessibility = checkAccessibility()
            case .automation:
                dispatchGroup.enter()
                checkAutomationPermission { success in
                    results.automation = success
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(results)
        }
    }



    private static func checkFullDiskAccess(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            let testFile = "/Library/Application Support/com.apple.TCC/TCC.db"
            let hasAccess = fileManager.isReadableFile(atPath: testFile)

            DispatchQueue.main.async {
                completion(hasAccess)
            }
        }
    }



    private static func checkAccessibility() -> Bool {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [checkOptPrompt: false]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return accessibilityEnabled
    }

    private static func checkAutomationPermission(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let script = NSAppleScript(source: "tell application \"Finder\" to return name of home")
            var error: NSDictionary?
            script?.executeAndReturnError(&error)

            let hasPermission: Bool
            if let error = error {
                // Check if the error is related to permission
                let errorNumber = error[NSAppleScript.errorNumber] as? Int
                hasPermission = (errorNumber != -1743)
            } else {
                hasPermission = true
            }

            DispatchQueue.main.async {
                completion(hasPermission)
            }
        }
    }
}




public struct PermissionsView: View {
    @Binding public var showNotification: Bool
    @State private var hovered: Bool = false
    @State private var showPermissionList = false
    @Environment(\.dismiss) var dismiss
    let results: PermissionManager.PermissionsCheckResults

    public init(showNotification: Binding<Bool>, results: PermissionManager.PermissionsCheckResults) {
        self._showNotification = showNotification
        self.results = results
    }

    public var body: some View {
        if showNotification {
            notificationView
                .sheet(isPresented: $showPermissionList) {
                    permissionsListView
                }
                .interactiveDismissDisabled(false)
        }
    }

    private var notificationView: some View {
        HStack {
            Text("Missing Permissions!")
                .font(.callout)
                .opacity(0.5)
                .padding(.leading, 7)

            Spacer()

            Button(action: {
                showPermissionList = true
            }) {
                labelContent
            }
            .buttonStyle(PlainButtonStyle())
            .padding(4)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hover in
                withAnimation {
                    hovered = hover
                }
            }
            .help("Check all permissions")
        }
        .frame(height: 30)
        .padding(5)
        .background(.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var labelContent: some View {
        HStack(alignment: .center) {
            Image(systemName: !hovered ? "lock" : "lock.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(.white)
            Text("Check")
                .foregroundStyle(.white)
        }
        .padding(3)
    }

    private var permissionsListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                Text("Permissions")
                    .font(.title2)
                Spacer()
                Button("") {
                    dismiss()
                }
                .buttonStyle(SimpleButtonStyle(icon: "x.circle", help: "Close", size: 18))
            }


            Divider()

            ForEach(results.checkedPermissions, id: \.self) { permission in
                HStack {
                    Image(systemName: results.grantedPermissions.contains(permission) ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(results.grantedPermissions.contains(permission) ? .green : .red)
                    Text(permissionName(for: permission))
                    Spacer()
                    Button("Open") {
                        openSettingsForPermission(permission)
                    }
                    .buttonStyle(.plain)
//                    .controlSize(.small)
                }
                .padding(5)
            }
        }
        .padding()
        .material()
        .frame(width: 250)
    }

    private func permissionName(for permission: PermissionManager.PermissionType) -> String {
        switch permission {
        case .fullDiskAccess:
            return "Full Disk Access"
        case .accessibility:
            return "Accessibility"
        case .automation:
            return "Automation"
        }
    }

    private func openSettingsForPermission(_ permission: PermissionManager.PermissionType) {
        let urlString: String
        switch permission {
        case .fullDiskAccess:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .automation:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
