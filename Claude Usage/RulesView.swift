//
//  RulesView.swift
//  Claude Usage
//
//  The notification rules list and the rule editor (templates, target, threshold,
//  live preview, plus a free text tab).
//

import SwiftUI

struct RulesListView: View {
    @Bindable var settings: AppSettings
    @State private var showEditor = false
    @State private var editingID: UUID?

    var body: some View {
        Form {
            Section {
                Toggle("Enable notifications", isOn: $settings.notificationsEnabled)
            } footer: {
                Text("Each rule is one alert tied to a usage limit. Toggle a rule to silence it without deleting it.")
            }

            Section("Rules") {
                ForEach($settings.rules) { $rule in
                    Button {
                        editingID = rule.id; showEditor = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(rule.summary).foregroundStyle(.primary)
                                Text(rule.target.label).font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .background(Theme.accent.opacity(0.14), in: .capsule)
                            }
                            Spacer()
                            Toggle("", isOn: $rule.enabled).labelsHidden().tint(Theme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { settings.rules.remove(atOffsets: $0) }

                Button {
                    editingID = nil; showEditor = true
                } label: {
                    Label("Add rule", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Notifications")
        .tint(Theme.accent)
        .sheet(isPresented: $showEditor) {
            RuleEditorView(
                rule: editingID.flatMap { id in settings.rules.first(where: { $0.id == id }) } ?? NotificationRule(),
                allowFreeText: editingID == nil
            ) { newRules in
                if let id = editingID, let idx = settings.rules.firstIndex(where: { $0.id == id }) {
                    if let first = newRules.first { settings.rules[idx] = first }
                    settings.rules.append(contentsOf: newRules.dropFirst())
                } else {
                    settings.rules.append(contentsOf: newRules)
                }
            }
        }
    }
}

struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var rule: NotificationRule
    var allowFreeText: Bool
    var onSave: ([NotificationRule]) -> Void

    @State private var mode = 0  // 0 build, 1 free text
    @State private var freeText = ""
    @State private var parsed: [NotificationRule] = []

    private var needsThreshold: Bool { rule.trigger == .crossesAbove || rule.trigger == .fallsBelow }

    var body: some View {
        NavigationStack {
            Form {
                if allowFreeText {
                    Picker("Mode", selection: $mode) {
                        Text("Build").tag(0)
                        Text("Free text").tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                if mode == 0 {
                    buildTab
                } else {
                    freeTextTab
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("New rule")
            .tint(Theme.accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(mode == 1 && parsed.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }

    @ViewBuilder private var buildTab: some View {
        Section("Template") {
            Picker("When", selection: $rule.trigger) {
                ForEach(RuleTrigger.allCases) { Text($0.label).tag($0) }
            }
        }
        Section("Limit") {
            Picker("Target", selection: $rule.target) {
                ForEach(RuleTarget.allCases) { Text($0.label).tag($0) }
            }
        }
        if needsThreshold {
            Section("Threshold") {
                HStack {
                    Text("At")
                    Spacer()
                    Text("\(Int(rule.threshold))%").monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $rule.threshold, in: 5...100, step: 5)
            }
        }
        if rule.trigger == .beforeReset {
            Section("Timing") {
                Stepper("\(rule.minutesBefore) minutes before", value: $rule.minutesBefore, in: 5...720, step: 5)
            }
        }
        Section("Preview") {
            Text(rule.summary).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var freeTextTab: some View {
        Section {
            TextField("warn me at 75 and 90 percent of my weekly limit", text: $freeText, axis: .vertical)
                .lineLimit(2...4)
            Button("Convert") { parsed = RuleParser.parse(freeText) }
                .disabled(freeText.trimmingCharacters(in: .whitespaces).isEmpty)
        } header: {
            Text("Describe the alert")
        } footer: {
            Text("Parsed on this device. Your text never leaves it.")
        }
        if !parsed.isEmpty {
            Section("Parsed into \(parsed.count) rule\(parsed.count == 1 ? "" : "s")") {
                ForEach(parsed) { r in
                    Text(r.summary).font(.subheadline)
                }
            }
        }
    }

    private func save() {
        if mode == 1 { onSave(parsed) } else { onSave([rule]) }
        dismiss()
    }
}
