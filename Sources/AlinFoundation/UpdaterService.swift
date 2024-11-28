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
        var request = URLRequest(url: url)
        if !token.isEmpty {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }
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
        var request = URLRequest(url: url)
        if !token.isEmpty {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data else { return }

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

        updateAvailable = latestRelease.tag_name > currentVersion

        // Set the sheet behavior
        DispatchQueue.main.async() {
            if sheet && self.updateAvailable {
                self.sheet = true
            } else if sheet && (!self.updateAvailable && force) {
                self.sheet = true
                self.force = true
            } else {
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
                // Prompt user to move the app to the Applications folder
                let alert = NSAlert()
                alert.messageText = "Attention!"
                alert.informativeText = "To avoid updater permission issues, please move \(Bundle.main.name) to your Applications folder before updating."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Okay")
                alert.addButton(withTitle: "Ignore")

                let response = alert.runModal()

                // If the user chooses "Ignore", return true to proceed
                return response == .alertSecondButtonReturn

        }
    }

    func downloadUpdate() {
        if !ensureAppIsInApplicationsFolder() {
            return
        }

        self.progressBar.0 = "Update in progress"
        self.progressBar.1 = 0.1

        guard let latestRelease = self.releases.first,
              let asset = latestRelease.assets.first,
              let url = URL(string: asset.url) else { return }
        var request = URLRequest(url: url)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        if !token.isEmpty {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

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
        let fileManager = FileManager.default

        do {
            DispatchQueue.main.async {
//                self.progressBar.0 = "UPDATER: Removing currently installed application bundle"
                self.progressBar.1 = 0.5
            }

            try fileManager.removeItem(atPath: appBundle)

            DispatchQueue.main.async {
//                self.progressBar.0 = "UPDATER: Unzipping file to original install location"
                self.progressBar.1 = 0.6
            }

            let process = Process()
//            let outputPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", fileURL, appDirectory]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
//            let outputHandle = outputPipe.fileHandleForReading

            try process.run()
            process.waitUntilExit()


//            let outputData = outputHandle.readDataToEndOfFile()
//            if let outputString = String(data: outputData, encoding: .utf8) {
//                print(outputString)
//            }

            DispatchQueue.main.async {
//                self.progressBar.0 = "UPDATER: Removing file from temp directory"
                self.progressBar.1 = 0.8
            }

            try fileManager.removeItem(atPath: fileURL)

            DispatchQueue.main.async {
                self.progressBar.0 = "Update completed"
                self.progressBar.1 = 1.0
                self.updater?.setNextUpdateDate()
            }

        } catch {
            printOS("Error replacing the app: \(error)", category: LogCategory.updater)
        }
    }
}
