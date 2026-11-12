import Foundation
import XCTest
@testable import ThumbTypeCore

final class LayoutTests: XCTestCase {
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Windows版 SelfTest.cs と同じ期待値（4層 × JIS 4行）。
    let expected: [[String]] = [
        ["１|２|３|４|５|６|７|８|９|０|－|{None}|{None}", "。|か|た|こ|さ|ら|ち|く|つ|，|、|{None}",
         "う|し|て|け|せ|は|と|き|い|ん|{Backspace}|{Escape}", "．|ひ|す|ふ|へ|め|そ|ね|ほ|・|{None}"],
        ["？|／|～|「|」|［|］|（|）|｛|｝|{None}|{None}", "ぁ|え|り|ゃ|れ|ぱ|ぢ|ぐ|づ|ぴ|{None}|{None}",
         "を|あ|な|ゅ|も|ば|ど|ぎ|ぽ|よ|{Backspace}|{Escape}", "ぅ|ー|ろ|や|ぃ|ぷ|ぞ|ぺ|ぼ|゛|{None}"],
        ["？|／|～|「|」|［|］|（|）|｛|｝|{None}|{None}", "゜|が|だ|ご|ざ|よ|に|る|ま|ぇ|{None}|{None}",
         "ゔ|じ|で|げ|ぜ|み|お|の|ょ|っ|{Backspace}|{Escape}", "{None}|び|ず|ぶ|べ|ぬ|ゆ|む|わ|ぉ|{None}"],
        ["！|”|＃|＄|％|＆|’|（|）|：|＝|～|｜", "Ｑ|Ｗ|Ｅ|Ｒ|Ｔ|Ｙ|Ｕ|Ｉ|Ｏ|Ｐ|‘|｛",
         "Ａ|Ｓ|Ｄ|Ｆ|Ｇ|Ｈ|Ｊ|Ｋ|Ｌ|＋|＊|｝", "Ｚ|Ｘ|Ｃ|Ｖ|Ｂ|Ｎ|Ｍ|＜|＞|？|＿"],
    ]

    func testBuiltInNICOLAAllLayers() {
        let nicola = Layout.builtIn
        XCTAssertEqual(nicola.rows.count, 48)
        XCTAssertTrue(nicola.hasPinky)
        for layer in 0..<4 {
            for row in 0..<4 {
                let cells = expected[layer][row].split(separator: "|").map(String.init)
                XCTAssertEqual(cells.count, MacKey.jisRows[row].count)
                for (col, want) in cells.enumerated() {
                    let m = nicola.rows[MacKey.jisRows[row][col]]!
                    let actual = [m.normal, m.left, m.right, m.shift ?? ""][layer]
                    XCTAssertEqual(actual, want, "NICOLA layer \(layer) row \(row) column \(col)")
                }
            }
        }
    }

    func testExportRoundTrip() throws {
        let reloaded = try Layout.parseTSV(YabLayout.export(.builtIn))
        XCTAssertEqual(reloaded, .builtIn)
        XCTAssertEqual(reloaded.rows[MacKey.semicolon]?.right, "っ")
    }

    func testYabRejections() {
        XCTAssertThrowsError(try YabLayout.parse(YabLayout.builtInText.replacingOccurrences(of: "ｌａ,ｅ", with: "unknown,ｅ")))
        XCTAssertThrowsError(try YabLayout.parse(YabLayout.builtInText.replacingOccurrences(of: "１,２,", with: "１,")))
        XCTAssertThrowsError(try YabLayout.parse("[未対応]\nA"))
        XCTAssertThrowsError(try YabLayout.parse("１,２"))
    }

