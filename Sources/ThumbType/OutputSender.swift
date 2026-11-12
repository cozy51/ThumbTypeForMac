import CoreGraphics
import ThumbTypeCore

/// 出力方式。
enum OutputMode: String, CaseIterable, Identifiable {
    /// かなをローマ字の打鍵としてIMEへ送ります（未確定文字になり、漢字変換できます）。
    case romaji
    /// 文字をUnicodeで直接送ります（Windows版と同じ方式。IMEの変換は行われません）。
    case unicode

    var id: String { rawValue }
    var label: String {
        switch self {
        case .romaji: return "ローマ字でIMEへ送る（漢字変換できます・推奨）"
        case .unicode: return "Unicodeで直接送る（Windows版と同じ・変換なし）"
        }
    }
}

/// 合成キーイベントを送信します。送信したイベントには目印を付け、イベントタップで再処理しません。
final class OutputSender {
    /// eventSourceUserData に入れる目印。
    static let tag: Int64 = 0x5468_756D_6254_7970 // "ThumbTyp"

    var mode: OutputMode = .romaji
    private let source: CGEventSource?

    init() {
        // 物理的に押されている修飾キー（親指のShiftなど）の影響を受けないよう、独立した状態で送ります。
        source = CGEventSource(stateID: .privateState)
        source?.userData = Self.tag
        // JISキーボードとして解釈されるよう、実際のキーボードの種類を引き継ぎます。
        if let hardware = CGEventSource(stateID: .hidSystemState) {
            source?.keyboardType = hardware.keyboardType
        }
    }

    func text(_ value: String) {
        if mode == .romaji, let romaji = KanaRomaji.romaji(for: value) {
            for ch in romaji {
                guard let key = MacKey.asciiKeys[ch] else { continue }
                // IMEが通常の打鍵と同じに扱えるよう、文字はキーコードから決めさせます。
                post(key: key, unicode: nil)
            }
            return
        }
        for ch in value { post(key: 0, unicode: String(ch)) }
    }

    /// キーを1回打鍵します。修飾キー（Shift・Command）の単独打鍵は送りません。
    func tap(_ key: Int) {
        if MacKey.isModifier(key) { return }
        post(key: key, unicode: nil)
    }

    private func post(key: Int, unicode: String?) {
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: down) else { continue }
            event.flags = []
            if let unicode {
                let units = Array(unicode.utf16)
                units.withUnsafeBufferPointer { buffer in
                    event.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
                }
            }
            event.setIntegerValueField(.eventSourceUserData, value: Self.tag)
            // HIDレベルに送ると、押したままの親指Shiftなど物理的な修飾キーの状態が合成されてしまい、
            // IME（Google日本語入力など）が「Shift＋文字」＝英字入力として扱います。
            // セッションレベルに送れば、設定したフラグ（修飾なし）のまま届きます。
            event.post(tap: .cgSessionEventTap)
        }
    }
}
