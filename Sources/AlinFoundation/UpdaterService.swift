//
//  UpdaterService.swift
//
//
//  Created by Alin Lupascu on 7/8/24.
//

import Foundation
import Combine
import AppKit

class UpdaterService: ObservableObject {
    @Published var releases: [Release] = []
    @Published var updateAvailable: Bool = false
    @Published var sheet: Bool = false
    @Published var force: Bool = false
    @Published var progressBar: (String, Double) = ("", 0.0)
    weak var updater: Updater?

    public let owner: String
    public let repo: String
    private let token: String

    init(owner: String, repo: String, token: String) {
        self.owner = owner
        self.repo = repo
        self.token = token
    }

    func setUpdater(_ updater: Updater) {
        self.updater = updater
    }

    func checkReleaseNotes() {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases")!
        var request = makeRequest(url: url, token: token)
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data else { return }

            if let decodedResponse = try? JSONDecoder().decode([Release].self, from: data) {
                DispatchQueue.main.async {
                    self.releases = Array(decodedResponse.prefix(3))
                }
            }
        }.resume()
    }

    func loadGithubReleases(sheet: Bool, force: Bool = false) {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases")!
        var request = makeRequest(url: url, token: token)
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                // Handle network error
                printOS("Updater Network error: \(error.localizedDescription)", category: LogCategory.updater)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                // Handle non-200 HTTP response
                printOS("Updater HTTP error: \(response.debugDescription)", category: LogCategory.updater)
                return
            }
            guard let data = data else { return }
            if let decodedResponse = try? JSONDecoder().decode([Release].self, from: data) {
                DispatchQueue.main.async {
                    self.releases = Array(decodedResponse.prefix(3))
                    self.checkForUpdate(sheet: sheet, force: force)
                }
            }
        }.resume()
    }

    private func checkForUpdate(sheet: Bool, force: Bool = false) {
        guard let latestRelease = releases.first else { return }
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        updateAvailable = latestRelease.tagName > currentVersion

        // Set the sheet behavior
        DispatchQueue.main.async() {
            if sheet && self.updateAvailable { // Update available and show sheet is ON
                self.sheet = true
            } else if sheet && (!self.updateAvailable && force) { // No update + force and show sheet is ON
                self.force = true
                self.sheet = true
            } else if sheet && (!self.updateAvailable && !force) { // No update + no force and show sheet is ON
                self.sheet = true
            } else { // Show sheet is OFF
                self.sheet = false
            }
        }

    }

    func ensureAppIsInApplicationsFolder() -> Bool {
        let appDirectory = Bundle.main.bundleURL.deletingLastPathComponent().path

        // Check if the app is in /Applications or ~/Applications
        let globalApplicationsPath = "/Applications"
        let userApplicationsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path

        if appDirectory.hasPrefix(globalApplicationsPath) || appDirectory.hasPrefix(userApplicationsPath) {
            return true
        } else {
            var response: NSApplication.ModalResponse = .abort
            let alert = NSAlert()
            alert.messageText = "Attention!"
            alert.informativeText = "To avoid updater permission issues, please move \(Bundle.main.name) to your Applications folder before updating."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Okay")
            alert.addButton(withTitle: "Ignore")
            response = alert.runModal()
            return response == .alertSecondButtonReturn
        }
    }

    func downloadUpdate() {
        if !ensureAppIsInApplicationsFolder() {
            return
        }

        self.progressBar.0 = "Update in progress".localized()
        self.progressBar.1 = 0.1

        guard let latestRelease = self.releases.first,
              let asset = latestRelease.assets.first(where: { $0.name.hasSuffix(".zip") }),
              let url = URL(string: asset.url) else { return }

        var request = makeRequest(url: url, token: token)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let destinationURL = appSupportDirectory
            .appendingPathComponent(Bundle.main.name)
            .appendingPathComponent(asset.name)

        let fileExists = FileManager.default.fileExists(atPath: destinationURL.path)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                printOS("Error fetching asset: \(error?.localizedDescription ?? "Unknown error")", category: LogCategory.updater)
                return
            }

            DispatchQueue.main.async {
                self.progressBar.1 = 0.2
            }

            do {
                if fileExists {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                try data.write(to: destinationURL)

                DispatchQueue.main.async {
                    self.progressBar.1 = 0.4
                }

                self.unzipAndReplace(downloadedFileURL: destinationURL.path)

            } catch {
                printOS("Error saving downloaded file: \(error.localizedDescription)", category: LogCategory.updater)
            }
        }

        task.resume()
    }

    private func unzipAndReplace(downloadedFileURL fileURL: String) {
        let appDirectory = Bundle.main.bundleURL.deletingLastPathComponent().path
        let appBundle = Bundle.main.bundleURL.path

        do {
            DispatchQueue.main.async {
                self.progressBar.1 = 0.5
            }
            // Remove the current app bundle
            try runShellCommand("rm -rf \"\(appBundle)\"")

            DispatchQueue.main.async {
                self.progressBar.1 = 0.6
            }
            // Unzip the update to the app directory
            try runShellCommand("ditto -xk \"\(fileURL)\" \"\(appDirectory)\"")

            DispatchQueue.main.async {
                self.progressBar.1 = 0.8
            }
            // Remove the downloaded file
            try runShellCommand("rm -f \"\(fileURL)\"")

            DispatchQueue.main.async {
                self.progressBar.0 = "Update completed".localized()
                self.progressBar.1 = 1.0
                self.updater?.setNextUpdateDate()
            }
        } catch {
            printOS("Error replacing the app: \(error)", category: LogCategory.updater)

            // If an error occurs, run all commands with elevated privileges
            let commands = "rm -rf \"\(appBundle)\" && ditto -xk \"\(fileURL)\" \"\(appDirectory)\" && rm -f \"\(fileURL)\""
            let result = performPrivilegedCommands(commands: commands)
            if result.0 {
                DispatchQueue.main.async {
                    self.progressBar.0 = "Update completed".localized()
                    self.progressBar.1 = 1.0
                    self.updater?.setNextUpdateDate()
                }
            } else {
                printOS("Privileged commands failed: \(result.1)", category: LogCategory.updater)
                self.progressBar.0 = "Failed to update, check debug logs".localized()
            }
        }
    }
}

// Helper function to create URLRequests with an optional token
public func makeRequest(url: URL, token: String) -> URLRequest {
    var request = URLRequest(url: url)
    if !token.isEmpty {
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
    }
    return request
}

public func runShellCommand(_ command: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", command]
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        throw NSError(domain: "ShellCommandError", code: Int(process.terminationStatus), userInfo: nil)
    }
}
