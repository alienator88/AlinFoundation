# AlinFoundation

`AlinFoundation` is a Swift package that houses my most commonly used classes, functions, and utilities, optimized for macOS projects. It simplifies the setup of new projects by providing foundational components, including a custom ColorPicker and a GitHub Updater.

## Features

- **GitHubUpdater**: Allows seamless updates by checking the latest available versions from a specified GitHub repository.
- **AlinFoundation**: Provides commonly used utilities. See below for what it has available
- **Component Based**: You can import the updater or foundation individually if you don't need all

## AlinFoundation
- Minimalistic color picker that follows macOS interface guidelines
- More coming soon

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
import GitHubUpdater // Make sure this package is correctly setup if it's external
import AlinFoundation
```

## Example

### App.swift
```swift
@main
struct FoundationTestingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AFstate()
    @StateObject private var updater = GitHubUpdater(owner: "alienator88", repo: "Viz")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(updater)
                .environmentObject(appState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(appState.themeColor)
        }
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
import GitHubUpdater
import AlinFoundation

struct ContentView: View {
    @EnvironmentObject var updater: GitHubUpdater
    @EnvironmentObject var appState: AFstate
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let slate = colorScheme == .light ? Color(.sRGB, red: 0.499549, green: 0.545169, blue: 0.682028, opacity: 1) : Color(.sRGB, red: 0.188143, green: 0.208556, blue: 0.262679, opacity: 1)
        let solarized = colorScheme == .light ? Color(.sRGB, red: 0.554372, green: 0.6557, blue: 0.734336, opacity: 1) : Color(.sRGB, red: 0.117257, green: 0.22506, blue: 0.249171, opacity: 1)
        let dracula = colorScheme == .light ? Color(.sRGB, red: 0.567094, green: 0.562125, blue: 0.81285, opacity: 1) : Color(.sRGB, red: 0.268614, green: 0.264737, blue: 0.383503, opacity: 1)
        let macOS = colorScheme == .light ? Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 1) : Color(.sRGB, red: 0.149, green: 0.149, blue: 0.149, opacity: 1)

        VStack {

            /// This view shows a minimalistic color picker. You can provide an optinal array of Colors to show on the picker popover, else a default set will show
            ColorButtonView(appState: appState, templateColors: [slate, solarized, dracula, macOS])

            /// This view will check for an update on appear and show if there's one available or not in the label. This does not trigger the Update sheet automatically, you have to click Update button
            updater.getUpdateButton()
                .controlSize(.extraLarge)

            /// This view will show the last 3 recent versions release notes
            updater.getReleasesView()
                .frame(width: 400, height: 300)

            /// This view will allow the user to set how often to check for updates using the function updater.checkAndUpdateIfNeeded()
            updater.getFrequencyView()
        }
        .onAppear {
            /// This will check for updates on appear based on the user configurable update frequency
            updater.checkAndUpdateIfNeeded()
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
