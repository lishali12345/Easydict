//
//  ActionManager.swift
//  Easydict
//
//  Created by tisfeng on 2025/8/29.
//  Copyright © 2025 izual. All rights reserved.
//

import AppKit
import AXSwift
import Defaults
import SelectedTextKit

// MARK: - ActionManager

/// Coordinates replacement requests and keeps asynchronous results tied to their original selection.
@MainActor
@objc(EZActionManager)
class ActionManager: NSObject {
    // MARK: Internal

    @objc static let shared = ActionManager()

    /// Preview the configured target languages for any detected source language.
    func translateAndReplace() async {
        await startAction(.translate)
    }

    /// Translate directly to the language bound to an instant replacement shortcut.
    func translateAndReplace(to target: Language) async {
        await startAction(.instant(target))
    }

    /// Polish in the detected source language and replace only after the result is complete.
    func polishAndReplace() async {
        await startAction(.polish)
    }

    // MARK: Private

    private enum ProcessingType {
        case translate
        case instant(Language)
        case polish
    }

    private let systemUtility = SystemUtility.shared
    private var operationID: UUID?
    private var operationTask: Task<(), Never>?
    private var services: [QueryService] = []
    private var previewController: ReplacementPreviewController?

    private func startAction(_ type: ProcessingType) async {
        cancelCurrentAction()
        let identifier = UUID()
        operationID = identifier
        let task = Task { await executeAction(type, identifier: identifier) }
        operationTask = task
        await task.value
    }

    private func cancelCurrentAction() {
        operationID = nil
        operationTask?.cancel()
        operationTask = nil
        services.forEach {
            $0.queryModel.stopAllService()
            $0.cancelStream()
        }
        services.removeAll()
        previewController?.close()
        previewController = nil
    }

    private func isCurrent(_ identifier: UUID) -> Bool {
        operationID == identifier && !Task.isCancelled
    }

    private func executeAction(_ type: ProcessingType, identifier: UUID) async {
        guard AXIsProcessTrusted() else {
            showNotice(NSLocalizedString("replacement.error.accessibility", comment: ""), identifier: identifier)
            return
        }
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let application = frontmostApplication?.processIdentifier == NSRunningApplication.current.processIdentifier
            ? NSWorkspace.shared.menuBarOwningApplication : frontmostApplication
        guard let application,
              application.processIdentifier != NSRunningApplication.current.processIdentifier
        else {
            showNotice(NSLocalizedString("replacement.error.no_selection", comment: ""), identifier: identifier)
            return
        }

        let originalElement = try? Application(application)?.focusedUIElement()
        let originalText = try? originalElement?.value()
        let originalRange = try? originalElement?.selectedTextRange()
        let enableSelectAll = Defaults[.autoSelectAllTextFieldText]
        if frontmostApplication?.processIdentifier != application.processIdentifier {
            guard application.activate(options: .activateIgnoringOtherApps) else {
                showNotice(ReplacementError.inputChanged.localizedDescription, identifier: identifier)
                return
            }
            for _ in 0 ..< 10 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                if !isCurrent(identifier) { return }
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier { break }
            }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier else {
                showNotice(ReplacementError.inputChanged.localizedDescription, identifier: identifier)
                return
            }
        }
        let elementInfo = await systemUtility.focusedElementInfo(
            enableSelectAll: enableSelectAll
        )
        guard isCurrent(identifier) else { return }
        var capturedText = elementInfo.focusedText
        if capturedText?.isEmpty ?? true {
            capturedText = await systemUtility.getSelectedText()
        }
        guard isCurrent(identifier) else { return }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier else {
            showNotice(ReplacementError.inputChanged.localizedDescription, identifier: identifier)
            return
        }

