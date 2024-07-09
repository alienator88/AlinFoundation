//
//  UpdateView.swift
//
//
//  Created by Alin Lupascu on 7/8/24.
//


import SwiftUI

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

                Text("\(updaterService.updateAvailable ? "Update Available 🥳" : "Completed 🚀")")
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

            ReleaseNotesView(releaseNotes: updaterService.releases.first?.modifiedBody)

            Spacer()

            VStack() {
                Text(updaterService.progressBar.0)
                    .opacity(0.5)
                ProgressView(value: updaterService.progressBar.1, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(height: 10)
            }
            .padding([.horizontal, .bottom])

            HStack(alignment: .center, spacing: 10) {

                if updaterService.progressBar.1 != 1.0 {
                    Button(action: {
                        updaterService.downloadUpdate()
                    }) {
                        Text("Update")
                            .padding(5)
                    }
                    Button(action: { dismiss() }) {
                        Text("Close")
                            .padding(5)
                    }
                } else {
                    Button(action: {
                        relaunchApp()
                    }) {
                        Text("Restart")
                            .padding(5)
                    }
                }

            }
            .padding(5)
            .padding(.bottom, isAppInCorrectDirectory ? 10 : 0)
        }
        .safeAreaInset(edge: .bottom, content: {
            if !isAppInCorrectDirectory {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        Spacer()
                        Text("To avoid update issues, please move \(Bundle.main.name) to the \(isUserAdmin ? "/Applications" : "\(NSHomeDirectory())/Applications") folder before updating")
                            .font(.callout)
                            .opacity(0.5)
                        Spacer()
                    }
                    .padding(.vertical, 7)
                }


            }
        })
        .onAppear {
            checkAppDirectoryAndUserRole { result in
                isUserAdmin = result.isAdmin
                isAppInCorrectDirectory = result.isInCorrectDirectory
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

                Text("\(updaterService.progressBar.1 != 1.0 ? "No Update 😌" : "Completed 🚀")")
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

        }
    }
}


public struct UpdateButton: View {
    @ObservedObject var updater: GitHubUpdater
    @State private var showUpdateView = false
    @State var showButton: Bool
    @State var showLabel: Bool
    @State var spacer: Bool

    public init(updater: GitHubUpdater, showButton: Bool = true, showLabel: Bool = true, spacer: Bool = false) {
        self.updater = updater
        self.showButton = showButton
        self.showLabel = showLabel
        self.spacer = spacer
    }

    public var body: some View {
        HStack {
            if showButton {
                Button("Update") {
                    showUpdateView = true
                }
            }
            if spacer {
                Spacer()
            }
            if showLabel {
                Text(updater.updateAvailable ? "Update Available" : "No Updates")
                    .font(.callout)
                    .opacity(0.5)
                    .onTapGesture {
                        showUpdateView = true
                    }
            }
        }
        .padding()
        .onAppear {
            updater.checkForUpdates()
        }
        .sheet(isPresented: $showUpdateView, content: {
            updater.getUpdateView()
        })
    }
}



struct FrequencyView: View {
    @ObservedObject var updater: GitHubUpdater
    @State private var localNextUpdateDate: Date

    init(updater: GitHubUpdater) {
        self.updater = updater
        _localNextUpdateDate = State(initialValue: updater.nextUpdateDate)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(Bundle.main.name) will check for updates")
                    .font(.callout)

                if updater.updateFrequency != .none {
                    Text("Next update check: \(formattedDate(localNextUpdateDate))")
                        .font(.footnote)
                        .opacity(0.5)
                }
            }

            Spacer()

            Picker("", selection: $updater.updateFrequency) {
                ForEach(UpdateFrequency.allCases, id: \.self) { frequency in
                    Text(frequency.rawValue).tag(frequency)
                }
            }
            .onChange(of: updater.updateFrequency) { _ in
                localNextUpdateDate = updater.nextUpdateDate
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .onReceive(updater.$nextUpdateDate) { newDate in
            localNextUpdateDate = newDate
        }
    }
}


struct ReleasesView: View {
    @ObservedObject var updater: GitHubUpdater

    init(updater: GitHubUpdater) {
        self.updater = updater
    }

    var body: some View {

        VStack {
            ScrollView {
                VStack() {
                    ForEach(updater.releases, id: \.id) { release in
                        VStack(alignment: .leading) {
                            LabeledDivider(label: "\(release.tag_name)")
                            Text(release.modifiedBody)
                        }

                    }
                }
                .padding()
            }

            Text("Showing last 3 releases")
                .font(.callout)
                .opacity(0.5)
        }


    }
}
