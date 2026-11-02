//
//  AppleLanguageDetector.swift
//  Easydict
//
//  Created by tisfeng on 2025/6/22.
//  Copyright © 2025 izual. All rights reserved.
//

import Foundation
import NaturalLanguage

// MARK: - AppleLanguageDetector

/// Advanced language detection using Apple's NaturalLanguage framework with intelligent corrections
///
/// Addresses common issues with raw Apple detection, especially for short text and mixed content.
/// Features smart post-processing, Chinese type intelligence, and user preference integration.
///
/// **Key Features:**
/// - Weighted language hints with user preference boost
/// - Hierarchical post-processing: Chinese/English verification → Mixed content → Short text corrections
/// - Accurate Chinese simplified/traditional detection
/// - Mixed script analysis without rewriting the input
/// - User preferred language fallback for ambiguous cases
///
/// **Usage:**
/// ```swift
/// // Basic usage without debug logs
/// let detector = AppleLanguageDetector()
/// let language = detector.detectLanguage(text: "apple")  // Returns .english instead of .turkish
/// let chinese = detector.detectLanguage(text: "很棒")    // Returns .simplifiedChinese accurately
///
/// // With debug logging enabled for debugging and development
/// let debugDetector = AppleLanguageDetector(enableDebugLog: true)
/// let result = debugDetector.detectLanguage(text: "Hello world")  // Prints detailed logs
///
/// // Mixed content handling
/// let mixed1 = detector.detectLanguage(text: "Hello world with one 中文 word")  // Returns .english
/// let mixed2 = detector.detectLanguage(text: "apple苹果")  // Returns .simplifiedChinese
/// ```
///
/// **Performance Characteristics:**
/// - Minimal overhead over raw Apple detection (~1-2ms additional processing)
/// - Simplified post-processing pipeline for better maintainability
/// - Optimized for both short and long text scenarios
/// - Optional debug logging with no performance impact when disabled
public class AppleLanguageDetector: NSObject {
    // MARK: Lifecycle

    /// Initialize language detector with optional debug logging and classical Chinese detection
    ///
    /// - Parameters:
    ///   - enableDebugLog: Whether to enable debug logging output (default: false)
    ///   - enableClassicalChineseDetection: Whether to enable classical Chinese detection (default: true)
    public init(enableDebugLog: Bool = false, enableClassicalChineseDetection: Bool = true) {
        self.isDebugLogEnabled = enableDebugLog
        self.isClassicalChineseDetectionEnabled = enableClassicalChineseDetection
        super.init()
    }

    // MARK: Public

    /// Controls whether debug logging is enabled
    public let isDebugLogEnabled: Bool
    /// Controls whether classical Chinese detection is enabled
    public let isClassicalChineseDetectionEnabled: Bool

    /// Records Chinese character statistics when English is detected and user prefers Chinese
    public private(set) var chineseCharacterCount: Int = 0
    public private(set) var simplifiedCharacterCount: Int = 0
    public private(set) var traditionalCharacterCount: Int = 0
    public private(set) var chineseCharacterRatio: Double = 0.0

    public private(set) var isAnalyzed: Bool = false
    public private(set) var englishCharacterCount: Int = 0
    public private(set) var englishCharacterRatio: Double = 0.0
    public private(set) var hasMixedScripts: Bool = false

    /// Raw language probabilities from Apple's NaturalLanguage framework
    ///
    /// - Note: These probabilities may be an empty dictionary for certain edge cases
    /// such as numeric-only text ("729") or unrecognizable input.
    public private(set) var rawProbabilities: [NLLanguage: Double] = [:]

    /// Adjusted language probabilities after applying user preference weights
    public private(set) var adjustedProbabilities: [NLLanguage: Double] = [:]

    /// Detect the most likely language of the provided text
    ///
    /// Primary interface for language detection with intelligent corrections
    /// for common misdetection cases and user preference consideration.
    ///
    /// - Parameter text: Text to analyze for language detection
    /// - Returns: Most likely Language enum value (.auto for empty text)
    public func detectLanguage(text: String) -> Language {
        // Reset analysis state for each detection
        resetAnalysis()
        return detectLanguageInternal(text: text)
    }

    /// Get detailed language detection probabilities for analysis and debugging
    ///
    /// Returns probability distribution from Apple's language detection system.
    /// Useful for debugging detection issues and analyzing confidence levels.
    ///
    /// - Parameter text: Text to analyze for language probabilities
    /// - Returns: Dictionary mapping BCP-47 language codes to probability values (0.0-1.0)
    public func detectLanguageDict(text: String) -> [NLLanguage: Double] {
        let startTime = CFAbsoluteTimeGetCurrent()

        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = languageMapper.recognizedLanguages
        recognizer.languageHints = languageMapper.customLanguageHints
        recognizer.processString(text)

        let probabilities = recognizer.languageHypotheses(withMaximum: 5)
        let dominantLanguage = recognizer.dominantLanguage

        if isDebugLogEnabled {
            print("Language probabilities: \(probabilities.prettyPrinted)\n")
            print("Dominant language: \(dominantLanguage?.rawValue ?? "nil")")
            print("Detection cost time: \(startTime.elapsedTimeString)")
        }

        return probabilities
    }

