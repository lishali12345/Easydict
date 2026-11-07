//
//  ReplacementTextSnapshotTests.swift
//  EasydictTests
//
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation
import Testing

@testable import Easydict

@Suite("Replacement Text Snapshot", .tags(.unit))
struct ReplacementTextSnapshotTests {
    @Test("Chrome all-selection includes paragraph breaks omitted from marker coordinates")
    func wholeMultilineField() throws {
        let snapshot = try #require(ReplacementTextSnapshot(
            fullText: "开始\n你好\n结束", coordinateText: "开始你好结束",
            coordinateRange: NSRange(location: 0, length: 6),
            startBoundary: .beforeLineBreaks, endBoundary: .afterLineBreaks
        ))
        #expect(snapshot.range == NSRange(location: 0, length: 8))
        #expect(snapshot.selectsAll)
        #expect(Array(snapshot.selectedText.utf8) == Array("开始\n你好\n结束".utf8))
        #expect(Array(snapshot.replacing(with: "Start\nHello\nEnd").utf8) == Array("Start\nHello\nEnd".utf8))
    }

    @Test("A partial selection in the second line preserves both neighboring lines")
    func partialSecondLine() throws {
        let snapshot = try #require(ReplacementTextSnapshot(
            fullText: "保留头\n您好朋友\n保留尾", coordinateText: "保留头您好朋友保留尾",
            coordinateRange: NSRange(location: 4, length: 2), startBoundary: nil, endBoundary: nil
        ))
        #expect(snapshot.selectedText == "好朋")
        #expect(!snapshot.selectsAll)
        #expect(Array(snapshot.replacing(with: "Hello").utf8) == Array("保留头\n您Hello友\n保留尾".utf8))
    }

    @Test("Selecting a whole middle line excludes its surrounding paragraph breaks")
    func middleLine() throws {
        let snapshot = try #require(ReplacementTextSnapshot(
            fullText: "开头\n你好\n结尾", coordinateText: "开头你好结尾",
            coordinateRange: NSRange(location: 2, length: 2),
            startBoundary: .afterLineBreaks, endBoundary: .beforeLineBreaks
        ))
        #expect(snapshot.selectedText == "你好")
        #expect(Array(snapshot.replacing(with: "Hello").utf8) == Array("开头\nHello\n结尾".utf8))
    }

    @Test("A cross-line partial selection preserves the untouched prefix and suffix")
    func crossLinePartial() throws {
        let snapshot = try #require(ReplacementTextSnapshot(
            fullText: "头部\n第一句\n第二句\n尾部", coordinateText: "头部第一句第二句尾部",
            coordinateRange: NSRange(location: 3, length: 4), startBoundary: nil, endBoundary: nil
        ))
        #expect(Array(snapshot.selectedText.utf8) == Array("一句\n第二".utf8))
        #expect(Array(snapshot.replacing(with: "one\nsecond").utf8) == Array("头部\n第one\nsecond句\n尾部".utf8))
    }

    @Test("Repeated text is resolved by coordinates instead of a substring search")
    func repeatedText() throws {
        let snapshot = try #require(ReplacementTextSnapshot(
            fullText: "重复\n重复\n重复", coordinateText: "重复重复重复",
            coordinateRange: NSRange(location: 2, length: 2),
            startBoundary: .afterLineBreaks, endBoundary: .beforeLineBreaks
        ))
        #expect(Array(snapshot.replacing(with: "Middle").utf8) == Array("重复\nMiddle\n重复".utf8))
    }

    @Test("Consecutive blank lines outside the selected line are retained")
    func blankLines() throws {
        let snapshot = try #require(ReplacementTextSnapshot(
            fullText: "头\n\n中\n\n尾", coordinateText: "头中尾",
            coordinateRange: NSRange(location: 1, length: 1),
            startBoundary: .afterLineBreaks, endBoundary: .beforeLineBreaks
        ))
        #expect(Array(snapshot.replacing(with: "Middle").utf8) == Array("头\n\nMiddle\n\n尾".utf8))
    }

    @Test("Field-edge coordinates do not imply selection of leading or trailing blank lines")
    func fieldEdgeAffinity() throws {
        let partial = try #require(ReplacementTextSnapshot(
            fullText: "\n\n头\n中\n\n", coordinateText: "头中",
            coordinateRange: NSRange(location: 0, length: 2),
            startBoundary: .afterLineBreaks, endBoundary: .beforeLineBreaks
        ))
        #expect(!partial.selectsAll)
        #expect(Array(partial.replacing(with: "Head\nMiddle").utf8) == Array("\n\nHead\nMiddle\n\n".utf8))
        let whole = try #require(ReplacementTextSnapshot(
            fullText: "\n\n头\n中\n\n", coordinateText: "头中",
            coordinateRange: NSRange(location: 0, length: 2),
            startBoundary: .beforeLineBreaks, endBoundary: .afterLineBreaks
        ))
        #expect(whole.selectsAll)
        #expect(Array(whole.selectedText.utf8) == Array("\n\n头\n中\n\n".utf8))
    }

    @Test("Explicit coordinate line breaks coexist with generated paragraph breaks")
    func explicitLineBreaks() throws {
        let snapshot = try #require(ReplacementTextSnapshot(
            fullText: "头\n\n中\n尾", coordinateText: "头\n中尾",
            coordinateRange: NSRange(location: 2, length: 1),
            startBoundary: .afterLineBreaks, endBoundary: .beforeLineBreaks
        ))
        #expect(snapshot.selectedText == "中")
        #expect(Array(snapshot.replacing(with: "Middle").utf8) == Array("头\n\nMiddle\n尾".utf8))
    }

    @Test("Emoji and decomposed Unicode before a selection retain their original bytes")
    func unicode() throws {
        let fullText = "👩🏽‍💻 e\u{301}\n你好\né"
        let coordinateText = "👩🏽‍💻 e\u{301}你好é"
        let range = (coordinateText as NSString).range(of: "你好")
        let snapshot = try #require(ReplacementTextSnapshot(
            fullText: fullText, coordinateText: coordinateText, coordinateRange: range,
            startBoundary: .afterLineBreaks, endBoundary: .beforeLineBreaks
        ))
        #expect(Array(snapshot.replacing(with: "Hello").utf8) == Array("👩🏽‍💻 e\u{301}\nHello\né".utf8))
    }

    @Test("Native selections preserve CRLF, tabs and unselected Unicode")
    func nativeSelection() throws {
        let fullText = "\t👩🏽‍💻 e\u{301}\r\n你好\r\n尾\t"
        let snapshot = try #require(ReplacementTextSnapshot(
            fullText: fullText, range: (fullText as NSString).range(of: "你好"), selectedText: "你好"
        ))
        #expect(Array(snapshot.replacing(with: "Hello").utf8) == Array("\t👩🏽‍💻 e\u{301}\r\nHello\r\n尾\t".utf8))
    }

    @Test("Ambiguous paragraph boundaries require marker affinity")
    func missingAffinity() {
        #expect(ReplacementTextSnapshot(
            fullText: "A\nB", coordinateText: "AB", coordinateRange: NSRange(location: 1, length: 1),
            startBoundary: nil, endBoundary: nil
        ) == nil)
        #expect(ReplacementTextSnapshot(
            fullText: "A\nB", coordinateText: "AB", coordinateRange: NSRange(location: 0, length: 1),
            startBoundary: nil, endBoundary: nil
        ) == nil)
    }

    @Test("Non-line-break mismatches anywhere in the field reject the snapshot", arguments: [
        ("A B", "AB"), ("A\tB", "AB"), ("A\rB", "AB"), ("A\u{2028}B", "AB"),
        ("A\nB", "A\n\nB"), ("A\nX", "AB"), ("e\u{301}", "é"),
    ])
    func mismatchedField(pair: (String, String)) {
        #expect(ReplacementTextSnapshot(
            fullText: pair.0, coordinateText: pair.1, coordinateRange: NSRange(location: 0, length: 1),
            startBoundary: .beforeLineBreaks, endBoundary: .afterLineBreaks
        ) == nil)
    }

    @Test("Native selection equality does not normalize Unicode")
    func nativeMismatch() {
        #expect(ReplacementTextSnapshot(
            fullText: "é",
            range: NSRange(location: 0, length: 1),
            selectedText: "e\u{301}"
        ) == nil)
    }

    @Test("Invalid ranges are rejected without overflow", arguments: [
        NSRange(location: -1, length: 1), NSRange(location: 0, length: -1), NSRange(location: 0, length: 0),
        NSRange(location: NSNotFound, length: 1), NSRange(location: 0, length: Int.max), NSRange(
            location: 1,
            length: 2
        ),
    ])
    func invalidRange(range: NSRange) {
        #expect(ReplacementTextSnapshot(fullText: "AB", range: range, selectedText: "A") == nil)
        #expect(ReplacementTextSnapshot(
            fullText: "A\nB", coordinateText: "AB", coordinateRange: range,
            startBoundary: .beforeLineBreaks, endBoundary: .afterLineBreaks
        ) == nil)
    }

    @Test("A range cannot split a UTF-16 surrogate pair", arguments: [
        NSRange(location: 0, length: 1), NSRange(location: 1, length: 1),
    ])
    func splitSurrogate(range: NSRange) {
        #expect(ReplacementTextSnapshot(fullText: "😀A", range: range, selectedText: "😀") == nil)
        #expect(ReplacementTextSnapshot(
            fullText: "😀\nA", coordinateText: "😀A", coordinateRange: range,
            startBoundary: .beforeLineBreaks, endBoundary: .afterLineBreaks
        ) == nil)
    }

    @Test("Conflicting affinities cannot produce an empty mapped selection")
    func emptyMappedSelection() {
        #expect(ReplacementTextSnapshot(
            fullText: "\n\n", coordinateText: "\n", coordinateRange: NSRange(location: 0, length: 1),
            startBoundary: .afterLineBreaks, endBoundary: .beforeLineBreaks
        ) == nil)
    }
}
