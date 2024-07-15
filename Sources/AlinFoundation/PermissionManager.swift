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

public class PermissionManager: ObservableObject {

    public static let shared = PermissionManager()

    public var results: PermissionsCheckResults?

    private init() {
        checkAllPermissions()
    }

    public var allPermissionsGranted: Bool {
        return results?.allCheckedPermissionsGranted ?? false
    }

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

    public func checkPermissions(types: [PermissionType], completion: @escaping (PermissionsCheckResults) -> Void) {
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



    private func checkFullDiskAccess(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            let testFile = "/Library/Application Support/com.apple.TCC/TCC.db"
            let hasAccess = fileManager.isReadableFile(atPath: testFile)

            DispatchQueue.main.async {
                completion(hasAccess)
            }
        }
    }



    private func checkAccessibility() -> Bool {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [checkOptPrompt: false]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return accessibilityEnabled
    }

    private func checkAutomationPermission(completion: @escaping (Bool) -> Void) {
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

    public func checkAllPermissions() {
        checkPermissions(types: [.fullDiskAccess, .accessibility, .automation]) { [weak self] results in
            self?.results = results
        }
    }
}




public struct PermissionsView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var permissionManager = PermissionManager.shared
    @State private var hovered: Bool = false
    @State private var showPermissionList = false
    @Environment(\.dismiss) var dismiss
    let dark: Bool
    let opacity: Double

    public init(dark: Bool = false, opacity: Double = 1) {
        self.dark = dark
        self.opacity = opacity
    }

    public var body: some View {
        Group {
            if let results = permissionManager.results, !permissionManager.allPermissionsGranted {
                AlertNotification(label: "Missing Permissions", icon: "lock", buttonAction: {
                    showPermissionList = true
                }, btnColor: Color.red, opacity: opacity, themeManager: themeManager)
                .sheet(isPresented: $showPermissionList) {
                    PermissionsListView(isPresented: $showPermissionList)
                }
            }
        }
    }

}

struct PermissionsListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var permissionManager = PermissionManager.shared
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            HStack {
                Spacer()
                Text("Permission Status")
                    .font(.title2)
//                Button("Refresh") {
//                    permissionManager.checkAllPermissions()
//                }

//                InfoButtonPerms()
                Spacer()
            }


            Divider()

            if let results = permissionManager.results {
                ForEach(results.checkedPermissions, id: \.self) { permission in
                    HStack {
                        Image(systemName: results.grantedPermissions.contains(permission) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(results.grantedPermissions.contains(permission) ? .green : .red)
                        Text(permissionName(for: permission))
                        Spacer()
                        Button("Open") {
                            openSettingsForPermission(permission)
                        }
                    }
                    .padding(5)
                }
            }

            Divider()

            Text("Restart \(Bundle.main.name) for changes to take effect").font(.footnote).opacity(0.5)


            Button("Close") {
                dismiss()
            }


        }
        .padding()
        .background(themeManager.pickerColor)
        .frame(width: 300)
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
