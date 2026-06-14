//
//  NotificationRules.swift
//  Claude Usage
//
//  The rule model behind alerts: one rule is one alert tied to a usage limit.
//  New users start with two sensible rules. A simple parser turns free text into
//  rules as an on device convenience.
//

import Foundation
import HeadroomCore

enum RuleTrigger: String, Codable, CaseIterable, Identifiable {
    case crossesAbove, fallsBelow, limitResets, onPace, beforeReset
    var id: String { rawValue }
    var label: String {
        switch self {
        case .crossesAbove: return "Crosses above"
        case .fallsBelow: return "Falls below"
        case .limitResets: return "Limit resets"
        case .onPace: return "On pace to hit"
        case .beforeReset: return "Before reset"
        }
    }
}

enum RuleTarget: String, Codable, CaseIterable, Identifiable {
    case session, weekly, weeklyOpus, extra
    var id: String { rawValue }
    var label: String {
        switch self {
        case .session: return "Session"
        case .weekly: return "Weekly"
        case .weeklyOpus: return "Weekly Opus"
        case .extra: return "Extra usage"
        }
    }
    /// Current percent and reset time for this target, if available.
    func value(in live: LiveLimits) -> (pct: Double, resetsAt: Date?)? {
        switch self {
        case .session: return live.fiveHour.map { ($0.usedPercent, $0.resetsAt) }
        case .weekly: return live.sevenDay.map { ($0.usedPercent, $0.resetsAt) }
        case .weeklyOpus: return live.sevenDayOpus.map { ($0.usedPercent, $0.resetsAt) }
        case .extra:
            guard let used = live.overageUsed, let cap = live.overageMonthlyLimit, cap > 0 else { return nil }
            return (used / cap * 100, nil)
        }
    }
    var window: TimeInterval { self == .session ? UsageWindow.session : UsageWindow.weekly }
}

struct NotificationRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var trigger: RuleTrigger = .crossesAbove
    var target: RuleTarget = .weekly
    var threshold: Double = 90
    var minutesBefore: Int = 30
    var enabled: Bool = true

    var summary: String {
        switch trigger {
        case .crossesAbove: return "Warn me when \(target.label) crosses \(Int(threshold))%"
        case .fallsBelow: return "Tell me when \(target.label) falls below \(Int(threshold))%"
        case .limitResets: return "Tell me when \(target.label) resets"
        case .onPace: return "Warn me when I am on pace to hit \(target.label)"
        case .beforeReset: return "Warn me \(minutesBefore) minutes before \(target.label) resets"
        }
    }
}

enum RulesStore {
    static let key = "notificationRules.v1"

    static var defaults: [NotificationRule] {
        [NotificationRule(trigger: .crossesAbove, target: .session, threshold: 90),
         NotificationRule(trigger: .crossesAbove, target: .weekly, threshold: 90)]
    }

    static func load() -> [NotificationRule] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let rules = try? JSONDecoder().decode([NotificationRule].self, from: data) else {
            return defaults
        }
        return rules
    }

    static func save(_ rules: [NotificationRule]) {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// Turns a plain sentence into one or more rules. A pragmatic on device parser;
/// it does not call any service.
enum RuleParser {
    static func parse(_ text: String) -> [NotificationRule] {
        let lower = text.lowercased()
        let target: RuleTarget = {
            if lower.contains("opus") { return .weeklyOpus }
            if lower.contains("session") || lower.contains("5h") || lower.contains("5 hour") { return .session }
            if lower.contains("extra") || lower.contains("credit") { return .extra }
            return .weekly
        }()

        // "N minutes before reset"
        if lower.contains("before") && lower.contains("reset") {
            let mins = firstInt(in: lower) ?? 30
            return [NotificationRule(trigger: .beforeReset, target: target, minutesBefore: mins)]
        }
        if lower.contains("on pace") || lower.contains("pace") {
            return [NotificationRule(trigger: .onPace, target: target)]
        }
        if lower.contains("reset") {
            return [NotificationRule(trigger: .limitResets, target: target)]
        }

        // Otherwise, one crosses-above rule per percentage mentioned.
        let pcts = percentages(in: lower)
        if pcts.isEmpty {
            return [NotificationRule(trigger: .crossesAbove, target: target, threshold: 90)]
        }
        let trigger: RuleTrigger = lower.contains("below") ? .fallsBelow : .crossesAbove
        return pcts.map { NotificationRule(trigger: trigger, target: target, threshold: $0) }
    }

    private static func percentages(in s: String) -> [Double] {
        var out: [Double] = []
        var num = ""
        func flush() {
            if let v = Double(num), v > 0, v <= 100 { out.append(v) }
            num = ""
        }
        for c in s {
            if c.isNumber { num.append(c) } else { flush() }
        }
        flush()
        return Array(Set(out)).sorted()
    }

    private static func firstInt(in s: String) -> Int? {
        var num = ""
        for c in s { if c.isNumber { num.append(c) } else if !num.isEmpty { break } }
        return Int(num)
    }
}
