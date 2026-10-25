//
//  LanguagePreferences.swift
//  Easydict
//
//  Copyright © 2026 izual. All rights reserved.
//

import Defaults
import Foundation

/// Ordered replacement targets, separate from query languages and provider capabilities.
@objcMembers
final class LanguagePreferences: NSObject {
    // MARK: Lifecycle

    private override init() {
        super.init()
    }

    // MARK: Internal

    static var configurableLanguages: [Language] {
        Language.allCases.filter { $0 != .auto }
    }

    /// Ordered replacement targets are independent of query-window language preferences.
    static var replacementTargetLanguages: [Language] {
        get { normalized(Defaults[.replacementTargetLanguages]) }
        set { Defaults[.replacementTargetLanguages] = normalized(newValue) }
    }

    // MARK: Private

    private static func normalized(_ languages: [Language]) -> [Language] {
        var result: [Language] = []
        for language in languages where configurableLanguages.contains(language) && !result.contains(language) {
            result.append(language)
        }
        return result
    }
}
