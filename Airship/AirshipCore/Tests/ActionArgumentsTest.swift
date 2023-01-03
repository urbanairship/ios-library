/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

final class ActionArgumentsTest: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    /*
     * Test the argumentsWithValue:withSituation factory method sets the values correctly
     */
    func testArgumentsWithValue() {
        var args = ActionArguments(value: "some-value", with: .backgroundPush)
        XCTAssertEqual("some-value", args.value as! String)
        XCTAssertEqual(.backgroundPush, args.situation)

        args = ActionArguments(value: "whatever", with: .manualInvocation)
        XCTAssertEqual(.manualInvocation, args.situation)
        
        args = ActionArguments(value: "whatever", with: .foregroundPush)
        XCTAssertEqual(.foregroundPush, args.situation)
        
        args = ActionArguments(value: "whatever", with: .launchedFromPush)
        XCTAssertEqual(.launchedFromPush, args.situation)

        args = ActionArguments(value: "whatever", with: .webViewInvocation)
        XCTAssertEqual(.webViewInvocation, args.situation)
        
        args = ActionArguments(value: "whatever", with: .foregroundInteractiveButton)
        XCTAssertEqual(.foregroundInteractiveButton, args.situation)
        
        args = ActionArguments(value: "whatever", with: .backgroundInteractiveButton)
        XCTAssertEqual(.backgroundInteractiveButton, args.situation)
        
        args = ActionArguments(value: "whatever", with: .automation)
        XCTAssertEqual(.automation, args.situation)
    }
    
    /*
     * Test the override of the description method
     */
    func testDescription() {
        let args = ActionArguments(value: "foo", with: .manualInvocation)
        let expectedDescription = "UAActionArguments with situation: Manual Invocation, value: \(args.value!)"
        XCTAssertEqual(args.description, expectedDescription)
    }
    
}
