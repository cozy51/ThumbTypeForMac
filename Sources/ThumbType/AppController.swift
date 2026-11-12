import AppKit
import ApplicationServices
import Combine
import ServiceManagement
import ThumbTypeCore
import UniformTypeIdentifiers

/// 親指キーに指定できるキー。
enum ThumbKey: Int, CaseIterable, Identifiable {
    case eisu = 102, kana = 104, space = 49, leftShift = 56, rightShift = 60, leftCommand = 55, rightCommand = 54

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .eisu: return "英数"
        case .kana: return "かな"
        case .space: return "Space"
        case .leftShift: return "左Shift"
        case .rightShift: return "右Shift"
        case .leftCommand: return "左Command"
        case .rightCommand: return "右Command"
        }
    }
}

/// 設定・状態・キーボード処理をまとめるアプリ本体。すべてメインスレッドで扱います。
final class AppController: ObservableObject {
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    private let defaults = UserDefaults.standard
    private var loading = true

    // MARK: 設定（変更すると保存し、動作中でもすぐ反映します）

    /// 配列ファイルのパス。空なら内蔵NICOLA。
    @Published private(set) var layoutPath: String
    @Published var directMode: Bool { didSet { settingsChanged() } }
    @Published var leftThumb: ThumbKey { didSet { settingsChanged() } }
    @Published var rightThumb: ThumbKey { didSet { settingsChanged() } }
    @Published var window: Double { didSet { settingsChanged() } }
    @Published var leftTap: Bool { didSet { settingsChanged() } }
    @Published var rightTap: Bool { didSet { settingsChanged() } }
    @Published var leftHold: Bool { didSet { settingsChanged() } }
    @Published var rightHold: Bool { didSet { settingsChanged() } }
    @Published var repeatEnabled: Bool { didSet { settingsChanged() } }
    @Published var outputMode: OutputMode { didSet { settingsChanged() } }

    // MARK: 状態

    @Published private(set) var running = false
    @Published private(set) var statusMessage = "● 停止中 — 通常のキーボード入力です"
    @Published private(set) var layoutMessage = ""
    @Published private(set) var layoutLoaded = false
    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginMessage = ""
    @Published private(set) var needsPermission = false

    let engine: Engine
    let router: InputRouter
    let sender = OutputSender()
    private var service: KeyboardService?
    private var permissionTimer: Timer?

    init() {
        engine = Engine(layout: .builtIn)
        router = InputRouter(engine: engine)
        let d = defaults
        layoutPath = d.string(forKey: "layoutPath") ?? ""
        directMode = d.bool(forKey: "directMode")
        leftThumb = ThumbKey(rawValue: d.object(forKey: "leftThumb") as? Int ?? -1) ?? .space
        rightThumb = ThumbKey(rawValue: d.object(forKey: "rightThumb") as? Int ?? -1) ?? .rightShift
        window = d.object(forKey: "window") as? Double ?? 65
        leftTap = d.object(forKey: "leftTap") as? Bool ?? true
        rightTap = d.object(forKey: "rightTap") as? Bool ?? true
        leftHold = d.object(forKey: "leftHold") as? Bool ?? true
        rightHold = d.object(forKey: "rightHold") as? Bool ?? true
        repeatEnabled = d.object(forKey: "repeat") as? Bool ?? true
        outputMode = OutputMode(rawValue: d.string(forKey: "outputMode") ?? "") ?? .romaji
        loading = false
        refreshLoginItem()
        loadLayout(path: layoutPath)
        applySettings()
    }

    var layoutTitle: String { layoutPath.isEmpty ? "内蔵NICOLA（JIS・48キー・4層）" : layoutPath }

    // MARK: 開始・停止

    /// 起動時の自動開始。権限がなければ許可を求め、許可されたら開始します。
    func startAtLaunch() {
        if Self.isTrusted(prompt: false) {
            start()
        } else {
            _ = Self.isTrusted(prompt: true)
            needsPermission = true
            statusMessage = "● 停止中 — アクセシビリティの許可を待っています"
            waitForPermission()
        }
    }

