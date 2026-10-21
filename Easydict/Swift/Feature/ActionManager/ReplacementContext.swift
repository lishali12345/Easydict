//
//  ReplacementContext.swift
//  Easydict
//
//  Copyright © 2026 izual. All rights reserved.
//

import AppKit
import AXSwift
import SelectedTextKit

// MARK: - ReplacementContext

/// A verified selection in the original application, independent of the preview window's focus.
@MainActor
struct ReplacementContext {
    // MARK: Lifecycle

    init?(application: NSRunningApplication, text: String) {
        guard let appElement = Application(application),
              let element = try? appElement.focusedUIElement(),
              let fullText = try? element.value(),
              let range = try? element.selectedTextRange(),
              range.location >= 0, range.length > 0,
              range.location <= (fullText as NSString).length,
              range.length <= (fullText as NSString).length - range.location,
              (fullText as NSString).substring(with: NSRange(location: range.location, length: range.length)) == text
        else {
            return nil
        }

        let canSetSelectedText = (try? element.attributeIsSettable(.selectedText)) == true
        guard canSetSelectedText || (try? element.attributeIsSettable(.value)) == true else { return nil }

        self.application = application
        self.element = element
        self.fullText = fullText
        self.selectedRange = range
        self.canSetSelectedText = canSetSelectedText
        // Chrome web editors can advertise AX writes without updating their editor state.
        self.usesPasteMenu = application.bundleIdentifier == "com.google.Chrome"
            && (try? element.role()) == .textArea
        logInfo("Replacement target: app=\(application.bundleIdentifier ?? "unknown"), pasteMenu=\(usesPasteMenu)")
    }

    // MARK: Internal

    /// Restores the original application, then validates again before a single replacement.
    func replace(with text: String, fromPreview: Bool) async throws {
        try Task.checkCancellation()
        guard selectionIsUnchanged else { throw ReplacementError.inputChanged }

        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        guard frontmostPID == application.processIdentifier
            || (fromPreview && frontmostPID == NSRunningApplication.current.processIdentifier)
        else {
            throw ReplacementError.inputChanged
        }

        if frontmostPID != application.processIdentifier {
            guard application.activate(options: .activateIgnoringOtherApps) else {
                throw ReplacementError.inputChanged
            }
            for _ in 0 ..< 10 {
                try await Task.sleep(nanoseconds: 50_000_000)
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier {
                    break
                }
            }
        }

        try Task.checkCancellation()
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier,
              selectionIsUnchanged
        else {
            throw ReplacementError.inputChanged
        }

        let expectedText = (fullText as NSString).replacingCharacters(
            in: NSRange(location: selectedRange.location, length: selectedRange.length),
            with: text
        )
        if usesPasteMenu {
            try await pasteVerifiedText(text, expectedText: expectedText)
            return
        }

        // Keep the direct AX write synchronous with the final validation.
        do {
            if canSetSelectedText {
                try element.setAttribute(.selectedText, value: text)
            } else {
                try element.setAttribute(.value, value: expectedText)
            }
            guard let updatedText = try element.value(), updatedText == expectedText else {
                throw ReplacementError.writeFailed
            }
        } catch {
            throw ReplacementError.writeFailed
        }
    }

    // MARK: Private

    private let application: NSRunningApplication
    private let element: UIElement
    private let fullText: String
    private let selectedRange: CFRange
    private let canSetSelectedText: Bool
    private let usesPasteMenu: Bool

    private var selectionIsUnchanged: Bool {
        guard !application.isTerminated,
              let appElement = Application(application),
              let focusedElement = try? appElement.focusedUIElement(),
              focusedElement == element,
              let currentText = try? element.value(),
              currentText == fullText,
              let currentRange = try? element.selectedTextRange()
        else {
            return false
        }
        return currentRange.location == selectedRange.location && currentRange.length == selectedRange.length
    }

    /// Uses the original app's Paste action only while the captured selection is still intact.
    private func pasteVerifiedText(_ text: String, expectedText: String) async throws {
        guard expectedText != fullText else { return }
        let pasteboard = NSPasteboard.general
        let originalChangeCount = pasteboard.changeCount
        let savedItems = pasteboard.backupItems()
        guard pasteboard.changeCount == originalChangeCount else { throw ReplacementError.writeFailed }

        pasteboard.clearContents()
        var replacementChangeCount = pasteboard.changeCount
        var canRestoreClipboard = true
        defer {
            // Never overwrite a clipboard change made by the user or another operation.
            if canRestoreClipboard, pasteboard.changeCount == replacementChangeCount {
                if savedItems.isEmpty {
                    pasteboard.clearContents()
                } else {
                    pasteboard.restoreItems(savedItems)
                }
            }
        }
        let copied = pasteboard.setString(text, forType: .string)
        replacementChangeCount = pasteboard.changeCount
        guard copied else { throw ReplacementError.writeFailed }

        let pasteItem: UIElement
        do {
            guard let item = try Application(application)?.findMenuItem(.paste),
                  try item.isEnabled() == true
            else { throw ReplacementError.writeFailed }
            pasteItem = item
        } catch {
            throw ReplacementError.writeFailed
        }

        try Task.checkCancellation()
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier,
              selectionIsUnchanged,
              pasteboard.changeCount == replacementChangeCount
        else { throw ReplacementError.inputChanged }

        // No suspension between validation and this single, application-scoped action.
        canRestoreClipboard = false
        do {
            try pasteItem.performAction(.press)
        } catch {
            // An AX error does not prove the application has not already queued Paste.
            logInfo("Replacement Paste action reported an error; waiting for writeback verification")
        }

        // Once Paste is dispatched, cancellation must not restore the clipboard before Chrome consumes it.
        // This bounded, unstructured task finishes readback even if the replacement request is cancelled.
        let completed = await Task { @MainActor in
            for _ in 0 ..< 20 {
                if (try? element.value()) == expectedText { return true }
                try? await Task.sleep(nanoseconds: 25_000_000)
            }
            return false
        }.value
        guard completed else { throw ReplacementError.writeFailed }
        canRestoreClipboard = true
        logInfo("Replacement writeback verified: pasteMenu=true")
        try Task.checkCancellation()
    }
}

// MARK: - ReplacementError

enum ReplacementError: LocalizedError {
    case inputChanged
    case writeFailed
    case emptyResult

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case .inputChanged:
            NSLocalizedString("replacement.error.input_changed", comment: "")
        case .writeFailed:
            NSLocalizedString("replacement.error.write_failed", comment: "")
        case .emptyResult:
            NSLocalizedString("replacement.error.empty_result", comment: "")
        }
    }
}
