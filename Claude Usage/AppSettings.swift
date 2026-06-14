//
//  AppSettings.swift
//  Claude Usage
//

import Foundation
import Observation

enum WidgetMetric: String, CaseIterable { case weekly, session }
enum TimeFormatPref: String, CaseIterable { case system, h24, h12 }
enum MenuBarStyle: String, CaseIterable {
    case percentage, percentageReset, timeLeft, credits, ring, sessionWeekly
    var title: String {
        switch self {
        case .percentage: return "Percentage"
        case .percentageReset: return "Percentage and time left"
        case .timeLeft: return "Time left"
        case .credits: return "Credits left"
        case .ring: return "Ring and percentage"
        case .sessionWeekly: return "Session and weekly"
        }
    }
}
enum DashboardTextSize: String, CaseIterable { case small, medium, large }

@MainActor
@Observable
final class AppSettings {
    // Alerts
    var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) } }
    var threshold: Double { didSet { defaults.set(threshold, forKey: Keys.threshold) } }
    var rules: [NotificationRule] { didSet { RulesStore.save(rules) } }

    // Display
    var showPaceMarker: Bool { didSet { defaults.set(showPaceMarker, forKey: Keys.showPaceMarker) } }
    var defaultWidgetMetric: WidgetMetric { didSet { defaults.set(defaultWidgetMetric.rawValue, forKey: Keys.defaultWidgetMetric) } }
    var timeFormat: TimeFormatPref { didSet { defaults.set(timeFormat.rawValue, forKey: Keys.timeFormat) } }
    var dashboardTextSize: DashboardTextSize { didSet { defaults.set(dashboardTextSize.rawValue, forKey: Keys.dashboardTextSize) } }

    // macOS menu bar
    var menuBarStyle: MenuBarStyle { didSet { defaults.set(menuBarStyle.rawValue, forKey: Keys.menuBarStyle) } }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let notificationsEnabled = "notificationsEnabled"
        static let threshold = "notificationThreshold"
        static let showPaceMarker = "showPaceMarker"
        static let defaultWidgetMetric = "defaultWidgetMetric"
        static let timeFormat = "timeFormat"
        static let dashboardTextSize = "dashboardTextSize"
        static let menuBarStyle = "menuBarStyle"
    }

    init() {
        notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        threshold = defaults.object(forKey: Keys.threshold) as? Double ?? 80
        rules = RulesStore.load()
        showPaceMarker = defaults.object(forKey: Keys.showPaceMarker) as? Bool ?? true
        defaultWidgetMetric = WidgetMetric(rawValue: defaults.string(forKey: Keys.defaultWidgetMetric) ?? "") ?? .weekly
        timeFormat = TimeFormatPref(rawValue: defaults.string(forKey: Keys.timeFormat) ?? "") ?? .system
        dashboardTextSize = DashboardTextSize(rawValue: defaults.string(forKey: Keys.dashboardTextSize) ?? "") ?? .medium
        menuBarStyle = MenuBarStyle(rawValue: defaults.string(forKey: Keys.menuBarStyle) ?? "") ?? .percentageReset
    }
}
