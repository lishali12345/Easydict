//
//  ChromeReplacementSelection.swift
//  Easydict
//
//  Copyright © 2026 izual. All rights reserved.
//

import AppKit
import AXSwift

/// Projects Chrome's tree-based selection onto AXValue without changing the original text.
struct ChromeReplacementSelection {
    // MARK: Lifecycle

    init?(element: UIElement, fullText: String, selectedText: String) {
        let reader = MarkerReader(element: element.element)
        guard let selected = reader.selectedRange(),
              let field = reader.range(for: element.element),
              let ordered = reader.ordered(selected),
              let coordinateText = reader.text(field),
              let prefix = reader.text(
                  from: AXTextMarkerRangeCopyStartMarker(field),
                  to: AXTextMarkerRangeCopyStartMarker(ordered)
              ),
              let selection = reader.text(ordered),
              let suffix = reader.text(
                  from: AXTextMarkerRangeCopyEndMarker(ordered),
                  to: AXTextMarkerRangeCopyEndMarker(field)
              ),
              (prefix + selection + suffix).utf8.elementsEqual(coordinateText.utf8),
              selection.utf8.elementsEqual(selectedText.utf8),
              let start = reader.boundary(AXTextMarkerRangeCopyStartMarker(ordered), in: field),
              let end = reader.boundary(AXTextMarkerRangeCopyEndMarker(ordered), in: field),
              let snapshot = ReplacementTextSnapshot(
                  fullText: fullText,
                  coordinateText: coordinateText,
                  coordinateRange: NSRange(location: prefix.utf16.count, length: selection.utf16.count),
                  startBoundary: start.affinity,
                  endBoundary: end.affinity
              )
        else { return nil }

        self.snapshot = snapshot
        self.markers = Self.identity(selected)
    }

    // MARK: Internal

    let snapshot: ReplacementTextSnapshot

    static func selectionIdentity(in element: UIElement) -> [Data]? {
        MarkerReader(element: element.element).selectedRange().map(identity)
    }

    func selectionIsUnchanged(in element: UIElement) -> Bool {
        Self.selectionIdentity(in: element) == markers
    }

    // MARK: Private

    private struct MarkerReader {
        // MARK: Internal

        struct Boundary {
            let affinity: ReplacementTextSnapshot.Boundary?
        }

        let element: AXUIElement

        func selectedRange() -> AXTextMarkerRange? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, "AXSelectedTextMarkerRange" as CFString, &value) == .success
            else { return nil }
            return markerRange(value)
        }

        func range(for owner: AXUIElement) -> AXTextMarkerRange? {
            markerRange(parameter("AXTextMarkerRangeForUIElement", owner))
        }

        func ordered(_ range: AXTextMarkerRange) -> AXTextMarkerRange? {
            let markers = [AXTextMarkerRangeCopyStartMarker(range), AXTextMarkerRangeCopyEndMarker(range)] as CFArray
            return markerRange(parameter("AXTextMarkerRangeForUnorderedTextMarkers", markers))
        }

        func text(_ range: AXTextMarkerRange) -> String? {
            parameter("AXStringForTextMarkerRange", range) as? String
        }

        func text(from start: AXTextMarker, to end: AXTextMarker) -> String? {
            text(AXTextMarkerRangeCreate(kCFAllocatorDefault, start, end))
        }

        /// A leaf's start is after the preceding paragraph break; its end is before the next one.
        /// An interior boundary with ambiguous generated breaks remains unresolved.
        func boundary(_ marker: AXTextMarker, in field: AXTextMarkerRange) -> Boundary? {
            guard let ownerValue = parameter("AXUIElementForTextMarker", marker),
                  CFGetTypeID(ownerValue) == AXUIElementGetTypeID()
            else { return nil }
            let owner = unsafeBitCast(ownerValue, to: AXUIElement.self)
            guard contains(owner) else { return nil }

            let fieldStart = AXTextMarkerRangeCopyStartMarker(field)
            let fieldEnd = AXTextMarkerRangeCopyEndMarker(field)
            if ChromeReplacementSelection.bytes(marker) == ChromeReplacementSelection.bytes(fieldStart) {
                return Boundary(affinity: .beforeLineBreaks)
            }
            if ChromeReplacementSelection.bytes(marker) == ChromeReplacementSelection.bytes(fieldEnd) {
                return Boundary(affinity: .afterLineBreaks)
            }
            guard let ownerRange = range(for: owner),
                  let before = text(from: AXTextMarkerRangeCopyStartMarker(ownerRange), to: marker),
                  let after = text(from: marker, to: AXTextMarkerRangeCopyEndMarker(ownerRange))
            else { return nil }
            if before.isEmpty, !after.isEmpty { return Boundary(affinity: .afterLineBreaks) }
            if after.isEmpty, !before.isEmpty { return Boundary(affinity: .beforeLineBreaks) }
            return Boundary(affinity: nil)
        }

        // MARK: Private

        private func contains(_ owner: AXUIElement) -> Bool {
            var current = owner
            for _ in 0 ..< 64 {
                if CFEqual(current, element) { return true }
                var parent: CFTypeRef?
                guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
                      let parent, CFGetTypeID(parent) == AXUIElementGetTypeID()
                else { return false }
                current = unsafeBitCast(parent, to: AXUIElement.self)
            }
            return false
        }

        private func markerRange(_ value: CFTypeRef?) -> AXTextMarkerRange? {
            guard let value, CFGetTypeID(value) == AXTextMarkerRangeGetTypeID() else { return nil }
            return unsafeBitCast(value, to: AXTextMarkerRange.self)
        }

        private func parameter(_ name: String, _ input: CFTypeRef) -> CFTypeRef? {
            var value: CFTypeRef?
            guard AXUIElementCopyParameterizedAttributeValue(element, name as CFString, input, &value) == .success
            else { return nil }
            return value
        }
    }

    private let markers: [Data]

    private static func identity(_ range: AXTextMarkerRange) -> [Data] {
        [bytes(AXTextMarkerRangeCopyStartMarker(range)), bytes(AXTextMarkerRangeCopyEndMarker(range))]
    }

    private static func bytes(_ marker: AXTextMarker) -> Data {
        Data(bytes: AXTextMarkerGetBytePtr(marker), count: AXTextMarkerGetLength(marker))
    }
}
