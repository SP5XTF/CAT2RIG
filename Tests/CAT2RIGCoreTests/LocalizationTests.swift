import XCTest
@testable import CAT2RIGCore

/// Pilnuje, żeby wersja angielska była kompletna: każdy tekst z L("…") w kodzie
/// ma tłumaczenie, a specyfikatory formatu (%@, %ld…) się zgadzają.
final class LocalizationTests: XCTestCase {

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)            // …/Tests/CAT2RIGCoreTests/LocalizationTests.swift
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func loadStrings(_ lang: String) throws -> [String: String] {
        let url = packageRoot.appendingPathComponent("Resources/\(lang).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: String], "\(lang): zły format pliku .strings")
    }

    /// Wszystkie klucze L("…") z kodu źródłowego.
    private func keysUsedInCode() throws -> Set<String> {
        let sources = packageRoot.appendingPathComponent("Sources")
        let regex = try NSRegularExpression(pattern: #"\bL\("((?:[^"\\]|\\.)*)""#)
        var keys = Set<String>()
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            for m in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let r = Range(m.range(at: 1), in: text) {
                    keys.insert(String(text[r]))
                }
            }
        }
        return keys
    }

    private func specifiers(_ s: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"%[0-9]*(?:l{0,2})[@dDuUxXfs]"#)
        return regex.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap {
            Range($0.range, in: s).map { String(s[$0]) }
        }
    }

    func testStringFilesParse() throws {
        XCTAssertFalse(try loadStrings("en").isEmpty)
        _ = try loadStrings("pl")
    }

    func testEveryCodeStringHasEnglishTranslation() throws {
        let en = try loadStrings("en")
        let keys = try keysUsedInCode()
        XCTAssertGreaterThan(keys.count, 10, "nie znaleziono tekstów L(…) – zła ścieżka?")
        let missing = keys.filter { en[$0] == nil }.sorted()
        XCTAssertTrue(missing.isEmpty, "brak tłumaczenia EN dla: \(missing)")
    }

    func testFormatSpecifiersMatch() throws {
        for (key, value) in try loadStrings("en") {
            XCTAssertEqual(specifiers(key), specifiers(value), "różne %… w: \(key)")
        }
    }

    func testFallbackIsPolishKey() {
        // w testach nie ma pakietu .app z tłumaczeniami – L() zwraca tekst polski
        XCTAssertEqual(L("Klient połączony: %@", "x"), "Klient połączony: x")
        XCTAssertEqual(L("Radio odpowiada: %ld Hz %@", 14_074_000, "USB"),
                       "Radio odpowiada: 14074000 Hz USB")
    }
}
