/// かなをローマ字の打鍵列へ変換します。
///
/// macOSのIME（日本語入力プログラム・Google日本語入力など）へローマ字として送ることで、
/// 未確定文字として入力され、そのまま漢字変換できます。
public enum KanaRomaji {
    static let table: [Character: String] = {
        var t: [Character: String] = [:]
        let rows: [(String, [String])] = [
            ("あいうえお", ["a", "i", "u", "e", "o"]),
            ("かきくけこ", ["ka", "ki", "ku", "ke", "ko"]),
            ("がぎぐげご", ["ga", "gi", "gu", "ge", "go"]),
            ("さしすせそ", ["sa", "si", "su", "se", "so"]),
            ("ざじずぜぞ", ["za", "zi", "zu", "ze", "zo"]),
            ("たちつてと", ["ta", "ti", "tu", "te", "to"]),
            ("だぢづでど", ["da", "di", "du", "de", "do"]),
            ("なにぬねの", ["na", "ni", "nu", "ne", "no"]),
            ("はひふへほ", ["ha", "hi", "hu", "he", "ho"]),
            ("ばびぶべぼ", ["ba", "bi", "bu", "be", "bo"]),
            ("ぱぴぷぺぽ", ["pa", "pi", "pu", "pe", "po"]),
            ("まみむめも", ["ma", "mi", "mu", "me", "mo"]),
            ("やゆよ", ["ya", "yu", "yo"]),
            ("らりるれろ", ["ra", "ri", "ru", "re", "ro"]),
            ("わをん", ["wa", "wo", "nn"]),
            ("ぁぃぅぇぉ", ["xa", "xi", "xu", "xe", "xo"]),
            ("ゃゅょっゎゔ", ["xya", "xyu", "xyo", "xtu", "xwa", "vu"]),
            ("ー、。・「」", ["-", ",", ".", "/", "[", "]"]),
        ]
        for (kana, romaji) in rows {
            for (k, r) in zip(kana, romaji) { t[k] = r }
        }
        return t
    }()

    /// 全文字がローマ字で打てる場合はその打鍵列を、そうでなければ nil を返します。
    public static func romaji(for text: String) -> String? {
        if text.isEmpty { return nil }
        var result = ""
        for ch in text {
            guard let r = table[ch] else { return nil }
            result += r
        }
        return result
    }
}

/// 入力ソース（TISの入力モードID）から、配列変換を行うかを判定します。
/// Windows版の「IMEが日本語入力（あ）のときだけ変換」に相当します。
public enum InputSourceRule {
    /// ひらがな・カタカナ入力モードなら true。英数（ローマ字）モード・キーボード配列・不明なら false。
    public static func isJapaneseKanaMode(_ modeID: String?) -> Bool {
        guard let id = modeID?.lowercased(), !id.isEmpty else { return false }
        for blocked in ["roman", "alphanumeric", "ascii", "direct"] where id.contains(blocked) { return false }
        // ことえり／日本語入力プログラム: com.apple.inputmethod.Japanese(.Katakana / .HalfWidthKana)
        // Google日本語入力: com.google.inputmethod.Japanese.base / .Katakana / .HalfWidthKana
        // ATOK: com.justsystems.inputmethod.atok**.Japanese(.Katakana …)
        return id.contains("japanese") || id.contains("hiragana") || id.contains("katakana")
    }
}
