import XCTest
@testable import ThumbTypeCore

/// Windows版 SelfTest.cs の入力処理・配列テストを移植したものです。実際のキー入力は送りません。
final class EngineTests: XCTestCase {
    var events: [String] = []
    var e: Engine!

    override func setUp() {
        super.setUp()
        events = []
        e = Engine(layout: try! Layout.parseTSV("A\ta\tL\tR\nB\tb\tX\tY\n"))
        e.onText = { [unowned self] in self.events.append($0) }
        e.onTap = { [unowned self] in self.events.append("tap\($0)") }
    }

    func reset() {
        e.reset()
        events.removeAll()
        e.direct = false
        e.repeatEnabled = true
        e.leftTap = true
        e.rightTap = true
        e.leftHold = false
        e.rightHold = false
        e.pinky = false
    }

    var result: String { events.joined(separator: "|") }
    let A = MacKey.a, B = MacKey.b, J = MacKey.j

    func testTimeoutAndBoundary() {
        e.handle(A, down: true, at: 0)
        e.tick(65)
        XCTAssertTrue(events.isEmpty, "deadline is inclusive")
        e.tick(66)
        XCTAssertEqual(result, "a", "timeout normal")
        e.handle(A, down: false, at: 70)
        XCTAssertEqual(result, "a", "no duplicate keyup")
    }

    func testCharacterThenThumb() {
        e.handle(A, down: true, at: 0); e.handle(e.left, down: true, at: 65)
        e.handle(A, down: false, at: 70); e.handle(e.left, down: false, at: 80)
        XCTAssertEqual(result, "L", "character then left / exact boundary / suppress thumb tap")
    }

    func testThumbThenCharacter() {
        e.handle(e.right, down: true, at: 0); e.handle(A, down: true, at: 40)
        e.handle(e.right, down: false, at: 50); e.handle(A, down: false, at: 60)
        XCTAssertEqual(result, "R")
    }

    func testStandaloneThumb() {
        e.handle(e.left, down: true, at: 0); e.handle(e.left, down: false, at: 30)
        XCTAssertEqual(result, "tap\(MacKey.space)")
        reset()
        e.leftTap = false
        e.handle(e.left, down: true, at: 0); e.handle(e.left, down: false, at: 30)
        XCTAssertTrue(events.isEmpty, "disabled standalone")
    }

    func testQuickReleaseAndLateThumb() {
        e.handle(A, down: true, at: 0); e.handle(A, down: false, at: 10); e.tick(100)
        XCTAssertEqual(result, "a", "quick key release")
        reset()
        e.handle(e.left, down: true, at: 0); e.handle(A, down: true, at: 66); e.handle(A, down: false, at: 70)
        XCTAssertEqual(result, "a", "late thumb not chord")
    }

    func testContinuousHeldThumb() {
        e.leftHold = true
        e.handle(e.left, down: true, at: 0); e.handle(A, down: true, at: 200); e.handle(A, down: false, at: 210)
        e.handle(B, down: true, at: 300); e.handle(B, down: false, at: 310); e.handle(e.left, down: false, at: 320)
        XCTAssertEqual(result, "L|X")
    }

    func testRepeat() {
        e.handle(A, down: true, at: 0); e.tick(70); e.handle(B, down: true, at: 80); e.tick(150); e.handle(A, down: true, at: 160)
        XCTAssertEqual(result, "a|b|a", "repeat remembers each physical key")
        reset()
        e.repeatEnabled = false
        e.handle(A, down: true, at: 0); e.tick(70); e.handle(A, down: true, at: 80)
        XCTAssertEqual(result, "a", "repeat disabled")
    }

    func testDirectMode() {
        e.direct = true
        XCTAssertFalse(e.handle(e.left, down: true, at: 0))
        XCTAssertTrue(events.isEmpty, "direct mode thumb pass through")
        e.handle(A, down: true, at: 10)
        XCTAssertEqual(result, "a", "direct mode immediate normal")
    }

    func testResetAndUnmapped() {
        e.handle(A, down: true, at: 0); e.reset(); e.tick(100)
        XCTAssertTrue(events.isEmpty, "stop discards pending text")
        reset()
        e.handle(A, down: true, at: 0)
        XCTAssertFalse(e.handle(MacKey.returnKey, down: true, at: 10))
        XCTAssertEqual(result, "a", "unmapped key flushes earlier text")
    }

    func testTwoThumbsNewestWins() {
        e.handle(e.left, down: true, at: 0); e.handle(e.right, down: true, at: 10); e.handle(A, down: true, at: 20)
        e.handle(e.left, down: false, at: 30); e.handle(e.right, down: false, at: 40)
        XCTAssertEqual(result, "R")
    }

    func testEmptyLayerFallsBack() throws {
        e.layout = try Layout.parseTSV("A\ta\t\t\n")
        XCTAssertEqual(e.layout.rows.count, 1)
        e.handle(e.left, down: true, at: 0); e.handle(A, down: true, at: 10)
        XCTAssertEqual(result, "a")
    }

    func testTSVRejections() {
        XCTAssertThrowsError(try Layout.parseTSV("A\ta\tb\tc\nA\tx\ty\tz"), "duplicate keys")
        XCTAssertThrowsError(try Layout.parseTSV("LControlKey\ta\tb\tc"), "modifier mapping")
        XCTAssertThrowsError(try Layout.parseTSV("A,a,b,c"), "malformed file")
        XCTAssertThrowsError(try Layout.parseTSV("# only comment\n"), "empty layout")
    }

