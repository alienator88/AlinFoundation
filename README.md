# AlinFoundation

`AlinFoundation` is a Swift package that houses my most commonly used classes, functions, and utilities, optimized for macOS projects. It simplifies the setup of new projects by providing foundational components, including a custom ColorPicker, GitHub Updater and PermissionsManager.

## Features

- **GitHubUpdater**: Allows seamless updates by checking the latest available versions from a specified GitHub repository. Supports private repos as well
- **ColorPicker**: Minimalistic color picker that follows macOS interface guidelines
- **Authorization**: Execute a sudo shell command, asking for permission from end-user
- **PermissionsManager**: Check for permissions and show a view to manage these (Currently supports FDA, Accessibility, Automation)
- **Utilities**: A multitude of functions and extensions
- **Styles**: Some custom views, buttonStyles, etc.
- **ThemeManager**: Choose appearance modes like Auto, Light, Dark. Or choose custom to set a theme color using the color picker
- **TokenManager**: Save passwords, keys and more to Keychain Access with encryption



## Screenshots
<img width="1053" alt="Screenshot 2024-07-11 at 9 34 29 PM" src="https://github.com/user-attachments/assets/60c106b8-52b6-4abe-8972-7c38e4ccd7e6">
<img width="1053" alt="Screenshot 2024-07-11 at 9 34 53 PM" src="https://github.com/user-attachments/assets/ab098967-768a-424a-ae3f-10d4bfd97353">
<img width="1053" alt="Screenshot 2024-07-11 at 9 38 38 PM" src="https://github.com/user-attachments/assets/9de34e30-81cc-44b8-870a-e493a61812c2">
<img width="1053" alt="Screenshot 2024-07-11 at 9 38 43 PM" src="https://github.com/user-attachments/assets/79debb00-7ba2-46ef-b350-7bacf6f9797c"> 



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
import SwiftUI
import AppKit
import AlinFoundation

@main
struct FoundationTestingApp: App {
    @StateObject private var updater = GitHubUpdater(owner: "USERNAME", repo: "REPO", token: "") //MARK: If you enter an API token, you can access private repositories as long as the API token has full repo permissions
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                /// Load theme manager in the environment
                .environmentObject(themeManager)
                /// Load updater in the environment
                .environmentObject(updater)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    /// Set background based on the theme manager color picker
                    themeManager.pickerColor
                )
                .onAppear{
                    /// Set the appearance on load based on the user's mode selection
                    themeManager.setupAppearance()
                }
                /// Set the color scheme of the app to the Theme Manager
                .preferredColorScheme(themeManager.displayMode.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
```

### ContentView.swift
```swift
import SwiftUI
import AlinFoundation

struct ContentView: View {
    @EnvironmentObject var updater: GitHubUpdater
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @State private var showNotification: Bool = false
    @State private var token: String = ""
    @State private var tokenStatus: String = ""
    @State private var permissionResults: PermissionManager.PermissionsCheckResults?

    var body: some View {

        HStack(spacing: 0) {
            ZStack {
                
                VStack {
                    Spacer()
                }
                .materialColor(themeManager: themeManager, brightness: 5, opacity: 1)

                VStack(alignment: .leading, spacing: 15) {

                    Text("Permissions Component").font(.title2)
                    /// This shows a permission notification view if permissions are missing
                    if let results = permissionResults {
                        PermissionsView(showNotification: $showNotification, results: results, dark: false, opacity: 1)
                    }

                    Divider()

                    Text("Updater Component").font(.title2)
                    /// This will check for an update on appear of the button and show if there's one available or not in the label
                    updater.getUpdateButton(dark: false, opacity: 1)

                    Divider()

                    Text("Frequency Component").font(.title2)
                    /// This will allow the user to set how often to check for updates
                    updater.getFrequencyView()

                    Divider()

                    Text("Appearance Component").font(.title2)
                    /// Show appearance/theme mode changer
                    ThemeSettingsView()

                    Spacer()
                }
                .padding()
                .padding(.top, 40)
            }
            .frame(width: 350)

            Divider()


            VStack(alignment: .leading, spacing: 20) {

                Text("Updater Releases Component").font(.title)
                /// This will show the last 3 versions release notes
                updater.getReleasesView()
                    .frame(height: 300)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.pickerColor.adjustBrightness())
                    }

                Divider()


                /// Create and store an encrypted token in Keychain Access
                Text("TokenManager Component").font(.title2)
                let tokenManager = TokenManager(name: "GitHub Token - Test")
                HStack {
                    TextField("Enter Token", text: $token)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Create") {
                        // Save token
                        tokenManager.saveToken(token) { success in
                            if success {
                                tokenStatus = "Token saved: \(token)"
                            } else {
                                tokenStatus = "Failed to save token: \(token)"
                            }
                        }
                    }
                    Button("Load") {
                        // Load a token
                        if let token = tokenManager.loadToken() {
                            tokenStatus = "Loaded token: \(token)"
                        } else {
                            tokenStatus = "No token found: \(token)"
                        }
                    }
                    Button("Delete") {
                        // Delete a token
                        tokenManager.deleteToken()
                        tokenStatus = "Token deleted: \(token)"
                    }
                }
                Text(tokenStatus)

                Spacer()

            }
            .padding()
            .onAppear {
                /// This will check for updates on load based on the update frequency
                updater.checkAndUpdateIfNeeded()

                /// Check permissions on load
                PermissionManager.checkPermissions(types: [.fullDiskAccess, .accessibility, .automation]) { results in
                    self.permissionResults = results
                    self.showNotification = !results.allCheckedPermissionsGranted
                }
            }
            .sheet(isPresented: $updater.showSheet, content: {
                /// This will show the update sheet based on the frequency check function only
                updater.getUpdateView()
            })
        }
        .edgesIgnoringSafeArea(.all)


    }
}
```

## License

Distributed under the MIT License.
