/* Copyright Airship and Contributors */

import Testing
@testable import AirshipAIModels

struct StringStrippingCodeFenceTest {

    @Test
    func plainStringPassesThrough() {
        #expect(#"{"allow":true}"#.strippingCodeFence == #"{"allow":true}"#)
    }

    @Test
    func stripsJsonCodeFence() {
        let fenced = "```json\n{\"allow\":true}\n```"
        #expect(fenced.strippingCodeFence == #"{"allow":true}"#)
    }

    @Test
    func stripsPlainCodeFence() {
        let fenced = "```\n{\"allow\":true}\n```"
        #expect(fenced.strippingCodeFence == #"{"allow":true}"#)
    }

    @Test
    func tripsLeadingTrailingWhitespace() {
        let fenced = "  ```json\n{\"k\":1}\n```  "
        #expect(fenced.strippingCodeFence == #"{"k":1}"#)
    }

    @Test
    func stripsOnlyClosingFenceAtEnd() {
        let fenced = "```json\nline1\nline2\n```"
        #expect(fenced.strippingCodeFence == "line1\nline2")
    }

    @Test
    func noClosingFenceKeepsBodyIntact() {
        let fenced = "```json\n{\"allow\":true}"
        #expect(fenced.strippingCodeFence == #"{"allow":true}"#)
    }

    @Test
    func emptyStringReturnsEmpty() {
        #expect("".strippingCodeFence == "")
    }

    @Test
    func codeBlockWithNoNewlineAfterFenceReturnsEmpty() {
        // fence with no newline — body is empty
        let fenced = "```json```"
        #expect(fenced.strippingCodeFence.isEmpty)
    }
}
