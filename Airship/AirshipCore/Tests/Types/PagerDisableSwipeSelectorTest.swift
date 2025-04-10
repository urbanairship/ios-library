/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore

struct PagerDisableSwipeSelectorTest {
    
    @Test("Parsing test")
    func testParsing() async throws {
        let json = """
        {
          "directions": {
            "type": "horizontal"
          },
          "when_state_matches": {
            "scope": [
              "test"
            ],
            "value": {
              "equals": [
                "is-complete"
              ]
            }
          }
        }
        """
        
        let expected = try AirshipJSON.from(json: json)
        let decoded: ThomasViewInfo.Pager.DisableSwipeSelector = try expected.decode()
        
        #expect(decoded.predicate != nil)
        #expect(decoded.direction == .horizontal)
        
        let encodedData = try JSONEncoder().encode(decoded)
        let encoded = try AirshipJSON.from(data: encodedData)
        #expect(expected == encoded)
    }
    
}
