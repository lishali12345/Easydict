//
//  StreamServicePromptTests.swift
//  EasydictTests
//
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation
import Testing

@testable import Easydict

@MainActor
@Suite("Stream Service Original Text Prompts", .tags(.unit))
struct StreamServicePromptTests {
    @Test("Template-looking source text remains literal during custom prompt expansion")
    func sourceTextIsNotExpandedAsTemplate() {
        let service = OpenAIService()
        service.queryModel = QueryModel(observesLanguageDefaults: false)
        service.queryModel.userSourceLanguage = .english
        service.queryModel.userTargetLanguage = .simplifiedChinese
        let text = "  e\u{301} 👑\n${{firstLanguage}} ${{queryFromLanguage}} ${{queryTargetLanguage}} ${{queryText}}\t "
        service.queryModel.inputText = text

        let result = service.replaceCustomPromptWithVariable(
            "${{queryFromLanguage}} -> ${{queryTargetLanguage}}\n<source>${{queryText}}</source>"
        )
        let expected = "\(Language.english.rawValue) -> \(Language.simplifiedChinese.rawValue)\n<source>\(text)</source>"
        #expect(Array(result.utf8) == Array(expected.utf8))
    }

    @Test("Automatic-source translation keeps the complete original text")
    func automaticSourcePromptPreservesText() throws {
        let service = OpenAIService()
        let text = "  👑_ɦαɳƭµ ૨เɱɓα🐒\n// snake_case e\u{301}\t "
        let query = ChatQueryParam(
            text: text,
            sourceLanguage: .auto,
            targetLanguage: .english,
            queryType: .translation,
            enableSystemPrompt: true
        )
        let message = try #require(service.translationMessages(query).last)
        #expect(message.role == .user)
        #expect(message.content.contains("Identify the language"))
        #expect(message.content.contains(Language.english.queryLanguageName))
        #expect(Array(message.content.suffix(text.count + 3).dropLast(3).utf8) == Array(text.utf8))
    }
}
