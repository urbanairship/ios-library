/* Copyright Airship and Contributors */

public import SwiftUI
public import AirshipSceneRenderer
public import Combine
import AirshipCore

/// Observable state for an ``AirshipEmbeddedCarousel``.
///
/// Own an instance with `@StateObject` and pass it to
/// ``AirshipEmbeddedCarousel/init(state:embeddedID:embeddedSize:selection:filterInstances:indicatorAlignment:indicator:previousArrow:nextArrow:placeholder:)``
/// to hoist the carousel's state out of the view - e.g. to drive a custom indicator
/// elsewhere on screen, or to navigate the carousel programmatically by assigning to
/// `currentPage`.
@MainActor
public final class AirshipEmbeddedCarouselState: ObservableObject {

    /// The index of the currently visible page, or `nil` before any content has loaded.
    ///
    /// Assign to this to navigate the carousel programmatically.
    @Published public var currentPage: Int?

    /// The number of available pages for the carousel's embedded ID.
    @Published public fileprivate(set) var pageCount: Int = 0

    /// Whether there is any content available to display. `false` while showing the placeholder.
    public var isAvailable: Bool { pageCount > 0 }

    /// Ids of the last-seen pending set, so `currentPage` can follow a message that shifts
    /// slots instead of following the slot itself.
    fileprivate var lastPendingIDs: [String] = []

    public init() {}
}

/// Displays every embedded view sharing an embedded ID as swipeable carousel pages.
///
/// Unlike ``AirshipEmbeddedView``, which shows a single pending instance at a time,
/// `AirshipEmbeddedCarousel` shows every pending instance for `embeddedID` as a page the
/// user can swipe between.
@MainActor
public struct AirshipEmbeddedCarousel<PlaceHolder: View, Indicator: View, PreviousArrow: View, NextArrow: View>: View {

    @StateObject
    private var ownedState = AirshipEmbeddedCarouselState()

    @ObservedObject
    private var providedState: AirshipEmbeddedCarouselState

    private let usesOwnedState: Bool

    /// `ownedState` when this carousel owns its state, `providedState` when hoisted - so a
    /// caller that swaps in a new state object is followed instead of silently ignored.
    private var state: AirshipEmbeddedCarouselState {
        usesOwnedState ? ownedState : providedState
    }

    private let embeddedID: String
    private let embeddedSize: AirshipEmbeddedSize?
    private let selection: AirshipEmbeddedSelection
    private let filterInstances: AirshipEmbeddedFilter?
    private let indicatorAlignment: Alignment
    private let placeholder: () -> PlaceHolder
    private let indicator: (_ currentPage: Int, _ pageCount: Int) -> Indicator
    private let previousArrow: (_ onTap: @escaping () -> Void, _ isEnabled: Bool) -> PreviousArrow
    private let nextArrow: (_ onTap: @escaping () -> Void, _ isEnabled: Bool) -> NextArrow

