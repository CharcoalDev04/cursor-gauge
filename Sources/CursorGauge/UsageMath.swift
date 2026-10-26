import Foundation

enum UsageMath {
    struct ModelSpend: Equatable, Sendable, Identifiable {
        let model: String
        let cents: Int
        var id: String { model }
    }

    /// Highest spend first. Equal totals break ties by model name. Blank names are dropped.
    static func topModelSpends(
        events: [(model: String, cents: Double)],
        limit: Int = 3
    ) -> [ModelSpend] {
        var totals: [String: Double] = [:]
        for event in events {
            let name = event.model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            totals[name, default: 0] += event.cents
        }
        return totals
            .map { ModelSpend(model: $0.key, cents: Int($0.value.rounded())) }
            .sorted { lhs, rhs in
                if lhs.cents != rhs.cents { return lhs.cents > rhs.cents }
                return lhs.model < rhs.model
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Calendar day in `timeZone`, `yyyy-MM-dd`.
    static func dayString(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    enum DailyTone: Equatable {
        case plain, warm, hot
    }

    /// Near a full day is warm. Past the daily budget is hot.
    static func dailyTone(_ percent: Double) -> DailyTone {
        if percent > 100 { return .hot }
        if percent >= 90 { return .warm }
        return .plain
    }

    static func usedCents(limit: Int, percent: Double) -> Int {
        Int((Double(limit) * percent / 100).rounded())
    }

    static func gmtLabel(timeZone: TimeZone = .current, date: Date = Date()) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        let sign = seconds >= 0 ? "+" : "-"
        let absolute = abs(seconds)
        let hours = absolute / 3600
        let minutes = (absolute % 3600) / 60
        if minutes == 0 {
            return "GMT\(sign)\(hours)"
        }
        return String(format: "GMT%@%d:%02d", sign, hours, minutes)
    }

    static func selfCheck() {
        let spends = topModelSpends(events: [
            ("a", 10.4),
            ("b", 50),
            ("a", 10.2),
            ("", 99),
            ("c", 5),
            ("d", 5),
        ])
        precondition(spends.map(\.model) == ["b", "a", "c"])
        precondition(spends[1].cents == 21)

        let evening = Date(timeIntervalSince1970: 20 * 3600)
        precondition(dayString(evening, timeZone: TimeZone(secondsFromGMT: 0)!) == "1970-01-01")
        precondition(dayString(evening, timeZone: TimeZone(secondsFromGMT: 7 * 3600)!) == "1970-01-02")
        precondition(gmtLabel(timeZone: TimeZone(secondsFromGMT: 7 * 3600)!, date: evening) == "GMT+7")
        precondition(dailyTone(89) == .plain)
        precondition(dailyTone(90) == .warm)
        precondition(dailyTone(100) == .warm)
        precondition(dailyTone(101) == .hot)
        precondition(usedCents(limit: 20_000, percent: 98) == 19_600)
        precondition(UsageCredits.individualPoolCents(otherModelsLimit: 2_000) == 22_000)
        precondition(UsageCredits.individualPoolCents(otherModelsLimit: nil) == 22_000)
        L10n.selfCheck()
        TokenProvider.selfCheck()
    }
}
