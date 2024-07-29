//
//  Updater.swift
//  
//
//  Created by Alin Lupascu on 7/8/24.
//


import SwiftUI
import Combine

public class Updater: ObservableObject {
    @Published public var updateAvailable: Bool = false
    @Published public var showSheet: Bool = false
    @Published public var releases: [Release] = []
    @Published public var announcementAvailable: Bool = false
    @Published public var progressBar: (String, Double) = ("", 0.0)
    @Published public var nextUpdateDate: Date {
        didSet {
            UserDefaults.standard.set(nextUpdateDate.timeIntervalSinceReferenceDate, forKey: "alinfoundation.updater.nextUpdateDate")
        }
    }

    private var lastViewedVersion: String {
        get {
            defaults.string(forKey: "alinfoundation.updater.lastViewedVersion") ?? ""
        }
        set {
            defaults.set(newValue, forKey: "alinfoundation.updater.lastViewedVersion")
        }
    }
    
    private var announcement: String = ""
    private var announcementChecked = false
    private let owner: String
    private let repo: String
    public var token: String = ""
    private var updaterService: UpdaterService!
    private var cancellables: Set<AnyCancellable> = []
    private let defaults = UserDefaults.standard
    public var tokenManager: TokenManager?

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    @Published public var updateFrequency: UpdateFrequency {
        didSet {
            defaults.set(updateFrequency.rawValue, forKey: "alinfoundation.updater.updateFrequency")
            setNextUpdateDate()
        }
    }

    public init(owner: String, repo: String, tokenEnabled: Bool = false, service: String? = nil, account: String? = nil) {
        self.owner = owner
        self.repo = repo

        let storedInterval = defaults.double(forKey: "alinfoundation.updater.nextUpdateDate")
        if storedInterval != 0.0 {
            self.nextUpdateDate = Date(timeIntervalSinceReferenceDate: storedInterval)
        } else {
            self.nextUpdateDate = Date()
        }

        if let rawValue = defaults.string(forKey: "alinfoundation.updater.updateFrequency"),
           let frequency = UpdateFrequency(rawValue: rawValue) {
            self.updateFrequency = frequency
        } else {
            self.updateFrequency = .daily
        }

        if tokenEnabled {
            self.tokenManager = TokenManager(service: service ?? "\(Bundle.main.bundleId)", account: account ?? "GitHub-API-Token", repoUser: owner, repoName: repo)
            loadToken()
        } else {
            initializeUpdaterService()
        }
    }

    private func loadToken() {
        _ = tokenManager?.loadToken { [weak self] success in
            guard let self = self else { return }
            if success {
                self.token = self.tokenManager?.loadToken { _ in } ?? ""
                self.validateToken()
            } else {
                DispatchQueue.main.async {
                    self.tokenManager?.setTokenValidity(false)
                    self.initializeUpdaterService()
                }
            }
        }
    }