    /// Creates a new AirshipEmbeddedCarousel that owns its own state.
    ///
    /// - Parameters:
    ///   - embeddedID: The embedded ID.
    ///   - embeddedSize: The embedded size info. This is needed in a scroll view to determine proper percent based sizing.
    ///   - selection: How to select which pending content is included, and its ordering. Defaults to `.priority`.
    ///   - filterInstances: Optional filter deciding which pending instances are eligible. Applied before `selection`, so a filtered-out instance never becomes a page. Defaults to no filtering.
    ///   - indicatorAlignment: Where the `indicator` overlay is placed on top of the carousel. Defaults to `.bottom`.
    ///   - indicator: Overlay slot rendered on top of the carousel, given the current page and page count.
    ///   - previousArrow: Overlay slot positioned at the leading edge, given a tap action and whether there is a previous page.
    ///   - nextArrow: Overlay slot positioned at the trailing edge, given a tap action and whether there is a next page.
    ///   - placeholder: The placeholder shown while no content is available.
    public init(
        embeddedID: String,
        embeddedSize: AirshipEmbeddedSize? = nil,
        selection: AirshipEmbeddedSelection = .priority,
        filterInstances: AirshipEmbeddedFilter? = nil,
        indicatorAlignment: Alignment = .bottom,
        @ViewBuilder indicator: @escaping (_ currentPage: Int, _ pageCount: Int) -> Indicator = { currentPage, pageCount in
            AirshipEmbeddedCarouselDefaults.dotsIndicator(currentPage: currentPage, pageCount: pageCount)
        },
        @ViewBuilder previousArrow: @escaping (_ onTap: @escaping () -> Void, _ isEnabled: Bool) -> PreviousArrow = { onTap, isEnabled in
            AirshipEmbeddedCarouselDefaults.previousArrow(onTap: onTap, isEnabled: isEnabled)
        },
        @ViewBuilder nextArrow: @escaping (_ onTap: @escaping () -> Void, _ isEnabled: Bool) -> NextArrow = { onTap, isEnabled in
            AirshipEmbeddedCarouselDefaults.nextArrow(onTap: onTap, isEnabled: isEnabled)
        },
        @ViewBuilder placeholder: @escaping () -> PlaceHolder = { EmptyView() }
    ) {
        self.usesOwnedState = true
        self._providedState = ObservedObject(wrappedValue: AirshipEmbeddedCarouselState())
        self.embeddedID = embeddedID
        self.embeddedSize = embeddedSize
        self.selection = selection
        self.filterInstances = filterInstances
        self.indicatorAlignment = indicatorAlignment
        self.indicator = indicator
        self.previousArrow = previousArrow
        self.nextArrow = nextArrow
        self.placeholder = placeholder
    }

    /// Creates a new AirshipEmbeddedCarousel with hoisted state.
    ///
    /// Use this overload to observe or control the carousel from outside the view - for
    /// example, to drive an indicator elsewhere in the layout, or to navigate
    /// programmatically by assigning to `state.currentPage`.
    ///
    /// - Parameters:
    ///   - state: The carousel's state. Own it with `@StateObject` in the parent view.
    ///   - embeddedID: The embedded ID.
    ///   - embeddedSize: The embedded size info. This is needed in a scroll view to determine proper percent based sizing.
    ///   - selection: How to select which pending content is included, and its ordering. Defaults to `.priority`.
    ///   - filterInstances: Optional filter deciding which pending instances are eligible. Applied before `selection`, so a filtered-out instance never becomes a page. Defaults to no filtering.
    ///   - indicatorAlignment: Where the `indicator` overlay is placed on top of the carousel. Defaults to `.bottom`.
    ///   - indicator: Overlay slot rendered on top of the carousel, given the current page and page count.
    ///   - previousArrow: Overlay slot positioned at the leading edge, given a tap action and whether there is a previous page.
    ///   - nextArrow: Overlay slot positioned at the trailing edge, given a tap action and whether there is a next page.
    ///   - placeholder: The placeholder shown while no content is available.
    public init(
        state: AirshipEmbeddedCarouselState,
        embeddedID: String,
        embeddedSize: AirshipEmbeddedSize? = nil,
        selection: AirshipEmbeddedSelection = .priority,
        filterInstances: AirshipEmbeddedFilter? = nil,
        indicatorAlignment: Alignment = .bottom,
        @ViewBuilder indicator: @escaping (_ currentPage: Int, _ pageCount: Int) -> Indicator = { currentPage, pageCount in
            AirshipEmbeddedCarouselDefaults.dotsIndicator(currentPage: currentPage, pageCount: pageCount)
        },
        @ViewBuilder previousArrow: @escaping (_ onTap: @escaping () -> Void, _ isEnabled: Bool) -> PreviousArrow = { onTap, isEnabled in
            AirshipEmbeddedCarouselDefaults.previousArrow(onTap: onTap, isEnabled: isEnabled)
        },
        @ViewBuilder nextArrow: @escaping (_ onTap: @escaping () -> Void, _ isEnabled: Bool) -> NextArrow = { onTap, isEnabled in
            AirshipEmbeddedCarouselDefaults.nextArrow(onTap: onTap, isEnabled: isEnabled)
        },
        @ViewBuilder placeholder: @escaping () -> PlaceHolder = { EmptyView() }
    ) {
        self.embeddedID = embeddedID
        self.embeddedSize = embeddedSize
        self.selection = selection
        self.filterInstances = filterInstances
        self.indicatorAlignment = indicatorAlignment
        self.indicator = indicator
        self.previousArrow = previousArrow
        self.nextArrow = nextArrow
        self.placeholder = placeholder
        self.usesOwnedState = false
        self._providedState = ObservedObject(wrappedValue: state)
    }

