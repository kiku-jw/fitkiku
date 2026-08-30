// SPDX-License-Identifier: MPL-2.0

import Foundation
import StoreKit
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.requestReview) private var requestReview
    @ObservedObject var model: AppModel
    @State private var pastedPairLink = ""
    @State private var showAdvancedSetup = false
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
                    VStack(spacing: 20) {
                        if !isReviewingConnection {
                            intro
                        }
                        if model.isPaired {
                            connectionCard
                        } else {
                            pairingCard
                        }
                        if !isReviewingConnection {
                            if model.isPaired || model.healthAccessRequested {
                                healthAccessCard
                            }
                            if model.healthAccessRequested {
                                if model.isPaired {
                                    chatGPTCard
                                }
                                summaries
                            }
                            if model.isPaired {
                                syncCard
                                    .id("delivery")
                            }
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
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.teal)
                .accessibilityHidden(true)
            Text("Let your AI use your steps and sleep")
                .font(.title.bold())
            Text("FitKiku privately brings recent Steps and Sleep to ChatGPT or another AI that can open links. No daily retyping. Revoke access anytime.")
            .font(.body)
            .foregroundStyle(Color.fitKikuSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pairingCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    title: "Connect ChatGPT",
                    detail: "Start here",
                    systemImage: "link.badge.plus"
                )

                if model.localCredentialCleanupPending {
                    cleanupRecovery
                } else if let consent = model.pendingAgentConsent {
                    agentConsentCard(consent)
                } else if let recovery = model.pendingLegacyPairing {
                    legacyConsentCard(recovery)
                } else {
                    Text("FitKiku creates your private read-only link. Approve Steps and Sleep, then copy one prepared message into ChatGPT.")
                        .foregroundStyle(Color.fitKikuSecondaryText)

                    Button {
                        Task { await model.beginHostedConnection() }
                    } label: {
                        actionLabel("Connect ChatGPT", systemImage: "message.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isBusy)

                    Text(
                        "You will approve read-only Steps and Sleep access before anything is shared."
                    )
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)

                    DisclosureGroup("Other agents and recovery", isExpanded: $showAdvancedSetup) {
                        VStack(alignment: .leading, spacing: 14) {
                            manualPairLinkSetup
                            Divider()
                            recoverySetup
                        }
                        .padding(.top, 10)
                    }
                }
                feedback
            }
        }
    }

    private var manualPairLinkSetup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paste a Pair Link only if a compatible FitKiku connection already returned one.")
                .font(.footnote)
                .foregroundStyle(Color.fitKikuSecondaryText)
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
            .buttonStyle(.bordered)
            .disabled(model.isBusy || pairLinkIsBlank)
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
            Text(
                LocalizedStringKey(
                    consent.createsPrivateShareLink
                        ? "Create your private link"
                        : "Approve this connection"
                )
            )
                .font(.headline)
            Text(
                LocalizedStringKey(
                    consent.createsPrivateShareLink
                        ? "FitKiku will create a revocable link for recent Steps and Sleep. Anyone with the link can read that summary."
                        : "This step only approves the destination below. Apple Health permission is still separate."
                )
            )
            .foregroundStyle(Color.fitKikuSecondaryText)
            if !consent.createsPrivateShareLink {
                detailRow("Claimed agent", value: consent.preview.assertedAgentName)
                Text("The requesting service supplied this name; FitKiku has not verified its identity.")
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                detailRow("Destination", value: consent.baseURL.absoluteString, monospaced: true)
            }
            detailRow("Read-only data", value: String(localized: "Steps and Sleep"))
            if consent.createsPrivateShareLink {
                Label(
                    "Keep the message private. Anyone with its link can read your recent Steps and Sleep until you revoke it in Settings.",
                    systemImage: "lock.shield"
                )
                .font(.footnote)
                .foregroundStyle(Color.fitKikuSecondaryText)
                DisclosureGroup("Privacy details") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(NativeHealthDisclosure.outbound)
                        Text("Only after you paste or share the prepared message. The AI service may retain the link and returned summary under its own policy.")
                    }
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                    .padding(.top, 8)
                }
            } else {
                Text(NativeHealthDisclosure.outbound)
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                detailRow("Request expires", value: consent.preview.formattedExpiresAt)
                disclosure(title: "Retention", body: consent.preview.retentionDisclosure)
                disclosure(title: "AI processing", body: consent.preview.aiProcessingDisclosure)
            }
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
            Text(LocalizedStringKey(title))
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
                    title: "iPhone connected",
                    detail: connectionHost,
                    systemImage: "checkmark.seal.fill",
                    tint: .green
                )
                Text(connectionStatusSummary)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                feedback
            }
        }
    }

    private var chatGPTCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Use with your AI",
                    detail: model.privateShareURL == nil ? "One tap" : "Ready",
                    systemImage: "message.fill",
                    tint: .teal
                )

                if let shareURL = model.privateShareURL {
                    Text("Copy the prepared message into ChatGPT, or share it with another AI that can open links. It includes your private link and requires a fresh read before relevant answers.")
                    .foregroundStyle(Color.fitKikuSecondaryText)

                    Button {
                        copyChatGPTPrompt(shareURL)
                    } label: {
                        actionLabel(FitKikuChatPrompt.buttonTitle, systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isBusy)

                    ShareLink(item: FitKikuChatPrompt.message(shareURL: shareURL)) {
                        actionLabel("Share with another AI", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isBusy)

                    if copiedSetupPrompt {
                        Label(
                            LocalizedStringKey(FitKikuChatPrompt.copiedStatus),
                            systemImage: "checkmark.circle.fill"
                        )
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }

                    Label(
                        "Keep the message private. Anyone with its link can read your recent Steps and Sleep until you revoke it in Settings.",
                        systemImage: "lock.shield"
                    )
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                } else {
                    Text(
                        "Create a private link for this connection. It does not expose raw Health data, sources, or write access."
                    )
                    .foregroundStyle(Color.fitKikuSecondaryText)
                    Button {
                        Task { await model.createPrivateShareLink() }
                    } label: {
                        actionLabel("Create my private link", systemImage: "link.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isBusy)
                }
            }
        }
    }

    private var healthAccessCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Allow Apple Health",
                    detail: model.isPaired ? "Next step" : "Local only",
                    systemImage: "heart.fill",
                    tint: .red
                )
                if !model.healthAccessRequested {
                    Text("FitKiku asks only for read access to Steps and Sleep. Nothing is written to Apple Health.")
                    .foregroundStyle(Color.fitKikuSecondaryText)
                    if !model.isPaired {
                        Text("You can review local summaries before connecting an agent.")
                            .font(.footnote)
                            .foregroundStyle(Color.fitKikuSecondaryText)
                    }
                    if model.isPaired {
                        Button {
                            Task { await model.requestHealthAccess() }
                        } label: {
                            actionLabel("Continue to Health", systemImage: "heart.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isBusy)
                    } else {
                        Button {
                            Task { await model.requestHealthAccess() }
                        } label: {
                            actionLabel("Continue to Health", systemImage: "heart.fill")
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy)
                    }
                } else {
                    Label("Read-only access requested", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text("Apple keeps read-denial status private. Missing data stays Unknown; FitKiku never replaces it with zero.")
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private var summaries: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Local Apple Health",
                    detail: "On this iPhone",
                    systemImage: "iphone"
                )
                Text("These summaries stay available on this iPhone, even without an agent connection.")
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)
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
                sectionHeader(
                    title: "Check delivery",
                    detail: deliveryDetailLabel,
                    systemImage: "arrow.triangle.2.circlepath"
                )
                Text("Refresh server and agent status, then inspect technical details only when needed.")
                    .font(.footnote)
                    .foregroundStyle(Color.fitKikuSecondaryText)

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
                        String(
                            format: String(localized: "Last server-confirmed sync %@"),
                            locale: Locale.current,
                            lastSyncAt.formatted(date: .abbreviated, time: .shortened)
                        ),
                        systemImage: "checkmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.fitKikuSecondaryText)
                }

                if let shareURL = model.privateShareURL,
                   let delivery = model.deliveryStatus,
                   delivery.dataFreshness == .current,
                   !delivery.hasCurrentAgentRead
                {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(
                            "Your iPhone data is current on the server, but your agent has not read the latest update yet."
                        )
                        .font(.footnote)
                        .foregroundStyle(Color.fitKikuSecondaryText)

                        Button {
                            copyChatGPTPrompt(shareURL)
                        } label: {
                            actionLabel(
                                FitKikuChatPrompt.buttonTitle,
                                systemImage: "doc.on.doc"
                            )
                        }
                        .buttonStyle(.bordered)

                        ShareLink(item: FitKikuChatPrompt.message(shareURL: shareURL)) {
                            actionLabel("Share with your AI", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)

                        if copiedSetupPrompt {
                            Label(
                                LocalizedStringKey(FitKikuChatPrompt.copiedStatus),
                                systemImage: "checkmark.circle.fill"
                            )
                            .font(.footnote)
                            .foregroundStyle(.green)
                        }
                    }
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

                        Button("Refresh delivery details") {
                            Task { await model.refreshDeliveryStatus() }
                        }
                        .buttonStyle(.bordered)
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
            } else if let status = model.statusMessage {
                Label {
                    Text(status)
                } icon: {
                    Image(systemName: "info.circle.fill")
                }
                    .foregroundStyle(Color.fitKikuSecondaryText)
                    .accessibilityLabel(
                        Text(
                            String(
                                format: String(localized: "Status: %@"),
                                locale: Locale.current,
                                status
                            )
                        )
                    )
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
                Text(LocalizedStringKey(title))
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 8)
                Text(LocalizedStringKey(detail))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.fitKikuSecondaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    headerIcon(systemImage, tint: tint)
                    Text(LocalizedStringKey(title))
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(LocalizedStringKey(detail))
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

    private var pairLinkIsBlank: Bool {
        pastedPairLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func reviewPairLink() {
        guard !pairLinkIsBlank, !model.isBusy else { return }
        let input = pastedPairLink
        pastedPairLink = ""
        copiedSetupPrompt = false
        Task { await model.loadPairingInput(input) }
    }

    private func copyChatGPTPrompt(_ shareURL: URL) {
        UIPasteboard.general.string = FitKikuChatPrompt.message(shareURL: shareURL)
        copiedSetupPrompt = true
    }

    private var connectionHost: String {
        URL(string: model.serverAddress)?.host ?? String(localized: "Approved destination")
    }

    private var connectionStatusSummary: String {
        if !model.healthAccessRequested {
            return String(localized: "This destination is approved, but Apple Health permission is still a separate step.")
        }
        if model.deliveryStatusError != nil {
            return String(localized: "This connection is approved, but delivery status is currently unavailable.")
        }
        guard let delivery = model.deliveryStatus else {
            return String(localized: "Daily Steps and Sleep can go here. Delivery has not been checked yet.")
        }
        switch delivery.dataFreshness {
        case .current:
            return delivery.hasCurrentAgentRead
                ? String(localized: "An approved AI fetched the latest server update.")
                : String(localized: "Recent Steps and Sleep reached FitKiku. Paste the prepared message when you want your AI to read them.")
        case .stale:
            return String(localized: "Daily Steps and Sleep are connected, but some recent delivery still needs attention.")
        case .unknown:
            return String(localized: "Daily Steps and Sleep are connected, but recent delivery status is still unknown.")
        }
    }

    private var deliveryDetailLabel: String {
        guard model.healthAccessRequested else { return String(localized: "Health permission required") }
        guard let delivery = model.deliveryStatus else {
            return model.deliveryStatusError == nil
                ? String(localized: "Not checked")
                : String(localized: "Unavailable")
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

    private var isReviewingConnection: Bool {
        model.pendingAgentConsent != nil
            || model.pendingLegacyPairing != nil
            || model.localCredentialCleanupPending
    }
}

enum FitKikuChatPrompt {
    static let buttonTitle = "Copy for ChatGPT"
    static let copiedStatus = "Prepared message copied. Paste it into ChatGPT."

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
        .tint(.teal)
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
                Text(
                    String(
                        format: String(localized: "Coverage: Steps %@, Sleep %@"),
                        locale: Locale.current,
                        summary.stepsCoverage.localizedLabel,
                        summary.sleepCoverage.localizedLabel
                    )
                )
                .font(.caption)
                .foregroundStyle(Color.fitKikuSecondaryText)

                DisclosureGroup("Local Health details") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(
                            String(
                                format: String(localized: "Sleep intervals on this iPhone: %@"),
                                locale: Locale.current,
                                String(summary.normalized.sleepIntervals.count)
                            )
                        )
                        Text(
                            String(
                                format: String(localized: "Health sources on this iPhone: %@"),
                                locale: Locale.current,
                                String(summary.normalized.sources.count)
                            )
                        )
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
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
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
