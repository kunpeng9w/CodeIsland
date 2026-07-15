import XCTest
@testable import CodeIsland

final class CopilotHookSupportTests: XCTestCase {
    func testCopilotDefaultEventsMatchCurrentHookContract() throws {
        let events = ConfigInstaller.defaultEvents(for: .copilot)

        XCTAssertEqual(events.map(\.0), [
            "sessionStart",
            "sessionEnd",
            "userPromptSubmitted",
            "preToolUse",
            "postToolUse",
            "postToolUseFailure",
            "permissionRequest",
            "notification",
            "agentStop",
            "subagentStart",
            "subagentStop",
            "preCompact",
            "errorOccurred",
        ])

        let permission = try XCTUnwrap(events.first { $0.0 == "permissionRequest" })
        XCTAssertEqual(permission.1, 86_400)
        XCTAssertFalse(permission.2)

        let preToolUse = try XCTUnwrap(events.first { $0.0 == "preToolUse" })
        XCTAssertEqual(preToolUse.1, 86_400)
        XCTAssertFalse(preToolUse.2)
    }

    func testBuiltInCopilotUsesDefaultEventSet() throws {
        let copilot = try XCTUnwrap(ConfigInstaller.allCLIs.first { $0.source == "copilot" })

        XCTAssertEqual(copilot.events.map(\.0), ConfigInstaller.defaultEvents(for: .copilot).map(\.0))
    }

    func testLegacySixEventInstallNeedsMigration() {
        var hooks: [String: Any] = [:]
        for event in [
            "sessionStart",
            "sessionEnd",
            "userPromptSubmitted",
            "preToolUse",
            "postToolUse",
            "errorOccurred",
        ] {
            hooks[event] = [[
                "type": "command",
                "bash": "/Users/test/.codeisland/codeisland-bridge --source copilot --event \(event)",
                "timeoutSec": 5,
            ]]
        }

        XCTAssertTrue(ConfigInstaller.copilotHooksNeedMigration(hooks))

        hooks["permissionRequest"] = [[
            "type": "command",
            "bash": "/Users/test/.codeisland/codeisland-bridge --source copilot --event permissionRequest",
            "timeoutSec": 86_400,
        ]]
        XCTAssertTrue(ConfigInstaller.copilotHooksNeedMigration(hooks))

        hooks["preToolUse"] = [[
            "type": "command",
            "bash": "/Users/test/.codeisland/codeisland-bridge --source copilot --event preToolUse",
            "timeoutSec": 86_400,
        ]]
        XCTAssertFalse(ConfigInstaller.copilotHooksNeedMigration(hooks))
    }
}
