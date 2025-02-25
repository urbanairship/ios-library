/* Copyright Urban Airship and Contributors */

import SwiftUI
import AirshipCore

/// Represents the available components of the tv date picker view.
struct TvDatePickerComponents: OptionSet {
    /// Displays day, month, and year based on the locale
    static var date: TvDatePickerComponents { TvDatePickerComponents(rawValue: 1 << 3) }
    /// Displays hour and minute components based on the locale
    static var hourAndMinute: TvDatePickerComponents { TvDatePickerComponents(rawValue: 1) }
    /// Displays all components based on the locale
    static var all: TvDatePickerComponents { [.date, .hourAndMinute] }
    
    var rawValue: Int8
    
    init(rawValue: Int8) {
        self.rawValue = rawValue
    }
}

/// A `SwiftUI` tvOS date picker view
struct TVDatePicker: View {
    
    var titleKey: String
    var displayedComponents: TvDatePickerComponents
    
    private let pickerStyle = SegmentedPickerStyle()
    private var minimumDate = Date.distantPast
    private var calendar: Calendar = .current
    
    @State
    private var isSheetPresented = false
    
    @Binding
    var selection: Date
    
    @State
    private var selectedYear: Int = 0
    
    @State
    private var selectedMonth: Int = 0
    
    @State
    private var selectedDay: Int = 0
    
    @State
    private var selectedHour: Int = 0
    
    @State
    private var selectedMinute: Int = 0
    
    private var currentSelectedYear: Int {
        calendar.component(.year, from: selection)
    }
    
    private var minimumYear: Int {
        calendar.component(.year, from: minimumDate)
    }
    
    private var months: Range<Int> {
        calendar.range(of: .month, in: .year, for: minimumDate) ?? Range(0...0)
    }
    
    private var daysInSelectedMonth: Range<Int> {
        calendar.range(of: .day, in: .month, for: selection) ?? Range(0...0)
    }
    
    private var hours: Range<Int> {
        calendar.range(of: .hour, in: .day, for: minimumDate) ?? Range(0...0)
    }
    
    private var minutes: Array<Int> { Array(stride(from: 0, to: 60, by: 5)) }
    
    /// Initializes the date picker view with the given values.
    ///
    /// - Parameters:
    ///   - titleKey: The key for the localized title of self, describing its purpose.
    ///   - selection: The date value being displayed and selected.
    ///   - displayedComponents: The date components that user is able to view and edit. Defaults to [.hourAndMinute, .date].
    init<S>(
        _ titleKey: S,
        selection: Binding<Date>,
        displayedComponents: TvDatePickerComponents = [.hourAndMinute, .date]
    ) where S : StringProtocol {
        self.titleKey = titleKey as! String
        self.displayedComponents = displayedComponents
        _selection = selection
    }
    
    var body: some View {
        Button {
            isSheetPresented = true
        } label: {
            HStack {
                Spacer()
                Text(AirshipDateFormatter.string(
                    fromDate: selection,
                    format: .relativeShort
                ))
                Image(systemName: "chevron.right")
            }
        }
        .background(
            EmptyView()
                .sheet(
                    isPresented: $isSheetPresented,
                    onDismiss: {
                        isSheetPresented = false
                    }) {
                    NavigationView {
                        VStack(
                            alignment: .leading,
                            content: content
                        )
                        .onAppear(perform: {
                            updateSelectedDateComponents()
                        })
                        .navigationTitle(.init(titleKey))
                        .navigationBarItems(
                            trailing: dismissButton()
                        )
                    }
                }
        )
        .airshipOnChangeOf(selection, initial: true, { _ in
            updateSelectedDateComponents()
        })
    }
}

private extension TVDatePicker {
    
    @ViewBuilder
    func content() -> some View {
        HStack {
            Spacer()
            Text(AirshipDateFormatter.string(
                fromDate: selection,
                format: .relativeShort
            ))
            .font(.largeTitle)
            Spacer()
        }
        
        Divider()
        
        Text("MM/DD/YYYY")
            .foregroundColor(.secondary)
            .font(.subheadline)
        
        if displayedComponents.contains(.date) {
            Picker(
                selection: $selectedYear,
                label: Text("Year")
            ) {
                let lowerBound = max(minimumYear, (currentSelectedYear - 5))
                let upperBound = max(minimumYear + 10, (currentSelectedYear + 5))
                ForEach(lowerBound...upperBound, id: \.self) { year in
                    Text(String(year))
                        .tag(year)
                }
            }
            .pickerStyle(pickerStyle)
            .airshipOnChangeOf(selectedYear) { value in
                updateComponent(.year, value: value)
            }
        }
        
        if displayedComponents.contains(.date) {
            Picker(
                selection: $selectedMonth,
                label: Text("Month")
            ) {
                ForEach(months, id: \.self) { month in
                    Text(DateFormatter().shortMonthSymbols[month - 1])
                        .tag(month)
                }
            }
            .pickerStyle(pickerStyle)
            .airshipOnChangeOf(selectedMonth) { value in
                updateComponent(.month, value: value)
            }
        }
        
        if displayedComponents.contains(.date) {
            Picker(
                selection: $selectedDay,
                label: Text("Day")
            ) {
                ForEach(daysInSelectedMonth, id: \.self) { day in
                    Text("\(day)")
                        .tag(day)
                }
            }
            .pickerStyle(pickerStyle)
            .airshipOnChangeOf(selectedDay) { value in
                updateComponent(.day, value: value)
            }
        }
        
        if displayedComponents.contains(.hourAndMinute) {
            Text("HH:mm")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            Picker(
                selection: $selectedHour,
                label: Text("Hour")
            ) {
                ForEach(hours, id: \.self) { hour in
                    Text("\(hour)")
                        .tag(hour)
                }
            }
            .pickerStyle(pickerStyle)
            .airshipOnChangeOf(selectedHour) { value in
                updateComponent(.hour, value: value)
            }
            
            Picker(
                selection: $selectedMinute,
                label: Text("Minute")
            ) {
                ForEach(Array(minutes), id: \.self) { minute in
                    Text("\(minute)")
                        .tag(minute)
                }
            }
            .pickerStyle(pickerStyle)
            .airshipOnChangeOf(selectedMinute) { value in
                updateComponent(.minute, value: value)
            }
        }
        
    }
    
    func dismissButton() -> some View {
        Button(action: {
            isSheetPresented = false
        }, label: {
            Image(systemName: "xmark")
        })
    }
    
    func updateComponent(_ component: Calendar.Component, value: Int) {
        let dateComponents = DateComponents(
            calendar: calendar,
            year: (component == .year) ? value : selectedYear,
            month: (component == .month) ? value : selectedMonth,
            day: (component == .day) ? value : selectedDay,
            hour: (component == .hour) ? value : selectedHour,
            minute: (component == .minute) ? value : selectedMinute
        )
        
        if let selectedDate = calendar.date(from: dateComponents) {
            self.selection = selectedDate
            updateSelectedDateComponents()
        }
    }
    
    func updateSelectedDateComponents() {
        selectedYear = calendar.component(.year, from: selection)
        selectedMonth = calendar.component(.month, from: selection)
        selectedDay = calendar.component(.day, from: selection)
        selectedHour = calendar.component(.hour, from: selection)
        
        let currentMinute = calendar.component(.minute, from: selection)
        selectedMinute = currentMinute - (currentMinute % 5)
    }
}

@available(iOS 17.0, *)
#Preview {
    
    @Previewable @State var date = Date.now
    
    TVDatePicker(
        "Date".localized(),
        selection: $date,
        displayedComponents: .all
    )
}