    /// Whether there is a page before the current one. Computed live, never cached.
    private var hasPrevious: Bool {
        guard let currentPage = state.currentPage else { return false }
        return currentPage > 0
    }

    /// Whether there is a page after the current one. Computed live, never cached.
    private var hasNext: Bool {
        guard let currentPage = state.currentPage else { return false }
        return currentPage < state.pageCount - 1
    }

    private func goToPrevious() {
        guard hasPrevious, let currentPage = state.currentPage else { return }
        withAnimation {
            state.currentPage = currentPage - 1
        }
    }

    private func goToNext() {
        guard hasNext, let currentPage = state.currentPage else { return }
        withAnimation {
            state.currentPage = currentPage + 1
        }
    }

    public var body: some View {
        AirshipEmbeddedView(
            embeddedID: embeddedID,
            embeddedSize: embeddedSize,
            selection: selection,
            filterInstances: filterInstances,
            placeholder: placeholder
        )
        .setAirshipEmbeddedStyle(
            CarouselEmbeddedViewStyle(
                currentPage: Binding(
                    get: { state.currentPage },
                    set: { state.currentPage = $0 }
                ),
                pageCount: Binding(
                    get: { state.pageCount },
                    set: { state.pageCount = $0 }
                ),
                lastPendingIDs: Binding(
                    get: { state.lastPendingIDs },
                    set: { state.lastPendingIDs = $0 }
                )
            )
        )
        .overlay(alignment: indicatorAlignment) {
            if state.isAvailable {
                indicator(state.currentPage ?? 0, state.pageCount)
            }
        }
        .overlay(alignment: .leading) {
            if state.isAvailable {
                previousArrow(goToPrevious, hasPrevious)
            }
        }
        .overlay(alignment: .trailing) {
            if state.isAvailable {
                nextArrow(goToNext, hasNext)
            }
        }
    }

    private struct CarouselEmbeddedViewStyle: AirshipEmbeddedViewStyle {
        @Binding var currentPage: Int?
        @Binding var pageCount: Int
        @Binding var lastPendingIDs: [String]

        /// Applies `selection`'s filtering/ordering to `pending`.
        ///
        /// `EmbeddedViewModel` only uses `selection` to pick one winner for
        /// `configuration.selected`, which this style never reads - so the carousel has to
        /// resolve `selection` itself.
        @MainActor
        private func resolvePending(
            _ pending: [Configuration.Pending],
            selection: AirshipEmbeddedSelection
        ) -> [Configuration.Pending] {
            switch selection {
            case .priority:
                return pending.sorted {
                    $0.content.embeddedInfo.priority < $1.content.embeddedInfo.priority
                }
            case .comparator(let comparator):
                return pending.sorted {
                    comparator($0.content.embeddedInfo, $1.content.embeddedInfo) == .orderedAscending
                }
            case .instance(let instanceIDs):
                // Named pages only, in the given order; ids that aren't pending are skipped.
                return instanceIDs.compactMap { id in
                    pending.first { $0.content.embeddedInfo.instanceID == id }
                }
            case .ai(_, let fallback):
                // Fallback.asSelection isn't public; map its cases by hand.
                switch fallback {
                case .priority:
                    return resolvePending(pending, selection: .priority)
                case .comparator(let comparator):
                    return resolvePending(pending, selection: .comparator(comparator))
                case .instance(let instanceIDs):
                    return resolvePending(pending, selection: .instance(instanceIDs))
                @unknown default:
                    return pending
                }
            @unknown default:
                // Unknown future case - show everything, unordered.
                return pending
            }
        }

        @ViewBuilder
        @MainActor
        private func makeContent(pending: [Configuration.Pending], placeholder: AnyView) -> some View {
            if pending.isEmpty {
                placeholder
            } else {
                #if os(iOS)
                if #available(iOS 17.0, *) {
                    makeScrollingCarousel(pending: pending)
                } else {
                    makeTabViewCarousel(pending: pending)
                }
                #else
                makeScrollingCarousel(pending: pending)
                #endif
            }
        }

