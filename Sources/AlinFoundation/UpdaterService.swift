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
    @Published var forceUpdate: Bool = false
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
        fetchReleases { [weak self] releases in
            self?.releases = releases
        }
    }

    func loadGithubReleases(sheet: Bool, force: Bool = false, forceUpdate: Bool = false) {
        fetchReleases { [weak self] releases in
            guard let self = self else { return }
            self.releases = releases
            self.checkForUpdate(sheet: sheet, force: force, forceUpdate: forceUpdate)
        }
    }

    private func checkForUpdate(sheet: Bool, force: Bool = false, forceUpdate: Bool = false) {
        guard let latestRelease = releases.first else { return }
        let currentVersion = updater?.currentVersion ?? "0.0.0"

        updateAvailable = latestRelease.tagName > currentVersion

        // Set the sheet behavior
        DispatchQueue.main.async() {
            if sheet {
                self.sheet = true
                self.force = force && !self.updateAvailable
                self.forceUpdate = forceUpdate
            } else {
                self.sheet = false
                self.force = false
                self.forceUpdate = false
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

        guard let latestRelease = self.releases.first else {
            DispatchQueue.main.async {
                self.progressBar.0 = "No releases available".localized()
                self.progressBar.1 = 0.0
            }
            return
        }
        
        guard let asset = selectAppropriateAsset(from: latestRelease.assets) else {
            DispatchQueue.main.async {
                self.progressBar.0 = "No downloadable update found".localized()
                self.progressBar.1 = 0.0
            }
            return
        }
        
        guard let url = URL(string: asset.url) else {
            DispatchQueue.main.async {
                self.progressBar.0 = "Invalid download URL".localized()
                self.progressBar.1 = 0.0
            }
            return
        }
        DispatchQueue.main.async {
            self.progressBar.1 = 0.2
        }
        
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
                DispatchQueue.main.async {
                    self.progressBar.0 = "Download failed".localized()
                    self.progressBar.1 = 0.0
                }
                return
            }

            DispatchQueue.main.async {
                self.progressBar.1 = 0.3
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
                DispatchQueue.main.async {
                    self.progressBar.0 = "Failed to save update".localized()
                    self.progressBar.1 = 0.0
                }
            }
        }

        task.resume()
    }

    private func selectAppropriateAsset(from assets: [Asset]) -> Asset? {
        let currentArch = isOSArm() ? "arm" : "intel"
        let appName = Bundle.main.name

        let zipAssets = assets.filter { asset in
            asset.name.hasSuffix(".zip") && !asset.name.hasSuffix(".dmg")
        }

        let archSpecificAsset = zipAssets.first { asset in
            asset.name.contains("\(appName)-\(currentArch).zip")
        }

        if let archAsset = archSpecificAsset {
            return archAsset
        }

        let genericAsset = zipAssets.first { asset in
            asset.name == "\(appName).zip"
        }

        if let generic = genericAsset {
            return generic
        }
        
        return zipAssets.first
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

            DispatchQueue.main.async {
                self.progressBar.1 = 0.9
            }
            
            let command = "rm -rf \\\"\(appBundle)\\\" && ditto -xk \\\"\(fileURL)\\\" \\\"\(appDirectory)\\\" && rm -f \\\"\(fileURL)\\\""
            let (success, output) = runOSACommand(command)

            DispatchQueue.main.async {
                if success {
                    self.progressBar.0 = "Update completed".localized()
                    self.progressBar.1 = 1.0
                    self.updater?.setNextUpdateDate()
                } else {
                    printOS("Updater OSA failed: \(output)", category: LogCategory.updater)
                    self.progressBar.0 = "Update failed - check permissions".localized()
                    self.progressBar.1 = 0.0
                }
            }

        }
    }

    private func fetchReleases(completion: @escaping ([Release]) -> Void) {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases")!
        var request = makeRequest(url: url, token: token)
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if handleGitHubResponseErrors(response: response, error: error) {
                return
            }

            guard let data = data,
                  let decodedResponse = try? JSONDecoder().decode([Release].self, from: data) else {
                return
            }

            let releases = Array(decodedResponse.prefix(3))
            DispatchQueue.main.async {
                completion(releases)
            }
        }.resume()
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

// Helper for github responses
public func handleGitHubResponseErrors(response: URLResponse?, error: Error?) -> Bool {
    if let error = error {
        printOS("Updater Network error: \(error.localizedDescription)", category: LogCategory.updater)
        return true
    }

    guard let httpResponse = response as? HTTPURLResponse else {
        printOS("Updater: invalid response type", category: LogCategory.updater)
        return true
    }

    guard httpResponse.statusCode == 200 else {
        printOS("Updater HTTP error: \(httpResponse.statusCode) — \(httpResponse.url?.absoluteString ?? "No URL")", category: LogCategory.updater)
        return true
    }

    return false
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

func runOSACommand(_ shellCommand: String) -> (Bool, String?) {
    let prompt = "\(Bundle.main.name) needs permission to complete the update"
    let appleScript = "do shell script \"\(shellCommand)\" with administrator privileges with prompt \"\(prompt)\""
    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", appleScript]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe

    do {
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (task.terminationStatus == 0, output)
    } catch {
        printOS("osascript failed: \(error)")
        return (false, nil)
    }
}
