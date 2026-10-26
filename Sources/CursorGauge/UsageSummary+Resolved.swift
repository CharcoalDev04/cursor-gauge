import Foundation

enum UsageCredits {
    /// Minimum Cursor Models (Auto / Composer / Cursor Grok) pool floor by tier, in cents.
    /// Pro: $200, Pro+: $400, Ultra: $2,000.
    static func minimumCursorModelsCents(for membershipType: String) -> Int {
        switch normalizedTier(membershipType) {
        case "ultra":
            200_000
        case "pro_plus":
            40_000
        default:
            20_000
        }
    }

    /// Official Other Models (API) monthly allowance by tier, in cents.
    /// Pro: $20, Pro+: $70, Ultra: $400.
    static func defaultOtherModelsCents(for membershipType: String) -> Int {
        switch normalizedTier(membershipType) {
        case "ultra":
            40_000
        case "pro_plus":
            7_000
        default:
            2_000
        }
    }

    /// Tier floor for total included pool when usage is 0% or not yet reported.
    static func minimumIncludedPoolCents(for membershipType: String, otherModelsLimit: Int?) -> Int {
        let cursorFloor = minimumCursorModelsCents(for: membershipType)
        let apiCap = otherModelsLimit ?? defaultOtherModelsCents(for: membershipType)
        return cursorFloor + apiCap
    }

    static func normalizedTier(_ raw: String) -> String {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        if cleaned.contains("ultra") { return "ultra" }
        if cleaned == "pro+" || cleaned.contains("pro_plus") || cleaned.contains("proplus") {
            return "pro_plus"
        }
        return cleaned
    }
}

extension UsageSummary {
    var isUnlimitedPlan: Bool { isUnlimited ?? false }

    var hasDisplayableUsage: Bool {
        isUnlimitedPlan
            || includedPercentUsed != nil
            || cursorModelsPercentUsed != nil
            || otherModelsPercentUsed != nil
            || includedUsedCents != nil
    }

    var resolvedMembershipType: String {
        let raw = membershipType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "unknown" : raw
    }

    var formattedMembershipName: String {
        switch UsageCredits.normalizedTier(resolvedMembershipType) {
        case "pro_plus":
            "Pro+"
        case "ultra":
            "Ultra"
        case "pro":
            "Pro"
        default:
            resolvedMembershipType.capitalized
        }
    }

    var plan: PlanUsage? { individualUsage?.plan }
    var overall: OverallUsage? { individualUsage?.overall }

    var resolvedOnDemand: OnDemandUsage? {
        individualUsage?.onDemand ?? teamUsage?.onDemand
    }

    /// Individual plans (Pro / Pro+ / Ultra). Never applied to Enterprise or team seats.
    var appliesIndividualCreditFloors: Bool {
        if limitType?.lowercased() == "team" { return false }
        switch UsageCredits.normalizedTier(resolvedMembershipType) {
        case "enterprise", "team", "business", "free", "hobby":
            return false
        default:
            return true
        }
    }

    /// Cursor Models pool (Auto, Composer, Cursor Grok). `autoPercentUsed` on the wire.
    var cursorModelsPercentUsed: Double? {
        if isUnlimitedPlan { return nil }
        return plan?.autoPercentUsed ?? Self.percent(fromDisplayMessage: autoModelSelectedDisplayMessage)
    }

    /// Other Models pool (named / third-party). `apiPercentUsed` on the wire.
    var otherModelsPercentUsed: Double? {
        if isUnlimitedPlan { return nil }
        return plan?.apiPercentUsed ?? Self.percent(fromDisplayMessage: namedModelSelectedDisplayMessage)
    }

    /// Blended included-usage percentage. Prefer `totalPercentUsed`, fallback to display message.
    var includedPercentUsed: Double? {
        if isUnlimitedPlan { return nil }
        return plan?.totalPercentUsed ?? Self.percent(fromDisplayMessage: autoModelSelectedDisplayMessage)
    }

