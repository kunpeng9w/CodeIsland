import XCTest
@testable import CodeIslandCore

final class CopilotHookAdapterTests: XCTestCase {
    func testNormalizesCurrentCopilotHookEvents() {
        let expected = [
            "sessionStart": "SessionStart",
            "sessionEnd": "SessionEnd",
            "userPromptSubmitted": "UserPromptSubmit",
            "preToolUse": "PreToolUse",
            "postToolUse": "PostToolUse",
            "postToolUseFailure": "PostToolUseFailure",
            "permissionRequest": "PermissionRequest",
            "notification": "Notification",
            "agentStop": "Stop",
            "subagentStart": "SubagentStart",
            "subagentStop": "SubagentStop",
            "preCompact": "PreCompact",
            "errorOccurred": "Notification",
        ]

        for (event, normalized) in expected {
            XCTAssertEqual(EventNormalizer.normalize(event), normalized, event)
        }
    }

    func testConvertsClaudeStylePermissionResponseForCopilot() throws {
        let response = Data(#"{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","reason":"Not allowed"}}}"#.utf8)

        let converted = CopilotHookAdapter.permissionResponse(from: response)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: converted) as? [String: Any])

        XCTAssertEqual(json["behavior"] as? String, "deny")
        XCTAssertEqual(json["message"] as? String, "Not allowed")
        XCTAssertEqual(json.count, 2)
    }

    func testPreservesAlreadyNativeCopilotPermissionResponse() {
        let response = Data(#"{"behavior":"allow"}"#.utf8)

        XCTAssertEqual(CopilotHookAdapter.permissionResponse(from: response), response)
    }

    func testPromotesEveryVSCodePreToolUseToPermissionRequest() {
        var terminal: [String: Any] = [
            "hook_event_name": "PreToolUse",
            "tool_name": "run_in_terminal",
            "tool_input": ["command": "pwd"],
        ]

        XCTAssertTrue(CopilotHookAdapter.promoteVSCodePreToolUseApproval(&terminal))
        XCTAssertEqual(terminal["hook_event_name"] as? String, "PermissionRequest")
        XCTAssertEqual(terminal["tool_name"] as? String, "Bash")
        XCTAssertEqual(terminal["_copilot_hook_event_name"] as? String, "PreToolUse")
        XCTAssertEqual((terminal["tool_input"] as? [String: Any])?["command"] as? String, "pwd")

        var read: [String: Any] = [
            "hook_event_name": "PreToolUse",
            "tool_name": "read_file",
        ]
        XCTAssertTrue(CopilotHookAdapter.promoteVSCodePreToolUseApproval(&read))
        XCTAssertEqual(read["hook_event_name"] as? String, "PermissionRequest")
        XCTAssertEqual(read["tool_name"] as? String, "read_file")

        var alternateTerminal: [String: Any] = [
            "hook_event_name": "PreToolUse",
            "tool_name": "runInTerminal",
        ]
        XCTAssertTrue(CopilotHookAdapter.promoteVSCodePreToolUseApproval(&alternateTerminal))

        var cliEvent: [String: Any] = [
            "hook_event_name": "preToolUse",
            "tool_name": "read_file",
        ]
        XCTAssertFalse(CopilotHookAdapter.promoteVSCodePreToolUseApproval(&cliEvent))
    }

    func testConvertsCodeIslandDecisionForVSCodePreToolUse() throws {
        let response = Data(#"{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","reason":"Not allowed"}}}"#.utf8)

        let converted = CopilotHookAdapter.vsCodePreToolUseResponse(from: response)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: converted) as? [String: Any])
        let output = try XCTUnwrap(root["hookSpecificOutput"] as? [String: Any])

        XCTAssertEqual(output["hookEventName"] as? String, "PreToolUse")
        XCTAssertEqual(output["permissionDecision"] as? String, "deny")
        XCTAssertEqual(output["permissionDecisionReason"] as? String, "Not allowed")
    }
}
