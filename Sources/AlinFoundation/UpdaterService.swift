//
//  UpdaterService.swift
//  
//
//  Created by Alin Lupascu on 7/8/24.
//

import Foundation
import Combine

class UpdaterService: ObservableObject {
    @Published var releases: [Release] = []
    @Published var updateAvailable: Bool = false
    @Published var showSheet: Bool = false
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

    func loadGithubReleases(showSheet: Bool) {
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
                    self.checkForUpdate(showSheet: showSheet)
                }
            }
        }.resume()
    }

    private func checkForUpdate(showSheet: Bool) {
        guard let latestRelease = releases.first else { return }
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        updateAvailable = latestRelease.tag_name > currentVersion
        DispatchQueue.main.async() {
            self.showSheet = showSheet
        }
    }

    func downloadUpdate() {
        self.progressBar.0 = "Update in progress"
        self.progressBar.1 = 0.1

        let fileManager = FileManager.default
        guard let latestRelease = self.releases.first,
              let asset = latestRelease.assets.first,
              let url = URL(string: asset.url) else { return }
        var request = URLRequest(url: url)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        if !token.isEmpty {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }



        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                printOS("Error fetching asset: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            DispatchQueue.main.async {
                self.progressBar.1 = 0.2
            }

            let destinationURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").appendingPathComponent(asset.name)

            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }

                try data.write(to: destinationURL)

                DispatchQueue.main.async {
                    self.progressBar.1 = 0.4
                }

                 self.unzipAndReplace(downloadedFileURL: destinationURL.path)
            } catch {
                printOS("Error saving downloaded file: \(error.localizedDescription)")
            }
        }

        task.resume()
    }

    private func unzipAndReplace(downloadedFileURL fileURL: String) {
        let appDirectory = Bundle.main.bundleURL.deletingLastPathComponent().path
        let appBundle = Bundle.main.bundleURL.path
        let fileManager = FileManager.default
        printOS(appDirectory, appBundle)

        do {
            DispatchQueue.main.async {
//                self.progressBar.0 = "UPDATER: Removing currently installed application bundle"
                self.progressBar.1 = 0.5
            }
            printOS("Remove app bundle")

            try fileManager.removeItem(atPath: appBundle)

            DispatchQueue.main.async {
//                self.progressBar.0 = "UPDATER: Unzipping file to original install location"
                self.progressBar.1 = 0.6
            }
            printOS("Extract zip file")

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
            printOS("Error updating the app: \(error)")
        }
    }
}
