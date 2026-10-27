//
//  ReplacementSettingsSection.swift
//  Easydict
//
//  Copyright © 2026 izual. All rights reserved.
//

import Defaults
import SFSafeSymbols
import SwiftUI

// MARK: - ReplacementSettingsSection

/// Settings for replacement actions, independent of query-window language and service ordering.
struct ReplacementSettingsSection: View {
    // MARK: Internal

    var body: some View {
        Section {
            LabeledContent("replacement.settings.targets") {
                Button("setting.languages.manage") { showsLanguages = true }
            }
            Text(targetSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            servicePicker(
                "replacement.settings.translation_service",
                selection: $translationServiceID,
                polishing: false
            )
            servicePicker("replacement.settings.polishing_service", selection: $polishingServiceID, polishing: true)

            ForEach([ShortcutAction.translateAndReplace, .polishAndReplace]) { action in
                KeyHolderRowView(
                    title: action.localizedStringKey(),
                    action: action,
                    confictAlterMessage: $shortcutConflict
                )
            }
            Text("replacement.settings.candidate_description")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("replacement.settings.enable_instant_shortcuts", isOn: instantShortcutsEnabled)
            if mode == "instant" {
                Text("replacement.settings.instant_description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(LanguagePreferences.replacementTargetLanguages, id: \.rawValue) { language in
                    ReplacementShortcutRecorder(language: language)
                }
            }
            if shortcutManager.candidateShortcutUnavailable {
                Text("replacement.settings.shortcut_unavailable")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("menu_translate_and_replace")
        }
        .sheet(isPresented: $showsLanguages) { ReplacementLanguagesSheet() }
        .keyHolderConfictAlter(
            Binding(get: { !shortcutConflict.message.isEmpty }, set: { _ in }),
            $shortcutConflict
        )
        .onAppear { services = ReplacementService.enabledServices }
        .onReceive(NotificationCenter.default.publisher(for: .serviceHasUpdated).receive(on: DispatchQueue.main)) { _ in
            services = ReplacementService.enabledServices
        }
    }

    // MARK: Private

    @State private var showsLanguages = false
    @State private var services: [QueryService] = []
    @State private var shortcutConflict = ShortcutConfictAlertMessage(title: "", message: "")
    @ObservedObject private var shortcutManager = ReplacementShortcutManager.shared

    @Default(.replacementTargetLanguages) private var targets
    @Default(.replacementTranslationServiceID) private var translationServiceID
    @Default(.replacementPolishingServiceID) private var polishingServiceID
    @Default(.replacementMode) private var mode

    // Keep the existing stored values so upgrading preserves instant shortcuts' enabled state.
    private var instantShortcutsEnabled: Binding<Bool> {
        Binding(get: { mode == "instant" }, set: { mode = $0 ? "instant" : "candidate" })
    }

    private var targetSummary: String {
        if targets.isEmpty { return String(localized: "setting.languages.empty_targets") }
        return LanguagePreferences.replacementTargetLanguages.map { "\($0.flagEmoji) \($0.localizedName)" }
            .joined(separator: "、")
    }

    private func servicePicker(
        _ title: LocalizedStringKey, selection: Binding<String>, polishing: Bool
    )
        -> some View {
        Picker(title, selection: selection) {
            if !services.contains(where: { $0.serviceTypeWithUniqueIdentifier() == selection.wrappedValue }) {
                Text("replacement.settings.service_unavailable").tag(selection.wrappedValue)
            }
            ForEach(services, id: \.self) { service in
                let supported = polishing
                    ? ReplacementService.supportsPolishing(service)
                    : ReplacementService.supportsTranslation(service)
                Text(supported ? service
                    .name() : String(localized: "replacement.settings.unsupported \(service.name())"))
                    .tag(service.serviceTypeWithUniqueIdentifier())
                    .disabled(!supported)
            }
        }
    }
}

// MARK: - ReplacementLanguagesSheet

/// Selected targets keep their persisted order; any other supported language can be added.
private struct ReplacementLanguagesSheet: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("replacement.settings.targets").font(.headline)
            Text("replacement.settings.targets_description")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("replacement.settings.selected_targets").font(.subheadline.weight(.semibold))
                    List {
                        ForEach(Array(selectedTargets.enumerated()), id: \.element.rawValue) { index, language in
                            HStack(spacing: 6) {
                                Toggle(isOn: targetBinding(language)) {
                                    Text(verbatim: "\(language.flagEmoji) \(language.localizedName)")
                                }
                                Spacer(minLength: 0)
                                Button { move(language, by: -1) } label: { Image(systemSymbol: .chevronUp) }
                                    .disabled(index == 0)
                                    .help("replacement.settings.move_up")
                                    .accessibilityLabel(Text("replacement.settings.move_up"))
                                Button { move(language, by: 1) } label: { Image(systemSymbol: .chevronDown) }
                                    .disabled(index == selectedTargets.count - 1)
                                    .help("replacement.settings.move_down")
                                    .accessibilityLabel(Text("replacement.settings.move_down"))
                            }
                        }
                    }
                    if selectedTargets.isEmpty {
                        Text("setting.languages.empty_targets").font(.caption).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    TextField("replacement.settings.search_languages", text: $searchText)
                    List(availableTargets, id: \.rawValue) { language in
                        Toggle(isOn: targetBinding(language)) {
                            Text(verbatim: "\(language.flagEmoji) \(language.localizedName)")
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("setting.languages.done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 680, height: 500)
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    @Default(.replacementTargetLanguages) private var targets

    private var selectedTargets: [Language] {
        // Read the observed preference so toggles and ordering refresh immediately.
        targets.filter { LanguagePreferences.configurableLanguages.contains($0) }
    }

    private var availableTargets: [Language] {
        LanguagePreferences.configurableLanguages.filter {
            !targets.contains($0) && (searchText.isEmpty
                || $0.localizedName.localizedCaseInsensitiveContains(searchText)
                || $0.rawValue.localizedCaseInsensitiveContains(searchText))
        }
    }

    private func targetBinding(_ language: Language) -> Binding<Bool> {
        Binding(
            get: { targets.contains(language) },
            set: { selected in
                var updated = LanguagePreferences.replacementTargetLanguages
                if selected {
                    if !updated.contains(language) { updated.append(language) }
                } else {
                    updated.removeAll { $0 == language }
                }
                LanguagePreferences.replacementTargetLanguages = updated
            }
        )
    }

    private func move(_ language: Language, by offset: Int) {
        var updated = LanguagePreferences.replacementTargetLanguages
        guard let index = updated.firstIndex(of: language), updated.indices.contains(index + offset) else { return }
        updated.swapAt(index, index + offset)
        LanguagePreferences.replacementTargetLanguages = updated
    }
}
