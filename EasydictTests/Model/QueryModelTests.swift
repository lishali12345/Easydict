//
//  QueryModelTests.swift
//  EasydictTests
//
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation
import Testing

@testable import Easydict

@MainActor
@Suite("Query Model Original Text", .tags(.unit))
struct QueryModelTests {
    @Test("Query text preserves every original byte", arguments: [
        "  hello world\t ",
        "first line\r\nsecond line\n\tthird line\n",
        "👑_ɦαɳƭµ ૨เɱɓα🐒",
        "e\u{301} é 👩🏽‍💻 🏳️‍🌈",
        "// a_code_comment\n/* another comment */",
        "snake_case camelCase PascalCase",
        "\u{200B}before\u{FFFC}after\u{200D}",
        "${{queryText}} ${{firstLanguage}} ${{queryFromLanguage}}",
    ])
    func preservesOriginalText(text: String) {
        let model = QueryModel(observesLanguageDefaults: false)
        model.inputText = text

        // Swift String equality normalizes canonically equivalent Unicode; bytes must also match.
        #expect(Array(model.inputText.utf8) == Array(text.utf8))
        #expect(Array(model.queryText.utf8) == Array(text.utf8))
    }

    @Test("Canonically equivalent edits retain the new Unicode representation")
    func updatesCanonicallyEquivalentText() {
        let model = QueryModel(observesLanguageDefaults: false)
        for text in ["é", "e\u{301}", "é"] {
            model.needDetectLanguage = false
            model.inputText = text
            #expect(Array(model.inputText.utf8) == Array(text.utf8))
            #expect(Array(model.queryText.utf8) == Array(text.utf8))
            #expect(model.needDetectLanguage)
        }
    }

    @Test("Copying a query preserves the original text and isolates subsequent edits")
    func copyPreservesOriginalText() throws {
        let text = "  // snake_case\r\n👑_ɦαɳƭµ ૨เɱɓα🐒 e\u{301}\t "
        let original = QueryModel(observesLanguageDefaults: false)
        original.inputText = text
        let copy = try #require(original.copy() as? QueryModel)

        #expect(Array(copy.inputText.utf8) == Array(text.utf8))
        #expect(Array(copy.queryText.utf8) == Array(text.utf8))
        copy.inputText = "edited"
        #expect(Array(original.queryText.utf8) == Array(text.utf8))
    }
}
