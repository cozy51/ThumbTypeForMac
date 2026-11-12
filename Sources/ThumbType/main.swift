import AppKit
import Combine
import SwiftUI

/// メニューバー常駐（Windows版の通知領域アイコンに相当）。
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let controller = AppController()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let startItem = NSMenuItem(title: "開始", action: #selector(start), keyEquivalent: "")
    private let stopItem = NSMenuItem(title: "停止・通常入力へ", action: #selector(stop), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .contains(where: { $0 != NSRunningApplication.current }) {
            let alert = NSAlert()
            alert.messageText = "ThumbTypeはすでに起動しています。"
            alert.informativeText = "メニューバーのキーボードアイコンから操作してください。"
            alert.runModal()
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
        let settings = NSMenuItem(title: "設定…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "ThumbTypeを終了", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu

        controller.$running.combineLatest(controller.$statusMessage)
            .receive(on: RunLoop.main)
            .sink { [weak self] running, message in self?.update(running: running, message: message) }
            .store(in: &cancellables)

        // Windows版と同じく、起動時に自動開始します。
        controller.startAtLaunch()
        if !controller.running { showSettings() }
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