    /// Reset all analysis statistics
    public func resetAnalysis() {
        chineseCharacterCount = 0
        simplifiedCharacterCount = 0
        traditionalCharacterCount = 0
        chineseCharacterRatio = 0.0
        englishCharacterCount = 0
        englishCharacterRatio = 0.0
        hasMixedScripts = false
        isAnalyzed = false
        chineseGenreAnalyzer = nil

        rawProbabilities = [:]
        adjustedProbabilities = [:]
    }

    public func getTextAnalysis() -> TextAnalysis? {
        chineseGenreAnalyzer?.analysis
    }

    // MARK: Private

    /// Shared language mapper for converting between Apple NLLanguage and Easydict Language enums
    private let languageMapper = AppleLanguageMapper.shared

    /// Chinese text detection utility for classical Chinese analysis
    private var chineseGenreAnalyzer: ChineseGenreAnalyzer?

    /// Detect the original text once, then apply non-recursive result corrections.
    ///
    ///
    /// - Parameters:
    ///   - text: Text to analyze for language detection
    /// - Returns: Detected Language enum value (.auto for empty text)
    private func detectLanguageInternal(text: String) -> Language {
        // Handle empty or whitespace-only text
        if text.isEmpty || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .auto
        }

        guard text.contains(where: { $0.isLetter }) else { return .auto }

        rawProbabilities = detectLanguageDict(text: text)

        // Handle empty results (e.g., numeric-only text like "729")
        guard !rawProbabilities.isEmpty else {
            return .auto
        }

        // Apply user preferred language weight correction
        adjustedProbabilities = applyUserPreferredLanguageWeights(
            to: rawProbabilities
        )

        // Find the language with highest probability after user preference adjustment
        let sortedLanguages = adjustedProbabilities.sorted {
            $0.value > $1.value
        }

        guard let mostConfident = sortedLanguages.first else {
            return .auto
        }

        let topConfidence = mostConfident.value
        let nlLanguage = mostConfident.key
        var detectedLanguage = languageMapper.languageEnum(from: nlLanguage)

        detectedLanguage = applyPostProcessingCorrections(
            detectedLanguage: detectedLanguage,
            confidence: topConfidence,
            text: text,
            allProbabilities: adjustedProbabilities
        )

        if isDebugLogEnabled {
            print("Final detected text: \(text.prefix200)")
            print(
                "Detected language: \(detectedLanguage) (\(String(format: "%.3f", topConfidence)))"
            )
        }

