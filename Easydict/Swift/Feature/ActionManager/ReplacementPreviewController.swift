//
//  ReplacementPreviewController.swift
//  Easydict
//
//  Copyright © 2026 izual. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - ReplacementPreviewController

/// Presents completed translations without changing the original text until the user chooses one.
@MainActor
final class ReplacementPreviewController: NSObject, ObservableObject, NSWindowDelegate {
    // MARK: Lifecycle

    init(languages: [Language], canReplace: Bool, notice: String? = nil) {
        self.rows = languages.map { Row(language: $0) }
        self.canReplace = canReplace
        self.notice = notice
        super.init()
    }

    // MARK: Internal

    struct Row: Identifiable {
        enum State {
            case loading
            case completed(String)
            case failed(String)
        }

        let language: Language
        var state: State = .loading

        var id: String { language.rawValue }
    }

    @Published var rows: [Row]
    @Published var canReplace: Bool
    @Published var isReplacing = false
    @Published var notice: String?

    var onChoose: ((String) -> ())?
    var onCancel: (() -> ())?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = NSLocalizedString("replacement.preview.title", comment: "")
            window.contentMinSize = NSSize(width: 420, height: 280)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentViewController = NSHostingController(
                rootView: ReplacementPreviewView(controller: self)
                    .environment(\.locale, .init(identifier: I18nHelper.shared.localizeCode))
            )
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func complete(_ language: Language, text: String) {
        update(language, state: .completed(text))
    }

    func fail(_ language: Language, error: Error) {
        update(language, state: .failed(error.localizedDescription))
    }

    func cancelPendingRows() {
        for index in rows.indices {
            if case .loading = rows[index].state {
                rows[index].state = .failed(NSLocalizedString("replacement.preview.cancelled", comment: ""))
            }
        }
    }

    func choose(_ text: String) {
        guard canReplace, !isReplacing else { return }
        isReplacing = true
        onChoose?(text)
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        notice = NSLocalizedString("replacement.preview.copied", comment: "")
    }

    func cancel() {
        let cancel = onCancel
        close()
        cancel?()
    }

    /// Programmatic closure does not call the cancellation callback.
    func close() {
        onCancel = nil
        onChoose = nil
        window?.delegate = nil
        window?.close()
        window?.contentViewController = nil
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        cancel()
    }

    // MARK: Private

    private var window: NSWindow?

    private func update(_ language: Language, state: Row.State) {
        guard let index = rows.firstIndex(where: { $0.language == language }) else { return }
        rows[index].state = state
    }
}

// MARK: - ReplacementPreviewView

private struct ReplacementPreviewView: View {
    @ObservedObject var controller: ReplacementPreviewController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("replacement.preview.instructions")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let notice = controller.notice {
                Text(notice)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(controller.rows) { row in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(row.language.localizedName)
                                .font(.headline)
                            switch row.state {
                            case .loading:
                                HStack {
                                    ProgressView().controlSize(.small)
                                    Text("replacement.preview.translating")
                                        .foregroundStyle(.secondary)
                                }
                            case let .completed(text):
                                Text(text)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                HStack {
                                    Button("replacement.preview.replace") { controller.choose(text) }
                                        .disabled(!controller.canReplace || controller.isReplacing)
                                    Button("replacement.preview.copy") { controller.copy(text) }
                                        .disabled(controller.isReplacing)
                                }
                            case let .failed(message):
                                Text(message)
                                    .foregroundStyle(.red)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            HStack {
                Spacer()
                Button("replacement.preview.cancel") { controller.cancel() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 280)
    }
}
