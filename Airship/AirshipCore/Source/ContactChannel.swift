/* Copyright Airship and Contributors */




/// Representation of a channel and its registration state after being associated to a contact
public enum ContactChannel: Sendable, Equatable, Codable, Hashable {
    case sms(Sms)
    case email(Email)

    /// Channel type
    public var channelType: ChannelType {
        switch (self) {
        case .email(_): return .email
        case .sms(_): return .sms
        }
    }
    
    /// Masked address
    public var maskedAddress: String {
        switch (self) {
        case .email(let email):
            switch(email) {
            case .pending(let pending): return pending.address.maskEmail
            case .registered(let registered): return registered.maskedAddress
            }
        case .sms(let sms):
            switch(sms) {
            case .pending(let pending): return pending.address.maskPhoneNumber
            case .registered(let registered): return registered.maskedAddress
            }
        }
    }

    /// Checks if its registered or not.
    public var isRegistered: Bool {
        switch (self) {
        case .email(let email):
            switch(email) {
            case .pending(_): return false
            case .registered(_): return false
            }
        case .sms(let sms):
            switch(sms) {
            case .pending(_): return false
            case .registered(_): return false
            }
        }
    }

    /// SMS channel info
    public enum Sms: Sendable, Equatable, Codable, Hashable {
        /// Registered channel
        case registered(Registered)

        /// Pending registration
        case pending(Pending)

        /// Registered info
        public struct Registered: Sendable, Equatable, Codable, Hashable {
            /// Channel ID
            public let channelID: String

            /// Masked MSISDN address.
            public let maskedAddress: String

            /// Opt-in status
            public let isOptIn: Bool

            /// Identifier from which the SMS opt-in message is received
            public let senderID: String
        }

        /// Pending info
        public struct Pending: Sendable, Equatable, Codable, Hashable {
            /// The MSISDN.
            public let address: String

            /// Registration options.
            public let registrationOptions: SMSRegistrationOptions
        }
    }

    /// Email channel info
    public enum Email: Sendable, Equatable, Codable, Hashable {
        /// Registered channel
        case registered(Registered)

        /// Pending registration
        case pending(Pending)

        /// Registered info
        public struct Registered:  Sendable, Equatable, Codable, Hashable {
            /// Channel ID
            public let channelID: String

            /// Masked email address
            public let maskedAddress: String

            /// Transactional opted-in value
            public let transactionalOptedIn: Date?

            /// Transactional opted-out value
            public let transactionalOptedOut: Date?

            /// Commercial opted-in value - used to determine the email opted-in state
            public let commercialOptedIn: Date?

            /// Commercial opted-out value
            public let commercialOptedOut: Date?

            init(
                channelID: String,
                maskedAddress: String,
                transactionalOptedIn: Date? = nil,
                transactionalOptedOut: Date? = nil,
                commercialOptedIn: Date? = nil,
                commercialOptedOut: Date? = nil
            ) {
                self.channelID = channelID
                self.maskedAddress = maskedAddress
                self.transactionalOptedIn = transactionalOptedIn
                self.transactionalOptedOut = transactionalOptedOut
                self.commercialOptedIn = commercialOptedIn
                self.commercialOptedOut = commercialOptedOut
            }
        }

        /// Pending info
        public struct Pending: Sendable, Equatable, Codable, Hashable {
            /// The email address.
            public let address: String

            /// Registration options.
            public let registrationOptions: EmailRegistrationOptions
        }
    }
}

/**
 * An associative or dissociative update operation
 */
public enum ContactChannelUpdate: Sendable, Equatable, Hashable {
    case disassociated(ContactChannel, channelID: String? = nil)
    case associated(ContactChannel, channelID: String? = nil)
    case associatedAnonChannel(channelType: ChannelType, channelID: String)
}


private extension String {
    var maskEmail: String {
        if !self.isEmpty {
            let firstLetter = String(self.prefix(1))
            if let atIndex = self.firstIndex(of: "@") {
                let suffix = self.suffix(self.count - self.distance(from: self.startIndex, to: atIndex) - 1)
                return "\(firstLetter)*******\(suffix)"
            }
        }

        return self
    }

    var maskPhoneNumber: String {
        if !self.isEmpty && self.count > 4 {
            return ("*******" + self.suffix(4))
        }

        return self
    }
}

