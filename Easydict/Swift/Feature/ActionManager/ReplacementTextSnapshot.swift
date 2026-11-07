//
//  ReplacementTextSnapshot.swift
//  Easydict
//
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation

/// A selection expressed in the original field's UTF-16 coordinates, without changing its text.
struct ReplacementTextSnapshot {
    // MARK: Lifecycle

    init?(fullText: String, range: NSRange, selectedText: String) {
        guard Self.isValid(range, in: Array(fullText.utf16)),
              (fullText as NSString).substring(with: range).utf8.elementsEqual(selectedText.utf8)
        else { return nil }
        self.fullText = fullText
        self.range = range
    }

    /// Projects browser text coordinates into AXValue. Only additional paragraph LFs are permitted.
    /// Boundary affinity must come from the actual marker owner, never from a text search.
    init?(
        fullText: String,
        coordinateText: String,
        coordinateRange: NSRange,
        startBoundary: Boundary?,
        endBoundary: Boundary?
    ) {
        let coordinates = Array(coordinateText.utf16)
        let original = Array(fullText.utf16)
        guard Self.isValid(coordinateRange, in: coordinates),
              let boundaries = Self.boundaries(original: original, coordinates: coordinates),
              let start = Self.resolve(boundaries[coordinateRange.location], affinity: startBoundary),
              let end = Self.resolve(boundaries[NSMaxRange(coordinateRange)], affinity: endBoundary),
              end > start
        else { return nil }
        let mappedRange = NSRange(location: start, length: end - start)
        guard Self.isValid(mappedRange, in: original) else { return nil }
        self.fullText = fullText
        self.range = mappedRange
    }

    // MARK: Internal

    enum Boundary {
        case beforeLineBreaks
        case afterLineBreaks
    }

    let fullText: String
    let range: NSRange

    var selectedText: String {
        (fullText as NSString).substring(with: range)
    }

    var selectsAll: Bool {
        range.location == 0 && range.length == fullText.utf16.count
    }

    func replacing(with text: String) -> String {
        (fullText as NSString).replacingCharacters(in: range, with: text)
    }

    // MARK: Private

    private static func isValid(_ range: NSRange, in units: [UInt16]) -> Bool {
        guard range.location >= 0, range.length > 0,
              range.location <= units.count, range.length <= units.count - range.location
        else { return false }
        return isScalarBoundary(range.location, in: units) && isScalarBoundary(NSMaxRange(range), in: units)
    }

    private static func isScalarBoundary(_ offset: Int, in units: [UInt16]) -> Bool {
        guard offset > 0, offset < units.count else { return true }
        return !(0xD800 ... 0xDBFF).contains(units[offset - 1]) || !(0xDC00 ... 0xDFFF).contains(units[offset])
    }

    private static func resolve(_ offsets: ClosedRange<Int>, affinity: Boundary?) -> Int? {
        if offsets.lowerBound == offsets.upperBound { return offsets.lowerBound }
        switch affinity {
        case .beforeLineBreaks: return offsets.lowerBound
        case .afterLineBreaks: return offsets.upperBound
        case nil: return nil
        }
    }

    /// Each coordinate boundary can straddle generated line breaks in the original field.
    /// Explicit LFs remain part of the coordinates; no other character may be inserted or removed.
    private static func boundaries(original: [UInt16], coordinates: [UInt16]) -> [ClosedRange<Int>]? {
        var result = Array(repeating: 0 ... 0, count: coordinates.count + 1)
        var originalOffset = 0
        var coordinateOffset = 0
        while true {
            let originalStart = originalOffset
            let coordinateStart = coordinateOffset
            while originalOffset < original.count, original[originalOffset] == 10 { originalOffset += 1 }
            while coordinateOffset < coordinates.count, coordinates[coordinateOffset] == 10 { coordinateOffset += 1 }
            let coordinateBreaks = coordinateOffset - coordinateStart
            let extraBreaks = originalOffset - originalStart - coordinateBreaks
            guard extraBreaks >= 0 else { return nil }
            for offset in 0 ... coordinateBreaks {
                let lower = originalStart + offset
                result[coordinateStart + offset] = lower ... (lower + extraBreaks)
            }
            if coordinateOffset == coordinates.count {
                return originalOffset == original.count ? result : nil
            }
            guard originalOffset < original.count,
                  original[originalOffset] == coordinates[coordinateOffset]
            else { return nil }
            originalOffset += 1
            coordinateOffset += 1
        }
    }
}
