import AppKit
import Carbon
import CoreGraphics
import ThumbTypeCore

/// 現在の入力ソースの入力モードID（例: com.apple.inputmethod.Japanese）。
func currentInputModeID() -> String? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
    for property in [kTISPropertyInputModeID, kTISPropertyInputSourceID] {
        if let pointer = TISGetInputSourceProperty(source, property) {
            return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
        }
    }
    return nil
}

private func keyboardTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                                 userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let service = Unmanaged<KeyboardService>.fromOpaque(userInfo).takeUnretainedValue()
    return service.handle(type: type, event: event)
}

/// キーボードのイベントタップ（Windows版の低レベルキーボードフックに相当）。
/// メインスレッドのランループで動作します。
final class KeyboardService {
    let engine: Engine
    let router: InputRouter
    let sender: OutputSender
    /// 緊急停止（Control + Option + F12）や異常時に呼ばれます。
    var onFailure: (String) -> Void = { _ in }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var active = false

    init(engine: Engine, router: InputRouter, sender: OutputSender) {
        self.engine = engine
        self.router = router
        self.sender = sender
        engine.onText = { [weak sender] value in
            sender?.text(value)
        }
        engine.onTap = { [weak sender] key in
            sender?.tap(key)
        }
    }

    deinit { stop() }

    static func now() -> Int64 { Int64(DispatchTime.now().uptimeNanoseconds / 1_000_000) }

    /// イベントタップを開始します。権限がない場合などは false を返します。
    func start() -> Bool {
        if active { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: CGEventMask(mask), callback: keyboardTapCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        router.cancelAll()
        active = true
        // 時間切れの保留文字を確定するためのタイマー。
        let timer = Timer(timeInterval: 0.005, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        return true
    }

    func stop() {
        active = false
        timer?.invalidate()
        timer = nil
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        router.cancelAll()
    }

    private func tick() {
        guard active, engine.hasPending else { return }
        router.tick(Self.now(), eligible: canConvert(flags: CGEventSource.flagsState(.combinedSessionState).rawValue))
    }

    /// Windows版 CanConvert に相当。小指シフト状態の更新も行います。
    private func canConvert(flags: UInt64) -> Bool {
        let thumbs: Set<Int> = [engine.left, engine.right]
        func held(_ key: Int) -> Bool {
            guard let bit = MacKey.modifierDeviceBits[key], !thumbs.contains(key) else { return false }
            return flags & bit != 0
        }
        let pinky = held(MacKey.leftShift) || held(MacKey.rightShift)
        if engine.pinky != pinky {
            router.setEnabled(false)
            engine.pinky = pinky
        }
        let shortcut = [MacKey.leftControl, MacKey.rightControl, MacKey.leftOption, MacKey.rightOption,
                        MacKey.leftCommand, MacKey.rightCommand].contains(where: held)
        // 左右を区別するビットのない修飾（仮想キーボード等）も安全側で素通しします。
        let generic: [(CGEventFlags, UInt64)] = [(.maskControl, 0x2001), (.maskAlternate, 0x60), (.maskCommand, 0x18)]
        let genericOnly = generic.contains { flags & $0.0.rawValue != 0 && flags & $0.1 == 0 }
        if shortcut || genericOnly { return false }
        if pinky && !engine.layout.hasPinky { return false }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return false
        }
        return InputSourceRule.isJapaneseKanaMode(currentInputModeID())
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOSにタップを無効化された場合は、状態を破棄して再開します。
            router.cancelAll()
            if active, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        case .keyDown, .keyUp, .flagsChanged:
            break
        default:
            return pass
        }
        guard active, event.getIntegerValueField(.eventSourceUserData) != OutputSender.tag else { return pass }
        let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.rawValue
        let isDown: Bool
        if type == .flagsChanged {
            guard let bit = MacKey.modifierDeviceBits[key] else { return pass }
            isDown = flags & bit != 0
        } else {
            isDown = type == .keyDown
        }
        if type == .keyDown && key == MacKey.f12 && flags & CGEventFlags.maskControl.rawValue != 0
            && flags & CGEventFlags.maskAlternate.rawValue != 0 {
            stop()
            DispatchQueue.main.async { self.onFailure("緊急停止しました。通常の入力に戻りました。") }
            return pass
        }
        let eligible = canConvert(flags: flags)
        if router.handle(key, down: isDown, at: Self.now(), eligible: eligible) { return nil }
        return pass
    }
}
