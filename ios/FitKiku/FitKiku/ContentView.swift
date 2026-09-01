// SPDX-License-Identifier: MPL-2.0

import Foundation
import StoreKit
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.requestReview) private var requestReview
    @ObservedObject var model: AppModel
    @State private var showSettings = false
    @State private var showDeliveryDetails: Bool
    @State private var copiedSetupPrompt = false
    @ScaledMetric(relativeTo: .body) private var minimumControlHeight = 44

    init(model: AppModel) {
        self.model = model
        _showDeliveryDetails = State(initialValue: model.shouldExpandDeliveryForDemo)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        if isReviewingConnection {
                            pairingCard
                        } else {
                            stageHeader
                            stageCard
                            if model.healthAccessRequested {
                                summaries
                            }
                            if model.isPaired && model.healthAccessRequested {
                                syncCard
                                    .id("delivery")
                            }
                        }
                        feedback
                        #if DEBUG
                        if model.demoScrollTarget != nil {
                            Color.clear.frame(height: 240).accessibilityHidden(true)
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
            .tint(Color.fitKikuAccent)
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
                SettingsView(model: model)
            }
            .onChange(of: model.deliveryStatus) { _, delivery in
                guard !model.isSyntheticDemo,
                      FitKikuReviewPromptPolicy.shouldRequestReview(
                          for: delivery,
                          appVersion: Bundle.main.object(
                              forInfoDictionaryKey: "CFBundleShortVersionString"
                          ) as? String,
                          defaults: .standard
                      )
                else { return }
                requestReview()
            }
            .onChange(of: model.privateShareURL) { _, _ in
                copiedSetupPrompt = false
            }
        }
    }

    @ViewBuilder
    private var stageCard: some View {
        switch presentationStage {
        case .connect:
            pairingCard
        case .health:
            healthAccessCard
        case .share:
            chatGPTCard
        case .ready:
            readyCard
        }
    }

    private var stageHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let step = presentationStage.step {
                setupProgress(step: step)
            } else {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }

            Text(LocalizedStringKey(presentationStage.title))
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)

            Text(stageSubtitle)
                .font(.title3)
                .foregroundStyle(Color.fitKikuSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func setupProgress(step: Int) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(1...3, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.fitKikuAccent : Color(.tertiarySystemFill))
                        .frame(width: 24, height: 5)
                }
            }
            Text(
                String(
                    format: String(localized: "Step %lld of 3"),
                    locale: Locale.current,
                    step
                )
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.fitKikuSecondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                String(
                    format: String(localized: "Step %lld of 3"),
                    locale: Locale.current,
                    step
                )
            )
        )
    }

    private var pairingCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                if model.localCredentialCleanupPending {
                    cleanupRecovery
                } else if let consent = model.pendingAgentConsent {
                    agentConsentCard(consent)
                } else if let recovery = model.pendingLegacyPairing {
                    legacyConsentCard(recovery)
                } else {
                    Button {
                        Task { await model.beginHostedConnection() }
                    } label: {
                        actionLabel("Get started", systemImage: "message.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Color.fitKikuPrimaryForeground)
                    .disabled(model.isBusy)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 18) {
                            Label("No login", systemImage: "person.crop.circle")
                            Label("Read-only", systemImage: "eye")
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Label("No login", systemImage: "person.crop.circle")
                            Label("Read-only", systemImage: "eye")
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.fitKikuSecondaryText)
                }
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
            .foregroundStyle(Color.fitKikuPrimaryForeground)
            .disabled(model.isBusy)
        }
    }

    private func agentConsentCard(_ consent: PendingAgentConsent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(
                LocalizedStringKey(
                    consent.createsPrivateShareLink
                        ? "Create your private link?"
                        : "Approve this connection"
                )
            )
            .font(.title2.bold())

            if consent.createsPrivateShareLink {
                Text("Your AI will be able to read only these daily summaries.")
                    .foregroundStyle(Color.fitKikuSecondaryText)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) {
                        Label("Steps", systemImage: "figure.walk")
                        Label("Sleep", systemImage: "bed.double.fill")
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Steps", systemImage: "figure.walk")
                        Label("Sleep", systemImage: "bed.double.fill")
                    }
                }
                .font(.headline)

                Label("Read-only. Revoke anytime in Settings.", systemImage: "lock.shield")
                    .font(.subheadline)
                    .foregroundStyle(Color.fitKikuSecondaryText)

                DisclosureGroup("How it works") {
                    VStack(alignment: .leading, spacing: 10) {
                        detailRow(
                            "Destination",
                            value: consent.baseURL.absoluteString,
                            monospaced: true
                        )
                        detailRow("Retention", value: consent.preview.retentionDisclosure)
                        detailRow("AI processing", value: consent.preview.aiProcessingDisclosure)
                        Text(NativeHealthDisclosure.outbound)
                        Text("Anyone with the private link can read the summary until you revoke it.")
                    }
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                    .padding(.top, 8)
                }
            } else {
                Text("Review the destination and data scope before connecting.")
                    .foregroundStyle(Color.fitKikuSecondaryText)
            }

            if !consent.createsPrivateShareLink {
                detailRow("Claimed agent", value: consent.preview.assertedAgentName)
                Text("The requesting service supplied this name; FitKiku has not verified its identity.")
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                detailRow("Destination", value: consent.baseURL.absoluteString, monospaced: true)
                detailRow("Read-only data", value: String(localized: "Steps and Sleep"))
                Text(NativeHealthDisclosure.outbound)
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                detailRow("Request expires", value: consent.preview.formattedExpiresAt)
                disclosure(title: "Retention", body: consent.preview.retentionDisclosure)
                disclosure(title: "AI processing", body: consent.preview.aiProcessingDisclosure)
            }

            Text("Health permission comes next.")
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
        }
        .buttonStyle(.bordered)
        .frame(minHeight: minimumControlHeight)
    }

    private var approvePairingButton: some View {
        Button {
            Task { await model.approveAgentPairing() }
        } label: {
            Label(
                LocalizedStringKey(
                    model.pendingAgentConsent?.createsPrivateShareLink == true
                        ? "Create private link"
                        : "Approve connection"
                ),
                systemImage: "lock.shield"
            )
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .foregroundStyle(Color.fitKikuPrimaryForeground)
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
        .foregroundStyle(Color.fitKikuPrimaryForeground)
        .disabled(model.isBusy)
    }

    private func disclosure(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.caption.weight(.semibold))
            Text(body)
                .font(.footnote)
                .foregroundStyle(Color.fitKikuSecondaryText)
        }
    }

    private var chatGPTCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                if let shareURL = model.privateShareURL {
                    if copiedSetupPrompt {
                        Label("Copied. Paste it into ChatGPT.", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)

                        Link(destination: FitKikuLinks.chatGPT) {
                            actionLabel("Open ChatGPT", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(Color.fitKikuPrimaryForeground)

                        Button {
                            copyChatGPTPrompt(shareURL)
                        } label: {
                            actionLabel("Copy again", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            copyChatGPTPrompt(shareURL)
                        } label: {
                            actionLabel(FitKikuChatPrompt.buttonTitle, systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(Color.fitKikuPrimaryForeground)
                        .disabled(model.isBusy)
                    }

                    ShareLink(item: FitKikuChatPrompt.message(shareURL: shareURL)) {
                        actionLabel("Share with another AI", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isBusy)

                    Label("The message contains your private link.", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                } else {
                    Button {
                        Task { await model.createPrivateShareLink() }
                    } label: {
                        actionLabel("Create my private link", systemImage: "link.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Color.fitKikuPrimaryForeground)
                    .disabled(model.isBusy)
                }
            }
        }
    }

    private var readyCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Label("Latest data received", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                Link(destination: FitKikuLinks.chatGPT) {
                    actionLabel("Open ChatGPT", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Color.fitKikuPrimaryForeground)

                if let shareURL = model.privateShareURL {
                    Button {
                        copyChatGPTPrompt(shareURL)
                    } label: {
                        actionLabel("Copy setup message", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var healthAccessCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                if !model.healthAccessRequested {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 18) {
                            Label("Steps", systemImage: "figure.walk")
                            Label("Sleep", systemImage: "bed.double.fill")
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Steps", systemImage: "figure.walk")
                            Label("Sleep", systemImage: "bed.double.fill")
                        }
                    }
                    .font(.headline)

                    Button {
                        Task { await model.requestHealthAccess() }
                    } label: {
                        actionLabel("Continue to Health", systemImage: "heart.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Color.fitKikuPrimaryForeground)
                    .disabled(model.isBusy)
                } else {
                    Label("Read-only access requested", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            }
        }
    }

    @ViewBuilder
    private var summaries: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("On this iPhone")
                    .font(.headline)
                CompactDaySummaryRow(title: "Today", summary: model.today)
                Divider()
                CompactDaySummaryRow(title: "Yesterday", summary: model.yesterday)
                    .id("yesterday")
            }
            .id("summaries")
        }
    }

    private var syncCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: deliveryStatusSymbol)
                        .font(.title3)
                        .foregroundStyle(deliveryStatusColor)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStringKey(deliveryStatusTitle))
                            .font(.headline)
                        Text(connectionStatusSummary)
                            .font(.subheadline)
                            .foregroundStyle(Color.fitKikuSecondaryText)
                    }
                }
                .accessibilityElement(children: .combine)

                Button {
                    Task { await model.syncNow() }
                } label: {
                    actionLabel(
                        model.isBusy ? "Syncing…" : "Sync now",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.healthAccessRequested)

                DisclosureGroup("Details", isExpanded: $showDeliveryDetails) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let lastSyncAt = model.lastSyncAt {
                            deliveryStatusLine(
                                "Last sync",
                                date: lastSyncAt,
                                emptyText: "Not synced yet"
                            )
                        }
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
                                    value: String(
                                        format: String(localized: "%@ · Steps %@, Sleep %@"),
                                        locale: Locale.current,
                                        latestLocalDate,
                                        coverage.steps.localizedLabel,
                                        coverage.sleep.localizedLabel
                                    )
                                )
                            }
                            Text(
                                delivery.missingLocalDates.isEmpty
                                    ? String(localized: "Recent server days are present.")
                                    : String(
                                        format: String(localized: "Missing recent server days: %@"),
                                        locale: Locale.current,
                                        delivery.missingLocalDates.joined(separator: ", ")
                                    )
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
                            Label {
                                Text(deliveryError)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle")
                            }
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        if let status = model.statusMessage {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(Color.fitKikuSecondaryText)
                        }
                    }
                    .padding(.top, 10)
                }
            }
        }
    }

    private var feedback: some View {
        Group {
            if let error = model.errorMessage {
                Label {
                    Text(error)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(.red)
                .accessibilityLabel(
                    Text(
                        String(
                            format: String(localized: "Error: %@"),
                            locale: Locale.current,
                            error
                        )
                    )
                )
            }
        }
        .font(.footnote)
    }

    private func detailRow(_ title: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(title))
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
        Label(LocalizedStringKey(title), systemImage: systemImage)
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

    private func copyChatGPTPrompt(_ shareURL: URL) {
        UIPasteboard.general.string = FitKikuChatPrompt.message(shareURL: shareURL)
        copiedSetupPrompt = true
    }

    private var presentationStage: FitKikuPresentationStage {
        guard model.isPaired else { return .connect }
        guard model.healthAccessRequested else { return .health }
        guard model.privateShareURL != nil,
              model.deliveryStatus?.hasCurrentAgentRead == true
        else { return .share }
        return .ready
    }

    private var stageSubtitle: String {
        switch presentationStage {
        case .connect:
            String(localized: "One quick setup. No more retyping steps and sleep.")
        case .health:
            String(localized: "Read-only. FitKiku never writes to Health.")
        case .share:
            model.privateShareURL == nil
                ? String(localized: "Create a private read-only link for your AI.")
                : String(localized: "Copy one prepared message and paste it into ChatGPT.")
        case .ready:
            connectionStatusSummary
        }
    }

    private var connectionStatusSummary: String {
        if !model.healthAccessRequested {
            return String(localized: "Health permission is still needed.")
        }
        if model.deliveryStatusError != nil {
            return String(localized: "Freshness could not be checked.")
        }
        guard let delivery = model.deliveryStatus else {
            return String(localized: "Sync once to check freshness.")
        }
        switch delivery.dataFreshness {
        case .current:
            return delivery.hasCurrentAgentRead
                ? String(localized: "ChatGPT has the latest update.")
                : String(localized: "Your iPhone is current. ChatGPT has not checked it yet.")
        case .stale:
            return String(localized: "Some recent data has not arrived yet.")
        case .unknown:
            return String(localized: "Freshness is not confirmed yet.")
        }
    }

    private var deliveryStatusTitle: String {
        if model.deliveryStatusError != nil { return "Status unavailable" }
        guard let delivery = model.deliveryStatus else { return "Not synced yet" }
        switch delivery.dataFreshness {
        case .current:
            return delivery.hasCurrentAgentRead ? "Up to date" : "Waiting for ChatGPT"
        case .stale:
            return "Needs an update"
        case .unknown:
            return "Status unknown"
        }
    }

    private var deliveryStatusSymbol: String {
        if model.deliveryStatusError != nil { return "exclamationmark.triangle.fill" }
        guard let delivery = model.deliveryStatus else { return "clock" }
        switch delivery.dataFreshness {
        case .current:
            return delivery.hasCurrentAgentRead ? "checkmark.circle.fill" : "arrow.up.circle"
        case .stale:
            return "arrow.triangle.2.circlepath"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var deliveryStatusColor: Color {
        if model.deliveryStatusError != nil { return .orange }
        guard let delivery = model.deliveryStatus else { return Color.fitKikuSecondaryText }
        switch delivery.dataFreshness {
        case .current:
            return delivery.hasCurrentAgentRead ? .green : Color.fitKikuAccent
        case .stale:
            return .orange
        case .unknown:
            return Color.fitKikuSecondaryText
        }
    }

    private var isReviewingConnection: Bool {
        model.pendingAgentConsent != nil
            || model.pendingLegacyPairing != nil
            || model.localCredentialCleanupPending
    }
}

private enum FitKikuPresentationStage {
    case connect
    case health
    case share
    case ready

    var step: Int? {
        switch self {
        case .connect: 1
        case .health: 2
        case .share: 3
        case .ready: nil
        }
    }

    var title: String {
        switch self {
        case .connect: "Connect ChatGPT"
        case .health: "Allow steps and sleep"
        case .share: "Send it to ChatGPT"
        case .ready: "You're connected"
        }
    }
}

enum FitKikuChatPrompt {
    static let buttonTitle = "Copy for ChatGPT"

    static func message(shareURL: URL) -> String {
        let format = NSLocalizedString(
            "fitkiku.chatgpt.prompt",
            value: "Use this private FitKiku URL when answering me about my activity, sleep, recovery, or routine. Open it now and again before each such answer:\n%@\n\nThis is a normal HTTPS JSON URL. Do not look for a FitKiku connector or Pair Link; none is required. Use only the Steps and Sleep daily aggregates returned by that URL. Always state data_freshness and latest_local_date. Treat missing dates or categories as unknown, never as zero. If data_freshness is not current, say clearly that the data may be stale. The link is read-only. Never repeat or expose the private URL in your answer.",
            comment: "Prepared message copied by the user into ChatGPT"
        )
        return String(format: format, locale: Locale.current, shareURL.absoluteString)
    }
}

enum FitKikuReviewPromptPolicy {
    static let requiredAgentReads = 2

    private static let lastCountedAgentFetchKey = "review.last-counted-agent-fetch"
    private static let confirmedAgentReadCountKey = "review.confirmed-agent-read-count"
    private static let promptedVersionKey = "review.prompted-version"

    static func shouldRequestReview(
        for delivery: DeviceDeliveryStatus?,
        appVersion: String?,
        defaults: UserDefaults
    ) -> Bool {
        guard let delivery,
              delivery.hasCurrentAgentRead,
              let agentFetchedAt = delivery.lastAgentFetchedAt,
              let appVersion,
              !appVersion.isEmpty
        else { return false }

        if let previousFetch = defaults.object(forKey: lastCountedAgentFetchKey) as? Date,
           agentFetchedAt <= previousFetch
        {
            return false
        }

        defaults.set(agentFetchedAt, forKey: lastCountedAgentFetchKey)
        let count = min(
            defaults.integer(forKey: confirmedAgentReadCountKey) + 1,
            requiredAgentReads
        )
        defaults.set(count, forKey: confirmedAgentReadCountKey)

        guard count >= requiredAgentReads,
              defaults.string(forKey: promptedVersionKey) != appVersion
        else { return false }

        defaults.set(appVersion, forKey: promptedVersionKey)
        return true
    }
}

enum FitKikuLinks {
    static let chatGPT = URL(string: "https://chatgpt.com/")!
    static let appStore = URL(string: "https://apps.apple.com/app/id6801516904")!
    static let review = URL(string: "https://apps.apple.com/app/id6801516904?action=write-review")!
    static let website = URL(string: "https://kikuai.dev/fitkiku/")!
    static let source = URL(string: "https://github.com/kiku-jw/fitkiku")!
    static let telegram = URL(string: "https://t.me/kiku_ai")!
    static let privacy = URL(string: "https://kikuai.dev/fitkiku/privacy/")!
    static let support = URL(string: "https://kikuai.dev/fitkiku/support/")!

    static let all = [appStore, review, website, source, telegram, privacy, support]
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: AppModel
    @State private var showDeleteConfirmation = false
    @State private var showRevokeLinkConfirmation = false
    @State private var showReplaceLinkConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    if model.isPaired {
                        LabeledContent("Destination", value: connectionDestination)
                        LabeledContent("Status") {
                            Text(settingsConnectionStatus)
                        }
                        Button("Disconnect and revoke server access", role: .destructive) {
                            Task { await model.disconnect() }
                        }
                        .frame(minHeight: 44)
                        .disabled(model.isBusy)
                        if model.canDeleteAccount {
                            Button("Delete FitKiku account and data", role: .destructive) {
                                showDeleteConfirmation = true
                            }
                            .frame(minHeight: 44)
                            .disabled(model.isBusy)
                        }
                    } else if model.localCredentialCleanupPending {
                        Text("Server access is already revoked. Finish local cleanup from the main screen before pairing again.")
                            .foregroundStyle(Color.fitKikuSecondaryText)
                    } else {
                        Text("No active FitKiku connection.")
                            .foregroundStyle(Color.fitKikuSecondaryText)
                    }

                    if let error = model.errorMessage {
                        Label {
                            Text(error)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if let status = model.statusMessage {
                        Label {
                            Text(status)
                        } icon: {
                            Image(systemName: "info.circle.fill")
                        }
                            .font(.footnote)
                            .foregroundStyle(Color.fitKikuSecondaryText)
                    }
                }

                if model.isPaired {
                    Section("Private AI link") {
                        if model.privateShareURL != nil {
                            Label("Private link ready", systemImage: "link.circle.fill")
                                .foregroundStyle(.green)
                            Text("Anyone with the link can read your recent Steps and Sleep. It cannot write to Apple Health or access other categories.")
                            .font(.footnote)
                            .foregroundStyle(Color.fitKikuSecondaryText)
                            Button("Replace private link") {
                                showReplaceLinkConfirmation = true
                            }
                            .disabled(model.isBusy)
                            Button("Revoke private link", role: .destructive) {
                                showRevokeLinkConfirmation = true
                            }
                            .disabled(model.isBusy)
                        } else {
                            Text("No private AI link exists for this connection.")
                                .foregroundStyle(Color.fitKikuSecondaryText)
                            Button("Create private link") {
                                Task { await model.createPrivateShareLink() }
                            }
                            .disabled(model.isBusy)
                        }
                    }
                }

                if !model.isPaired && !model.localCredentialCleanupPending {
                    Section("More ways to connect") {
                        NavigationLink {
                            AdvancedConnectionView(
                                model: model,
                                closeSettings: { dismiss() }
                            )
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Other AI or private server")
                                    Text("Manual setup and recovery")
                                        .font(.caption)
                                        .foregroundStyle(Color.fitKikuSecondaryText)
                                }
                            } icon: {
                                Image(systemName: "link.badge.plus")
                            }
                        }
                    }
                }

                Section("FitKiku") {
                    ShareLink(
                        item: FitKikuLinks.appStore,
                        subject: Text("FitKiku"),
                        message: Text(
                            "FitKiku lets the AI you choose use recent read-only Steps and Sleep without daily retyping."
                        )
                    ) {
                        Label("Share FitKiku", systemImage: "square.and.arrow.up")
                            .frame(minHeight: 44)
                    }
                    .accessibilityHint("Opens the system share sheet")
                    settingsLink(
                        "Rate FitKiku",
                        systemImage: "star",
                        url: FitKikuLinks.review,
                        hint: "Opens the App Store review page"
                    )
                    settingsLink("Product website", systemImage: "globe", url: FitKikuLinks.website)
                    settingsLink("Source code", systemImage: "chevron.left.forwardslash.chevron.right", url: FitKikuLinks.source)
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
        .tint(Color.fitKikuAccent)
        .confirmationDialog(
            "Delete FitKiku account?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete account and data", role: .destructive) {
                Task { await model.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes the anonymous FitKiku connection, synced summaries, and agent access from the server. It does not delete anything from Apple Health.")
        }
        .confirmationDialog(
            "Replace private link?",
            isPresented: $showReplaceLinkConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replace link") {
                Task { await model.createPrivateShareLink() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The old link will stop working immediately. Chats that saved it will need the new prepared message.")
        }
        .confirmationDialog(
            "Revoke private link?",
            isPresented: $showRevokeLinkConfirmation,
            titleVisibility: .visible
        ) {
            Button("Revoke link", role: .destructive) {
                Task { await model.revokePrivateShareLink() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The link will stop working immediately. Your iPhone remains connected to FitKiku.")
        }
    }

    private func settingsLink(
        _ title: String,
        systemImage: String,
        url: URL,
        hint: String = "Opens in your browser"
    ) -> some View {
        Link(destination: url) {
            Label(LocalizedStringKey(title), systemImage: systemImage)
                .frame(minHeight: 44)
        }
        .accessibilityHint(LocalizedStringKey(hint))
    }

    private var connectionDestination: String {
        URL(string: model.serverAddress)?.host ?? String(localized: "Approved destination")
    }

    private var settingsConnectionStatus: String {
        if !model.healthAccessRequested {
            return String(localized: "Waiting for Apple Health permission")
        }
        if model.deliveryStatusError != nil {
            return String(localized: "Delivery status unavailable")
        }
        guard let delivery = model.deliveryStatus else {
            return String(localized: "Delivery not checked")
        }
        switch delivery.dataFreshness {
        case .current:
            return delivery.hasCurrentAgentRead
                ? String(localized: "Agent up to date")
                : String(localized: "Waiting for agent")
        case .stale:
            return String(localized: "Needs attention")
        case .unknown:
            return String(localized: "Unknown")
        }
    }
}

private struct AdvancedConnectionView: View {
    @ObservedObject var model: AppModel
    let closeSettings: () -> Void

    @State private var pastedPairLink = ""

    var body: some View {
        Form {
            Section("Pair Link from another AI") {
                Text("Use this only when your AI gave you a FitKiku Pair Link.")
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)

                SecureField("Paste Pair Link", text: $pastedPairLink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                    .submitLabel(.go)
                    .onSubmit(reviewPairLink)

                Button("Review connection", action: reviewPairLink)
                    .disabled(model.isBusy || pairLinkIsBlank)
                    .frame(minHeight: 44)
            }

            Section("Private server recovery") {
                Text("Use the server address and 8-digit code supplied by your FitKiku server.")
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)

                TextField("https://fitkiku.example", text: $model.serverAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                    .keyboardType(.URL)

                TextField("8-digit code", text: $model.pairingCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .onChange(of: model.pairingCode) { _, value in
                        model.pairingCode = String(value.filter(\.isNumber).prefix(8))
                    }

                Button("Connect with recovery code") {
                    Task {
                        await model.pairLegacyManually()
                        if model.isPaired {
                            closeSettings()
                        }
                    }
                }
                .disabled(model.isBusy || model.pairingCode.count != 8)
                .frame(minHeight: 44)
            }

            if let error = model.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Advanced connection")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pairLinkIsBlank: Bool {
        pastedPairLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func reviewPairLink() {
        guard !pairLinkIsBlank, !model.isBusy else { return }
        let input = pastedPairLink
        pastedPairLink = ""
        Task {
            await model.loadPairingInput(input)
            if model.pendingAgentConsent != nil || model.pendingLegacyPairing != nil {
                closeSettings()
            }
        }
    }
}

private extension CoverageState {
    var localizedLabel: String {
        switch self {
        case .complete:
            String(localized: "Complete")
        case .partial:
            String(localized: "Partial")
        case .unknown:
            String(localized: "Unknown")
        }
    }
}

private extension Color {
    static var fitKikuAccent: Color {
        Color.primary
    }

    static var fitKikuPrimaryForeground: Color {
        Color(.systemBackground)
    }

    static var fitKikuSecondaryText: Color {
        Color.primary.opacity(0.68)
    }
}

private struct CompactDaySummaryRow: View {
    let title: String
    let summary: DaySummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(LocalizedStringKey(title))
                    .font(.headline)
                Spacer(minLength: 12)
                Text(summary?.localDate ?? String(localized: "Not available"))
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.fitKikuSecondaryText)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    metric(
                        title: "Steps",
                        value: summary?.steps.map(String.init) ?? String(localized: "Unknown"),
                        symbol: "figure.walk"
                    )
                    metric(title: "Sleep", value: sleepText, symbol: "bed.double.fill")
                }
                VStack(spacing: 12) {
                    metric(
                        title: "Steps",
                        value: summary?.steps.map(String.init) ?? String(localized: "Unknown"),
                        symbol: "figure.walk"
                    )
                    metric(title: "Sleep", value: sleepText, symbol: "bed.double.fill")
                }
            }

            if let summary {
                if summary.stepsCoverage != .complete || summary.sleepCoverage != .complete {
                    Label("Some data is incomplete", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            } else {
                Label("No Health summary is available yet", systemImage: "clock")
                    .font(.caption)
                .foregroundStyle(Color.fitKikuSecondaryText)
            }
        }
    }

    private var sleepText: String {
        guard let minutes = summary?.asleepMinutes else { return String(localized: "Unknown") }
        return String(
            format: String(localized: "%@ h %@ min"),
            locale: Locale.current,
            String(minutes / 60),
            String(minutes % 60)
        )
    }

    private func metric(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(LocalizedStringKey(title), systemImage: symbol)
                .font(.caption)
                .foregroundStyle(Color.fitKikuSecondaryText)
            Text(value)
                .font(.headline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView(model: AppModel())
}
