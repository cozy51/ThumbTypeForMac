# ThumbType for Mac

Windows用の親指シフト・キー配列変更アプリ [ThumbType](https://github.com/cozy51/ThumbType)（v0.7）をmacOSへ移植したものです。
メニューバーに常駐し、JISキーボードで NICOLA 配列の親指シフト入力を行います。

- 同時打鍵の判定（文字→親指／親指→文字、時間範囲、単独打鍵、連続シフト、キーリピート、小指シフト）はWindows版のエンジンをそのまま移植しています。
- 内蔵NICOLA配列（JIS・48キー・4層）と、Windows版と同じ `.yab`（4セクション）・`.tsv`（4列／5列）を読み込めます。Windows版で作ったTSVもそのまま使えます。
- **Mac版の追加点**：かなをローマ字の打鍵としてIMEへ送るので、入力したかながそのまま未確定文字になり、**漢字変換できます**（Windows版と同じUnicode直接出力も選べます）。

## 動作環境

- macOS 13 Ventura 以降（Apple Silicon / Intel）
- JISキーボード（MacBookの日本語キーボードなど）。USキーボードでは記号キーの位置が異なります。
- 日本語入力プログラム（ことえり）、Google日本語入力、ATOK などのIME

## インストール

1. [Actions](../../actions) の最新の成功したビルド、またはReleasesから `ThumbType-mac.zip` をダウンロードして展開します。
2. `ThumbType.app` を「アプリケーション」フォルダへ移動します。
3. 初回は署名・公証がないため、そのままでは開けません。次のどちらかで開きます。
   - Finderで `ThumbType.app` を右クリック →「開く」（macOS 15以降は、一度開こうとした後に システム設定 →「プライバシーとセキュリティ」→「このまま開く」）
   - またはターミナルで：
     ```bash
     xattr -dr com.apple.quarantine /Applications/ThumbType.app
     ```
4. 「アクセシビリティ」の許可を求められたら、システム設定 →「プライバシーとセキュリティ」→「アクセシビリティ」で ThumbType をオンにします。許可すると自動で開始します。「入力監視」を求められた場合も許可してください。

アプリを更新（再ビルド）した場合は、アクセシビリティの一覧から古い ThumbType を削除（−）して、もう一度許可してください。

## 使い方

1. メニューバーのキーボードアイコンが ThumbType です。起動時に自動で開始します。
2. 入力ソースを「ひらがな」にして、テキストエディットなどで確認します。
3. 「設定…」で配列・親指キー・時間範囲などを変更できます。設定は自動保存され、動作中でもすぐ反映されます。

| 操作（初期設定） | 出力例 |
| --- | --- |
| J | と |
| 右Shift＋J | お |
| ;（セミコロン） | ん |
| Space＋; | よ |
| 右Shift＋; | っ |
| Space＋X | ー |
| 左Shift＋1 | ！（小指シフト） |
| :（コロン） | Backspace |
| ] | Escape |

### メニューバーのアイコンが見つからない場合

- 起動中にもう一度 `ThumbType.app` をダブルクリックすると、設定画面が開きます。
- ノッチのあるMacBookでは、メニューバーのアイコンが多いとノッチの裏に隠れることがあります。他の常駐アプリのアイコンを減らすか、⌘キーを押しながらアイコンをドラッグして並べ替えてください。
- macOS 26以降では、システム設定 →「メニューバー」で ThumbType の表示が許可されているか確認してください。
- 動いているかどうかは「アクティビティモニタ」で ThumbType を検索して確認できます。

### かなにならずローマ字のまま入力される場合

- 右親指キーが「右Shift」だと、IMEによっては「Shift＋文字」と判断して英字のまま入力することがあります。設定画面で右親指キーを「かな」（左親指を「英数」）に変えると確実です。
- それでも直らない場合は、出力方式を「Unicodeで直接送る」にしてください（漢字変換はできません）。

### 初期設定（Windows版と同じ）

- 左親指：Space、右親指：右Shift、同時打鍵 65ms、左右の単独打鍵・連続シフト有効、キーリピート有効
- 親指キーは 英数／かな／Space／左右Shift／左右Command から選べます。MacのJISキーボードでは「英数」「かな」を親指キーにするのもおすすめです（単独打鍵で従来どおり入力モードを切り替えられます）。

### 動作のルール