        let element = try? Application(application)?.focusedUIElement()
        if let originalElement {
            guard element == originalElement, (try? element?.value()) == originalText else {
                showNotice(ReplacementError.inputChanged.localizedDescription, identifier: identifier)
                return
            }
        }
        if let originalRange {
            let expectedRange = enableSelectAll && originalRange.length == 0
                ? CFRange(location: 0, length: (originalText as NSString?)?.length ?? 0) : originalRange
            guard let range = try? element?.selectedTextRange(),
                  range.location == expectedRange.location, range.length == expectedRange.length
            else {
                showNotice(ReplacementError.inputChanged.localizedDescription, identifier: identifier)
                return
            }
        }
        // Prefer the untrimmed AX selection so validation and replacement refer to the exact UTF-16 range.
        let selectedText: String? = try? element?.attribute(.selectedText)
        let queryText = selectedText?.isEmpty == false ? selectedText : capturedText
        guard let queryText, !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showNotice(NSLocalizedString("replacement.error.no_selection", comment: ""), identifier: identifier)
            return
        }

        let context = originalElement != nil && originalRange != nil
            ? ReplacementContext(application: application, text: queryText) : nil
        logInfo(
            "Replacement context: app=\(application.bundleIdentifier ?? "unknown"), "
                + "element=\(originalElement != nil), range=\(originalRange != nil), verified=\(context != nil)"
        )
        do {
            let model = try await DetectManager().detectText(queryText)
            guard isCurrent(identifier) else { return }
            let source = model.detectedLanguage
            guard source != .auto else {
                showNotice(NSLocalizedString("replacement.error.detect_language", comment: ""), identifier: identifier)
                return
            }

            switch type {
            case .translate:
                await previewTranslations(queryText, from: source, context: context, identifier: identifier)
            case let .instant(target):
                await processDirectly(
                    queryText, from: source, destination: (target, false), context: context, identifier: identifier
                )
            case .polish:
                await processDirectly(
                    queryText, from: source, destination: (source, true), context: context, identifier: identifier
                )
            }
        } catch {
            guard isCurrent(identifier) else { return }
            showNotice(
                NSLocalizedString("replacement.error.detect_language", comment: ""),
                identifier: identifier
            )
        }
    }

    private func processDirectly(
        _ text: String, from: Language, destination: (target: Language, polishing: Bool),
        context: ReplacementContext?, identifier: UUID
    ) async {
        let (target, polishing) = destination
        do {
            let service = try ReplacementService.configuredService(polishing: polishing)
            services.append(service)
            do {
                let result = try await ReplacementService.completedText(text, from: from, to: target, service: service)
                guard isCurrent(identifier) else { return }
                await replaceDirectly(result, target: target, context: context, identifier: identifier)
            } catch {
                throw ReplacementService.error(error, from: service)
            }
        } catch {
            guard isCurrent(identifier) else { return }
            let preview = makePreview(languages: [target], context: context, identifier: identifier)
            preview.fail(target, error: error)
            preview.show()
        }
    }

    private func previewTranslations(
        _ text: String, from: Language, context: ReplacementContext?, identifier: UUID
    ) async {
        let targets = LanguagePreferences.replacementTargetLanguages
        let preview = makePreview(languages: targets, context: context, identifier: identifier)
        if targets.isEmpty {
            preview.notice = NSLocalizedString("replacement.preview.no_targets", comment: "")
        }
        preview.show()

        await withTaskGroup(of: Void.self) { group in
            for target in targets {
                do {
                    let service = try ReplacementService.configuredService(polishing: false)
                    services.append(service)
                    group.addTask { @MainActor in
                        do {
                            let result = try await ReplacementService.completedText(
                                text, from: from, to: target, service: service
                            )
                            guard self.isCurrent(identifier) else { return }
                            preview.complete(target, text: result)
                        } catch {
                            guard self.isCurrent(identifier) else { return }
                            preview.fail(target, error: ReplacementService.error(error, from: service))
                        }
                    }
                } catch {
                    preview.fail(target, error: error)
                }
            }
        }
    }

    private func replaceDirectly(
        _ text: String, target: Language, context: ReplacementContext?, identifier: UUID
    ) async {
        var failure: Error?
        if let context {
            do {
                try await context.replace(with: text, fromPreview: false)
                guard isCurrent(identifier) else { return }
                cancelCurrentAction()
                return
            } catch {
                failure = error
            }
        }
        guard isCurrent(identifier) else { return }
        let preview = makePreview(languages: [target], context: nil, identifier: identifier)
        preview.complete(target, text: text)
        if let failure { preview.notice = failure.localizedDescription }
        preview.show()
    }

    private func makePreview(
        languages: [Language], context: ReplacementContext?, identifier: UUID
    )
        -> ReplacementPreviewController {
        let preview = ReplacementPreviewController(
            languages: languages,
            canReplace: context != nil,
            notice: context == nil ? NSLocalizedString("replacement.preview.copy_only", comment: "") : nil
        )
        preview.onCancel = { [weak self] in
            guard self?.operationID == identifier else { return }
            self?.cancelCurrentAction()
        }
        preview.onChoose = { [weak self, weak preview] text in
            guard let self, let preview, let context, operationID == identifier else { return }
            // A completed row can be selected while the remaining translation requests are running.
            operationTask?.cancel()
            services.forEach {
                $0.queryModel.stopAllService()
                $0.cancelStream()
            }
            preview.cancelPendingRows()
            operationTask = Task {
                do {
                    try await context.replace(with: text, fromPreview: true)
                    guard self.isCurrent(identifier) else { return }
                    self.cancelCurrentAction()
                } catch {
                    guard self.isCurrent(identifier) else { return }
                    preview.canReplace = false
                    preview.isReplacing = false
                    preview.notice = error.localizedDescription
                    preview.show()
                }
            }
        }
        previewController = preview
        return preview
    }

    private func showNotice(_ message: String, identifier: UUID) {
        guard isCurrent(identifier) else { return }
        let preview = makePreview(languages: [], context: nil, identifier: identifier)
        preview.notice = message
        preview.show()
    }
}