    func start() {
        guard !running else { return }
        guard layoutLoaded else {
            statusMessage = "● 停止中 — 配列を読み込めません。配列を選び直してください"
            return
        }
        guard leftThumb != rightThumb else {
            statusMessage = "● 停止中 — 左右の親指には別のキーを指定してください"
            return
        }
        guard Self.isTrusted(prompt: true) else {
            needsPermission = true
            statusMessage = "● 停止中 — システム設定でアクセシビリティを許可してください"
            waitForPermission()
            return
        }
        needsPermission = false
        applySettings()
        let service = KeyboardService(engine: engine, router: router, sender: sender)
        service.onFailure = { [weak self] message in self?.stop(message: message) }
        guard service.start() else {
            statusMessage = "● 停止中 — キー入力の監視を開始できません（入力監視・アクセシビリティの許可を確認してください）"
            return
        }
        self.service = service
        running = true
        statusMessage = "● 動作中 — 緊急停止 Control + Option + F12"
    }

    func stop(message: String? = nil) {
        service?.stop()
        service = nil
        running = false
        statusMessage = message.map { "● 停止中 — \($0)" } ?? "● 停止中 — 通常のキーボード入力です"
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    private func waitForPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if Self.isTrusted(prompt: false) {
                timer.invalidate()
                self.permissionTimer = nil
                self.needsPermission = false
                self.start()
            }
        }
    }

    // MARK: 配列

    func useBuiltIn() { loadLayout(path: "") }

    func chooseLayoutFile() {
        let panel = NSOpenPanel()
        panel.title = "配列ファイルを選択"
        panel.allowedContentTypes = ["yab", "tsv", "txt"].compactMap { UTType(filenameExtension: $0) }
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url { loadLayout(path: url.path) }
    }

    /// 読み込みに成功した場合だけ配列の場所を保存します。失敗した場合は停止します。
    private func loadLayout(path: String) {
        do {
            let layout = path.isEmpty ? Layout.builtIn : try YabLayout.readFile(URL(fileURLWithPath: path))
            router.cancelAll()
            engine.layout = layout
            layoutPath = path
            defaults.set(path, forKey: "layoutPath")
            layoutLoaded = true
            layoutMessage = "配列を読み込みました（\(layout.rows.count)キー\(layout.hasPinky ? "・小指シフトあり" : "")）"
        } catch {
            // Windows版と同じく、失敗時は停止し、保存済みの配列の場所は変更しません。内蔵配列へも自動では戻しません。
            stop(message: "配列を読み込めません。ファイルを選び直してください")
            layoutPath = path
            layoutLoaded = false
            layoutMessage = "読み込めませんでした：\(error.localizedDescription)"
        }
    }

    // MARK: 設定の反映

    private func settingsChanged() {
        guard !loading else { return }
        let d = defaults
        d.set(directMode, forKey: "directMode")
        d.set(leftThumb.rawValue, forKey: "leftThumb")
        d.set(rightThumb.rawValue, forKey: "rightThumb")
        d.set(window, forKey: "window")
        d.set(leftTap, forKey: "leftTap")
        d.set(rightTap, forKey: "rightTap")
        d.set(leftHold, forKey: "leftHold")
        d.set(rightHold, forKey: "rightHold")
        d.set(repeatEnabled, forKey: "repeat")
        d.set(outputMode.rawValue, forKey: "outputMode")
        applySettings()
        if running && leftThumb == rightThumb { stop(message: "左右の親指には別のキーを指定してください") }
    }

    private func applySettings() {
        router.cancelAll()
        engine.left = leftThumb.rawValue
        engine.right = rightThumb.rawValue
        engine.window = Int64(window.rounded())
        engine.leftTap = leftTap
        engine.rightTap = rightTap
        engine.leftHold = leftHold
        engine.rightHold = rightHold
        engine.repeatEnabled = repeatEnabled
        engine.direct = directMode
        sender.mode = outputMode
    }

    // MARK: ログイン時の起動

    func refreshLoginItem() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        loginMessage = status == .requiresApproval
            ? "システム設定 →「一般」→「ログイン項目」で ThumbType を許可してください。" : ""
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            refreshLoginItem()
        } catch {
            refreshLoginItem()
            loginMessage = "ログイン項目を変更できません：\(error.localizedDescription)"
        }
    }
}
