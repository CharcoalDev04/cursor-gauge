import AppKit
import SwiftUI

struct PanelView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var updater: UpdateChecker
    @ObservedObject var agents: AgentMonitor
    @StateObject private var panel = PanelSettings()
    @AppStorage(MenuBarPrefs.languageKey) private var language = "system"
    @AppStorage(MenuBarPrefs.showQuotaKey) private var showQuota = true
    @AppStorage(MenuBarPrefs.showDailyKey) private var showDaily = false
    @AppStorage(MenuBarPrefs.showOverspendKey) private var showOverspend = false
    @AppStorage(MenuBarPrefs.showAgentsKey) private var showAgents = true
    @AppStorage(MenuBarPrefs.showGaugeKey) private var showGauge = true
    @AppStorage(MenuBarPrefs.showRemainingKey) private var showRemaining = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if panel.showSettings {
                settings
            } else {
                main
            }
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if let error = store.loadError, store.summary == nil {
                Text(L10n.message(for: error, language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                hero
                if !stats.isEmpty {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(stats) { stat in
                            statCell(stat)
                        }
                    }
                }
                modelsSection
                extraSections
                needsInputSection
            }
            footer
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(L10n.t("settings", language)) { panel.showSettings = false }
                    .buttonStyle(.plain)
                    .font(.headline)
                Spacer()
                Text(planName)
                    .foregroundStyle(.secondary)
            }

            MenuBarStatusView.live(
                store: store,
                agents: agents,
                language: language,
                showGauge: showGauge,
                showQuota: showQuota,
                showAgents: showAgents,
                showDaily: showDaily,
                showRemaining: showRemaining,
                showOverspend: showOverspend,
                lightText: colorScheme == .dark
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            Text(L10n.t("language", language))
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(L10n.t("language", language), selection: $language) {
                Text(L10n.t("system", language)).tag("system")
                Text(L10n.t("thai", language)).tag("th")
                Text(L10n.t("english", language)).tag("en")
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(L10n.t("showInMenuBar", language))
                .font(.caption)
                .foregroundStyle(.secondary)
            toggle("gauge", $showGauge)
            toggle("quotaPercent", $showQuota)
            toggle("agentBadge", $showAgents)
            toggle("dailyPercent", $showDaily)
            toggle("remainingMoney", $showRemaining)
            toggle("overspend", $showOverspend)
            Text(L10n.t("allOffHint", language))
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                Button(L10n.t("checkUpdates", language)) {
                    Task { await updater.checkForUpdates(announceResult: true) }
                }
                .buttonStyle(.plain)
                .disabled(updater.isChecking || updater.isUpdating)
                Spacer()
                Button(L10n.t("done", language)) { panel.showSettings = false }
                    .buttonStyle(.glass)
            }

            if let update = updater.availableUpdate {
                HStack {
                    Text(L10n.updateAvailable(update.version, language))
                        .font(.caption)
                    Spacer()
                    Button(updater.isUpdating ? L10n.t("updating", language) : L10n.t("update", language)) {
                        Task { await updater.installUpdate() }
                    }
                    .disabled(updater.isUpdating)
                }
            }
            if let notice = updater.notice {
                Text(L10n.updateNotice(notice, language))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Cursor Gauge")
                    .font(.headline)
                Spacer()
                Text(planName)
                    .foregroundStyle(.secondary)
            }
            Text(cycleLine)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(L10n.todayInZone(store.timeZoneLabel, language))
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.08), in: Capsule())
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 2) {
            if store.summary?.isUnlimitedPlan == true {
                Text(L10n.t("unlimited", language))
                    .font(.system(size: 32, weight: .semibold))
            } else if let remaining = store.includedRemainingCreditsCents {
                Text(L10n.t("remaining", language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(UsageStore.formatDollars(cents: remaining))
                    .font(.system(size: 32, weight: .semibold))
                    .monospacedDigit()
                if let used = store.includedUsedCreditsCents, let limit = store.includedLimitCreditsCents {
                    Text(L10n.used(
                        UsageStore.formatDollars(cents: used),
                        of: UsageStore.formatDollars(cents: limit),
                        language
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            ForEach(store.statusMessages, id: \.self) { message in
                Text(L10n.usageNote(message, language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var modelsSection: some View {
        Group {
            if !store.topModelSpends.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("models", language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(store.topModelSpends) { spend in
                        HStack {
                            Text(spend.model)
                                .lineLimit(1)
                            Spacer()
                            Text(UsageStore.formatDollars(cents: spend.cents))
                                .monospacedDigit()
                        }
                        .font(.callout)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var extraSections: some View {
        if store.hasTokenTotals {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("tokens", language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let count = store.periodTokenCount {
                    amountRow(L10n.t("thisCycle", language), UsageStore.formatTokens(count))
                }
                if let count = store.lifetimeTokenCount {
                    amountRow(L10n.t("allTime", language), UsageStore.formatTokens(count))
                }
            }
        }

        if let team = store.teamOnDemand {
            VStack(alignment: .leading, spacing: 4) {
                amountRow(
                    L10n.t("teamOnDemand", language),
                    teamLine(team),
                    emphasize: true
                )
            }
        }

        if store.hasOverspend {
            VStack(alignment: .leading, spacing: 4) {
                amountRow(L10n.t("overspend", language), UsageStore.formatDollars(cents: store.overspendCents), alert: true)
                if store.includedOverageCents > 0 {
                    amountRow(L10n.t("overIncluded", language), UsageStore.formatDollars(cents: store.includedOverageCents), alert: true)
                        .font(.caption)
                }
                if store.onDemandUsedCents > 0 {
                    amountRow(L10n.t("onDemand", language), UsageStore.formatDollars(cents: store.onDemandUsedCents), alert: true)
                        .font(.caption)
                }
            }
        }

        if store.onDemandEnabled {
            VStack(alignment: .leading, spacing: 4) {
                if let limit = store.onDemandLimitCents {
                    amountRow(L10n.t("onDemandBudget", language), UsageStore.formatDollars(cents: limit))
                        .font(.caption)
                }
                if let remaining = store.onDemandRemainingCents {
                    amountRow(L10n.t("onDemandRemaining", language), UsageStore.formatDollars(cents: remaining), alert: remaining == 0)
                        .font(.caption)
                }
            }
        }

        if let error = store.loadError, store.summary != nil {
            Text(L10n.message(for: error, language))
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var needsInputSection: some View {
        if !agents.agentsNeedingInput.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("needsInput", language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                ForEach(agents.agentsNeedingInput) { agent in
                    Button {
                        agent.openInCursor()
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(agent.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Text(agent.reason)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(L10n.t("openInCursor", language))
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(updatedLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button(L10n.t("settings", language)) { panel.showSettings = true }
                .buttonStyle(.plain)
            Button(L10n.t("refresh", language)) {
                Task { await store.refresh() }
            }
            .buttonStyle(.glass)
            .disabled(store.isLoading)
            Button(L10n.t("quit", language)) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
    }

    private var stats: [StatCell] {
        var items: [StatCell] = []
        if let percent = store.dailyUtilizationPercent {
            let detail = dollarPair(store.todaySpendCents, store.dailyBudgetCents)
            items.append(StatCell(
                id: "today",
                title: L10n.t("today", language),
                value: percentText(percent),
                detail: detail,
                tone: UsageMath.dailyTone(percent)
            ))
        }
        if let percent = store.cursorModelsPercentUsed {
            items.append(StatCell(
                id: "composer",
                title: L10n.t("composer", language),
                value: percentText(percent),
                detail: dollarPair(store.cursorModelsUsedCreditsCents, store.cursorModelsLimitCreditsCents),
                tone: percent >= 100 ? .hot : .plain
            ))
        }
        if let percent = store.otherModelsPercentUsed {
            items.append(StatCell(
                id: "api",
                title: L10n.t("api", language),
                value: percentText(percent),
                detail: dollarPair(store.otherModelsUsedCreditsCents, store.otherModelsLimitCreditsCents),
                tone: percent >= 100 ? .hot : .plain
            ))
        }
        items.append(StatCell(
            id: "agents",
            title: L10n.t("agents", language),
            value: "\(agents.totalRunning)",
            detail: L10n.machines(agents.localRunningCount, agents.cloudRunningCount, language),
            tone: .plain
        ))
        return items
    }

    private var planName: String {
        guard store.summary != nil else { return L10n.t("unknownPlan", language) }
        return store.planDisplayName
    }

    private var cycleLine: String {
        guard let start = store.billingCycleStartDate, let end = store.billingCycleEndDate else {
            return L10n.t("cycleUnavailable", language)
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        var line = "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        if let days = store.daysUntilReset {
            line += " · \(L10n.resets(in: days, language))"
        }
        return line
    }

    private var updatedLine: String {
        let time: String
        if let lastUpdated = store.lastUpdated {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            time = formatter.string(from: lastUpdated)
        } else {
            time = L10n.t("never", language)
        }
        return "\(L10n.t("updated", language)) \(time)"
    }

    private func percentText(_ percent: Double) -> String {
        "\(Int(percent.rounded()))%"
    }

    private func dollarPair(_ used: Int?, _ limit: Int?) -> String {
        switch (used, limit) {
        case let (used?, limit?):
            "\(UsageStore.formatDollars(cents: used)) / \(UsageStore.formatDollars(cents: limit))"
        case let (used?, nil):
            UsageStore.formatDollars(cents: used)
        case let (nil, limit?):
            UsageStore.formatDollars(cents: limit)
        default:
            ""
        }
    }

    private func toneColor(_ tone: UsageMath.DailyTone) -> Color {
        switch tone {
        case .plain: .primary
        case .warm: .yellow
        case .hot: .red
        }
    }

    private func teamLine(_ team: OnDemandUsage) -> String {
        if let limit = team.limit {
            return "\(UsageStore.formatDollars(cents: team.usedCents)) / \(UsageStore.formatDollars(cents: limit))"
        }
        return UsageStore.formatDollars(cents: team.usedCents)
    }

    private func toggle(_ key: String, _ binding: Binding<Bool>) -> some View {
        Toggle(L10n.t(key, language), isOn: binding)
    }

    private func statCell(_ stat: StatCell) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stat.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(stat.value)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(toneColor(stat.tone))
            Text(stat.detail.isEmpty ? " " : stat.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .opacity(stat.detail.isEmpty ? 0 : 1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func amountRow(_ title: String, _ value: String, alert: Bool = false, emphasize: Bool = false) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(emphasize ? .primary : .secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(alert ? Color.red : Color.primary)
        }
        .font(emphasize ? .callout.weight(.medium) : .callout)
    }
}

private struct StatCell: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let tone: UsageMath.DailyTone
}

@MainActor
private final class PanelSettings: ObservableObject {
    @Published var showSettings = false
}
