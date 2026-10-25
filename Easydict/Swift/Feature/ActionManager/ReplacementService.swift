//
//  ReplacementService.swift
//  Easydict
//
//  Copyright © 2026 izual. All rights reserved.
//

import Defaults
import Foundation

/// Resolves replacement requests to the explicitly selected configured service instance.
@MainActor
enum ReplacementService {
    // MARK: Internal

    static var enabledServices: [QueryService] {
        var identifiers = Set<String>()
        return [EZWindowType.fixed, .main, .mini]
            .flatMap { LocalStorage.shared().enabledServiceTypeIDs($0) }
            .filter { identifiers.insert($0).inserted }
            .compactMap { QueryServiceFactory.shared.service(withTypeId: $0) }
    }

    static func supportsTranslation(_ service: QueryService) -> Bool {
        !(service is AIToolService) && service.supportedQueryType().contains(.translation)
    }

    static func supportsPolishing(_ service: QueryService) -> Bool {
        // Doubao uses a translation-only API; summary overrides the shared prompt pipeline.
        service is PolishingService || (
            service is StreamService && !(service is DoubaoService) && !(service is AIToolService)
        )
    }

    static func configuredService(polishing: Bool) throws -> QueryService {
        let identifier = polishing ? Defaults[.replacementPolishingServiceID]
            : Defaults[.replacementTranslationServiceID]
        guard let service = enabledServices.first(where: { $0.serviceTypeWithUniqueIdentifier() == identifier }) else {
            throw QueryError(type: .api, message: String(localized: "replacement.error.service_unavailable"))
        }
        guard polishing ? supportsPolishing(service) : supportsTranslation(service) else {
            throw QueryError(type: .unsupportedQueryType)
        }
        (service as? StreamService)?.usesPolishingPrompt = polishing
        return service
    }

    /// Accumulates complete output before allowing any write to the original input.
    static func completedText(
        _ text: String, from: Language, to: Language, service: QueryService
    ) async throws
        -> String {
        try Task.checkCancellation()
        service.queryType = .translation
        service.queryModel = QueryModel(observesLanguageDefaults: false)
        service.queryModel.userSourceLanguage = from
        service.queryModel.userTargetLanguage = to
        let (handled, result) = try await service.prehandleQueryText(text, from: from, to: to)
        if let error = result.error { throw error }
        try Task.checkCancellation()
        let serviceLabel = description(service)
        logInfo("Replacement request: service=\(serviceLabel), from=\(from.rawValue), to=\(to.rawValue)")

        let finalText: String
        if handled {
            finalText = result.translatedText ?? ""
        } else if let stream = service as? StreamService {
            var output = ""
            for try await chunk in stream.contentStreamTranslate(text, from: from, to: to) {
                try Task.checkCancellation()
                output += chunk
            }
            finalText = stream.getFinalResultText(output)
        } else {
            let translated = try await service.translate(text, from: from, to: to)
            if let error = translated.error { throw error }
            finalText = translated.translatedText ?? ""
        }
        try Task.checkCancellation()
        guard !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReplacementError.emptyResult
        }
        logInfo(
            "Replacement completed: service=\(serviceLabel), to=\(to.rawValue), characters=\(finalText.count)"
        )
        return finalText
    }

    static func error(_ error: Error, from service: QueryService) -> QueryError {
        QueryError(type: .api, message: description(service), errorDataMessage: error.localizedDescription)
    }

    // MARK: Private

    private static func description(_ service: QueryService) -> String {
        if let stream = service as? StreamService {
            return "\(service.name()) [\(service.serviceTypeWithUniqueIdentifier())] (\(stream.model))"
        }
        return "\(service.name()) [\(service.serviceTypeWithUniqueIdentifier())]"
    }
}
