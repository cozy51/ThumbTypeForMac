import Foundation

/// 同梱NICOLA.yabにある4つのローマ字セクションの読み込み（Windows版 YabLayout の移植）。
/// やまぶきRの汎用インタプリタではありません。未対応の構文はエラーにします。
public enum YabLayout {
    static let sections = ["ローマ字シフト無し", "ローマ字左親指シフト", "ローマ字右親指シフト", "ローマ字小指シフト"]

    static let kana: [String: String] = {
        let pairs = "ka=か ta=た ko=こ sa=さ ra=ら ti=ち ku=く tu=つ u=う si=し te=て ke=け se=せ ha=は to=と ki=き i=い nn=ん hi=ひ su=す fu=ふ he=へ me=め so=そ ne=ね ho=ほ la=ぁ e=え ri=り lya=ゃ re=れ pa=ぱ di=ぢ gu=ぐ du=づ pi=ぴ wo=を a=あ na=な lyu=ゅ mo=も ba=ば do=ど gi=ぎ po=ぽ yo=よ lu=ぅ ro=ろ ya=や li=ぃ pu=ぷ zo=ぞ pe=ぺ bo=ぼ ga=が da=だ go=ご za=ざ ni=に ru=る ma=ま le=ぇ vu=ゔ zi=じ de=で ge=げ ze=ぜ mi=み o=お no=の lyo=ょ ltu=っ bi=び zu=ず bu=ぶ be=べ nu=ぬ yu=ゆ mu=む wa=わ lo=ぉ"
        var table: [String: String] = [:]
        for pair in pairs.split(separator: " ") {
            let f = pair.split(separator: "=")
            table[String(f[0])] = String(f[1])
        }
        return table
    }()

    /// 1セルを出力文字列へ変換します。
    public static func decode(_ cell: String) throws -> String {
        let value = cell.trimmingCharacters(in: .whitespaces)
        if value.count >= 2, value.hasPrefix("'"), value.hasSuffix("'") {
            return String(value.dropFirst().dropLast())
        }
        switch value {
        case "無": return Layout.none
        case "後": return Layout.backspace
        case "逃": return Layout.escape
        default: break
        }
        let roman = value.precomposedStringWithCompatibilityMapping
        if let k = kana[roman] { return k }
        switch roman {
        case ".": return "。"
        case ",": return "、"
        case "/": return "・"
        case "-": return "ー"
        case "[": return "「"
        case "]": return "」"
        default: break
        }
        // 同梱ファイルの残りの引用符なし出力は、1文字の記号・数字です。
        if value.count == 1, let scalar = value.unicodeScalars.first,
           !CharacterSet.controlCharacters.contains(scalar),
           !(roman.count == 1 && roman.first!.isLowercase) {
            return value
        }
        throw LayoutError("未対応のやまぶき配列トークン: \(value)")
    }

    static func splitRow(_ row: String) throws -> [String] {
        var cells: [String] = []
        var cell = ""
        var quoted = false
        for c in row {
            if c == "'" { quoted.toggle() }
            if c == "," && !quoted {
                cells.append(cell)
                cell = ""
            } else {
                cell.append(c)
            }
        }
        if quoted { throw LayoutError("引用符が閉じていません。") }
        cells.append(cell)
        return cells
    }

    public static func parse(_ text: String) throws -> Layout {
        var data: [String: [[String]]] = [:]
        var current: String?
        let normalized = text.replacingOccurrences(of: "\r", with: "")
        for raw in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = String(raw).trimmingCharacters(in: .whitespaces)
            while line.unicodeScalars.first == "\u{FEFF}" { line = String(line.unicodeScalars.dropFirst()) }
            if line.isEmpty || line.hasPrefix(";") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                let section = String(line.dropFirst().dropLast())
                guard sections.contains(section) else { throw LayoutError("未対応のセクション: \(section)") }
                if data[section] != nil { throw LayoutError("セクションが重複しています。") }
                data[section] = []
                current = section
                continue
            }
            guard let section = current else { throw LayoutError("セクションの外に配列行があります。") }
            let row = data[section]!.count
            guard row < MacKey.jisRows.count else { throw LayoutError("配列行が多すぎます。") }
            let cells = try splitRow(line)
            guard cells.count == MacKey.jisRows[row].count else {
                throw LayoutError("配列の列数がJISキーボードと一致しません。")
            }
            data[section]!.append(try cells.map(decode))
        }
        for section in sections where data[section]?.count != 4 {
            throw LayoutError("4行のセクションが必要です: \(section)")
        }
        var layout = Layout()
        for (row, keys) in MacKey.jisRows.enumerated() {
            for (col, key) in keys.enumerated() {
                layout.rows[key] = Mapping(normal: data[sections[0]]![row][col], left: data[sections[1]]![row][col],
                                           right: data[sections[2]]![row][col], shift: data[sections[3]]![row][col])
            }
        }
        return layout
    }

    /// UTF-8、BOM付きUTF-16/UTF-8、UTF-8として読めない場合はShift-JISとして読み込みます。
    public static func decodeText(_ data: Data) throws -> String {
        let bytes = [UInt8](data.prefix(3))
        if bytes.count >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE {
            if let s = String(data: data.dropFirst(2), encoding: .utf16LittleEndian) { return s }
        } else if bytes.count >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF {
            if let s = String(data: data.dropFirst(2), encoding: .utf16BigEndian) { return s }
        } else if bytes.count >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF {
            if let s = String(data: data.dropFirst(3), encoding: .utf8) { return s }
        } else if let s = String(data: data, encoding: .utf8) {
            return s
        } else if let s = String(data: data, encoding: .shiftJIS) {
            return s
        }
        throw LayoutError("文字コードを判別できません（UTF-8・UTF-16・Shift-JISに対応）。")
    }

    /// .yab または .tsv ファイルを読み込みます。
    public static func readFile(_ url: URL) throws -> Layout {
        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw LayoutError("ファイルを開けません: \(url.path)") }
        let text = try decodeText(data)
        return url.pathExtension.lowercased() == "yab" ? try parse(text) : try Layout.parseTSV(text)
    }

    /// TSV（5列）へ書き出します。キー名はWindows版と同じです。
    public static func export(_ layout: Layout) -> String {
        var text = "# ThumbType / provided NICOLA.yab / JIS 109\n# Key\tNormal\tLeft\tRight\tPinkyShift\n"
        for row in MacKey.jisRows {
            for key in row {
                guard let m = layout.rows[key], let name = MacKey.name(of: key) else { continue }
                text += "\(name)\t\(m.normal)\t\(m.left)\t\(m.right)\t\(m.shift ?? "")\n"
            }
        }
        return text
    }
}
