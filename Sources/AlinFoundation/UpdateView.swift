//
//  UpdateView.swift
//
//
//  Created by Alin Lupascu on 7/8/24.
//


import SwiftUI


struct UpdateContentView: View {
    let updaterService: UpdaterService

    var body: some View {
        Group {
            if updaterService.updateAvailable {
                UpdateView(updaterService: updaterService)
                    .edgesIgnoringSafeArea(.all)
                    .material(.hudWindow)
                    .frame(width: 600, height: 350)

            } else {
                NoUpdateView(updaterService: updaterService)
                    .edgesIgnoringSafeArea(.all)
                    .material(.hudWindow)
                    .frame(width: 500, height: 200)
            }
        }
    }
}



struct UpdateView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var updaterService: UpdaterService
    @State private var isAppInCorrectDirectory: Bool = true
    @State private var isUserAdmin: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Installed: v\(Bundle.main.version)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .opacity(0.5)
                    .padding(5)

                Spacer()

                Text("\(updaterService.updateAvailable ? "Update Available 🥳".localized() : "Completed 🚀".localized())")
                    .font(.title2)
                    .bold()
                    .padding(.vertical, 7)

                Spacer()

                Text("GitHub: v\(updaterService.releases.first?.tag_name ?? "")")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .opacity(0.5)
                    .padding(5)
            }
            .padding(7)

            Divider()

            ReleaseNotesView(
                release: updaterService.releases.first,
                owner: updaterService.owner,
                repo: updaterService.repo
            )

            Spacer()

            VStack() {
                ProgressView(value: updaterService.progressBar.1, total: 1.0, label: {Text(updaterService.progressBar.0)}, currentValueLabel: {Text("\(Int(updaterService.progressBar.1 * 100))%")})
            }
            .padding(.horizontal)

            HStack(alignment: .center, spacing: 10) {

                if updaterService.progressBar.1 == 0.0 {

                    Button(action: {
                        updaterService.downloadUpdate()
                    }) {
                        Text("Update")
                            .padding(5)
                    }
                    .disabled(updaterService.releases.first?.name.lowercased() == "ignore")
                    .contextMenu {
                        Button("Force Update") {
                            updaterService.downloadUpdate()
                        }
                    }
                } else if updaterService.progressBar.1 == 1.0 {
                    Button(action: {
                        relaunchApp(afterDelay: 1)
                    }) {
                        Text("Restart")
                            .padding(5)
                    }
                }

                Button(action: { dismiss() }) {
                    Text("Close")
                        .padding(5)
                }



            }
            .padding(.vertical)

            if updaterService.releases.first?.name.lowercased() == "ignore" {
                Text("Please ignore this testing release, it will be removed shortly")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
        }

    }
}



struct NoUpdateView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var updaterService: UpdaterService

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Installed: v\(Bundle.main.version)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .opacity(0.5)
                    .padding(5)

                Spacer()

                Text("\(updaterService.progressBar.1 != 1.0 ? "No Update 😌".localized() : "Completed 🚀".localized())")
                    .font(.title)
                    .bold()
                    .padding(.vertical, 5)

                Spacer()

                Text("GitHub: v\(updaterService.releases.first?.tag_name ?? "")")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .opacity(0.5)
                    .padding(5)
            }
            .padding(7)

            Divider()

            Spacer()

            Text("\(Bundle.main.name) is already on the latest release available")
                .font(.body)

            Spacer()

            Divider()

            Button(action: { dismiss() }) {
                Text("Close")
                    .padding(5)
            }
            .padding(.vertical)
            .contextMenu {
                Button("Force Update") {
                    updaterService.loadGithubReleases(showSheet: true, force: true)
                }
            }

        }

    }
}


public struct UpdateBadge: View {
    @ObservedObject var updater: Updater
    @State private var showUpdateView = false
    @State private var hovered = false


    public init(updater: Updater) {
        self.updater = updater
    }

