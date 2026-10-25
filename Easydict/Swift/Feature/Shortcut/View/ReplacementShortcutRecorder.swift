//
//  ReplacementShortcutRecorder.swift
//  Easydict
//
//  Copyright © 2026 izual. All rights reserved.
//

import Defaults
import KeyHolder
import Magnet
import SwiftUI

// MARK: - ReplacementShortcutRecorder

/// Records a shortcut against a language identity, independently of its display position.
struct ReplacementShortcutRecorder: View {
    // MARK: Internal

    let language: Language

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Text(verbatim: "\(language.flagEmoji) \(language.localizedName)")
                Spacer()
                ReplacementKeyHolder(language: language, keyCombo: shortcuts[language.rawValue], conflict: $conflict)
                    .frame(width: 150, height: 28)
                    .borderedCard()
            }
            if manager.unavailableLanguages.contains(language.rawValue) {
                Text("replacement.settings.shortcut_unavailable")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .keyHolderConfictAlter(
            Binding(get: { !conflict.message.isEmpty }, set: { _ in }),
            $conflict
        )
    }

    // MARK: Private

    @ObservedObject private var manager = ReplacementShortcutManager.shared
    @State private var conflict = ShortcutConfictAlertMessage(title: "", message: "")

    @Default(.replacementInstantShortcuts) private var shortcuts
}

// MARK: - ReplacementKeyHolder

private struct ReplacementKeyHolder: NSViewRepresentable {
    final class Coordinator: NSObject, RecordViewDelegate {
        // MARK: Lifecycle

        init(language: Language, conflict: Binding<ShortcutConfictAlertMessage>) {
            self.language = language
            _conflict = conflict
        }

        // MARK: Internal

        @Binding var conflict: ShortcutConfictAlertMessage

        let language: Language

        func recordViewShouldBeginRecording(_: RecordView) -> Bool {
            MyConfiguration.shared.isRecordingSelectTextShortcutKey = true
            ReplacementShortcutManager.shared.beginRecording()
            return true
        }

        func recordViewDidEndRecording(_: RecordView) {
            MyConfiguration.shared.isRecordingSelectTextShortcutKey = false
            ReplacementShortcutManager.shared.endRecording()
        }

        func recordView(_: RecordView, canRecordKeyCombo _: KeyCombo) -> Bool { true }

        func recordView(_ view: RecordView, didChangeKeyCombo keyCombo: KeyCombo?) {
            if let keyCombo,
               ShortcutManager.validateShortcut(keyCombo, excludingReplacementLanguage: language.rawValue) {
                conflict = ShortcutConfictAlertMessage(
                    title: String(
                        localized: "shortcut_confict_title \(keyCombo.keyEquivalentModifierMaskString + keyCombo.characters)"
                    ),
                    message: String(
                        localized: "shortcut_confict_message \(ShortcutManager.shared.confictShortcutTitle)"
                    )
                )
                view.keyCombo = Defaults[.replacementInstantShortcuts][language.rawValue]
                return
            }
            ReplacementShortcutManager.shared.store(keyCombo, for: language)
        }
    }

    let language: Language
    let keyCombo: KeyCombo?

    @Binding var conflict: ShortcutConfictAlertMessage

    static func dismantleNSView(_ view: RecordView, coordinator: Coordinator) {
        if view.isRecording { view.endRecording() }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(language: language, conflict: $conflict)
    }

    func makeNSView(context: Context) -> RecordView {
        let view = RecordView(frame: .zero)
        view.delegate = context.coordinator
        view.clearButtonMode = .whenRecorded
        view.keyCombo = keyCombo
        return view
    }

    func updateNSView(_ view: RecordView, context: Context) {
        if !view.isRecording { view.keyCombo = keyCombo }
    }
}
