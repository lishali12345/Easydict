//
//  ReplacementShortcutManager.swift
//  Easydict
//
//  Copyright © 2026 izual. All rights reserved.
//

import Combine
import Defaults
import Magnet
import Sauce

/// Registers per-language shortcuts only while instant replacement is enabled.
final class ReplacementShortcutManager: ObservableObject {
    // MARK: Internal

    static let shared = ReplacementShortcutManager()

    @Published private(set) var unavailableLanguages: Set<String> = []
    @Published var candidateShortcutUnavailable = false

    private(set) var isPreviewVisible = false
    private(set) var isRecording = false

    /// Include inactive bindings in validation so changing mode cannot create a hidden conflict.
    static func conflictTitle(for keyCombo: KeyCombo, excludingLanguage: String? = nil) -> String? {
        let shortcuts = Defaults[.replacementInstantShortcuts]
        return Defaults[.replacementTargetLanguages].first {
            $0.rawValue != excludingLanguage && shortcuts[$0.rawValue] == keyCombo
        }?.localizedName
    }

    func setup() {
        guard cancellables.isEmpty else { return }
        migrateCandidateShortcut()
        initializeShortcuts()
        Defaults.publisher(.replacementMode, options: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        Defaults.publisher(.replacementTargetLanguages, options: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.initializeShortcuts()
                self?.refresh()
            }
            .store(in: &cancellables)
        Defaults.publisher(.replacementInstantShortcuts, options: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        for action in ShortcutAction.allCases {
            guard let key = action.defaultsKey else { continue }
            Defaults.publisher(key, options: [])
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.refresh() }
                .store(in: &cancellables)
        }
        refresh()
    }

    func setPreviewVisible(_ visible: Bool) {
        isPreviewVisible = visible
        if visible {
            for action in ShortcutAction.globalActions {
                HotKeyCenter.shared.unregisterHotKey(with: action.rawValue)
            }
        } else {
            ShortcutManager.shared.setupGlobalShortcutActions()
        }
        refresh()
    }

    /// Temporarily release hotkeys so the recorder receives the original key event.
    func beginRecording() {
        isRecording = true
        for action in ShortcutAction.globalActions {
            HotKeyCenter.shared.unregisterHotKey(with: action.rawValue)
        }
        unregisterInstantShortcuts()
    }

    func endRecording() {
        isRecording = false
        ShortcutManager.shared.setupGlobalShortcutActions()
        refresh()
    }

    func store(_ keyCombo: KeyCombo?, for language: Language) {
        var shortcuts = Defaults[.replacementInstantShortcuts]
        shortcuts[language.rawValue] = keyCombo
        Defaults[.replacementInstantShortcuts] = shortcuts
        var initialized = Defaults[.replacementInstantShortcutInitializedLanguages]
        if !initialized.contains(language.rawValue) {
            initialized.append(language.rawValue)
            Defaults[.replacementInstantShortcutInitializedLanguages] = initialized
        }
        refresh()
    }

    func refresh() {
        unregisterInstantShortcuts()
        guard Defaults[.replacementMode] == "instant", !isPreviewVisible, !isRecording else { return }
        var unavailable: Set<String> = []
        let shortcuts = Defaults[.replacementInstantShortcuts]
        for language in Defaults[.replacementTargetLanguages] {
            guard let keyCombo = shortcuts[language.rawValue] else { continue }
            if ShortcutManager.validateShortcut(keyCombo, excludingReplacementLanguage: language.rawValue) {
                unavailable.insert(language.rawValue)
                continue
            }
            let identifier = identifier(for: language)
            let hotKey = HotKey(identifier: identifier, keyCombo: keyCombo) { _ in
                Task { @MainActor in
                    guard Defaults[.replacementMode] == "instant",
                          !self.isPreviewVisible, !self.isRecording,
                          Defaults[.replacementTargetLanguages].contains(language) else { return }
                    await ActionManager.shared.translateAndReplace(to: language)
                }
            }
            if hotKey.register() {
                registeredIdentifiers.insert(identifier)
            } else {
                unavailable.insert(language.rawValue)
            }
        }
        unavailableLanguages = unavailable
    }

    // MARK: Private

    private var cancellables: Set<AnyCancellable> = []
    private var registeredIdentifiers: Set<String> = []

    private func identifier(for language: Language) -> String {
        "replacement.instant.\(language.rawValue)"
    }

    private func unregisterInstantShortcuts() {
        for identifier in registeredIdentifiers {
            HotKeyCenter.shared.unregisterHotKey(with: identifier)
        }
        registeredIdentifiers.removeAll()
    }

    private func initializeShortcuts() {
        let digits: [Key] = [.one, .two, .three, .four, .five, .six, .seven, .eight, .nine]
        var shortcuts = Defaults[.replacementInstantShortcuts]
        var initialized = Defaults[.replacementInstantShortcutInitializedLanguages]
        let savedActionShortcuts = ShortcutAction.allCases.compactMap { action in
            action.defaultsKey.flatMap { Defaults[$0] }
        }
        for (index, language) in Defaults[.replacementTargetLanguages].enumerated() {
            guard !initialized.contains(language.rawValue) else { continue }
            initialized.append(language.rawValue)
            if shortcuts[language.rawValue] == nil, index < digits.count {
                // Existing bindings follow their language, so a new row cannot reuse its position blindly.
                let preferredIndices = [index] + digits.indices.filter { $0 != index }
                shortcuts[language.rawValue] = preferredIndices.compactMap {
                    KeyCombo(key: digits[$0], cocoaModifiers: [.command, .shift])
                }.first {
                    !shortcuts.values.contains($0) && !savedActionShortcuts.contains($0)
                }
            }
        }
        Defaults[.replacementInstantShortcutInitializedLanguages] = initialized
        if Defaults[.replacementInstantShortcuts] != shortcuts {
            Defaults[.replacementInstantShortcuts] = shortcuts
        }
    }

    private func migrateCandidateShortcut() {
        guard !Defaults[.replacementShortcutMigrationCompleted] else { return }
        let oldDefault = KeyCombo(key: .t, cocoaModifiers: [.control, .option])
        if Defaults[.translateAndReplaceShortcut] == oldDefault {
            let newDefault = KeyCombo(key: .t, cocoaModifiers: [.command, .shift])
            Defaults[.translateAndReplaceShortcut] = newDefault
            ShortcutManager.shared.bindingGlobalShortcutAction(keyCombo: newDefault, action: .translateAndReplace)
        }
        Defaults[.replacementShortcutMigrationCompleted] = true
    }
}
