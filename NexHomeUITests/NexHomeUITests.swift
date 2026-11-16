import XCTest

/// Taps through the real app in the simulator: cards open their controls, switches, quick
/// controls, segmented modes, the fader, hold-to-confirm scenes and Setup all change state.
/// Every test starts from the original house (`-uiTesting YES` clears saved edits).
final class NexHomeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @MainActor
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "YES"] + arguments
        app.launch()
        return app
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func element(_ app: XCUIApplication, id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func element(_ app: XCUIApplication, idPrefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", idPrefix))
            .firstMatch
    }

    /// Waits until `predicate` holds for `element`.
    private func wait(_ element: XCUIElement, _ format: String, timeout: TimeInterval = 6) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: format), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func closeSheet(_ app: XCUIApplication, _ sheet: XCUIElement) {
        let close = app.buttons["Close"]
        if close.exists && close.isHittable {
            close.tap()
        } else {
            sheet.swipeDown(velocity: .fast)
        }
    }

    // MARK: - Tests

    /// Rooms → Living Room → tap a device card → its controls open; Close dismisses them.
    @MainActor
    func testTappingADeviceCardOpensItsControls() {
        let app = launch()
        app.tabBars.buttons["Rooms"].tap()

        let livingRoom = element(app, id: "room.0")
        XCTAssertTrue(livingRoom.waitForExistence(timeout: 10), "Rooms shows the Living Room tile")
        livingRoom.tap()

        let card = element(app, idPrefix: "deviceCard.")
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The room lists device cards")
        snap(app, "1-room")
        card.tap()

        let sheet = element(app, id: "deviceSheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 6), "Tapping a device card opens its controls")
        snap(app, "1-sheet-open")

        closeSheet(app, sheet)
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 6), "The sheet closes")
    }

    /// A Featured card on Home opens too (cards in a different screen and scroll position).
    @MainActor
    func testTappingAFeaturedCardOnHomeOpensItsControls() {
        let app = launch()
        let card = element(app, idPrefix: "deviceCard.")
        for _ in 0..<12 where !(card.exists && card.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(card.isHittable, "Home shows a Featured device card")
        card.tap()
        XCTAssertTrue(element(app, id: "deviceSheet").waitForExistence(timeout: 6))
        snap(app, "2-featured-sheet")
    }

    /// The master power switch in a light's sheet turns it off and the status follows.
    @MainActor
    func testPowerSwitchTurnsALightOff() {
        let app = launch(["-openKind", "DIMMER"])
        let toggle = app.switches["powerToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "The light sheet has a power switch")
        let status = element(app, id: "sheetStatus")
        let before = status.label
        let valueBefore = toggle.value as? String

        toggle.tap()
        if toggle.value as? String == valueBefore {
            toggle.switches.firstMatch.tap()
        }

        XCTAssertTrue(wait(toggle, "value != '\(valueBefore ?? "")'"), "The switch flips")
        XCTAssertTrue(wait(status, "label != '\(before)'"), "The status line follows the switch")
        snap(app, "3-light-off")
    }

    /// Dragging the brightness fader changes the light's level.
    @MainActor
    func testDraggingTheBrightnessFaderChangesTheLevel() {
        let app = launch(["-openKind", "DIMMER"])
        let status = element(app, id: "sheetStatus")
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        let before = status.label

        let fader = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Level'")).firstMatch
        XCTAssertTrue(fader.waitForExistence(timeout: 6), "The light sheet has a brightness fader")
        let start = fader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        let end = fader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        start.press(forDuration: 0.05, thenDragTo: end)

        XCTAssertTrue(wait(status, "label != '\(before)'"), "Dragging the fader changes the brightness")
        snap(app, "4-fader-dragged")
    }

    /// Tapping a mode in the thermostat's segmented control selects it.
    @MainActor
    func testThermostatModeCanBeChanged() {
        let app = launch(["-openKind", "THERMOSTAT_DIAL"])
        XCTAssertTrue(element(app, id: "deviceSheet").waitForExistence(timeout: 10))
        let auto = app.buttons["Auto"].firstMatch
        XCTAssertTrue(auto.waitForExistence(timeout: 6), "The thermostat has an Auto mode")
        auto.tap()
        XCTAssertTrue(wait(auto, "selected == true"), "Auto becomes the selected mode")
        snap(app, "5-thermostat-auto")
    }

    /// The lock orb on a lock card locks/unlocks without opening the sheet.
    @MainActor
    func testQuickControlOnACardWorks() {
        let app = launch()
        app.tabBars.buttons["Security"].tap()
        let orb = app.buttons.matching(identifier: "quickControl").firstMatch
        XCTAssertTrue(orb.waitForExistence(timeout: 10), "Lock cards have a quick lock button")
        let before = orb.value as? String ?? ""
        orb.tap()
        XCTAssertTrue(wait(orb, "value != '\(before)'"), "Tapping the quick button changes the lock")
        XCTAssertFalse(element(app, id: "deviceSheet").exists, "The quick button doesn't open the sheet")
        snap(app, "6-quick-control")
    }

    /// Holding the Morning scene orb applies the scene.
    @MainActor
    func testHoldingASceneAppliesIt() {
        let app = launch()
        let morning = app.buttons["Morning"].firstMatch
        for _ in 0..<8 where !(morning.exists && morning.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(morning.isHittable, "Home shows the Morning scene")
        morning.press(forDuration: 1.6)
        snap(app, "7-scene-held")

        for _ in 0..<10 { app.swipeDown() }
        let subtitle = element(app, id: "heroSubtitle")
        XCTAssertTrue(subtitle.waitForExistence(timeout: 6))
        XCTAssertTrue(wait(subtitle, "label CONTAINS 'Morning scene'"), "The scene is applied")
    }

    /// The setup wizard: + → choose Floor Lamp → it is "found" → set up → name it → add → open it.
    @MainActor
    func testSetupWizardFindsAndAddsADevice() {
        let app = launch()
        app.buttons["Add Device"].firstMatch.tap()

        let lamp = element(app, id: "setupType.FLOOR_LAMP")
        XCTAssertTrue(lamp.waitForExistence(timeout: 8), "The wizard asks what to set up")
        snap(app, "9-wizard-choose")
        lamp.tap()

        XCTAssertTrue(element(app, id: "setupSearching").waitForExistence(timeout: 4), "It searches")
        snap(app, "9-wizard-searching")

        let start = app.buttons["setupStart"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "It finds the device")
        snap(app, "9-wizard-found")
        start.tap()

        XCTAssertTrue(element(app, id: "setupPairing").waitForExistence(timeout: 4), "It pairs")
        snap(app, "9-wizard-pairing")

        let name = app.textFields["setupName"]
        XCTAssertTrue(name.waitForExistence(timeout: 15), "It asks for a name and room")
        app.buttons["Clear name"].firstMatch.tap()
        name.tap()
        name.typeText("Reading Lamp")
        snap(app, "9-wizard-naming")
        app.buttons["setupFinish"].tap()

        let done = element(app, id: "setupDoneTitle")
        XCTAssertTrue(done.waitForExistence(timeout: 6))
        XCTAssertTrue(wait(done, "label CONTAINS 'Reading Lamp'"), "The new device is ready")
        snap(app, "9-wizard-done")

        app.buttons["Open Controls"].firstMatch.tap()
        let sheet = element(app, id: "deviceSheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 8), "Its controls open")
        XCTAssertTrue(app.staticTexts["Reading Lamp"].firstMatch.waitForExistence(timeout: 4))
        let toggle = app.switches["powerToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 4), "The new lamp can be switched")
        let before = toggle.value as? String
        toggle.tap()
        if toggle.value as? String == before { toggle.switches.firstMatch.tap() }
        XCTAssertTrue(wait(toggle, "value != '\(before ?? "")'"), "The new lamp responds")
        snap(app, "9-new-device-controls")
    }

    /// Setup's house controls act on the whole house, and a room can be added.
    @MainActor
    func testSetupHouseControlsAndAddingARoom() {
        let app = launch(["-openSetup", "YES"])
        let banner = element(app, id: "addDeviceBanner")
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "Setup opens")
        snap(app, "10-setup")

        let lightsOff = element(app, id: "houseAction.lightsOff")
        for _ in 0..<8 where !(lightsOff.exists && lightsOff.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(lightsOff.isHittable, "Setup has house controls")
        snap(app, "10-house-controls")
        lightsOff.tap()
        XCTAssertTrue(wait(lightsOff, "label CONTAINS '0 of'"), "All lights go off")

        let addRoom = element(app, id: "addRoomTile")
        for _ in 0..<8 where !(addRoom.exists && addRoom.isHittable) {
            app.swipeDown()
        }
        addRoom.tap()
        let sunroom = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sunroom'")).firstMatch
        XCTAssertTrue(sunroom.waitForExistence(timeout: 6), "Rooms can be added")
        sunroom.tap()
        app.buttons["Add"].firstMatch.tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Sunroom'"))
                .firstMatch.waitForExistence(timeout: 6),
            "The new room is listed in Setup"
        )
        snap(app, "10-room-added")

        app.buttons["Done"].firstMatch.tap()
        app.tabBars.buttons["Rooms"].tap()
        let tile = element(app, id: "room.25")
        for _ in 0..<12 where !(tile.exists && tile.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(tile.isHittable, "The Sunroom appears in Rooms")
        tile.tap()
        XCTAssertTrue(app.staticTexts["No Devices Yet"].firstMatch.waitForExistence(timeout: 6))
        snap(app, "10-empty-room")
    }
}