    /// Amount used against the included pool. Prefer `breakdown.total` over `plan.used`:
    /// on some Enterprise payloads `plan.used` is the Other Models cap, not included spend.
    var includedUsedCents: Int? {
        if let total = plan?.breakdown?.total { return total }
        if let overallUsed = overall?.used { return overallUsed }
        return nil
    }

    /// Total included pool limit in cents:
    /// 1. `overall.limit` if present
    /// 2. `cursorModelsLimitCents + otherModelsLimitCents` when both pools are known
    /// 3. Derived from `includedUsedCents / (includedPercentUsed / 100)`, floored by the plan's minimum
    var includedLimitCents: Int? {
        if let overallLimit = overall?.limit, overallLimit > 0 {
            return overallLimit
        }

        let floor = appliesIndividualCreditFloors
            ? UsageCredits.minimumIncludedPoolCents(
                for: resolvedMembershipType,
                otherModelsLimit: otherModelsLimitCents
            )
            : 0

        let percent = includedPercentUsed ?? 0
        var derived = 0
        if let used = includedUsedCents, percent > 0, percent < 100 {
            derived = Int((Double(used) / (percent / 100.0)).rounded())
        }

        if let cursorLimit = cursorModelsLimitCents, let apiLimit = otherModelsLimitCents {
            derived = max(derived, cursorLimit + apiLimit)
        }

        let result = max(derived, floor)
        return result > 0 ? result : nil
    }

    /// Other Models dollar cap from `plan.limit`, or tier default ($20 Pro / $70 Pro+ / $400 Ultra) on individual plans.
    var otherModelsLimitCents: Int? {
        guard plan?.enabled != false else { return nil }
        if let limit = plan?.limit, limit > 0 {
            return limit
        }
        if appliesIndividualCreditFloors, otherModelsPercentUsed != nil {
            return UsageCredits.defaultOtherModelsCents(for: resolvedMembershipType)
        }
        return nil
    }

    var otherModelsUsedCents: Int? {
        guard let limit = otherModelsLimitCents, let percent = otherModelsPercentUsed else { return nil }
        return UsageMath.usedCents(limit: limit, percent: percent)
    }

    /// Actual Cursor Models spend when `includedUsedCents` is known (`totalUsed - apiUsed`),
    /// otherwise derived from the Cursor Models limit and `autoPercentUsed`.
    var cursorModelsUsedCents: Int? {
        if let totalUsed = includedUsedCents {
            let apiUsed = otherModelsUsedCents ?? 0
            return max(totalUsed - apiUsed, 0)
        }
        guard let limit = cursorModelsLimitCents, let percent = cursorModelsPercentUsed else { return nil }
        return UsageMath.usedCents(limit: limit, percent: percent)
    }

    /// Cursor Models pool cap derived from actual Cursor Models spend and `autoPercentUsed`,
    /// floored by the tier minimum ($200 Pro / $400 Pro+ / $2,000 Ultra).
    var cursorModelsLimitCents: Int? {
        guard cursorModelsPercentUsed != nil else { return nil }
        let floor = appliesIndividualCreditFloors
            ? UsageCredits.minimumCursorModelsCents(for: resolvedMembershipType)
            : 0

        var derived = 0
        if let totalUsed = includedUsedCents,
           let percent = cursorModelsPercentUsed,
           percent > 0,
           percent < 100
        {
            let apiUsed = otherModelsUsedCents ?? 0
            let cursorUsed = max(totalUsed - apiUsed, 0)
            derived = Int((Double(cursorUsed) / (percent / 100.0)).rounded())
        }

        let result = max(derived, floor)
        return result > 0 ? result : nil
    }

    /// Leading `N` or `N.N` before `%` in Cursor's prose, e.g. "You've used 8% of your included total usage".
    static func percent(fromDisplayMessage message: String?) -> Double? {
        guard let message, let match = message.firstMatch(of: /(\d+(?:\.\d+)?)\s*%/) else { return nil }
        return Double(match.1)
    }
}
