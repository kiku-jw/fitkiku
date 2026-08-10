// SPDX-License-Identifier: MPL-2.0

import Foundation
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var pastedPairLink = ""
    @State private var showManualPairLink = false
    @State private var showRecoverySetup = false
    @State private var showSettings = false
    @State private var showDeliveryDetails: Bool
    @ScaledMetric(relativeTo: .body) private var minimumControlHeight = 44

    init(model: AppModel) {
        self.model = model
        _showDeliveryDetails = State(initialValue: model.shouldExpandDeliveryForDemo)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        intro
                        if model.isPaired {
                            connectionCard
                        } else {
                            pairingCard
                        }
                        healthAccessCard
                        if model.healthAccessRequested {
                            summaries
                        }
                        if model.isPaired {
                            syncCard
                                .id("delivery")
                        }
                        privacyNote
                        #if DEBUG
                        if model.demoScrollTarget != nil {
                            Color.clear
                                .frame(height: 440)
                                .accessibilityHidden(true)
                        }
                        #endif
                    }
                    .frame(maxWidth: 620)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .background(Color(.systemGroupedBackground))
                .scrollDismissesKeyboard(.interactively)
                .task {
                    guard let target = model.demoScrollTarget else { return }
                    proxy.scrollTo(target, anchor: .top)
                }
            }
            .navigationTitle("FitKiku")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(.teal)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Open settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.teal)
                .accessibilityHidden(true)
            Text("Apple Health, on your terms")
                .font(.title.bold())
            Text(
                "Give an agent you approve read-only Steps and Sleep. "
                    + "You can see what was delivered and revoke access at any time."
            )
            .font(.body)
            .foregroundStyle(Color.fitKikuSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pairingCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    title: "Connect an agent",
                    detail: "Step 1 of 2",
                    systemImage: "link.badge.plus"
                )

                if model.localCredentialCleanupPending {
                    cleanupRecovery
                } else if let consent = model.pendingAgentConsent {
                    agentConsentCard(consent)
                } else if let recovery = model.pendingLegacyPairing {
                    legacyConsentCard(recovery)
                } else {
                    Text(
                        "Ask your agent to connect Apple Health, then open the "
                            + "FitKiku Pair Link it sends. Opening a link never shares health data."
                    )
                    .foregroundStyle(Color.fitKikuSecondaryText)

                    DisclosureGroup(
                        "Paste a Pair Link manually",
                        isExpanded: $showManualPairLink
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Pair Link")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.fitKikuSecondaryText)
                            SecureField("Paste Pair Link", text: $pastedPairLink)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.URL)
                                .submitLabel(.go)
                                .onSubmit(reviewPairLink)
                                .textFieldStyle(.roundedBorder)
                            Button(action: reviewPairLink) {
                                actionLabel("Review connection", systemImage: "checkmark.shield")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isBusy || pairLinkIsBlank)
                        }
                        .padding(.top, 10)
                    }

                    DisclosureGroup(
                        "Recovery options",
                        isExpanded: $showRecoverySetup
                    ) {
                        recoverySetup
                            .padding(.top, 10)
                    }
                }
                feedback
            }
        }
    }

    private var cleanupRecovery: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Server access is already revoked", systemImage: "lock.slash")
                .font(.headline)
            Text(
                "Remove the unusable credential from this iPhone before creating another connection."
            )
            .foregroundStyle(Color.fitKikuSecondaryText)
            Button {
                Task { await model.retryLocalCredentialCleanup() }
            } label: {
                actionLabel("Finish local cleanup", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isBusy)
        }
    }

    private var recoverySetup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Use this only when your private FitKiku server gives you an 8-digit code.")
                .font(.footnote)
                .foregroundStyle(Color.fitKikuSecondaryText)
            Text("Server address")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.fitKikuSecondaryText)
            TextField("https://fitkiku.example", text: $model.serverAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.URL)
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)
            Text("Pairing code")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.fitKikuSecondaryText)
            TextField("8-digit code", text: $model.pairingCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .textFieldStyle(.roundedBorder)
                .onChange(of: model.pairingCode) { _, value in
                    model.pairingCode = String(value.filter(\.isNumber).prefix(8))
                }
            Button {
                Task { await model.pairLegacyManually() }
            } label: {
                actionLabel("Connect with recovery code", systemImage: "wrench.and.screwdriver")
            }
            .buttonStyle(.bordered)
            .disabled(model.isBusy || model.pairingCode.count != 8)
        }
    }

    private func agentConsentCard(_ consent: PendingAgentConsent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Review before connecting")
                .font(.headline)
            detailRow("Claimed agent", value: consent.preview.assertedAgentName)
            Text("The requesting service supplied this name; FitKiku has not verified its identity.")
                .font(.footnote)
                .foregroundStyle(Color.fitKikuSecondaryText)
            detailRow("Destination", value: consent.baseURL.absoluteString, monospaced: true)
            detailRow("Read-only data", value: "Steps and Sleep")
            Text(NativeHealthDisclosure.outbound)
                .font(.footnote)
                .foregroundStyle(Color.fitKikuSecondaryText)
            detailRow("Request expires", value: consent.preview.expiresAt)
            disclosure(title: "Retention", body: consent.preview.retentionDisclosure)
            disclosure(title: "AI processing", body: consent.preview.aiProcessingDisclosure)
            Text("Apple Health permission is a separate next step.")
                .font(.footnote.weight(.medium))

            ViewThatFits(in: .horizontal) {
                HStack {
                    cancelPairingButton
                    Spacer(minLength: 12)
                    approvePairingButton
                }
                VStack(spacing: 10) {
                    approvePairingButton
                    cancelPairingButton
                }
            }
        }
    }

    private var cancelPairingButton: some View {
        Button("Cancel", role: .cancel) {
            model.cancelPendingPairing()
            pastedPairLink = ""
        }
        .buttonStyle(.bordered)
        .frame(minHeight: minimumControlHeight)
    }

    private var approvePairingButton: some View {
        Button {
            Task {
                await model.approveAgentPairing()
                if model.pendingAgentConsent == nil {
                    pastedPairLink = ""
                }
            }
        } label: {
            Label("Approve connection", systemImage: "lock.shield")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.isBusy)
        .frame(minHeight: minimumControlHeight)
    }

    private func legacyConsentCard(_ recovery: PendingLegacyPairing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recovery connection", systemImage: "wrench.and.screwdriver")
                .font(.headline)
            detailRow("HTTPS destination", value: recovery.baseURL.absoluteString, monospaced: true)
            Text("This older flow does not include the agent's retention or AI-processing disclosure.")
                .font(.footnote)
                .foregroundStyle(Color.fitKikuSecondaryText)
            ViewThatFits(in: .horizontal) {
                HStack {
                    Button("Cancel", role: .cancel) {
                        model.cancelPendingPairing()
                    }
                    .buttonStyle(.bordered)
                    Spacer(minLength: 12)
                    legacyApproveButton
                }
                VStack(spacing: 10) {
                    legacyApproveButton
                    Button("Cancel", role: .cancel) {
                        model.cancelPendingPairing()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var legacyApproveButton: some View {
        Button {
            Task { await model.approveLegacyPairing() }
        } label: {
            Label("Connect", systemImage: "lock.shield")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.isBusy)
    }

    private func disclosure(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
            Text(body)
                .font(.footnote)
                .foregroundStyle(Color.fitKikuSecondaryText)
        }
    }

    private var connectionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: "Agent connected",
                    detail: connectionHost,
                    systemImage: "checkmark.seal.fill",
                    tint: .green
                )
                Text("Only read-only Steps and Sleep can be delivered to this destination.")
                    .foregroundStyle(Color.fitKikuSecondaryText)
                feedback
            }
        }
    }

    private var healthAccessCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Allow Apple Health",
                    detail: "Step 2 of 2",
                    systemImage: "heart.fill",
                    tint: .red
                )
                if !model.healthAccessRequested {
                    Text(
                        "FitKiku asks only for read access to Steps and Sleep. "
                            + "Nothing is written to Apple Health."
                    )
                    .foregroundStyle(Color.fitKikuSecondaryText)
                    if !model.isPaired {
                        Text("You can review local summaries before connecting an agent.")
                            .font(.footnote)
                            .foregroundStyle(Color.fitKikuSecondaryText)
                    }
                    Button {
                        Task { await model.requestHealthAccess() }
                    } label: {
                        actionLabel("Continue to Health", systemImage: "heart.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isBusy)
                } else {
                    Label("Read-only access requested", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text(
                        "Apple keeps read-denial status private. Missing data stays Unknown; "
                            + "FitKiku never replaces it with zero."
                    )
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private var summaries: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("On this iPhone")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .id("summaries")
            DaySummaryCard(title: "Today", summary: model.today)
            DaySummaryCard(title: "Yesterday", summary: model.yesterday)
                .id("yesterday")
        }
    }

    private var syncCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Delivery",
                    detail: deliveryHeadline,
                    systemImage: "arrow.triangle.2.circlepath"
                )

                Button {
                    Task { await model.syncNow() }
                } label: {
                    actionLabel(
                        model.isBusy ? "Checking…" : "Check and sync now",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.healthAccessRequested)

                if let lastSyncAt = model.lastSyncAt {
                    Label(
                        "Last server-confirmed sync \(lastSyncAt.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "checkmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                }

                DisclosureGroup("Delivery details", isExpanded: $showDeliveryDetails) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let delivery = model.deliveryStatus {
                            deliveryStatusLine(
                                "Server confirmed",
                                date: delivery.lastServerReceivedAt,
                                emptyText: "Waiting for first sync"
                            )
                            deliveryStatusLine(
                                "Agent fetched",
                                date: delivery.lastAgentFetchedAt,
                                emptyText: "Not fetched yet"
                            )
                            if let latestLocalDate = delivery.latestLocalDate,
                               let coverage = delivery.latestCoverage
                            {
                                detailRow(
                                    "Latest server day",
                                    value: "\(latestLocalDate) · Steps \(coverage.steps.rawValue), Sleep \(coverage.sleep.rawValue)"
                                )
                            }
                            Text(
                                delivery.missingLocalDates.isEmpty
                                    ? "Recent server days are present."
                                    : "Missing recent server days: \(delivery.missingLocalDates.joined(separator: ", "))"
                            )
                            .font(.caption)
                            .foregroundStyle(
                                delivery.missingLocalDates.isEmpty ? Color.fitKikuSecondaryText : Color.orange
                            )
                        } else {
                            Text("Delivery has not been checked yet.")
                                .font(.caption)
                                .foregroundStyle(Color.fitKikuSecondaryText)
                        }

                        if let deliveryError = model.deliveryStatusError {
                            Label(deliveryError, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        Button("Refresh delivery details") {
                            Task { await model.refreshDeliveryStatus() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy)

                        Divider()

                        Button("Disconnect and revoke access", role: .destructive) {
                            Task { await model.disconnect() }
                        }
                        .disabled(model.isBusy)
                    }
                    .padding(.top, 10)
                }
            }
        }
    }

    private var privacyNote: some View {
        Label(
            "FitKiku sends daily Steps, asleep minutes, coverage, and source details only after approval. Sleep interval times stay on this iPhone.",
            systemImage: "lock.shield"
        )
        .font(.footnote)
        .foregroundStyle(Color.fitKikuSecondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var feedback: some View {
        Group {
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Error: \(error)")
            } else if let status = model.statusMessage {
                Label(status, systemImage: "info.circle.fill")
                    .foregroundStyle(Color.fitKikuSecondaryText)
                    .accessibilityLabel("Status: \(status)")
            }
        }
        .font(.footnote)
    }

    private func sectionHeader(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color = .teal
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                headerIcon(systemImage, tint: tint)
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 8)
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.fitKikuSecondaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    headerIcon(systemImage, tint: tint)
                    Text(title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.fitKikuSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func headerIcon(_ systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }

    private func detailRow(_ title: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.fitKikuSecondaryText)
            Text(value)
                .font(monospaced ? .caption.monospaced() : .subheadline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func deliveryStatusLine(_ title: String, date: Date?, emptyText: String) -> some View {
        detailRow(
            title,
            value: date?.formatted(date: .abbreviated, time: .shortened) ?? emptyText
        )
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity, minHeight: minimumControlHeight)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
    }

    private var pairLinkIsBlank: Bool {
        pastedPairLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func reviewPairLink() {
        guard !pairLinkIsBlank, !model.isBusy else { return }
        let input = pastedPairLink
        pastedPairLink = ""
        Task { await model.loadPairingInput(input) }
    }

    private var connectionHost: String {
        URL(string: model.serverAddress)?.host ?? "Approved destination"
    }

    private var deliveryHeadline: String {
        guard let delivery = model.deliveryStatus else { return "Not checked" }
        switch delivery.dataFreshness {
        case .current:
            return "Current"
        case .stale:
            return "Needs attention"
        case .unknown:
            return "Unknown"
        }
    }
}

enum FitKikuLinks {
    static let website = URL(string: "https://kikuai.dev/fitkiku/")!
    static let source = URL(string: "https://github.com/kiku-jw/fitkiku")!
    static let github = URL(string: "https://github.com/kiku-jw")!
    static let telegram = URL(string: "https://t.me/kiku_ai")!
    static let privacy = URL(string: "https://kikuai.dev/fitkiku/privacy/")!
    static let support = URL(string: "https://kikuai.dev/fitkiku/support/")!

    static let all = [website, source, github, telegram, privacy, support]
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("FitKiku") {
                    settingsLink("Product website", systemImage: "globe", url: FitKikuLinks.website)
                    settingsLink("Source code", systemImage: "chevron.left.forwardslash.chevron.right", url: FitKikuLinks.source)
                    settingsLink("GitHub", systemImage: "person.crop.circle", url: FitKikuLinks.github)
                    settingsLink("Telegram blog", systemImage: "paperplane", url: FitKikuLinks.telegram)
                }

                Section("Help and privacy") {
                    settingsLink("Privacy policy", systemImage: "hand.raised", url: FitKikuLinks.privacy)
                    settingsLink("Support", systemImage: "questionmark.circle", url: FitKikuLinks.support)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .tint(.teal)
    }

    private func settingsLink(_ title: String, systemImage: String, url: URL) -> some View {
        Link(destination: url) {
            Label(title, systemImage: systemImage)
                .frame(minHeight: 44)
        }
        .accessibilityHint("Opens in your browser")
    }
}

private extension Color {
    static var fitKikuSecondaryText: Color {
        Color.primary.opacity(0.68)
    }
}

private struct DaySummaryCard: View {
    let title: String
    let summary: DaySummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer(minLength: 12)
                Text(summary?.localDate ?? "Not available")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.fitKikuSecondaryText)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    metric(
                        title: "Steps",
                        value: summary?.steps.map(String.init) ?? "Unknown",
                        symbol: "figure.walk"
                    )
                    metric(title: "Sleep", value: sleepText, symbol: "bed.double.fill")
                }
                VStack(spacing: 12) {
                    metric(
                        title: "Steps",
                        value: summary?.steps.map(String.init) ?? "Unknown",
                        symbol: "figure.walk"
                    )
                    metric(title: "Sleep", value: sleepText, symbol: "bed.double.fill")
                }
            }

            if let summary {
                Label("Read from Apple Health", systemImage: "checkmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.fitKikuSecondaryText)
                Text(
                    "Coverage: Steps \(summary.stepsCoverage.rawValue), "
                        + "Sleep \(summary.sleepCoverage.rawValue)"
                )
                .font(.caption)
                .foregroundStyle(Color.fitKikuSecondaryText)

                DisclosureGroup("Local Health details") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sleep intervals on this iPhone: \(summary.normalized.sleepIntervals.count)")
                        Text("Health sources on this iPhone: \(summary.normalized.sources.count)")
                        Text("Interval timestamps are not included in schema 1.1 uploads.")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                    .padding(.top, 8)
                }
                .font(.caption.weight(.semibold))
            } else {
                Label("No Health summary is available yet", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(Color.fitKikuSecondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    private var sleepText: String {
        guard let minutes = summary?.asleepMinutes else { return "Unknown" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private func metric(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(Color.fitKikuSecondaryText)
            Text(value)
                .font(.title3.bold())
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(
            Color(.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView(model: AppModel())
}
