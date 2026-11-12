import AppKit
import Combine
import SwiftUI

/// メニューバー常駐（Windows版の通知領域アイコンに相当）。
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let controller = AppController()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    static let showSettingsNotification = Notification.Name("io.github.cozy51.ThumbType.showSettings")
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let startItem = NSMenuItem(title: "開始", action: #selector(AppDelegate.start), keyEquivalent: "")
    private let stopItem = NSMenuItem(title: "停止・通常入力へ", action: #selector(AppDelegate.stop), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 二重起動の確認（自分自身はプロセスIDで除外します）。
        let myPID = ProcessInfo.processInfo.processIdentifier
        if let bundleID = Bundle.main.bundleIdentifier,
           let other = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.processIdentifier != myPID && !$0.isTerminated }) {
            // 既に動いている方に設定画面を開かせ、こちらは終了します。
            DistributedNotificationCenter.default().postNotificationName(
                Self.showSettingsNotification, object: nil, userInfo: nil, deliverImmediately: true)
            other.activate(options: [])
            NSApp.terminate(nil)
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        for item in [startItem, stopItem] {
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "設定…", action: #selector(AppDelegate.showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "ThumbTypeを終了", action: #selector(AppDelegate.quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu

        controller.$running.combineLatest(controller.$statusMessage)
            .receive(on: RunLoop.main)
            .sink { [weak self] running, message in self?.update(running: running, message: message) }
            .store(in: &cancellables)

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(AppDelegate.showSettings), name: Self.showSettingsNotification, object: nil)

        // Windows版と同じく、起動時に自動開始します。
        controller.startAtLaunch()
        // 初回起動時と停止中は設定画面を表示します。
        let defaults = UserDefaults.standard
        if !controller.running || !defaults.bool(forKey: "launchedBefore") { showSettings() }
        defaults.set(true, forKey: "launchedBefore")
    }

    /// 起動中にもう一度アプリを開いた場合は設定画面を出します（メニューバーのアイコンが隠れていても操作できるように）。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }

    private func update(running: Bool, message: String) {
        let symbol = running ? "keyboard.fill" : "keyboard"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "ThumbType")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = !running
        statusItem.button?.toolTip = "ThumbType \(AppController.version) — \(running ? "動作中" : "停止中")"
        statusLine.title = message
        startItem.isEnabled = !running
        stopItem.isEnabled = running
    }

    @objc private func start() {
        controller.start()
        if !controller.running { showSettings() }
    }

    @objc private func stop() { controller.stop() }

    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(controller: controller)))
            window.title = "ThumbType \(AppController.version)"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        controller.refreshLoginItem()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