    func testEmbeddedTextMatchesShippedFile() throws {
        let data = try Data(contentsOf: Self.repoRoot.appendingPathComponent("layouts/NICOLA.yab"))
        let file = try YabLayout.decodeText(data).replacingOccurrences(of: "\r", with: "")
        XCTAssertEqual(file.trimmingCharacters(in: .whitespacesAndNewlines),
                       YabLayout.builtInText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func testShippedFilesLoad() throws {
        let yab = try YabLayout.readFile(Self.repoRoot.appendingPathComponent("layouts/NICOLA.yab"))
        XCTAssertEqual(yab.rows[MacKey.semicolon]?.normal, "ん", "UTF-16LE YAB loads directly from file")
        let tsv = try YabLayout.readFile(Self.repoRoot.appendingPathComponent("layouts/NICOLA.tsv"))
        XCTAssertEqual(tsv.rows[MacKey.semicolon]?.shift, "＋", "Windows five-column TSV loads directly")
        XCTAssertEqual(tsv, yab)
    }

    func testDecodeTextEncodings() throws {
        let text = "A\tあ\tい\tう\n"
        XCTAssertEqual(try YabLayout.decodeText(Data(text.utf8)), text)
        XCTAssertEqual(try YabLayout.decodeText(Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)), text)
        XCTAssertEqual(try YabLayout.decodeText(Data([0xFF, 0xFE]) + text.data(using: .utf16LittleEndian)!), text)
    }

    func testKanaRomaji() {
        XCTAssertEqual(KanaRomaji.romaji(for: "と"), "to")
        XCTAssertEqual(KanaRomaji.romaji(for: "ん"), "nn")
        XCTAssertEqual(KanaRomaji.romaji(for: "っ"), "xtu")
        XCTAssertEqual(KanaRomaji.romaji(for: "ゔ"), "vu")
        XCTAssertEqual(KanaRomaji.romaji(for: "。"), ".")
        XCTAssertNil(KanaRomaji.romaji(for: "１"))
        XCTAssertNil(KanaRomaji.romaji(for: "゛"))
        XCTAssertNil(KanaRomaji.romaji(for: ""))
        // 内蔵配列のかなはすべてローマ字で送れ、送信に使う文字はすべてキーが割り当て済み。
        for m in Layout.builtIn.rows.values {
            for v in [m.normal, m.left, m.right] {
                if let r = KanaRomaji.romaji(for: v) {
                    for ch in r { XCTAssertNotNil(MacKey.asciiKeys[ch], "key for \(ch)") }
                } else if v.unicodeScalars.allSatisfy({ (0x3041...0x3094).contains($0.value) }) {
                    XCTFail("kana without romaji: \(v)")
                }
            }
        }
    }

    func testInputSourceRule() {
        XCTAssertTrue(InputSourceRule.isJapaneseKanaMode("com.apple.inputmethod.Japanese"))
        XCTAssertTrue(InputSourceRule.isJapaneseKanaMode("com.apple.inputmethod.Japanese.Katakana"))
        XCTAssertTrue(InputSourceRule.isJapaneseKanaMode("com.google.inputmethod.Japanese.base"))
        XCTAssertFalse(InputSourceRule.isJapaneseKanaMode("com.apple.inputmethod.Roman"))
        XCTAssertFalse(InputSourceRule.isJapaneseKanaMode("com.apple.inputmethod.Japanese.FullWidthRoman"))
        XCTAssertFalse(InputSourceRule.isJapaneseKanaMode("com.google.inputmethod.Japanese.Roman"))
        XCTAssertFalse(InputSourceRule.isJapaneseKanaMode("com.apple.keylayout.ABC"))
        XCTAssertFalse(InputSourceRule.isJapaneseKanaMode(nil))
    }

    func testKeyNames() {
        XCTAssertEqual(MacKey.key(named: "oem1"), MacKey.colon)
        XCTAssertEqual(MacKey.key(named: "OemSemicolon"), MacKey.colon)
        XCTAssertEqual(MacKey.key(named: "Oemplus"), MacKey.semicolon)
        XCTAssertNil(MacKey.key(named: "Space"))
        XCTAssertEqual(Set(MacKey.jisRows.joined()).count, 48)
    }
}
