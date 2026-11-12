/// macOSの仮想キーコード（JISキーボードの物理位置）。
/// Carbon の kVK_* 定数と同じ値です。Linuxでもテストできるよう数値で定義しています。
public enum MacKey {
    public static let a = 0, s = 1, d = 2, f = 3, h = 4, g = 5, z = 6, x = 7, c = 8, v = 9
    public static let b = 11, q = 12, w = 13, e = 14, r = 15, y = 16, t = 17
    public static let one = 18, two = 19, three = 20, four = 21, six = 22, five = 23
    public static let caret = 24          // JIS「^」（kVK_ANSI_Equal）
    public static let nine = 25, seven = 26
    public static let minus = 27
    public static let eight = 28, zero = 29
    public static let openBracket = 30    // JIS「[」（kVK_ANSI_RightBracket）
    public static let o = 31, u = 32
    public static let at = 33             // JIS「@」（kVK_ANSI_LeftBracket）
    public static let i = 34, p = 35
    public static let returnKey = 36
    public static let l = 37, j = 38
    public static let colon = 39          // JIS「:」（kVK_ANSI_Quote）
    public static let k = 40
    public static let semicolon = 41
    public static let closeBracket = 42   // JIS「]」（kVK_ANSI_Backslash）
    public static let comma = 43, slash = 44, n = 45, m = 46, period = 47
    public static let tab = 48, space = 49
    public static let backspace = 51, escape = 53
    public static let rightCommand = 54, leftCommand = 55, leftShift = 56, capsLock = 57
    public static let leftOption = 58, leftControl = 59, rightShift = 60, rightOption = 61, rightControl = 62
    public static let function = 63
    public static let yen = 93            // JIS「¥」
    public static let underscore = 94     // JIS「_」（ろ）
    public static let eisu = 102          // 英数
    public static let kana = 104          // かな
    public static let f12 = 111

    /// 修飾キーのキーコードと、CGEventFlags のデバイス依存ビット（左右を区別するビット）。
    public static let modifierDeviceBits: [Int: UInt64] = [
        leftControl: 0x0000_0001, leftShift: 0x0000_0002, rightShift: 0x0000_0004,
        leftCommand: 0x0000_0008, rightCommand: 0x0000_0010,
        leftOption: 0x0000_0020, rightOption: 0x0000_0040, rightControl: 0x0000_2000,
    ]

    public static func isModifier(_ key: Int) -> Bool { modifierDeviceBits[key] != nil }

    /// .yab の4行（JIS 109キーボードの文字キー48個）に対応する物理キー。
    public static let jisRows: [[Int]] = [
        [one, two, three, four, five, six, seven, eight, nine, zero, minus, caret, yen],
        [q, w, e, r, t, y, u, i, o, p, at, openBracket],
        [a, s, d, f, g, h, j, k, l, semicolon, colon, closeBracket],
        [z, x, c, v, b, n, m, comma, period, slash, underscore],
    ]

    /// TSVのキー名。Windows版（Windows Formsの Keys 名）と互換です。先頭が書き出し時の名前です。
    static let namedKeys: [(names: [String], key: Int)] = [
        (["D1", "1"], one), (["D2", "2"], two), (["D3", "3"], three), (["D4", "4"], four), (["D5", "5"], five),
        (["D6", "6"], six), (["D7", "7"], seven), (["D8", "8"], eight), (["D9", "9"], nine), (["D0", "0"], zero),
        (["OemMinus", "Minus"], minus), (["Oem7", "OemQuotes", "Caret"], caret), (["Oem5", "OemPipe", "Yen"], yen),
        (["Q"], q), (["W"], w), (["E"], e), (["R"], r), (["T"], t), (["Y"], y), (["U"], u), (["I"], i), (["O"], o), (["P"], p),
        (["Oemtilde", "Oem3", "At"], at), (["OemOpenBrackets", "Oem4", "OpenBracket"], openBracket),
        (["A"], a), (["S"], s), (["D"], d), (["F"], f), (["G"], g), (["H"], h), (["J"], j), (["K"], k), (["L"], l),
        (["Oemplus", "Semicolon"], semicolon), (["Oem1", "OemSemicolon", "Colon"], colon),
        (["Oem6", "OemCloseBrackets", "CloseBracket"], closeBracket),
        (["Z"], z), (["X"], x), (["C"], c), (["V"], v), (["B"], b), (["N"], n), (["M"], m),
        (["Oemcomma", "Comma"], comma), (["OemPeriod", "Period"], period), (["OemQuestion", "Oem2", "Slash"], slash),
        (["OemBackslash", "Oem102", "Underscore"], underscore),
    ]

    static let keysByName: [String: Int] = {
        var table: [String: Int] = [:]
        for entry in namedKeys { for name in entry.names { table[name.lowercased()] = entry.key } }
        return table
    }()

    /// キー名からキーコードへ（大文字小文字を区別しません）。
    public static func key(named name: String) -> Int? { keysByName[name.lowercased()] }

    /// 書き出し用のキー名（Windows版と同じ名前）。
    public static func name(of key: Int) -> String? { namedKeys.first { $0.key == key }?.names.first }

    /// ローマ字入力の送信に使うASCII文字のキー（JIS配列の位置）。
    public static let asciiKeys: [Character: Int] = [
        "a": a, "b": b, "c": c, "d": d, "e": e, "f": f, "g": g, "h": h, "i": i, "j": j, "k": k, "l": l, "m": m,
        "n": n, "o": o, "p": p, "q": q, "r": r, "s": s, "t": t, "u": u, "v": v, "w": w, "x": x, "y": y, "z": z,
        "-": minus, ",": comma, ".": period, "/": slash, "[": openBracket, "]": closeBracket,
    ]
}
