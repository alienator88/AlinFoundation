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
    @Published public var progressBar: (String, Double) = ("", 0.0)
    @Published public var nextUpdateDate: Date {
        didSet {
            UserDefaults.standard.set(nextUpdateDate.timeIntervalSinceReferenceDate, forKey: "alinfoundation.updater.nextUpdateDate")
        }
    }

    private let updaterService: UpdaterService
    private var cancellables: Set<AnyCancellable> = []
    private let defaults = UserDefaults.standard

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    @Published public var updateFrequency: UpdateFrequency {
        didSet {
            defaults.set(updateFrequency.rawValue, forKey: "alinfoundation.updater.updateFrequency")
            setNextUpdateDate()
        }
    }

    public init(owner: String, repo: String, token: String = "") {
        self.updaterService = UpdaterService(owner: owner, repo: repo, token: token)

        let storedInterval = defaults.double(forKey: "alinfoundation.updater.nextUpdateDate")
        self.nextUpdateDate = Date(timeIntervalSinceReferenceDate: storedInterval)

        if let rawValue = defaults.string(forKey: "alinfoundation.updater.updateFrequency"),
           let frequency = UpdateFrequency(rawValue: rawValue) {
            self.updateFrequency = frequency
        } else {
            self.updateFrequency = .daily
        }

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
    }

    public func checkForUpdates(showSheet: Bool = true, checkUpdate: Bool = true) {
        updaterService.loadGithubReleases(showSheet: showSheet, checkUpdate: checkUpdate)
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
            setNextUpdateDate()
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
}
