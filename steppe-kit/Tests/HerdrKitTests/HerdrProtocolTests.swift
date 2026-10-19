import XCTest
@testable import HerdrKit

final class HerdrProtocolTests: XCTestCase {
    func testDecodesSessionSnapshot() throws {
        let snapshot = try JSONDecoder.herdr.decode(
            SessionSnapshot.self,
            from: Data(Self.snapshotJSON.utf8)
        )

        XCTAssertEqual(snapshot.version, "0.9.3")
        XCTAssertEqual(snapshot.protocolVersion, 22)
        XCTAssertEqual(snapshot.focusedWorkspaceId, "w1")
        XCTAssertEqual(snapshot.focusedPaneId, "w1:p1")
        XCTAssertEqual(snapshot.workspaces.count, 1)
        XCTAssertEqual(snapshot.tabs.count, 1)
        XCTAssertEqual(snapshot.panes.count, 1)
        XCTAssertEqual(snapshot.agents.count, 1)

        let workspace = try XCTUnwrap(snapshot.workspaces.first)
        XCTAssertEqual(workspace.label, "steppe")
        XCTAssertEqual(workspace.worktree?.repoName, "steppe")
        XCTAssertEqual(workspace.activeTabId, "w1:t1")

        let agent = try XCTUnwrap(snapshot.agents.first)
        XCTAssertEqual(agent.resolvedName, "reviewer")
        XCTAssertEqual(agent.agentStatus, .blocked)
        XCTAssertEqual(agent.statusLabel, "needs review")
        XCTAssertEqual(snapshot.blockedAgents.count, 1)
    }

    func testDecodesResponseEnvelope() throws {
        let json = """
        {"id":"req_1","result":{"type":"session_snapshot","snapshot":\(Self.snapshotJSON)}}
        """

        let envelope = try JSONDecoder.herdr.decode(
            ResponseEnvelope<SnapshotResult>.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(envelope.id, "req_1")
        XCTAssertNil(envelope.error)
        XCTAssertEqual(envelope.result?.type, "session_snapshot")
        XCTAssertEqual(envelope.result?.snapshot.agents.first?.agentStatus, .blocked)
    }

    func testDecodesEventEnvelopeAndIgnoresUnknownData() throws {
        let json = """
        {"event":"pane.agent_status_changed","data":{"pane_id":"w1:p1","agent_status":"working","future_field":true}}
        """

        let event = try JSONDecoder.herdr.decode(HerdrEvent.self, from: Data(json.utf8))
        XCTAssertEqual(event.event, "pane.agent_status_changed")

        guard case .object(let data) = event.data else {
            return XCTFail("expected object data")
        }
        XCTAssertEqual(data["pane_id"], .string("w1:p1"))
    }

    func testJSONValueRoundTrip() throws {
        let value = JSONValue.object([
            "method": .string("pane.split"),
            "params": .object([
                "ratio": .number(0.5),
                "focus": .bool(true),
                "labels": .array([.string("a"), .null]),
            ]),
        ])

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testErrorEnvelopeDecodes() throws {
        let json = """
        {"id":"req_1","error":{"code":"not_found","message":"pane not found"}}
        """

        let envelope = try JSONDecoder.herdr.decode(
            ResponseEnvelope<AckResult>.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(envelope.error?.code, "not_found")
        XCTAssertEqual(envelope.error?.errorDescription, "not_found: pane not found")
        XCTAssertNil(envelope.result)
    }

    private static let snapshotJSON = """
    {
      "version": "0.9.3",
      "protocol": 22,
      "focused_workspace_id": "w1",
      "focused_tab_id": "w1:t1",
      "focused_pane_id": "w1:p1",
      "workspaces": [
        {
          "workspace_id": "w1",
          "number": 1,
          "label": "steppe",
          "focused": true,
          "pane_count": 1,
          "tab_count": 1,
          "active_tab_id": "w1:t1",
          "agent_status": "blocked",
          "worktree": {
            "checkout_path": "/Users/example/repos/steppe",
            "is_linked_worktree": false,
            "repo_key": "/Users/example/repos/steppe/.git",
            "repo_name": "steppe",
            "repo_root": "/Users/example/repos/steppe"
          }
        }
      ],
      "tabs": [
        {
          "tab_id": "w1:t1",
          "workspace_id": "w1",
          "number": 1,
          "label": "main",
          "focused": true,
          "pane_count": 1,
          "agent_status": "blocked"
        }
      ],
      "panes": [
        {
          "pane_id": "w1:p1",
          "terminal_id": "term_abc123",
          "workspace_id": "w1",
          "tab_id": "w1:t1",
          "focused": true,
          "agent_status": "blocked",
          "revision": 42,
          "cwd": "/Users/example/repos/steppe",
          "foreground_cwd": "/Users/example/repos/steppe",
          "agent": "claude",
          "display_agent": "reviewer",
          "title": "Review the fork plan",
          "scroll": {
            "offset_from_bottom": 0,
            "max_offset_from_bottom": 240,
            "viewport_rows": 40
          }
        }
      ],
      "layouts": [],
      "agents": [
        {
          "pane_id": "w1:p1",
          "terminal_id": "term_abc123",
          "workspace_id": "w1",
          "tab_id": "w1:t1",
          "focused": true,
          "agent_status": "blocked",
          "revision": 42,
          "agent": "claude",
          "name": "reviewer",
          "display_agent": "reviewer",
          "title": "Review the fork plan",
          "state_labels": {
            "blocked": "needs review",
            "working": "reviewing"
          },
          "state_change_seq": 7
        }
      ]
    }
    """
}
