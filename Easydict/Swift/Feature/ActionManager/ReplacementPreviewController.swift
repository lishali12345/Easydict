//
//  ReplacementPreviewController.swift
//  Easydict
//
//  Copyright © 2026 izual. All rights reserved.
//

import AppKit
import SFSafeSymbols
import SwiftUI

// MARK: - ReplacementPreviewLayout

private enum ReplacementPreviewLayout {
    static let width: CGFloat = 480
    static let maximumHeight: CGFloat = 640
    static let padding: CGFloat = 12
    static let spacing: CGFloat = 10
    static let closeSize: CGFloat = 28
    static let actionHeight: CGFloat = 24
    static let screenMargin: CGFloat = 16
    static let chromeHeight = padding * 2 + spacing + closeSize
}

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
    @Published private(set) var viewportHeight: CGFloat = 1

    private(set) var panelWidth = ReplacementPreviewLayout.width

    var onChoose: ((String) -> ())?
    var onCancel: (() -> ())?

    func show() {
        if window == nil {
            let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
            let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
            panelWidth = min(
                ReplacementPreviewLayout.width,
                visibleFrame.width - ReplacementPreviewLayout.screenMargin * 2
            )
            viewportHeight = min(CGFloat(max(rows.count, 1)) * 64, maximumViewportHeight(in: visibleFrame))
            let size = NSSize(width: panelWidth, height: viewportHeight + ReplacementPreviewLayout.chromeHeight)
            let window = ReplacementPreviewPanel(
                contentRect: NSRect(
                    x: visibleFrame.midX - size.width / 2,
                    y: visibleFrame.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                ),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.title = NSLocalizedString("replacement.preview.title", comment: "")
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.isFloatingPanel = true
            window.level = .floating
            window.hidesOnDeactivate = false
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            let hostingController = NSHostingController(
                rootView: ReplacementPreviewView(controller: self)
                    .environment(\.locale, .init(identifier: I18nHelper.shared.localizeCode))
            )
            hostingController.sizingOptions = []
            hostingController.view.frame = NSRect(origin: .zero, size: size)
            self.window = window
            window.contentViewController = hostingController
            window.setContentSize(size)
        }
        ReplacementShortcutManager.shared.setPreviewVisible(true)
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
        guard window?.isKeyWindow == true, !isReplacing else { return }
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
        ReplacementShortcutManager.shared.setPreviewVisible(false)
    }

    func windowWillClose(_ notification: Notification) {
        cancel()
    }

    /// Keep the top edge steady as translations arrive, while leaving the close control outside scrolling.
    func updateContentHeight(_ height: CGFloat) {
        guard height.isFinite, height > 0, let window else { return }
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
        let newHeight = min(ceil(height), maximumViewportHeight(in: visibleFrame))
        guard abs(viewportHeight - newHeight) > 0.5 else { return }
        viewportHeight = newHeight
        var frame = window.frame
        let top = frame.maxY
        frame.size.height = newHeight + ReplacementPreviewLayout.chromeHeight
        frame.origin.y = max(
            visibleFrame.minY + ReplacementPreviewLayout.screenMargin,
            min(top, visibleFrame.maxY - ReplacementPreviewLayout.screenMargin) - frame.height
        )
        window.setFrame(frame, display: true)
    }

    // MARK: Private

    private var window: NSWindow?

    private func maximumViewportHeight(in frame: NSRect) -> CGFloat {
        max(
            1,
            min(
                ReplacementPreviewLayout.maximumHeight,
                frame.height - ReplacementPreviewLayout.screenMargin * 2
            ) - ReplacementPreviewLayout.chromeHeight
        )
    }

    private func update(_ language: Language, state: Row.State) {
        guard let index = rows.firstIndex(where: { $0.language == language }) else { return }
        rows[index].state = state
    }
}

// MARK: - ReplacementPreviewPanel

private final class ReplacementPreviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - ReplacementPreviewContentHeight

private struct ReplacementPreviewContentHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - ReplacementPreviewView

private struct ReplacementPreviewView: View {
    // MARK: Internal

    @ObservedObject var controller: ReplacementPreviewController

    var body: some View {
        VStack(spacing: ReplacementPreviewLayout.spacing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let notice = controller.notice {
                        Text(notice)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(Array(controller.rows.enumerated()), id: \.element.id) { index, row in
                        translationRow(row, index: index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: ReplacementPreviewContentHeight.self, value: proxy.size.height)
                    }
                }
            }
            .frame(height: controller.viewportHeight)
            .onPreferenceChange(ReplacementPreviewContentHeight.self) { controller.updateContentHeight($0) }

            Button {
                controller.cancel()
            } label: {
                Image(systemSymbol: .xmark)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: ReplacementPreviewLayout.closeSize, height: ReplacementPreviewLayout.closeSize)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel(Text("replacement.preview.cancel"))
            .help("replacement.preview.instructions")
        }
        .padding(ReplacementPreviewLayout.padding)
        .frame(width: controller.panelWidth)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .windowBackgroundColor))
        }
    }

    // MARK: Private

    private func translationRow(_ row: ReplacementPreviewController.Row, index: Int) -> some View {
        let actionInset: CGFloat = if case .completed = row.state {
            ReplacementPreviewLayout.actionHeight / 2
        } else {
            0
        }
        return VStack(alignment: .leading, spacing: 0) {
            switch row.state {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("replacement.preview.translating")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            case let .completed(text):
                Text(text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                actionButtons(text, index: index)
            case let .failed(message):
                Text(message)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
            }
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Keep the full action strip in the layout while its lower half extends beyond the card.
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary.opacity(0.5))
                .padding(.bottom, actionInset)
        }
        .overlay(alignment: .topTrailing) {
            Text(verbatim: "\(row.language.flagEmoji) \(row.language.localizedName)")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(nsColor: .windowBackgroundColor), in: Capsule())
                .padding(.trailing, 10)
                .offset(y: -6)
        }
        .padding(.top, 6)
    }

    private func actionButtons(_ text: String, index: Int) -> some View {
        HStack(spacing: 4) {
            Button {
                controller.choose(text)
            } label: {
                HStack(spacing: 6) {
                    Image(systemSymbol: .arrowLeftArrowRight)
                    if index < 9 {
                        Text(verbatim: "⌘\(index + 1)")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: ReplacementPreviewLayout.actionHeight)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(shortcut(for: index, modifiers: .command))
            .accessibilityLabel(Text("replacement.preview.replace"))
            .help("replacement.preview.replace")
            .disabled(!controller.canReplace || controller.isReplacing)
            Button {
                controller.copy(text)
            } label: {
                HStack(spacing: 6) {
                    Image(systemSymbol: .docOnDoc)
                    if index < 9 {
                        Text(verbatim: "⌥\(index + 1)")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: ReplacementPreviewLayout.actionHeight)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(shortcut(for: index, modifiers: .option))
            .accessibilityLabel(Text("replacement.preview.copy"))
            .help("replacement.preview.copy")
            .disabled(controller.isReplacing)
        }
        .padding(.horizontal, 4)
        .background(Color(nsColor: .windowBackgroundColor), in: Capsule())
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 10)
    }

    private func shortcut(for index: Int, modifiers: SwiftUI.EventModifiers) -> KeyboardShortcut? {
        guard index < 9 else { return nil }
        return KeyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: modifiers)
    }
}
