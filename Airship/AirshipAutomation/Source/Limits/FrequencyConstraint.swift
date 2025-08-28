/* Copyright Airship and Contributors */



/// Represents a constraint on occurrences within a given time period.
struct FrequencyConstraint: Equatable, Hashable, Sendable, Decodable {

    var identifier: String

    var range: TimeInterval

    var count: UInt
    

    fileprivate enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case range = "range"
        case boundary = "boundary"
        case period = "period"
    }

    fileprivate enum Period: String, Decodable {
        case seconds
        case minutes
        case hours
        case days
        case weeks
        case months
        case years

        func toTimeInterval(_ value: Double) -> TimeInterval {
            switch (self) {
            case .seconds:
                return value
            case .minutes:
                return value * 60
            case .hours:
                return value * 60 * 60
            case .days:
                return value * 60 * 60 * 24
            case .weeks:
                return value * 60 * 60 * 24 * 6
            case .months:
                return value * 60 * 60 * 24 * 30
            case .years:
                return value * 60 * 60 * 24 * 365
            }
        }
    }

    init(identifier: String, range: TimeInterval, count: UInt) {
        self.identifier = identifier
        self.range = range
        self.count = count
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let identifier = try container.decode(String.self, forKey: .identifier)
        let periodRange = try container.decode(Double.self, forKey: .range)
        let period = try container.decode(Period.self, forKey: .period)
        let boundary = try container.decode(UInt.self, forKey: .boundary)

        self.init(
            identifier: identifier,
            range: period.toTimeInterval(periodRange),
            count: boundary
        )
    }
}
