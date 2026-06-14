//
//  NotificationManager.swift
//  Claude Usage
//
//  Evaluates the user's notification rules against each refresh, with edge
//  detection so each transition fires once. State lives in UserDefaults.
//

import Foundation
import UserNotifications
import HeadroomCore

@MainActor
enum NotificationManager {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func evaluateIfEnabled(_ snapshot: UsageSnapshot) {
        let d = UserDefaults.standard
        guard d.object(forKey: "notificationsEnabled") as? Bool ?? true else { return }
        guard let live = snapshot.live else { return }
        for rule in RulesStore.load() where rule.enabled {
            evaluate(rule, live: live)
        }
    }

    private static func evaluate(_ rule: NotificationRule, live: LiveLimits) {
        guard let (pct, resetsAt) = rule.target.value(in: live) else { return }
        let d = UserDefaults.standard
        let firedKey = "rule.fired.\(rule.id.uuidString)"
        let highKey = "rule.high.\(rule.id.uuidString)"
        let windowKey = "rule.window.\(rule.id.uuidString)"
        let name = rule.target.label

        switch rule.trigger {
        case .crossesAbove:
            if pct >= rule.threshold {
                if !d.bool(forKey: firedKey) {
                    notify("\(name) is high", "You have used \(Int(pct.rounded()))% of your \(name) limit. Resets \(Fmt.untilLong(resetsAt)).")
                    d.set(true, forKey: firedKey)
                }
            } else { d.set(false, forKey: firedKey) }

        case .fallsBelow:
            if pct <= rule.threshold {
                if !d.bool(forKey: firedKey) {
                    notify("\(name) has room again", "\(name) is back down to \(Int(pct.rounded()))%.")
                    d.set(true, forKey: firedKey)
                }
            } else { d.set(false, forKey: firedKey) }

        case .limitResets:
            if pct >= 50 { d.set(true, forKey: highKey) }
            if d.bool(forKey: highKey) && pct < 10 {
                notify("\(name) reset", "Your \(name) limit just reset. Full access is back.")
                d.set(false, forKey: highKey)
            }

        case .onPace:
            guard rule.target != .extra else { return }
            let onPace = Pace.projectedExhaustion(usedPercent: pct, resetsAt: resetsAt, window: rule.target.window) != nil
            if onPace {
                if !d.bool(forKey: firedKey) {
                    notify("On pace to hit \(name)", "At this pace you will hit your \(name) limit before it resets.")
                    d.set(true, forKey: firedKey)
                }
            } else { d.set(false, forKey: firedKey) }

        case .beforeReset:
            guard let resetsAt else { return }
            let secs = resetsAt.timeIntervalSinceNow
            let stamp = resetsAt.timeIntervalSince1970
            if secs > 0, secs <= Double(rule.minutesBefore * 60) {
                if d.double(forKey: windowKey) != stamp {
                    notify("\(name) resets soon", "Your \(name) limit resets \(Fmt.untilLong(resetsAt)).")
                    d.set(stamp, forKey: windowKey)
                }
            }
        }
    }

    private static func notify(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Claude Usage"
        content.subtitle = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