        return detectedLanguage
    }

    /// Apply user preferred language weight correction to detected probabilities
    ///
    /// Only affects languages that appear in detection results, preventing artificial
    /// promotion of undetected languages. Preferred languages get +0.1 to +0.4 boost.
    ///
    /// - Parameter languageProbabilities: Original detection probabilities from Apple NL
    /// - Returns: Adjusted probabilities with user preference weights applied
    private func applyUserPreferredLanguageWeights(
        to languageProbabilities: [NLLanguage: Double]
    )
        -> [NLLanguage: Double] {
        var adjustedProbabilities = languageProbabilities
        let preferredLanguages = EZLanguageManager.shared().preferredLanguages

        // Apply user preferred language weights
        for (index, preferredLanguage) in preferredLanguages.enumerated() {
            // Convert to Apple NLLanguage
            guard let nlLanguage = languageMapper.appleLanguagesDictionary[preferredLanguage],
                  let originalProbability = languageProbabilities[nlLanguage]
            else {
                continue // Only boost languages that were actually detected
            }

            // Calculate weight boost based on preference position
            let maxWeight = 0.4
            let step = 0.1
            var weightBoost = maxWeight - Double(index) * step
            if weightBoost < 0.1 {
                weightBoost = 0.1
            }

            // Additional boost for English based on user's first language
            if preferredLanguage == .english {
                let isChineseFirst = EZLanguageManager.shared().isUserChineseFirstLanguage()
                weightBoost += isChineseFirst ? 0.1 : 0.2
            }

            // Apply the weight boost
            let newProbability = originalProbability + weightBoost
            adjustedProbabilities[nlLanguage] = newProbability
        }

        // Add English boost if not in user preferences (widely used language)
        if !preferredLanguages.contains(.english),
           let englishProbability = languageProbabilities[.english] {
            let englishBoost = 0.2
            let newProbability = englishProbability + englishBoost
            adjustedProbabilities[.english] = newProbability
        }

        if isDebugLogEnabled {
            print("User preferred languages: \(preferredLanguages.prettyPrinted)")
            print("Adjusted probabilities: \(adjustedProbabilities.prettyPrinted)")
        }

        return adjustedProbabilities
    }

    /// Apply intelligent post-processing corrections for common misdetection cases
    ///
    /// Three-tier priority system for corrections:
    /// 1. Chinese type verification (simplified vs traditional)
    /// 2. Mixed content detection and analysis
    /// 3. Short text and obvious misdetection corrections
    ///
    /// - Parameters:
    ///   - detectedLanguage: Language detected by ML system
    ///   - confidence: Detection confidence score (0.0-1.0)
    ///   - text: Original input text
    ///   - allProbabilities: All language probabilities from detection
    /// - Returns: Corrected language after all post-processing steps
    private func applyPostProcessingCorrections(
        detectedLanguage: Language,
        confidence: Double,
        text: String,
        allProbabilities: [NLLanguage: Double]
    )
        -> Language {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Early return for edge cases
        if cleanText.isEmpty {
            return .auto
        }

        // Priority 1: Handle detected Chinese with intelligent verification
        if let chineseLanguageType = determineChineseType(
            for: cleanText,
            detectedLanguage: detectedLanguage
        ) {
            return chineseLanguageType
        }

        // Priority 2: Handle common misdetections with mixed content
        if let correctedLanguage = handleMixedContent(
            detectedLanguage: detectedLanguage,
            text: cleanText
        ) {
            return correctedLanguage
        }

        // Priority 3: Handle obviously wrong detections for short text
        if let correctedLanguage = handleShortTextCorrections(
            detectedLanguage: detectedLanguage,
            text: cleanText,
            confidence: confidence,
            allProbabilities: allProbabilities
        ) {
            return correctedLanguage
        }

        // Default: trust the original detection
        return detectedLanguage
    }

    /// Resolve mixed scripts using only statistics and probabilities from the original text.
    /// Ambiguous content remains automatic instead of re-detecting a filtered string.
    private func handleMixedContent(
        detectedLanguage: Language,
        text: String
    )
        -> Language? {
        analyzeTextCharacterComposition(for: text)
        guard hasMixedScripts, detectedLanguage == .english else { return nil }

        let otherLetters = text.filter { $0.isLetter && !String($0).isEnglishAlphabet }
        guard !otherLetters.isEmpty, text.englishWordCount <= otherLetters.count else { return .english }

        // Script analysis is local only; the recognizer always receives the original text.
        if otherLetters.allSatisfy({ String($0).isChineseTextByRegex }) {
            return determineChineseType(for: text, detectedLanguage: .simplifiedChinese)
        }
        if otherLetters.wholeMatch(of: /[\p{Han}\p{Hiragana}\p{Katakana}]+/) != nil {
            return .japanese
        }
        if otherLetters.wholeMatch(of: /[\p{Han}\p{Hangul}]+/) != nil {
            return .korean
        }

        // Preference weights can promote English over the recognizer's original leading candidate.
        if let candidate = rawProbabilities.max(by: { $0.value < $1.value }),
           candidate.key != .english {
            let language = languageMapper.languageEnum(from: candidate.key)
            return determineChineseType(for: text, detectedLanguage: language) ?? language
        }
        return .auto
    }

    /// Determine Chinese type (simplified,traditional, or classical)
    private func determineChineseType(
        for text: String,
        detectedLanguage: Language
    )
        -> Language? {
        // This function is only used for Chinese text detection
        if !detectedLanguage.isChinese {
            return nil
        }

        if isClassicalChineseDetectionEnabled, MyConfiguration.shared.beta {
            // Initialize ChineseDetection if not already created
            if chineseGenreAnalyzer == nil {
                chineseGenreAnalyzer = ChineseGenreAnalyzer(text: text)
            }

            // Use ChineseGenreAnalyzer to analyze if it's classical Chinese
            let analysis = chineseGenreAnalyzer!.detect()
            if analysis.genre.isClassical {
                return .classicalChinese
            }
        }

        // Record Chinese character statistics if conditions are met
        analyzeTextCharacterComposition(for: text, detectedLanguage: detectedLanguage)

        if isSimplifiedChinese() {
            return .simplifiedChinese
        } else {
            return .traditionalChinese
        }
    }

    private func isSimplifiedChinese() -> Bool {
        let simplifiedRatio = Double(simplifiedCharacterCount) / Double(chineseCharacterCount)
        return simplifiedRatio >= 0.9
    }

    /// Handle corrections for short text and obvious misdetections
    ///
    /// Applies conservative corrections for edge cases:
    /// - Numeric-heavy text → Undetermined
    /// - Short low-confidence Latin text → English (if probability supports it)
    /// - Very short text → User preferred language or English fallback
    ///
    /// - Parameters:
    ///   - detectedLanguage: Language detected by ML system
    ///   - text: Input text to analyze
    ///   - confidence: Detection confidence score
    ///   - allProbabilities: All language probabilities for fallback analysis
    /// - Returns: Corrected language if applicable, nil to trust original detection
    private func handleShortTextCorrections(
        detectedLanguage: Language,
        text: String,
        confidence: Double,
        allProbabilities: [NLLanguage: Double]
    )
        -> Language? {
        // Handle numeric-heavy text
        if text.isNumericHeavy {
            return .auto
        }

        // Handle short text with low confidence
        if confidence < 0.5, text.count <= 10, text.isLatinText {
            if let englishProb = allProbabilities[.english],
               englishProb > 0.1 {
                return .english
            }
        }

        // Handle very short text conservatively
        if text.count <= 3 {
            let preferredLanguages = EZLanguageManager.shared().preferredLanguages
            if preferredLanguages.contains(detectedLanguage), confidence > 0.3 {
                return detectedLanguage
            }

            if text.isLatinText {
                return .english
            }
        }

        return nil
    }

    /// Comprehensive text character analysis with script detection and Chinese statistics
    ///
    /// Universal function for analyzing character composition including mixed scripts detection.
    /// Replaces both hasMixedScripts checking and Chinese character statistics in one pass.
    /// Updates internal properties when conditions are met. Only runs once per instance.
    ///
    /// - Parameters:
    ///   - text: Text to analyze for character composition
    ///   - detectedLanguage: Current detected language (optional condition check)
    private func analyzeTextCharacterComposition(
        for text: String,
        detectedLanguage: Language? = nil
    ) {
        // Only analyze once per detction call
        guard !isAnalyzed else { return }

        let totalCharacters = text.count
        guard totalCharacters > 0 else {
            isAnalyzed = true
            return
        }

        // Single pass character analysis
        var chineseChars: [Character] = []
        var hasLatin = false
        var hasChinese = false
        var hasOther = false

        for char in text {
            let charString = String(char)

            if charString.isChineseTextByRegex {
                chineseChars.append(char)
                hasChinese = true
            } else if charString.isEnglishAlphabet {
                englishCharacterCount += 1
                hasLatin = true
            } else if charString.isLatinAlphabet {
                hasLatin = true
            } else if char.isLetter {
                hasOther = true
            }
        }

        let chineseCount = chineseChars.count
        chineseCharacterRatio = Double(chineseCount) / Double(totalCharacters)
        englishCharacterRatio = Double(englishCharacterCount) / Double(totalCharacters)

        // Mixed scripts detection
        let scriptCount = [hasLatin, hasChinese, hasOther].filter { $0 }.count
        hasMixedScripts = scriptCount >= 2

        chineseCharacterCount = chineseCount

        // Count traditional characters (those that change when converted to simplified)
        traditionalCharacterCount =
            chineseChars.filter {
                String($0) != String($0).toSimplifiedChinese()
            }.count

        // Calculate simplified character count
        simplifiedCharacterCount = chineseCharacterCount - traditionalCharacterCount

        // Log the statistics for debugging
        if isDebugLogEnabled {
            print(
                "Chinese character stats - Total: \(chineseCharacterCount), Simplified: \(simplifiedCharacterCount), Traditional: \(traditionalCharacterCount)"
            )
            print(
                "Chinese character ratio: \(String(format: "%.3f", chineseCharacterRatio)) (\(String(format: "%.1f", chineseCharacterRatio * 100))%)"
            )

            if chineseCharacterCount > 0 {
                let simplifiedRatio =
                    Double(simplifiedCharacterCount) / Double(chineseCharacterCount)
                print(
                    "Simplified ratio among Chinese chars: \(String(format: "%.3f", simplifiedRatio)) (\(String(format: "%.1f", simplifiedRatio * 100))%)"
                )
            }
        }

        isAnalyzed = true
    }
}

// MARK: - Pretty print for [NLLanguage: Double]

extension [NLLanguage: Double] {
    /// Returns a sorted and pretty-printed string representation of the language probabilities
    var prettyPrinted: String {
        let stringDict: [String: NSNumber] = reduce(into: [:]) { result, pair in
            result[pair.key.rawValue] = NSNumber(value: pair.value)
        }
        return stringDict.prettyPrinted
    }
}

extension [String: NSNumber] {
    /// Returns a sorted and pretty-printed string representation of the language probabilities
    var prettyPrinted: String {
        let sorttedString = sorted { $0.value.doubleValue > $1.value.doubleValue }
            .map { "\($0.key): \(String(format: "%.3f", $0.value.doubleValue))" }
            .joined(separator: "\n")
        return "\n" + sorttedString
    }
}
