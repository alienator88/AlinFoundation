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
    private let instanceID = UUID().uuidString.prefix(8)
    
    @Published public var updateAvailable: Bool = false
    @Published public var sheet: Bool = false
    @Published public var releases: [Release] = []
    @Published public var announcementAvailable: Bool = false
    @Published public var progressBar: (String, Double) = ("", 0.0)
    @Published public var nextUpdateDate: Date {
        didSet {
            saveNextUpdateDate()
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
    private var updaterService: UpdaterService?
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

    private var tokenValidationAttempted = false
    private var isInitializingService = false

    public init(owner: String, repo: String, tokenEnabled: Bool = false, service: String? = nil, account: String? = nil) {
        
        self.owner = owner
        self.repo = repo

        // Initialize date and frequency settings...
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

        // Setup token manager if needed
        if tokenEnabled {
            setupTokenManager(service: service, account: account)
        } else {
            initializeUpdaterService()
        }

        ensureApplicationSupportFolderExists()
    }
    
    deinit {
        printOS("💀 Updater DEINIT - Instance: \(instanceID)", category: LogCategory.updater)
    }

    private func setupTokenManager(service: String?, account: String?) {
        
        let serviceName = service ?? (Bundle.main.bundleIdentifier ?? "AlinFoundation.Updater")
        let accountName = account ?? "GitHub-API-Token"
        
        self.tokenManager = TokenManager(
            service: serviceName,
            account: accountName,
            repoUser: owner,
            repoName: repo
        )
        
        loadAndValidateToken()
    }

    private func loadAndValidateToken() {
        tokenManager?.loadToken { [weak self] success, token in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if success {
                    self.token = token
                    self.validateTokenAndInitialize()
                } else {
                    self.tokenManager?.setTokenValidity(false)
                    self.initializeUpdaterService() // ← This should always be called
                }
            }
        }
    }

    private func validateTokenAndInitialize() {
        guard !tokenValidationAttempted else {
            initializeUpdaterService()
            return
        }
        
        tokenValidationAttempted = true
        tokenManager?.checkTokenValidity(token: token) { [weak self] isValid in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.tokenManager?.setTokenValidity(isValid)
                self.initializeUpdaterService()
            }
        }
    }

    private func initializeUpdaterService() {
        if isInitializingService {
            printOS("⚠️ Updater: Already initializing service, skipping", category: LogCategory.updater)
            return
        }
        
        isInitializingService = true
        
        self.updaterService = UpdaterService(owner: owner, repo: repo, token: token)
        
        // Safely unwrap updaterService for Combine assignments
        guard let service = updaterService else {
            printOS("Updater: Failed to create UpdaterService", category: LogCategory.updater)
            isInitializingService = false
            return
        }
        
        service.$releases
            .assign(to: \.releases, on: self)
            .store(in: &cancellables)

        service.$updateAvailable
            .assign(to: \.updateAvailable, on: self)
            .store(in: &cancellables)

        service.$sheet
            .assign(to: \.sheet, on: self)
            .store(in: &cancellables)

        service.$progressBar
            .assign(to: \.progressBar, on: self)
            .store(in: &cancellables)

        service.setUpdater(self)

        isInitializingService = false

        /// This will check for updates on load based on the update frequency
        self.checkAndUpdateIfNeeded()

        /// Get new features
        self.checkForAnnouncement()
    }

    public func checkForUpdates(sheet: Bool = false, force: Bool = false) {
        guard updateFrequency != .none || force else { // Disable so no badge check happens when set to Never frequency. Allow forced check.
            printOS("Updater: frequency set to never, skipping badge update check", category: LogCategory.updater)
            return
        }
        
        // Remove this problematic guard - service should always be initialized by now
        // guard let service = updaterService else {
        //     printOS("Updater: UpdaterService not initialized, initializing now...", category: LogCategory.updater)
        //     initializeUpdaterService()
        //     return
        // }
        
        guard let service = updaterService else {
            printOS("Updater: UpdaterService not initialized - this shouldn't happen", category: LogCategory.updater)
            return
        }
        
        service.loadGithubReleases(sheet: sheet, force: force)

    }

    public func checkReleaseNotes() {
        guard let service = updaterService else {
            printOS("Updater: UpdaterService not initialized for checkReleaseNotes", category: LogCategory.updater)
            return
        }
        service.checkReleaseNotes()
    }

    public func downloadUpdate() {
        guard let service = updaterService else {
            printOS("Updater: UpdaterService not initialized for downloadUpdate", category: LogCategory.updater)
            return
        }
        service.downloadUpdate()
    }

    public func getUpdateView() -> some View {
        if let service = updaterService {
            return UpdateContentView(updaterService: service)
        } else {
            // Return a placeholder view if service isn't initialized
            return UpdateContentView(updaterService: UpdaterService(owner: owner, repo: repo, token: token))
        }
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

        switch updateFrequency {
        case .daily:
            self.nextUpdateDate = calendar.date(byAdding: .second, value: 1, to: now) ?? Date() /// Check on every launch
        case .weekly:
            self.nextUpdateDate = calendar.date(byAdding: .day, value: 7, to: now) ?? Date()
        case .monthly:
            self.nextUpdateDate = calendar.date(byAdding: .month, value: 1, to: now) ?? Date()
        case .none:
            self.nextUpdateDate = .distantFuture
        }

        // Ensure next update date is in the future
        if self.nextUpdateDate <= now {
            self.nextUpdateDate = calendar.date(byAdding: .second, value: 1, to: now) ?? Date()
        }
    }

    private func saveNextUpdateDate() {
        UserDefaults.standard.set(nextUpdateDate.timeIntervalSinceReferenceDate, forKey: DefaultsKeys.nextUpdateDate)
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

        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/announcements.json") else {
            printOS("Updater: invalid announcement URL", category: LogCategory.updater)
            return
        }

        var request = makeRequest(url: url, token: token)
        request.setValue("application/vnd.github.VERSION.raw", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if handleGitHubResponseErrors(response: response, error: error) {
                return
            }

            let bundleVersion = currentVersion

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
            guard let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
                return ("No announcement available for this version.".announcementFormat(), false)
            }

            if force {
                let sortedAnnouncements = jsonDict
                    .sorted { $0.key > $1.key }
                    .map { "\($0.key)\n\n\($0.value)" }
                    .joined(separator: "\n\n\n")
                return (sortedAnnouncements.announcementFormat(), true)
            } else if let announcementText = jsonDict[bundleVersion] {
                return ("v\(bundleVersion)\n\n\(announcementText)".announcementFormat(), true)
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
        let bundleVersion = currentVersion
        if !bundleVersion.isEmpty {
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
