import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    Circle()
                        .fill(controller.running ? Color.green : Color.secondary)
                        .frame(width: 10, height: 10)
                    Text(controller.statusMessage)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("開始") { controller.start() }
                        .disabled(controller.running)
                    Button("停止・通常入力へ") { controller.stop() }
                        .disabled(!controller.running)
                }
                if controller.needsPermission {
                    HStack {
                        Text("キー入力の変換には「アクセシビリティ」の許可が必要です。許可すると自動で開始します。")
                            .font(.callout)
                        Spacer()
                        Button("システム設定を開く") { controller.openAccessibilitySettings() }
                    }
                    HStack(alignment: .top) {
                        Text("一覧でオンなのに開始しない場合は、アプリを更新したため古い許可が残っています。右のボタンで許可をリセットすると、ThumbTypeが再起動します。そのあと表示される案内に従って、もう一度オンにしてください。")
                            .font(.callout)
                        Spacer()
                        Button("許可をリセットして再起動") { controller.resetPermissionsAndQuit() }
                    }
                    Text(controller.diagnostics)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("配列") {
                Text(controller.layoutTitle)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
                if !controller.layoutMessage.isEmpty {
                    Text(controller.layoutMessage)
                        .font(.callout)
                        .foregroundStyle(controller.layoutLoaded ? Color.secondary : Color.red)
                }
                HStack {
                    Button("内蔵NICOLA") { controller.useBuiltIn() }
                    Button("参照…") { controller.chooseLayoutFile() }
                    Spacer()
                    Text(".yab（やまぶきR形式の4セクション）／.tsv").font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("親指シフト") {
                Picker("動作", selection: $controller.directMode) {
                    Text("親指シフト（通常／左／右の3層）").tag(false)
                    Text("キー配列変更（親指キーは通常動作）").tag(true)
                }
                Picker("左親指キー", selection: $controller.leftThumb) {
                    ForEach(ThumbKey.allCases) { Text($0.label).tag($0) }
                }
                Picker("右親指キー", selection: $controller.rightThumb) {
                    ForEach(ThumbKey.allCases) { Text($0.label).tag($0) }
                }
                if controller.leftThumb == controller.rightThumb {
                    Text("左右の親指には別のキーを指定してください。").foregroundStyle(.red)
                }
                HStack {
                    Text("同時打鍵の時間範囲")
                    Slider(value: $controller.window, in: 10...300, step: 1)
                    Text("\(Int(controller.window)) ms")
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }
                Toggle("左親指の単独打鍵（離した時に元のキーを1回送る）", isOn: $controller.leftTap)
                Toggle("右親指の単独打鍵（離した時に元のキーを1回送る）", isOn: $controller.rightTap)
                Toggle("左親指の連続シフト（押している間は時間範囲を過ぎてもシフト）", isOn: $controller.leftHold)
                Toggle("右親指の連続シフト（押している間は時間範囲を過ぎてもシフト）", isOn: $controller.rightHold)
                Toggle("キーリピート", isOn: $controller.repeatEnabled)
                Text("文字→親指、親指→文字の両順序に対応します。左右を同時に押した場合は、後から押した親指を優先します。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("出力") {
                Picker("出力方式", selection: $controller.outputMode) {
                    ForEach(OutputMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
                Text("ローマ字で送ると、かなはIMEの未確定文字になり、そのまま漢字変換できます。数字・記号・濁点などローマ字で打てない文字はUnicodeで送ります。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("起動設定") {
                Toggle("ログイン時に起動する", isOn: Binding(
                    get: { controller.launchAtLogin },
                    set: { controller.setLaunchAtLogin($0) }))
                if !controller.loginMessage.isEmpty {
                    Text(controller.loginMessage).font(.callout).foregroundStyle(.orange)
                }
            }

            Section {
                Text("""
                IMEが日本語入力（ひらがな・カタカナ）のときだけ配列を変換します。英数・ABC・状態不明では通常入力を通します。
                Control・Option・Commandを使うショートカットは素通しします。親指以外のShiftは小指シフトです。
                ウインドウを閉じても動作は継続します。完全に終了するにはメニューバーの「終了」を選びます。
                緊急停止：Control + Option + F12
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 600)
        .frame(minHeight: 560)
    }
}
