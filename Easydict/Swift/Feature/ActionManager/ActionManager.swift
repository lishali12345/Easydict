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

    /// Translate Chinese directly to English, or preview configured translations for English.
    func translateAndReplace() async {
        await startAction(.translate)
    }

    /// Polish in the detected source language and replace only after the result is complete.
    func polishAndReplace() async {
        await startAction(.polish)
    }

    // MARK: Private

    private enum ProcessingType {
        case translate
        case polish
    }

    private let systemUtility = SystemUtility.shared
    private var operationID: UUID?
    private var operationTask: Task<(), Never>?
    private var services: [StreamService] = []
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
        services.forEach { $0.cancelStream() }
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
        do {
            let model = try await DetectManager().detectText(queryText)
            guard isCurrent(identifier) else { return }
            let source = model.detectedLanguage
            guard source != .auto else {
                showNotice(NSLocalizedString("replacement.error.detect_language", comment: ""), identifier: identifier)
                return
            }

            if type == .translate, source == .english {
                await previewTranslations(queryText, context: context, identifier: identifier)
            } else {
                let target = type == .polish ? source
                    : (source == .simplifiedChinese ? .english : model.queryTargetLanguage)
                let service: StreamService = type == .polish ? PolishingService() : OpenAIService()
                services.append(service)
                do {
                    let result = try await completedText(queryText, from: source, to: target, service: service)
                    guard isCurrent(identifier) else { return }
                    await replaceDirectly(result, target: target, context: context, identifier: identifier)
                } catch {
                    guard isCurrent(identifier) else { return }
                    let preview = makePreview(languages: [target], context: context, identifier: identifier)
                    preview.fail(target, error: serviceError(error, from: service))
                    preview.show()
                }
            }
        } catch {
            guard isCurrent(identifier) else { return }
            showNotice(
                NSLocalizedString("replacement.error.detect_language", comment: ""),
                identifier: identifier
            )
        }
    }

    private func previewTranslations(_ text: String, context: ReplacementContext?, identifier: UUID) async {
        let targets = LanguagePreferences.replacementTargetLanguages
        let preview = makePreview(languages: targets, context: context, identifier: identifier)
        if targets.isEmpty {
            preview.notice = NSLocalizedString("replacement.preview.no_targets", comment: "")
        }
        preview.show()

        await withTaskGroup(of: Void.self) { group in
            for target in targets {
                let service = OpenAIService()
                services.append(service)
                group.addTask { @MainActor in
                    do {
                        let result = try await self.completedText(text, from: .english, to: target, service: service)
                        guard self.isCurrent(identifier) else { return }
                        preview.complete(target, text: result)
                    } catch {
                        guard self.isCurrent(identifier) else { return }
                        preview.fail(target, error: self.serviceError(error, from: service))
                    }
                }
            }
        }
    }

    /// Accumulates the complete stream so a failed request never leaves partial text in another app.
    private func completedText(
        _ text: String,
        from: Language,
        to: Language,
        service: StreamService
    ) async throws
        -> String {
        try Task.checkCancellation()
        service.queryType = .translation
        let (prehandled, result) = try await service.prehandleQueryText(text, from: from, to: to)
        if prehandled, let error = result.error { throw error }
        try Task.checkCancellation()

        // Custom prompt variables must use this request's languages, not the query window defaults.
        service.queryModel.userSourceLanguage = from
        service.queryModel.userTargetLanguage = to
        logInfo(
            "Replacement request: service=\(service.serviceType().rawValue), model=\(service.model), "
                + "from=\(from.rawValue), to=\(to.rawValue)"
        )

        var output = ""
        for try await chunk in service.contentStreamTranslate(text, from: from, to: to) {
            try Task.checkCancellation()
            output += chunk
        }
        try Task.checkCancellation()
        let finalText = service.getFinalResultText(output)
        guard !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReplacementError.emptyResult
        }
        logInfo(
            "Replacement completed: service=\(service.serviceType().rawValue), model=\(service.model), "
                + "to=\(to.rawValue), characters=\(finalText.count)"
        )
        return finalText
    }

    private func serviceError(_ error: Error, from service: StreamService) -> QueryError {
        QueryError(
            type: .api,
            message: "\(service.name()) (\(service.model))",
            errorDataMessage: error.localizedDescription
        )
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
            services.forEach { $0.cancelStream() }
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
