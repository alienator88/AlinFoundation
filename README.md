# AlinFoundation

`AlinFoundation` is a Swift package that houses my most commonly used classes, functions, and utilities, optimized for macOS projects. It simplifies the setup of new projects by providing foundational components, including a custom ColorPicker, Updater and PermissionsManager.

## Features

- **Updater**: Allows seamless updates by checking the latest available versions from a specified public or private GitHub repository. Works with the TokenManager below as well to load private GitHub API token from KeyChain app
- **TokenManager**: Save passwords, keys and more to Keychain Access with encryption
- **ColorPicker**: Minimalistic color picker that follows macOS interface guidelines
- **ThemeManager**: Choose appearance modes like Auto, Light, Dark. Or choose custom to set a theme color using the color picker above
- **PermissionsManager**: Check for permissions and show a view to manage these (Currently supports FDA, Accessibility, Automation)
- **Authorization**: Execute a sudo shell command, asking for permission from end-user
- **Utilities**: A multitude of functions and extensions
- **Styles**: Some custom views, buttonStyles, etc.



## Screenshots
![Screenshot 2024-07-18 at 2 00 57 PM](https://github.com/user-attachments/assets/5c68da88-166b-4eb1-acc8-5f2f0497544c)
![Screenshot 2024-07-18 at 2 01 02 PM](https://github.com/user-attachments/assets/82f204b3-ca81-4189-bb02-f493f94ac998)
![Screenshot 2024-07-18 at 2 01 07 PM](https://github.com/user-attachments/assets/539f961e-5781-49d1-9cc4-280a2d2b28ad)
![Screenshot 2024-07-18 at 2 01 18 PM](https://github.com/user-attachments/assets/f4545da8-1f2f-4c34-857d-78a86df57904)




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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var updater = Updater(owner: "USER", repo: "REPO")
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var permissionManager = PermissionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(updater)
                .environmentObject(permissionManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    themeManager.pickerColor
                )
                .onAppear{
                    themeManager.setupAppearance()
                }
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
    @EnvironmentObject var updater: Updater
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var permissions: ThemeManager

    @Environment(\.colorScheme) var colorScheme
    @State private var token: String = ""
    @State private var tokenStatus: String = ""
    @State var show = false
    let tokenManager = TokenManager(service: Bundle.main.bundleId, account: "API-Token")

    var body: some View {

        HStack(spacing: 0) {
            ZStack {
                
                VStack {
                    Spacer()
                }
                .materialColor(themeManager: themeManager, brightness: 5, opacity: 1)

                VStack(alignment: .leading, spacing: 15) {

                    Text("Permissions Badge").font(.title2)
                    /// This shows a permission notification view if permissions are missing
                    PermissionsBadge()
                        .backgroundAF(opacity: 1)

                    Divider()

                    Text("Updater Badge").font(.title2)
                    /// This will check for an update on appear of the button and show if there's one available or not in the label
                    UpdateBadge(updater: updater)
                        .backgroundAF(opacity: 1)


                    Divider()

                    Text("Token Badge").font(.title2)
                    /// This will check if the token is valid
                    if tokenManager.tokenValid {
                        TokenBadge(buttonAction: {
                            print("Show a token view")
                        })
                        .backgroundAF(opacity: 1)
                    }


                    Text("Frequency").font(.title2)
                    /// This will allow the user to set how often to check for updates
                    FrequencyView(updater: updater)
                        .backgroundAF(opacity: 1)

                    Divider()

                    Text("Appearance").font(.title2)
                    /// Show appearance/theme mode changer
                    ThemeSettingsView(opacity: 1)
                        .backgroundAF(opacity: 1)

                    Text("ColorPicker").font(.title2)
                    /// Show a color picker
                    ColorButtonView(themeManager: themeManager)
                        .backgroundAF(opacity: 1)

                    Spacer()
                }
                .padding()
                .padding(.top, 40)
            }
            .frame(width: 350)

            Divider()


            VStack(alignment: .leading, spacing: 20) {

                Text("Updater Releases").font(.title2)
                /// This will show the last 3 versions release notes
                ReleasesView(updater: updater)
                    .frame(height: 300)
                    .backgroundAF(opacity: 0.5)

                Divider()


                /// Create and store an encrypted token in Keychain Access
                Text("Token Manager").font(.title2)

                HStack {
                    TextField(" Enter Token", text: $token)
                        .textFieldStyle(.plain)
                        .backgroundAF(opacity: 0.7)
                    Button("Create") {
                        // Save token
                        tokenManager.saveToken(token) { success in
                            if success {
                                tokenStatus = "Token saved:\n\(token)"
                            } else {
                                tokenStatus = token.isEmpty ? "Token cannot be empty" : "Failed to save token:\n\(token)"
                            }
                        }
                    }
                    .buttonStyle(AFButtonStyle(image: "plus"))

                    Button("Load") {
                        // Load a token
                        var loadedToken = ""
                        loadedToken = tokenManager.loadToken { success in
                            if success {
                                DispatchQueue.main.async {
                                    token = loadedToken
                                    tokenStatus = "Token loaded:\n\(token)"

                                    tokenManager.checkTokenValidity(token: token) { success in
                                        if success {
                                            print("Token is good")
                                        } else {
                                            print("Token is bad")
                                        }
                                    }
                                }
                            } else {
                                DispatchQueue.main.async {
                                    tokenStatus = "No token found:\n\(token)"
                                }
                            }
                        }

                    }
                    .buttonStyle(AFButtonStyle(image: "externaldrive"))

                    Button("Delete") {
                        // Delete a token
                        tokenManager.deleteToken() { success in
                            if success {
                                tokenStatus = "Token deleted:\n\(token)"
                                token = ""
                            } else {
                                tokenStatus = token.isEmpty ? "Unable to delete empty token" : "Error deleting token:\n\(token)"
                            }
                        }
                    }
                    .buttonStyle(AFButtonStyle(image: "minus"))

                }
                Text(tokenStatus)

                Spacer()

            }
            .padding()
            .onAppear {
                /// This will check for updates on load based on the update frequency
                updater.checkAndUpdateIfNeeded()
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
