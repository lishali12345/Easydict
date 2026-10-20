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
    }

    // MARK: Internal

    /// Restores only the original application, then validates again before a single AX write.
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

        // Keep this synchronous with the final validation: no task suspension or simulated paste.
        let expectedText = (fullText as NSString).replacingCharacters(
            in: NSRange(location: selectedRange.location, length: selectedRange.length),
            with: text
        )
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
