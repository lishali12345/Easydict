//
//  LanguagePreferences.swift
//  Easydict
//
//  Copyright © 2026 izual. All rights reserved.
//

import Defaults
import Foundation

/// User-visible language choices, separate from provider capabilities and language detection.
@objcMembers
final class LanguagePreferences: NSObject {
    // MARK: Lifecycle

    private override init() {
        super.init()
    }

    // MARK: Internal

    static let didChangeNotificationName = "MEDictEnabledLanguagesDidChange"

    static var configurableLanguages: [Language] {
        Language.allCases.filter { $0 != .auto }
    }

    /// Keeps the current first and second languages selectable until the user changes them.
    static var requiredLanguages: [Language] {
        normalized([Defaults[.firstLanguage], Defaults[.secondLanguage]])
    }

    static var enabledLanguages: [Language] {
        get {
            normalized(Defaults[.enabledLanguages] + requiredLanguages)
        }
        set {
            let languages = normalized(newValue + requiredLanguages)
            Defaults[.enabledLanguages] = languages

            if !languages.contains(Defaults[.queryFromLanguage]) {
                Defaults[.queryFromLanguage] = .auto
            }
            if !languages.contains(Defaults[.queryToLanguage]) {
                Defaults[.queryToLanguage] = .auto
            }
            if !languages.contains(Defaults[.autoShowQueryIconExcludedLanguage]) {
                Defaults[.autoShowQueryIconExcludedLanguage] = Defaults[.firstLanguage]
            }
            NotificationCenter.default.post(
                name: Notification.Name(didChangeNotificationName), object: nil
            )
        }
    }

    /// Preview targets must be enabled and different from the English source language.
    static var replacementTargetLanguages: [Language] {
        get {
            normalized(Defaults[.replacementTargetLanguages]).filter {
                enabledLanguages.contains($0) && $0 != .english
            }
        }
        set {
            Defaults[.replacementTargetLanguages] = normalized(newValue).filter {
                enabledLanguages.contains($0) && $0 != .english
            }
        }
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
