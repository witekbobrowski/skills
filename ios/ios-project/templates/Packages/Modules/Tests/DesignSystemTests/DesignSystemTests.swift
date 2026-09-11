import Testing
@testable import DesignSystem

@Suite("DesignSystem")
struct DesignSystemTests {
    @Test func cornerRadiusIsPositive() {
        #expect(DesignSystem.cornerRadius > 0)
    }
}
