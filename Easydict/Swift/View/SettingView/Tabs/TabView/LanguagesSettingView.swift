//
//  LanguagesSettingView.swift
//  Easydict
//
//  Copyright © 2026 izual. All rights reserved.
//

import Defaults
import SwiftUI

// MARK: - LanguagesSettingView

/// Opens the language configuration shared by query menus and translation previews.
struct LanguagesSettingView: View {
    // MARK: Internal

    var body: some View {
        Button("setting.languages.manage") {
            isPresented = true
        }
        .sheet(isPresented: $isPresented) {
            LanguagesConfigurationSheet()
        }
    }

    // MARK: Private

    @State private var isPresented = false
}

// MARK: - LanguagesConfigurationSheet

private struct LanguagesConfigurationSheet: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("setting.languages.title")
                .font(.headline)
            Text("setting.languages.description")
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("setting.languages.enabled")
                        .font(.subheadline.weight(.semibold))
                    List(LanguagePreferences.configurableLanguages, id: \.rawValue) { language in
                        Toggle(isOn: enabledBinding(for: language)) {
                            languageLabel(language)
                        }
                        .disabled(language == firstLanguage || language == secondLanguage)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("setting.languages.replacement_targets")
                        .font(.subheadline.weight(.semibold))
                    List(targetOptions, id: \.rawValue) { language in
                        Toggle(isOn: targetBinding(for: language)) {
                            languageLabel(language)
                        }
                    }
                    if LanguagePreferences.replacementTargetLanguages.isEmpty {
                        Text("setting.languages.empty_targets")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("setting.languages.required")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("setting.languages.done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 620, height: 500)
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss

    @Default(.enabledLanguages) private var enabledLanguages
    @Default(.replacementTargetLanguages) private var replacementTargetLanguages
    @Default(.firstLanguage) private var firstLanguage
    @Default(.secondLanguage) private var secondLanguage

    private var targetOptions: [Language] {
        enabledLanguages.filter {
            LanguagePreferences.configurableLanguages.contains($0) && $0 != .english
        }
    }

    private func languageLabel(_ language: Language) -> some View {
        Text(verbatim: "\(language.flagEmoji) \(language.localizedName)")
    }

    private func enabledBinding(for language: Language) -> Binding<Bool> {
        Binding(
            get: {
                enabledLanguages.contains(language) || language == firstLanguage || language == secondLanguage
            },
            set: { isEnabled in
                var languages = LanguagePreferences.enabledLanguages
                if isEnabled {
                    languages.append(language)
                } else {
                    languages.removeAll { $0 == language }
                }
                LanguagePreferences.enabledLanguages = languages
            }
        )
    }

    private func targetBinding(for language: Language) -> Binding<Bool> {
        Binding(
            get: { replacementTargetLanguages.contains(language) },
            set: { isEnabled in
                var languages = LanguagePreferences.replacementTargetLanguages
                if isEnabled {
                    languages.append(language)
                } else {
                    languages.removeAll { $0 == language }
                }
                LanguagePreferences.replacementTargetLanguages = languages
            }
        )
    }
}
