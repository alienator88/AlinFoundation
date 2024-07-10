# AlinFoundation

`AlinFoundation` is a Swift package that houses my most commonly used classes, functions, and utilities, optimized for macOS projects. It simplifies the setup of new projects by providing foundational components, including a custom ColorPicker and a GitHub Updater.

## Features

- **GitHubUpdater**: Allows seamless updates by checking the latest available versions from a specified GitHub repository.
- **ColorPicker**: Minimalistic color picker that follows macOS interface guidelines
- **Authorization**: Execute a sudo shell command, asking for permission from end-user
- **PermissionsManager**: Check for permissions and show a view to manage these (Currently supports FDA, Accessibility, Automation)
- **Utilities**: A multitude of functions and extensions
- **Styles**: Some custom views, buttonStyles, etc.
- **ThemeManager**: TO-DO



## Screenshots
Each usable component is separated with a border

![Screenshot 2024-07-10 at 4 17 16 PM](https://github.com/alienator88/AlinFoundation/assets/6263626/e3eb6f4b-63d4-4846-ae13-e449b784e9b5)
![Screenshot 2024-07-10 at 4 16 25 PM](https://github.com/alienator88/AlinFoundation/assets/6263626/350ce626-cf4e-474a-bc39-28d9c435c87b)
![Screenshot 2024-07-10 at 4 16 08 PM](https://github.com/alienator88/AlinFoundation/assets/6263626/f5edfb9a-3ca8-449a-853d-1db841f3a829)




## Installation

To integrate `AlinFoundation` into your Swift project, configure your `Package.swift` to include the following dependency:

```swift
dependencies: [
    .package(url: "https://github.com/alienator88/AlinFoundation.git", from: "1.0.0")
]
```
Then, import AlinFoundation in your project files where you need to use its functionalities.

## Usage

### Importing the Package

To use AlinFoundation in your Swift project, you need to import it along with other necessary frameworks:
```swift
import SwiftUI
import AppKit
import AlinFoundation
```

## Example

### App.swift
```swift
@main
struct FoundationTestingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AFstate()
    @StateObject private var updater = GitHubUpdater(owner: "USERNAME", repo: "REPO")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(updater)
                .environmentObject(appState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    appState.themeColor
                )
        }
        .windowStyle(.hiddenTitleBar)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
       return true
    }
}
```

### ContentView.swift
```swift
import SwiftUI
import AlinFoundation

struct ContentView: View {
    @EnvironmentObject var updater: GitHubUpdater
    @EnvironmentObject var appState: AFstate
    @Environment(\.colorScheme) var colorScheme
    @State private var showNotification: Bool = false
    @State private var permissionResults: PermissionManager.PermissionsCheckResults?

    var body: some View {
        let slate = colorScheme == .light ? Color(.sRGB, red: 0.499549, green: 0.545169, blue: 0.682028, opacity: 1) : Color(.sRGB, red: 0.188143, green: 0.208556, blue: 0.262679, opacity: 1)
        let solarized = colorScheme == .light ? Color(.sRGB, red: 0.554372, green: 0.6557, blue: 0.734336, opacity: 1) : Color(.sRGB, red: 0.117257, green: 0.22506, blue: 0.249171, opacity: 1)
        let dracula = colorScheme == .light ? Color(.sRGB, red: 0.567094, green: 0.562125, blue: 0.81285, opacity: 1) : Color(.sRGB, red: 0.268614, green: 0.264737, blue: 0.383503, opacity: 1)
        let macOS = colorScheme == .light ? Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 1) : Color(.sRGB, red: 0.149, green: 0.149, blue: 0.149, opacity: 1)

        VStack {

            /// This shows a permission notification view if permissions are missing
            if let results = permissionResults {
                PermissionsView(showNotification: $showNotification, results: results)
            }

            /// This shows a minimalistic color picker
            ColorButtonView(appState: appState, templateColors: [slate, solarized, dracula, macOS])

            /// This will check for an update on appear of the button and show if there's one available or not in the label
            updater.getUpdateButton()
                .controlSize(.extraLarge)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(lineWidth: 1)
                }

            /// This will show the last 3 versions release notes
            updater.getReleasesView()
                .frame(width: 400, height: 300)
                .padding()
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(lineWidth: 1)
                }

            /// This will allow the user to set how often to check for updates
            updater.getFrequencyView()
                .padding()
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(lineWidth: 1)
                }
        }
        .padding()
        .onAppear {
            /// This will check for updates on load based on the update frequency
            updater.checkAndUpdateIfNeeded()

            /// Check permissions on load
            PermissionManager.checkPermissions(types: [.fullDiskAccess, .accessibility]) { results in
                self.permissionResults = results
                self.showNotification = !results.allCheckedPermissionsGranted
            }
        }
        .sheet(isPresented: $updater.showSheet, content: {
            /// This will show the update sheet based on the frequency check function only
            updater.getUpdateView()
        })

    }
}
```

## License

Distributed under the MIT License.
