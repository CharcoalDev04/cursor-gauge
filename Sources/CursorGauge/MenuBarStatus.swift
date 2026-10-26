import AppKit
import SwiftUI

enum MenuBarPrefs {
    static let showQuotaKey = "menuBarShowQuota"
    static let showDailyKey = "menuBarShowDaily"
    static let showOverspendKey = "menuBarShowOverspend"
    static let showAgentsKey = "menuBarShowAgents"
    static let showGaugeKey = "menuBarShowGauge"
    static let showRemainingKey = "menuBarShowRemaining"
    static let languageKey = "uiLanguage"
}

struct MenuBarStatusView: View {
    var showGauge: Bool
    var showQuota: Bool
    var showAgents: Bool
    var showDaily: Bool
    var showRemaining: Bool
    var showOverspend: Bool
    var quotaText: String?
    var quotaIsOver: Bool
    var dailyText: String?
    var dailyTone: UsageMath.DailyTone = .plain
    var remainingText: String?
    var overspendText: String?
    var agentBadge: String?
    var dimmed: Bool
    var lightText: Bool

    private var ink: Color { lightText ? .white : .black }
    private var alert: Color { lightText ? Color(red: 1, green: 0.41, blue: 0.38) : .red }

    private var drawGauge: Bool {
        showGauge || visibleCount == 0
    }

    private var visibleCount: Int {
        var count = showGauge ? 1 : 0
        if showQuota, quotaText != nil { count += 1 }
        if showAgents, agentBadge != nil, !showGauge { count += 1 }
        if showDaily, dailyText != nil { count += 1 }
        if showRemaining, remainingText != nil { count += 1 }
        if showOverspend, overspendText != nil { count += 1 }
        return count
    }

    var body: some View {
        HStack(spacing: 5) {
            if drawGauge {
                gauge
            } else if showAgents, let agentBadge {
                badge(agentBadge)
            }
            if showQuota, let quotaText {
                figure(quotaText, tone: quotaIsOver ? .hot : .plain)
            }
            if showDaily, let dailyText {
                figure(dailyText, tone: dailyTone)
            }
            if showRemaining, let remainingText {
                figure(remainingText, tone: .plain)
            }
            if showOverspend, let overspendText {
                figure("+\(overspendText)", tone: .hot)
            }
        }
        .foregroundStyle(ink)
    }

    private var gauge: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.system(size: 14, weight: .medium))
                .opacity(dimmed ? 0.45 : 1)
                .frame(width: 16, height: 16)
            if showAgents, let agentBadge {
                badge(agentBadge)
                    .offset(x: 7, y: -6)
            }
        }
        .frame(width: 22, height: 18)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 3)
            .frame(minWidth: 12, minHeight: 12)
            .background(Capsule().fill(Color.yellow))
    }

    private func figure(_ text: String, tone: UsageMath.DailyTone) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(menuColor(tone))
            .opacity(dimmed ? 0.45 : 1)
    }

    private func menuColor(_ tone: UsageMath.DailyTone) -> Color {
        switch tone {
        case .plain: ink
        case .warm: .yellow
        case .hot: alert
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var agents: AgentMonitor
    @AppStorage(MenuBarPrefs.showQuotaKey) private var showQuota = true
    @AppStorage(MenuBarPrefs.showDailyKey) private var showDaily = false
    @AppStorage(MenuBarPrefs.showOverspendKey) private var showOverspend = false
    @AppStorage(MenuBarPrefs.showAgentsKey) private var showAgents = true
    @AppStorage(MenuBarPrefs.showGaugeKey) private var showGauge = true
    @AppStorage(MenuBarPrefs.showRemainingKey) private var showRemaining = false
    @AppStorage(MenuBarPrefs.languageKey) private var language = "system"
    @StateObject private var chrome = MenuBarChromeMonitor()

    var body: some View {
        let _ = chrome.isDark
        if store.summary == nil {
            Text(store.menuBarLabel)
                .monospacedDigit()
        } else if let image = renderedImage {
            Image(nsImage: image)
        } else {
            Text(store.menuBarLabel)
                .monospacedDigit()
        }
    }

    private var renderedImage: NSImage? {
        let content = MenuBarStatusView.live(
            store: store,
            agents: agents,
            language: language,
            showGauge: showGauge,
            showQuota: showQuota,
            showAgents: showAgents,
            showDaily: showDaily,
            showRemaining: showRemaining,
            showOverspend: showOverspend,
            lightText: chrome.isDark
        )
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}

extension MenuBarStatusView {
    static func live(
        store: UsageStore,
        agents: AgentMonitor,
        language: String,
        showGauge: Bool,
        showQuota: Bool,
        showAgents: Bool,
        showDaily: Bool,
        showRemaining: Bool,
        showOverspend: Bool,
        lightText: Bool
    ) -> MenuBarStatusView {
        let quota = store.quotaPercentUsed
        let idle = agents.totalRunning == 0 && agents.needsInputCount == 0
        let quotaText: String? = {
            if store.summary?.isUnlimitedPlan == true { return L10n.t("unlimited", language) }
            guard let quota else { return nil }
            return "\(Int(quota.rounded()))%"
        }()
        let dailyText = store.dailyUtilizationPercent.map { "\(Int($0.rounded()))%" }
        let remainingText = store.includedRemainingCreditsCents.map(UsageStore.formatDollarsCompact)
        let overspendText = store.hasOverspend ? UsageStore.formatDollarsCompact(cents: store.overspendCents) : nil
        return MenuBarStatusView(
            showGauge: showGauge,
            showQuota: showQuota,
            showAgents: showAgents,
            showDaily: showDaily,
            showRemaining: showRemaining,
            showOverspend: showOverspend,
            quotaText: quotaText,
            quotaIsOver: (quota ?? 0) >= 100 || store.hasOverspend,
            dailyText: dailyText,
            dailyTone: store.dailyUtilizationPercent.map(UsageMath.dailyTone) ?? .plain,
            remainingText: remainingText,
            overspendText: overspendText,
            agentBadge: agents.needsInputCount > 0 ? AgentMonitorFormatting.compactCount(agents.needsInputCount) : nil,
            dimmed: idle && (quota ?? 0) == 0 && store.summary?.isUnlimitedPlan != true,
            lightText: lightText
        )
    }
}
