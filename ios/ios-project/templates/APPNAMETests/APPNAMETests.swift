import Testing

@testable import APPNAME

// App-target unit tests (Swift Testing, hosted in the app). Test app-specific
// stores and orchestration here; shared/module logic is tested in
// Packages/Modules/Tests instead.
@Suite("APPNAME")
struct APPNAMETests {
    @Test func rootViewConstructs() {
        _ = RootView()
    }
}