    private func validateToken() {

        tokenManager?.checkTokenValidity(token: token) { [weak self] isValid in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.tokenManager?.setTokenValidity(isValid)
                self.initializeUpdaterService()
            }
        }
    }

    private func initializeUpdaterService() {
        self.updaterService = UpdaterService(owner: owner, repo: repo, token: token)

        updaterService.$releases
            .assign(to: \.releases, on: self)
            .store(in: &cancellables)

        updaterService.$updateAvailable
            .assign(to: \.updateAvailable, on: self)
            .store(in: &cancellables)

        updaterService.$showSheet
            .assign(to: \.showSheet, on: self)
            .store(in: &cancellables)

        updaterService.$progressBar
            .assign(to: \.progressBar, on: self)
            .store(in: &cancellables)

        updaterService.setUpdater(self)

        /// This will check for updates on load based on the update frequency
        self.checkAndUpdateIfNeeded()

        /// Get new features
        self.checkForAnnouncement()
    }

    public func checkForUpdates(showSheet: Bool = true) {
        updaterService.loadGithubReleases(showSheet: showSheet)
    }

    public func checkReleaseNotes() {
        updaterService.checkReleaseNotes()
    }

    public func downloadUpdate() {
        updaterService.downloadUpdate()
    }

    public func getUpdateView() -> some View {
        UpdateContentView(updaterService: updaterService)
    }


    public func checkAndUpdateIfNeeded() {
        guard updateFrequency != .none else {
            self.checkReleaseNotes()
            print("Updater: frequency set to never, skipping update check")
            return
        }

        let now = Date()

//        if now <= nextUpdateDate { //MARK: Debugging
        if now >= nextUpdateDate {
            print("Updater: performing update check")
            self.checkForUpdates(showSheet: false)
        } else {
            self.checkReleaseNotes()
            print("Updater: next update date is in the future, skipping (\(formattedDate(nextUpdateDate)))")
        }
    }

    public func setNextUpdateDate() {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

//        print("Current time: \(now)")
//        print("Current update frequency: \(updateFrequency)")

        switch updateFrequency {
        case .daily:
            self.nextUpdateDate = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
//            print("Setting daily update: \(self.nextUpdateDate)")
        case .weekly:
            self.nextUpdateDate = calendar.date(byAdding: .day, value: 7, to: now)!
//            print("Setting weekly update: \(self.nextUpdateDate)")
        case .monthly:
            self.nextUpdateDate = calendar.date(byAdding: .month, value: 1, to: now)!
//            print("Setting monthly update: \(self.nextUpdateDate)")
        case .none:
            self.nextUpdateDate = .distantFuture
//            print("Setting no updates")
        }

        if self.nextUpdateDate <= now {
            self.nextUpdateDate = calendar.date(byAdding: .second, value: 1, to: now)!
//            print("Adjusted to future date: \(self.nextUpdateDate)")
        }

//        print("Final next update date: \(self.nextUpdateDate)")
    }

    //MARK: Features
    public func checkForAnnouncement(force: Bool = false) {

        if !force && announcementChecked {
            print("Updater: Skipping redundant feature check")
            return
        }

        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/announcements.json")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.VERSION.raw", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if !token.isEmpty {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            // Common logic to get the bundle version
            let bundleVersion = Bundle.main.version

            if let data = data {
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                    if let jsonDict = jsonObject as? [String: String] {
                        if force {
                            print("Updater: Forced check")
                            let sortedKeys = jsonDict.keys.sorted { $0 > $1 }
                            let allAnnouncement = sortedKeys.compactMap { key -> String? in
                                if let announcementText = jsonDict[key] {
                                    return "\(key)\n\n\(announcementText)"
                                }
                                return nil
                            }.joined(separator: "\n\n\n")

                            DispatchQueue.main.async {
                                self.announcement = allAnnouncement.announcementFormat()
                                self.announcementAvailable = true
                            }
                        } else if let announcementText = jsonDict[bundleVersion] {
                            print("Updater: Announcement check for version \(bundleVersion)")
                            DispatchQueue.main.async {
                                self.announcement = "v\(bundleVersion)\n\n\(announcementText)".announcementFormat()
                                self.announcementAvailable = force || (self.lastViewedVersion != bundleVersion)
                            }
                        } else {
                            print("Updater: No announcement for this version")
                            DispatchQueue.main.async {
                                self.announcement = "No announcement available for this version.".announcementFormat()
                                self.announcementAvailable = false
                            }
                        }
                        self.announcementChecked = true
                    } else {
                        print("Updater: JSON is not a dictionary of strings")
                        DispatchQueue.main.async {
                            self.announcement = "No announcement available for this version.".announcementFormat()
                            self.announcementAvailable = false
                        }
                    }
                } catch {
                    print("Updater: Error parsing announcement JSON from GitHub: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.announcement = "No announcement available for this version.".announcementFormat()
                        self.announcementAvailable = false
                    }
                }
            } else {
                print("Updater: Error fetching announcement JSON from GitHub: \(error?.localizedDescription ?? "Unknown error")")
            }
        }.resume()
    }




    public func getAnnouncementView() -> some View {
        FeatureView(updater: self)
    }

    public func markAnnouncementAsViewed() {
        if let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            lastViewedVersion = bundleVersion
            announcementAvailable = false
        }
    }

    public func resetAnnouncementAlert() {
        checkForAnnouncement(force: true)
    }

    public func getAnnouncement() -> String {
        return announcement
    }

    
}
