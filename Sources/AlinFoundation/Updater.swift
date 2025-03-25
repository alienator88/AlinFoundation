//
//  Updater.swift
//
//
//  Created by Alin Lupascu on 7/8/24.
//


import SwiftUI
import Combine

public enum DefaultsKeys {
    static let nextUpdateDate = "alinfoundation.updater.nextUpdateDate"
    static let lastViewedVersion = "alinfoundation.updater.lastViewedVersion"
    static let updateFrequency = "alinfoundation.updater.updateFrequency"
}

public class Updater: ObservableObject {
    @Published public var updateAvailable: Bool = false
    @Published public var sheet: Bool = false
    @Published public var releases: [Release] = []
    @Published public var announcementAvailable: Bool = false
    @Published public var progressBar: (String, Double) = ("", 0.0)
    @Published public var nextUpdateDate: Date {
        didSet {
            UserDefaults.standard.set(nextUpdateDate.timeIntervalSinceReferenceDate, forKey: DefaultsKeys.nextUpdateDate)
        }
    }

    private var lastViewedVersion: String {
        get {
            defaults.string(forKey: DefaultsKeys.lastViewedVersion) ?? ""
        }
        set {
            defaults.set(newValue, forKey: DefaultsKeys.lastViewedVersion)
        }
    }

    private var announcement: String = ""
    private var announcementChecked = false
    @Published var owner: String
    @Published var repo: String
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
            defaults.set(updateFrequency.rawValue, forKey: DefaultsKeys.updateFrequency)
            setNextUpdateDate()
        }
    }

    public init(owner: String, repo: String, tokenEnabled: Bool = false, service: String? = nil, account: String? = nil) {
        self.owner = owner
        self.repo = repo

        let storedInterval = defaults.double(forKey: DefaultsKeys.nextUpdateDate)
        if storedInterval != 0.0 {
            self.nextUpdateDate = Date(timeIntervalSinceReferenceDate: storedInterval)
        } else {
            self.nextUpdateDate = Date()
        }

        if let rawValue = defaults.string(forKey: DefaultsKeys.updateFrequency),
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
        tokenManager?.loadToken { [weak self] success, token in
            guard let self = self else { return }
            if success {
                self.token = token
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

        updaterService.$sheet
            .assign(to: \.sheet, on: self)
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

    public func checkForUpdates(sheet: Bool = false, force: Bool = false) {
        guard updateFrequency != .none else { // Disable so no badge check happens when set to Never frequency
            printOS("Updater: frequency set to never, skipping badge update check", category: LogCategory.updater)
            return
        }

        updaterService.loadGithubReleases(sheet: sheet, force: force)

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
            printOS("Updater: frequency set to never, skipping update check", category: LogCategory.updater)
            return
        }

        let now = Date()

        if now >= nextUpdateDate {
            printOS("Updater: performing update check", category: LogCategory.updater)
            self.checkForUpdates()
        } else {
            self.checkReleaseNotes()
            printOS("Updater: next update date is in the future, skipping (\(formattedDate(nextUpdateDate)))", category: LogCategory.updater)
        }
    }

    public func setNextUpdateDate() {
        let calendar = Calendar.current
        let now = Date()
        //        let startOfToday = calendar.startOfDay(for: now)

        switch updateFrequency {
        case .daily:
            self.nextUpdateDate = calendar.date(byAdding: .second, value: 1, to: now)! /// Check on every launch
                                                                                       //            self.nextUpdateDate = calendar.date(byAdding: .day, value: 1, to: startOfToday)! /// Check only once per day
        case .weekly:
            self.nextUpdateDate = calendar.date(byAdding: .day, value: 7, to: now)!
        case .monthly:
            self.nextUpdateDate = calendar.date(byAdding: .month, value: 1, to: now)!
        case .none:
            self.nextUpdateDate = .distantFuture
        }

        if self.nextUpdateDate <= now {
            self.nextUpdateDate = calendar.date(byAdding: .second, value: 1, to: now)!
        }
    }

    //MARK: Features
    public func checkForAnnouncement(force: Bool = false) {

        guard updateFrequency != .none || force else {
            printOS("Updater: frequency set to never, skipping announcement check", category: LogCategory.updater)
            return
        }

        if !force && announcementChecked {
            printOS("Updater: skipping redundant feature check", category: LogCategory.updater)
            return
        }

        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/announcements.json")!
        var request = makeRequest(url: url, token: token)
        request.setValue("application/vnd.github.VERSION.raw", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                printOS("Updater Network error: \(error.localizedDescription)", category: LogCategory.updater)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                printOS("Updater HTTP error: \(response.debugDescription)", category: LogCategory.updater)
                return
            }

            let bundleVersion = Bundle.main.version

            if let data = data {
                if let result = self.parseAnnouncement(from: data, for: bundleVersion, force: force) {
                    DispatchQueue.main.async {
                        self.announcement = result.announcement
                        self.announcementAvailable = force || (self.lastViewedVersion != bundleVersion) && result.available
                    }
                } else {
                    printOS("Updater: no announcement found or JSON in unexpected format", category: LogCategory.updater)
                    DispatchQueue.main.async {
                        self.announcement = "No announcement available for this version.".announcementFormat()
                        self.announcementAvailable = false
                    }
                }
            } else {
                printOS("Updater: error fetching announcement JSON from GitHub: \(error?.localizedDescription ?? "Unknown error")", category: LogCategory.updater)
            }
        }.resume()
    }


    private func parseAnnouncement(from data: Data, for bundleVersion: String, force: Bool) -> (announcement: String, available: Bool)? {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            if let jsonDict = jsonObject as? [String: String] {
                if force {
                    let sortedKeys = jsonDict.keys.sorted { $0 > $1 }
                    let allAnnouncement = sortedKeys.compactMap { key -> String? in
                        if let announcementText = jsonDict[key] {
                            return "\(key)\n\n\(announcementText)"
                        }
                        return nil
                    }.joined(separator: "\n\n\n")
                    return (allAnnouncement.announcementFormat(), true)
                } else if let announcementText = jsonDict[bundleVersion] {
                    return ("v\(bundleVersion)\n\n\(announcementText)".announcementFormat(), true)
                } else {
                    return ("No announcement available for this version.".announcementFormat(), false)
                }
            } else {
                return ("No announcement available for this version.".announcementFormat(), false)
            }
        } catch {
            return nil
        }
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
