/* Copyright Airship and Contributors */

import Foundation

/**
  * Pager branching directives. These control the branching behavior of the
  * `PagerController`.
  */
struct ThomasPagerControllerBranching: ThomasSerializable {
    /**
      * Determines when a pager is completed, since we can not rely on the last
      * page meaning "completed" in branching. The given `PagerCompletions` are
      * evaluated to determine that completion. Evaluated in order, first match
      * wins.
      */
    let completions: [ThomasPageControllerCompletion]
    
    enum CodingKeys: String, CodingKey {
        case completions = "pager_completions"
    }
}

/**
  * Pager completion directives; used to determine when a pager has been
  * completed, and optional actions to take upon completion.
  */
struct ThomasPageControllerCompletion: ThomasSerializable {
    /**
      * Predicate to match when evaluating completion. If not provided, it is an
      * implicit match.
      */
    let predicate: JSONPredicate?
    
    /**
      * State actions to run when the pager completes.
      */
    let stateActions: [ThomasStateAction]?
    
    enum CodingKeys: String, CodingKey {
        case predicate = "when_state_matches"
        case stateActions = "state_actions"
    }
}

/**
  * Page branching directives, used to evaluate page behavior when the page's
  * parent controller has branching enabled.
  */
struct ThomasPageBranching: ThomasSerializable {
    /**
      * Controls which page should be used as the next page; only evaluated when
      * the `PagerController` is configured for branching logic. Predicates are
      * evaluated in order, and the first matching predicate is used. If no
      * predicates are matched, or if this directive is not present, proceeding to
      * the next page is blocked.
      */
    let nextPage: [ThomasNextPageSelector]?
    
    /**
      * Controls if moving to the previous page is allowed; only evaluated when the
      * `PagerController` is configured for branching logic. If this directive is
      * not present, moving to the previous page is allowed.
      */
    let previousPageControl: PreviousPageControl?
    
    enum CodingKeys: String, CodingKey {
        case nextPage = "next_page"
        case previousPageControl = "previous_page_disabled"
    }
    
    private enum NextPageSelectorKeys: String, CodingKey {
        case selectors
    }
    
    struct PreviousPageControl: ThomasSerializable {
        /**
          * When provided, moving to the previous page is disabled when the predicate
          * matches.
          */
        let predicate: JSONPredicate?
        
        /**
          * When set `true`, moving to the previous page is always disabled.
          */
        let alwaysDisabled: Bool?
        
        enum CodingKeys: String, CodingKey {
            case predicate = "when_state_matches"
            case alwaysDisabled = "always"
        }
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.previousPageControl = try container.decodeIfPresent(PreviousPageControl.self, forKey: .previousPageControl)
        
        let nextPageContainer = try container.nestedContainer(
            keyedBy: NextPageSelectorKeys.self,
            forKey: .nextPage)
        
        self.nextPage = try nextPageContainer.decodeIfPresent([ThomasNextPageSelector].self, forKey: .selectors)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(self.previousPageControl, forKey: .previousPageControl)
        
        var nextPageContainer = container.nestedContainer(keyedBy: NextPageSelectorKeys.self, forKey: .nextPage)
        try nextPageContainer.encode(self.nextPage, forKey: .selectors)
    }
}

struct ThomasNextPageSelector: ThomasSerializable {
    /**
      * Predicate which is matched for the given `page_id`. When `undefined`, it is
      * an implicit match.
      */
    let predicate: JSONPredicate?
    
    /**
      * ID of the page to be used as the next page.
      */
    let pageId: String
    
    enum CodingKeys: String, CodingKey {
        case predicate = "when_state_matches"
        case pageId = "page_id"
    }
}
