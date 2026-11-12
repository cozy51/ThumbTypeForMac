/// 同時打鍵の判定を行う純粋な状態機械です。OSへの副作用はありません（Windows版 Engine の移植）。
///
/// - 文字→親指、親指→文字のどちらも時間範囲内（境界を含む）で同時打鍵と判定します。
/// - 文字キーを先に離すと通常文字が確定し、その後の親指は遡って適用しません。
/// - 未使用の親指は離した時に元のキーを1回送ります（単独打鍵）。
/// - 左右の親指を押した場合は、後から押した親指の層を使います。
public final class Engine {
    public enum Layer { case normal, left, right, pinky }

    public var layout: Layout
    public var left: Int = MacKey.space
    public var right: Int = MacKey.rightShift
    /// 同時打鍵の時間範囲（ミリ秒）。
    public var window: Int64 = 65
    public var leftTap = true, rightTap = true
    public var leftHold = false, rightHold = false
    public var repeatEnabled = true
    /// キー配列変更モード（親指キーは通常動作）。
    public var direct = false
    /// 小指シフト中。
    public var pinky = false

    /// 文字列を出力します。
    public var onText: (String) -> Void = { _ in }
    /// キーを1回打鍵します（Backspace・Escape・親指の単独打鍵）。
    public var onTap: (Int) -> Void = { _ in }

    private var down = Set<Int>()
    private var outputs: [Int: String] = [:]
    private var pending: Int?
    private var pendingTime: Int64 = 0
    private var thumb: Int?
    private var thumbTime: Int64 = 0
    private var used = false

    public init(layout: Layout) { self.layout = layout }

    public var hasPending: Bool { pending != nil }

    public func reset() {
        down.removeAll()
        outputs.removeAll()
        pending = nil
        thumb = nil
        used = false
    }

    private func output(_ value: String) {
        switch value {
        case Layout.none: return
        case Layout.backspace: onTap(MacKey.backspace)
        case Layout.escape: onTap(MacKey.escape)
        default: if !value.isEmpty { onText(value) }
        }
    }

    private func layer(for thumbKey: Int) -> Layer { thumbKey == left ? .left : .right }

    private func emit(_ key: Int, _ layer: Layer) {
        guard let m = layout.rows[key] else { return }
        var value: String
        switch layer {
        case .pinky: value = m.shift ?? m.normal
        case .left: value = m.left
        case .right: value = m.right
        case .normal: value = m.normal
        }
        if value.isEmpty { value = m.normal }
        output(value)
        outputs[key] = value
    }

    private func flushPending() {
        if let k = pending {
            pending = nil
            emit(k, .normal)
        }
    }

    /// 時間切れの保留文字を通常文字として確定します。
    public func tick(_ now: Int64) {
        if let k = pending, now - pendingTime > window {
            pending = nil
            emit(k, .normal)
        }
    }

    /// キーの押下・解放を処理します。true のとき元のキーイベントは破棄します。
    @discardableResult
    public func handle(_ key: Int, down isDown: Bool, at now: Int64) -> Bool {
        tick(now)
        let isThumb = !direct && (key == left || key == right)
        if !isDown {
            guard down.remove(key) != nil else { return false }
            outputs[key] = nil
            if key == pending {
                pending = nil
                emit(key, .normal)
            }
            if isThumb && key == thumb {
                if !used && ((key == left && leftTap) || (key == right && rightTap)) { onTap(key) }
                thumb = nil
                used = false
            }
            return true
        }
        if down.contains(key) {
            if repeatEnabled && !isThumb, let value = outputs[key] { output(value) }
            return true
        }
        if isThumb {
            down.insert(key)
            // 2つの親指は保留中の単独打鍵を取り消し、後から押した親指が層を選びます。
            thumb = key
            thumbTime = now
            used = false
            if let k = pending, now - pendingTime <= window {
                pending = nil
                used = true
                emit(k, layer(for: key))
            }
            return true
        }
        guard let mapping = layout.rows[key] else {
            flushPending()
            return false
        }
        down.insert(key)
        flushPending()
        if pinky && mapping.shift != nil {
            emit(key, .pinky)
            return true
        }
        if direct {
            emit(key, .normal)
            return true
        }
        if let t = thumb {
            let held = t == left ? leftHold : rightHold
            if now - thumbTime <= window || held {
                used = true
                emit(key, layer(for: t))
                return true
            }
        }
        pending = key
        pendingTime = now
        return true
    }
}

/// 押下と解放の組が、必ずフィルタの同じ側（破棄／通過）に留まるようにします（Windows版 InputRouter の移植）。
public final class InputRouter {
    private let engine: Engine
    private var consumed = Set<Int>(), passed = Set<Int>(), cancelled = Set<Int>()
    private var enabled = false

    public init(engine: Engine) { self.engine = engine }

    public var isEnabled: Bool { enabled }

    public func setEnabled(_ value: Bool) {
        if enabled != value {
            cancelled.formUnion(consumed)
            engine.reset()
            enabled = value
        }
    }

    public func tick(_ now: Int64, eligible: Bool) {
        setEnabled(eligible)
        if enabled { engine.tick(now) }
    }

    /// 全状態を破棄します（停止・配列変更時）。押下中のキーの解放は引き続き破棄します。
    public func cancelAll() {
        cancelled.formUnion(consumed)
        engine.reset()
    }

    @discardableResult
    public func handle(_ key: Int, down: Bool, at now: Int64, eligible: Bool) -> Bool {
        setEnabled(eligible)
        if !down {
            passed.remove(key)
            let discard = cancelled.remove(key) != nil
            if consumed.remove(key) != nil {
                if enabled && !discard { engine.handle(key, down: false, at: now) }
                return true
            }
            return false
        }
        if passed.contains(key) { return false }
        if consumed.contains(key) {
            if enabled && !cancelled.contains(key) { engine.handle(key, down: true, at: now) }
            return true
        }
        if enabled && engine.handle(key, down: true, at: now) {
            consumed.insert(key)
            return true
        }
        passed.insert(key)
        return false
    }
}
