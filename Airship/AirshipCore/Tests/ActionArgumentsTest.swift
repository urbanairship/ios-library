///* Copyright Airship and Contributors */
//
//import XCTest
//
//@testable import AirshipCore
//
//final class ActionArgumentTest: XCTestCase {
//
//    override func setUpWithError() throws {
//        try super.setUpWithError()
//    }
//
//    /*
//     * Test the argumentsWithValue:withSituation factory method sets the values correctly
//     */
//    func testArgumentsWithValue() {
//        var args = ActionArguments(value: "some-value", situation: .backgroundPush)
//        XCTAssertEqual("some-value", args.value as! String)
//        XCTAssertEqual(.backgroundPush, args.situation)
//
//        args = ActionArguments(value: "whatever", situation: .manualInvocation)
//        XCTAssertEqual(.manualInvocation, args.situation)
//        
//        args = ActionArguments(value: "whatever", situation: .foregroundPush)
//        XCTAssertEqual(.foregroundPush, args.situation)
//        
//        args = ActionArguments(value: "whatever", situation: .launchedFromPush)
//        XCTAssertEqual(.launchedFromPush, args.situation)
//
//        args = ActionArguments(value: "whatever", situation: .webViewInvocation)
//        XCTAssertEqual(.webViewInvocation, args.situation)
//        
//        args = ActionArguments(value: "whatever", situation: .foregroundInteractiveButton)
//        XCTAssertEqual(.foregroundInteractiveButton, args.situation)
//        
//        args = ActionArguments(value: "whatever", situation: .backgroundInteractiveButton)
//        XCTAssertEqual(.backgroundInteractiveButton, args.situation)
//        
//        args = ActionArguments(value: "whatever", situation: .automation)
//        XCTAssertEqual(.automation, args.situation)
//    }
//    
//    /*
//     * Test the override of the description method
//     */
//    /*
//    func testDescription() {
//        let args = ActionArguments(value: "foo", situation: .manualInvocation)
//        let expectedDescription = "UAActionArgument with situation: Manual Invocation, value: \(args.value!)"
//        XCTAssertEqual(args.description, expectedDescription)
//    }
//    */
//}
