import Foundation

public enum CopilotHookAdapter {
    private static let terminalToolNames: Set<String> = [
        "bash", "powershell", "local_shell", "runInTerminal", "run_in_terminal", "Bash",
    ]

    /// VS Code exposes approval control only through PreToolUse and does not say
    /// whether its native UI will ask later. Promote every VS Code PreToolUse so
    /// CodeIsland becomes the single approval surface. Copilot CLI uses the
    /// lower-camel `preToolUse`, so it remains an ordinary status event.
    public static func promoteVSCodePreToolUseApproval(_ payload: inout [String: Any]) -> Bool {
        guard payload["hook_event_name"] as? String == "PreToolUse",
              let toolName = payload["tool_name"] as? String,
              !toolName.isEmpty else {
            return false
        }

        payload["_copilot_hook_event_name"] = "PreToolUse"
        payload["hook_event_name"] = "PermissionRequest"
        if terminalToolNames.contains(toolName) {
            payload["tool_name"] = "Bash"
        }
        return true
    }

    /// CodeIsland internally uses Claude's nested PermissionRequest response.
    /// Copilot's camelCase hook contract expects the decision at the top level.
    public static func permissionResponse(from response: Data) -> Data {
        guard let root = try? JSONSerialization.jsonObject(with: response) as? [String: Any] else {
            return response
        }
        if root["behavior"] is String {
            return response
        }
        guard let output = root["hookSpecificOutput"] as? [String: Any],
              let decision = output["decision"] as? [String: Any],
              let behavior = decision["behavior"] as? String,
              behavior == "allow" || behavior == "deny" else {
            return response
        }

        var result: [String: Any] = ["behavior": behavior]
        if let message = decision["message"] as? String ?? decision["reason"] as? String {
            result["message"] = message
        }
        if let interrupt = decision["interrupt"] as? Bool {
            result["interrupt"] = interrupt
        }
        return (try? JSONSerialization.data(withJSONObject: result)) ?? response
    }

    /// VS Code's PreToolUse contract expects the decision inside
    /// hookSpecificOutput rather than Copilot CLI's top-level response.
    public static func vsCodePreToolUseResponse(from response: Data) -> Data {
        guard let root = try? JSONSerialization.jsonObject(with: response) as? [String: Any] else {
            return response
        }

        let decision = (root["hookSpecificOutput"] as? [String: Any])?["decision"] as? [String: Any]
        guard let behavior = root["behavior"] as? String ?? decision?["behavior"] as? String,
              behavior == "allow" || behavior == "deny" else {
            return response
        }

        var output: [String: Any] = [
            "hookEventName": "PreToolUse",
            "permissionDecision": behavior,
        ]
        if let reason = root["message"] as? String
            ?? decision?["message"] as? String
            ?? decision?["reason"] as? String {
            output["permissionDecisionReason"] = reason
        }

        let result: [String: Any] = ["hookSpecificOutput": output]
        return (try? JSONSerialization.data(withJSONObject: result)) ?? response
    }
}