    public var body: some View {

        if updater.releases.first?.name.lowercased() != "ignore" {
            AlertNotification(
                label: updater.updateFrequency == .none ? "Updates Disabled".localized() : (updater.updateAvailable ? "Update Available".localized() : "No Updates".localized()),
                icon: "arrow.down.app",
                buttonAction: {
                    showUpdateView = true
                },
                btnColor: Color.green,
                disabled: updater.updateFrequency == .none
            )
            .onAppear {
                if updater.forceUpdate {
                    updater.checkForUpdatesForce(showSheet: false)
                } else {
                    updater.checkForUpdates(showSheet: false)
                }
            }
            .sheet(isPresented: $showUpdateView, content: {
                updater.getUpdateView()
            })
        }


    }
}



public struct FrequencyView: View {
    @ObservedObject var updater: Updater
    @State private var localNextUpdateDate: Date

    public init(updater: Updater) {
        self.updater = updater
        _localNextUpdateDate = State(initialValue: updater.nextUpdateDate)
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(Bundle.main.name) will check for updates")
                    .font(.callout)

                if updater.updateFrequency != .none && updater.updateFrequency != .daily {
                    Text("Next update check: \(formattedDate(localNextUpdateDate))")
                        .font(.footnote)
                        .opacity(0.5)
                }
            }
            .padding(.leading, 2)

            Spacer()

            Picker("", selection: $updater.updateFrequency) {
                ForEach(UpdateFrequency.allCases, id: \.self) { frequency in
                    Text(frequency.rawValue.localized()).tag(frequency)
                }
            }
            .onChange(of: updater.updateFrequency) { _ in
                localNextUpdateDate = updater.nextUpdateDate
                updater.checkForUpdates(showSheet: false)
            }
            .buttonStyle(.borderless)
        }
        .onReceive(updater.$nextUpdateDate) { newDate in
            localNextUpdateDate = newDate
        }
    }
}


public struct ReleasesView: View {
    @ObservedObject var updater: Updater

    public init(updater: Updater) {
        self.updater = updater
    }

    public var body: some View {

        VStack {
            if !updater.releases.isEmpty {
                ScrollView {
                    VStack() {
                        ForEach(updater.releases, id: \.id) { release in
                            VStack(alignment: .leading) {
                                LabeledDivider(label: "\(release.tag_name)")

                                if let attributedString = release.modifiedBody(owner: updater.owner, repo: updater.repo) {
                                    let swiftAttributedString = AttributedString(attributedString)
                                    Text(swiftAttributedString)
                                        .font(.body)
                                        .multilineTextAlignment(.leading)
                                        .padding(10)
                                        .textSelection(.disabled)
                                } else {
                                    Text("Failed to display release notes")
                                        .font(.body)
                                        .foregroundColor(.red)
                                        .padding(10)
                                }
                            }


                        }
                    }
                    .padding()
                }
            } else {
                VStack {
                    Text("No releases to display")
                        .font(.title)
                        .foregroundColor(.primary)
                    Text("Updater frequency is set to Never")
                        .font(.body)
                        .foregroundColor(.primary.opacity(0.5))
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            }

            if !updater.releases.isEmpty {
                Text("Showing last 3 releases")
                    .font(.callout)
                    .opacity(0.5)
                    .padding(5)
            }

        }
    }
}



//MARK: Features
public struct FeatureBadge: View {
    @ObservedObject var updater: Updater
    @State private var showFeatureView = false

    public init(updater: Updater) {
        self.updater = updater
    }

    public var body: some View {
        AlertNotification(label: updater.announcementAvailable ? "New Announcement".localized() : "No New Announcement".localized(), icon: "star", buttonAction: {
            showFeatureView = true
        }, btnColor: Color.blue)
        .sheet(isPresented: $showFeatureView, content: {
            updater.getAnnouncementView()
        })
    }
}


public struct FeatureView: View {
    @ObservedObject var updater: Updater
    @Environment(\.dismiss) var dismiss

    public var body: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Text("Announcement")
                    .font(.title)
                    .bold()
                Spacer()
            }

            Divider()

            ScrollView() {
                Text(updater.getAnnouncement())
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding()
            }
            .frame(width: 500)
            .frame(maxHeight: 400)


            HStack(alignment: .center, spacing: 20) {
                Button(action: {
                    updater.markAnnouncementAsViewed()
                    dismiss()
                }) {
                    Text("Close")
                }
            }
            .padding(.vertical)
        }
        .padding()
        .material(.hudWindow)

    }
}
