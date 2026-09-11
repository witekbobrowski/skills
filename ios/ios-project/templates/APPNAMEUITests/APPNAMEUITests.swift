import XCTest

// UI smoke test: the app launches and shows the root view. Keep this target
// small — behavior belongs in APPNAMETests and the package test targets.
final class APPNAMEUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesToRootView() throws {
        let app = XCUIApplication()
        app.launch()

        let rootView = app.descendants(matching: .any)
            .matching(identifier: "root-view")
            .firstMatch
        XCTAssertTrue(
            rootView.waitForExistence(timeout: 10),
            "Root view did not appear after launch"
        )
    }
}