- 入力ソースが日本語入力（ひらがな・カタカナ）のときだけ配列を変換します。英数・ABC・状態不明では通常入力を通します。
- Control・Option・Commandを使うショートカットは素通しします（親指キーに指定したCommandを除く）。
- 親指に指定していないShiftは小指シフトです。小指シフトの定義がない配列ではShiftをそのまま通します。
- 文字キーを先に離すと通常文字が確定し、その後の親指は遡って適用しません。
- 未使用の親指は離した時に元のキーを1回送ります（Space・英数・かな）。Shift・Commandの単独打鍵は何も送りません。
- ThumbType自身の設定画面では変換しません。
- ウインドウを閉じても動作は継続します。完全に終了するにはメニューの「ThumbTypeを終了」を選びます。
- **緊急停止：Control＋Option＋F12**（停止後は「開始」で再開します）

### 出力方式

| 出力方式 | 内容 |
| --- | --- |
| ローマ字でIMEへ送る（初期設定） | かなを `to`・`xtu`・`nn` のようなローマ字の打鍵として送ります。IMEの未確定文字になり、そのまま漢字変換できます。「、」「。」「ー」「・」「「」「」」もIMEのキーとして送るので、IMEの句読点の設定に従います。数字・全角記号・濁点などローマ字で打てない文字はUnicodeで送ります。 |
| Unicodeで直接送る | Windows版と同じく、文字そのものを送ります。IMEの変換は行われません。 |

## 配列ファイル（.yab・.tsv）

Windows版と同じ形式です。「参照…」で選ぶと読み込み、成功した場合だけ場所を記憶します。

- `.yab`：やまぶきR形式のうち「ローマ字シフト無し」「ローマ字左親指シフト」「ローマ字右親指シフト」「ローマ字小指シフト」の4セクションを、それぞれ4行のJIS物理キー配列で記述したもの。UTF-8・BOM付きUTF-16・Shift-JISに対応します。**やまぶきRの全機能に対応するものではありません。**
- `.tsv`：UTF-8のタブ区切りで `キー名 / 通常 / 左親指 / 右親指 / 小指Shift（省略可）`。キー名はWindows版と同じ（`D1`、`Q`、`OemMinus`、`Oem1` など）です。予約出力 `{None}`、`{Backspace}`、`{Escape}` を使えます。

同梱の配列は `layouts/NICOLA.yab`（元配列）と `layouts/NICOLA.tsv`（変換済み）です。内蔵配列は `Sources/ThumbTypeCore/BuiltInNICOLA.swift` にあり、テストで `layouts/NICOLA.yab` と一致することを確認しています。

## 安全設計と制限

- システムのキーボード配列・IMEの設定・ドライバは変更しません。ネットワーク通信は行いません。
- 設定はユーザーのデフォルト（`~/Library/Preferences/io.github.cozy51.ThumbType.plist`）に保存します。
- ログイン時の起動は、設定画面の「ログイン時に起動する」で macOS のログイン項目に登録します（初期状態は登録しません）。
- パスワード入力欄など、macOSがキー入力の監視を禁止している場所では変換されません。
- 未署名・未公証のアプリです。

## ソースとビルド

Xcode（またはXcodeコマンドラインツール）が入ったMacで実行します。

```bash
swift test
```

```bash
./scripts/build-app.sh
```

`build/ThumbType.app` と配布用の `build/ThumbType-mac.zip` ができます。自分のMac用だけを速くビルドするには `ARCHS=arm64 ./scripts/build-app.sh`（Intel Macは `x86_64`）とします。

| ファイル | 内容 | Windows版の対応 |
| --- | --- | --- |
| `Sources/ThumbTypeCore/Engine.swift` | 同時打鍵エンジン・InputRouter（OS非依存） | `Engine.cs`・`InputRouter.cs` |
| `Sources/ThumbTypeCore/Layout.swift`・`YabLayout.swift` | TSV・YABの読み込み | `Engine.cs`（Layout）・`YabLayout.cs` |
| `Sources/ThumbTypeCore/MacKeys.swift` | JISキーボードのMacキーコード | — |
| `Sources/ThumbTypeCore/KanaRomaji.swift` | かな→ローマ字、入力ソースの判定 | `Native.cs`（IME判定） |
| `Sources/ThumbType/KeyboardService.swift` | イベントタップ（キー入力の横取り） | `Native.cs`（キーボードフック） |
| `Sources/ThumbType/OutputSender.swift` | 合成キーイベントの送信 | `Native.cs`（SendInput） |
| `Sources/ThumbType/AppController.swift`・`SettingsView.swift`・`main.swift` | メニューバー・設定画面 | `Program.cs`・`TrayIcon.cs` |

OSに依存しない部分のテスト（Windows版 `--self-test` の入力処理・配列テストを移植）は、GitHub Actions で macOS と Linux の両方で実行しています。

## 検証状況

- 自動テスト：同時打鍵エンジン・InputRouter・NICOLA全4層×48キー・YAB/TSV読み込み・ローマ字変換・入力ソース判定。
- 実機のMac・物理キーボード・各IMEでの動作は、受入確認が必要です。保存不要な文書で確認してください。
