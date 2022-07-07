/* Copyright Airship and Contributors */

/**
 * Convenience class for aggregating and merging multiple UAActionResults.
 */
@objc(UAAggregateActionResult)
public class AggregateActionResult : ActionResult {
    
    private var _value : [String : ActionResult] = [:]
    public override var value: Any? {
        get {
            return self._value
        }
    }
    
    private var _fetchResult : ActionFetchResult = .noData
    
    public override var fetchResult: ActionFetchResult {
        get {
            return self._fetchResult
        }
    }

    /**
     * Adds a new result, merging with the existing result.
     *
     * - Parameters:
     *   - result: The result.
     *   - actionName: The action name.
     */
    @objc(addResult:forAction:)
    public func add(_ result: ActionResult, actionName: String) {
        self.mergeFetch(result.fetchResult)
        self._value[actionName] = result
    }

    /**
     * Gets the results for an action
     *
     * - Parameters:
     *   - actionName: The action name.
     * - Returns: The action result for the name.
     */
    @objc(resultForAction:)
    public func result(actionName: String) -> ActionResult? {
        return self._value[actionName]
    }

    private func mergeFetch(_ result: ActionFetchResult) {
        if self._fetchResult == [] || result == [] {
            self._fetchResult = []
        } else if fetchResult == ActionFetchResult.failed || result == ActionFetchResult.failed {
            self._fetchResult = ActionFetchResult.failed
        }
    }
}
