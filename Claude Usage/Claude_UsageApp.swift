//
//  Claude_UsageApp.swift
//  Claude Usage
//
//  Created by Panda on 13/06/2026.
//

import SwiftUI

@main
struct Claude_UsageApp: App {
    @State private var model = UsageModel()
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, settings: settings)
                .task {
                    model.startAutoRefresh()
                }
        }

        #if os(macOS)
        MenuBarExtra {
            MenuBarPopover(model: model, settings: settings)
                .task { model.startAutoRefresh() }
        } label: {
            MenuBarLabel(model: model, settings: settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model, settings: settings)
        }
        #endif
    }
}
