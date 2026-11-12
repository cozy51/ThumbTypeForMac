import Foundation

/// 配列の読み込みエラー。メッセージはそのまま画面に表示します。
public struct LayoutError: Error, LocalizedError, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// 1つの物理キーに対する各層の出力。
public struct Mapping: Equatable {
    public var normal: String
    public var left: String
    public var right: String
    /// 小指シフト（親指に指定していないShift）。nil は定義なし。
    public var shift: String?

    public init(normal: String, left: String, right: String, shift: String? = nil) {
        self.normal = normal
        self.left = left
        self.right = right
        self.shift = shift
    }
}

/// キーコード（macOSの仮想キーコード）から出力への配列。
public struct Layout: Equatable {
    public var rows: [Int: Mapping] = [:]

    public init() {}

    public var hasPinky: Bool { rows.values.contains { $0.shift != nil } }

    /// 予約出力。
    public static let none = "{None}", backspace = "{Backspace}", escape = "{Escape}"

    /// UTF-8のタブ区切りTSV（4列または5列）を読み込みます。Windows版と同じ形式です。
    /// `キー名 / 通常 / 左親指 / 右親指 / 小指Shift（省略可）`
    public static func parseTSV(_ text: String) throws -> Layout {
        var result = Layout()
        var line = 0
        let normalized = text.replacingOccurrences(of: "\r", with: "")
        for raw in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            line += 1
            var trimmed = String(raw).trimmingCharacters(in: .whitespaces)
            if line == 1, trimmed.hasPrefix("\u{FEFF}") { trimmed.removeFirst() }
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            var rawLine = String(raw)
            if line == 1, rawLine.hasPrefix("\u{FEFF}") { rawLine.removeFirst() }
            let fields = rawLine.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 4 || fields.count == 5 else {
                throw LayoutError("行 \(line): タブ区切りの4列または5列が必要です。")
            }
            guard let key = MacKey.key(named: fields[0].trimmingCharacters(in: .whitespaces)) else {
                throw LayoutError("行 \(line): 未対応のキー名です。")
            }
            if result.rows[key] != nil { throw LayoutError("行 \(line): キーが重複しています。") }
            for value in fields.dropFirst() where value.count > 32 || value.contains("\0") {
                throw LayoutError("行 \(line): 出力は32文字以内にしてください。")
            }
            result.rows[key] = Mapping(normal: fields[1], left: fields[2], right: fields[3],
                                       shift: fields.count == 5 ? fields[4] : nil)
        }
        if result.rows.isEmpty { throw LayoutError("配列が空です。") }
        return result
    }

    /// 内蔵NICOLA配列。
    public static let builtIn: Layout = {
        do { return try YabLayout.parse(YabLayout.builtInText) } catch { fatalError("内蔵NICOLA配列を読み込めません: \(error)") }
    }()
}