        @ViewBuilder
        @MainActor
        @available(iOS 17.0, *)
        private func makeScrollingCarousel(pending: [Configuration.Pending]) -> some View {
            GeometryReader { metrics in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(pending.enumerated()), id: \.element.id) { index, item in
                            item.content
                                .frame(width: metrics.size.width, height: metrics.size.height)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentPage)
                .scrollIndicators(.never)
            }
        }

        #if os(iOS)
        @ViewBuilder
        @MainActor
        private func makeTabViewCarousel(pending: [Configuration.Pending]) -> some View {
            GeometryReader { metrics in
                TabView(selection: $currentPage) {
                    ForEach(Array(pending.enumerated()), id: \.element.id) { index, item in
                        item.content
                            .frame(width: metrics.size.width, height: metrics.size.height)
                            .tag(index as Int?)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        #endif

        @MainActor
        @preconcurrency
        func makeBody(configuration: Configuration) -> some View {
            let pending = resolvePending(configuration.pending, selection: configuration.selection)
            return makeContent(pending: pending, placeholder: configuration.placeHolder)
                .onPendingChange(pending.map(\.id)) { ids in
                    let oldIDs = lastPendingIDs
                    lastPendingIDs = ids
                    pageCount = ids.count

                    guard !ids.isEmpty else {
                        currentPage = nil
                        return
                    }

                    // Keep following the same message across dismissals/refills, not just
                    // the numeric slot it used to occupy.
                    if let current = currentPage, oldIDs.indices.contains(current),
                       let newIndex = ids.firstIndex(of: oldIDs[current]) {
                        currentPage = newIndex
                    } else {
                        currentPage = min(currentPage ?? 0, ids.count - 1)
                    }
                }
        }
    }
}

/// Default accessories for ``AirshipEmbeddedCarousel``.
public enum AirshipEmbeddedCarouselDefaults {

    /// An accessible, VoiceOver-labelled back-arrow button for the carousel's leading edge.
    @MainActor
    @ViewBuilder
    public static func previousArrow(onTap: @escaping () -> Void, isEnabled: Bool) -> some View {
        Button(action: onTap) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .padding(.leading, 8)
        .accessibilityLabel("ua_previous".airshipLocalizedString(fallback: "Previous"))
    }

    /// An accessible, VoiceOver-labelled forward-arrow button for the carousel's trailing edge.
    @MainActor
    @ViewBuilder
    public static func nextArrow(onTap: @escaping () -> Void, isEnabled: Bool) -> some View {
        Button(action: onTap) {
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .padding(.trailing, 8)
        .accessibilityLabel("ua_next".airshipLocalizedString(fallback: "Next"))
    }

    /// A row of dots reporting the current page as a single accessibility element (e.g.
    /// "Page 2 of 5") instead of exposing each dot individually to VoiceOver.
    @MainActor
    @ViewBuilder
    public static func dotsIndicator(currentPage: Int, pageCount: Int) -> some View {
        if pageCount > 0 {
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.thinMaterial, in: Capsule())
            .padding(.bottom, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                String(
                    format: "ua_pager_progress".airshipLocalizedString(fallback: "Page %@ of %@"),
                    (currentPage + 1).airshipLocalizedForVoiceOver(),
                    pageCount.airshipLocalizedForVoiceOver()
                )
            )
        }
    }
}

/// Spells out numbers for VoiceOver (e.g. "one" instead of "1") so page announcements read naturally.
private extension Int {
    func airshipLocalizedForVoiceOver() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: self)) ?? String(self)
    }
}

private extension View {
    /// Like `onChange(of:initial:_:)`, but back-deployed without needing the newer API's
    /// two-platform-version-list availability dance at every call site.
    @ViewBuilder
    func onPendingChange<Value: Equatable>(_ value: Value, perform action: @escaping (Value) -> Void) -> some View {
        if #available(iOS 17.0, tvOS 17.0, visionOS 1.0, *) {
            self.onChange(of: value, initial: true) { _, newValue in
                action(newValue)
            }
        } else {
            self
                .onAppear { action(value) }
                .onChange(of: value) { newValue in
                    action(newValue)
                }
        }
    }
}
