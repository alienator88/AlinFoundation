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

    private let owner: String
    private let repo: String

    init(owner: String, repo: String) {
        self.owner = owner
        self.repo = repo
    }

    func loadGithubReleases(showSheet: Bool) {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases")!
        let request = URLRequest(url: url)

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
        self.showSheet = showSheet
    }

    func downloadUpdate() {
        self.progressBar.0 = "Update in progress"
        self.progressBar.1 = 0.1

        let fileManager = FileManager.default
        guard let latestRelease = self.releases.first,
              let asset = latestRelease.assets.first,
              let url = URL(string: asset.browser_download_url) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

        let downloadTask = URLSession.shared.downloadTask(with: request) { localURL, urlResponse, error in
            DispatchQueue.main.async {
//                self.progressBar.0 = "UPDATER: Starting download of update file"
                self.progressBar.1 = 0.2
            }

            guard let localURL = localURL else { return }

            let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(asset.name)

            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }

                DispatchQueue.main.async {
//                    self.progressBar.0 = "UPDATER: File downloaded to temp directory"
                    self.progressBar.1 = 0.3
                }
                try fileManager.moveItem(at: localURL, to: destinationURL)

                DispatchQueue.main.async {
//                    self.progressBar.0 = "UPDATER: File renamed using asset name"
                    self.progressBar.1 = 0.4
                }

                self.unzipAndReplace(downloadedFileURL: destinationURL.path)

            } catch {
                print("Error moving downloaded file: \(error.localizedDescription)")
            }
        }
        downloadTask.resume()
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
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", fileURL, appDirectory]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            try process.run()
            process.waitUntilExit()

            DispatchQueue.main.async {
//                self.progressBar.0 = "UPDATER: Removing file from temp directory"
                self.progressBar.1 = 0.8
            }

            try fileManager.removeItem(atPath: fileURL)

            DispatchQueue.main.async {
                self.progressBar.0 = "Update completed"
                self.progressBar.1 = 1.0
            }

        } catch {
            print("Error updating the app: \(error)")
        }
    }
}