    func testRightShiftThumbWithNICOLA() {
        e.layout = .builtIn
        e.left = MacKey.space; e.right = MacKey.rightShift; e.rightHold = true
        e.handle(MacKey.rightShift, down: true, at: 0); e.handle(J, down: true, at: 200)
        e.handle(J, down: false, at: 220); e.handle(MacKey.rightShift, down: false, at: 240)
        XCTAssertEqual(result, "お", "held right Shift + J gives お without standalone Shift")
        events.removeAll()
        e.handle(J, down: true, at: 300); e.handle(J, down: false, at: 320); e.tick(400)
        XCTAssertEqual(result, "と", "J after right Shift release gives と")
        reset()
        e.rightHold = false
        e.handle(MacKey.rightShift, down: true, at: 0); e.handle(J, down: true, at: 40)
        XCTAssertEqual(result, "お", "right Shift + J within timing window")
    }

    func testRouter() {
        e.layout = .builtIn
        e.left = MacKey.space; e.right = MacKey.rightShift; e.rightHold = true
        let router = InputRouter(engine: e)
        XCTAssertFalse(router.handle(J, down: true, at: 0, eligible: false))
        XCTAssertFalse(router.handle(J, down: false, at: 20, eligible: false))
        XCTAssertTrue(events.isEmpty, "English J passes down and up without kana")
        router.handle(J, down: true, at: 30, eligible: true); router.handle(J, down: false, at: 40, eligible: true)
        XCTAssertEqual(result, "と", "Japanese J produces kana"); events.removeAll()
        router.handle(MacKey.rightShift, down: true, at: 100, eligible: true); router.handle(J, down: true, at: 120, eligible: true)
        router.handle(J, down: false, at: 130, eligible: true); router.handle(MacKey.rightShift, down: false, at: 140, eligible: true)
        XCTAssertEqual(result, "お", "Japanese right Shift J still works"); events.removeAll()
        router.handle(J, down: true, at: 200, eligible: true); router.tick(300, eligible: false)
        XCTAssertTrue(events.isEmpty, "switch to English discards pending kana before timer")
        XCTAssertTrue(router.handle(J, down: false, at: 310, eligible: false))
        XCTAssertTrue(events.isEmpty, "suppressed down keeps matching release suppressed after mode change")
        router.handle(J, down: true, at: 400, eligible: false)
        XCTAssertFalse(router.handle(J, down: true, at: 410, eligible: true))
        XCTAssertFalse(router.handle(J, down: false, at: 420, eligible: true))
        XCTAssertTrue(events.isEmpty, "English held key stays native when switching to Japanese")
        router.handle(MacKey.rightShift, down: true, at: 500, eligible: true); router.tick(510, eligible: false); router.tick(520, eligible: true)
        router.handle(MacKey.rightShift, down: true, at: 530, eligible: true); router.handle(MacKey.rightShift, down: false, at: 540, eligible: true)
        XCTAssertTrue(events.isEmpty, "cancelled thumb does not replay or reactivate after toggling twice")
        router.handle(J, down: true, at: 600, eligible: false); router.handle(J, down: false, at: 610, eligible: false)
        router.handle(J, down: true, at: 620, eligible: true); router.handle(J, down: false, at: 630, eligible: true)
        XCTAssertEqual(result, "と", "new presses remap again after re-enabling Japanese mode")
    }

    func testNICOLASpecialOutputs() {
        e.layout = .builtIn
        e.left = MacKey.space; e.right = MacKey.rightShift
        e.handle(MacKey.semicolon, down: true, at: 0); e.handle(MacKey.semicolon, down: false, at: 10)
        XCTAssertEqual(result, "ん", "semicolon produces ん"); reset()
        e.handle(MacKey.rightShift, down: true, at: 0); e.handle(MacKey.semicolon, down: true, at: 10)
        e.handle(MacKey.semicolon, down: false, at: 20); e.handle(MacKey.rightShift, down: false, at: 30)
        XCTAssertEqual(result, "っ", "right thumb semicolon produces small tsu"); reset()
        e.handle(MacKey.rightShift, down: true, at: 0); e.handle(MacKey.z, down: true, at: 10)
        e.handle(MacKey.z, down: false, at: 20); e.handle(MacKey.rightShift, down: false, at: 30)
        XCTAssertTrue(events.isEmpty, "無 is explicit no output, never normal fallback"); reset()
        e.handle(MacKey.colon, down: true, at: 0); e.handle(MacKey.colon, down: false, at: 10)
        XCTAssertEqual(result, "tap\(MacKey.backspace)", "後 sends Backspace"); reset()
        e.handle(MacKey.closeBracket, down: true, at: 0); e.handle(MacKey.closeBracket, down: false, at: 10)
        XCTAssertEqual(result, "tap\(MacKey.escape)", "逃 sends Escape"); reset()
        e.pinky = true
        e.handle(MacKey.one, down: true, at: 0); e.handle(MacKey.one, down: true, at: 70); e.handle(MacKey.one, down: false, at: 80)
        XCTAssertEqual(result, "！|！", "pinky shift symbols and repeat")
    }
}
