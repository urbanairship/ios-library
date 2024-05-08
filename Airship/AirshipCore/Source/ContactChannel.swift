/* Copyright Airship and Contributors */

import Foundation


/// Representation of a channel and its registration state after being associated to a contact
public enum ContactChannel: Sendable, Equatable, Codable, Hashable {
    case registered(Registered)
    case pending(PendingRegistration)

    /// Registered state indicates a channel that has registered and received a channel ID
    public struct Registered: Sendable, Equatable, Codable, Hashable {
        var channelID: String
        var deIdentifiedAddress: String
        public var registrationInfo: RegistrationInfo
    }

    /// Pending registration state indicates a channel registration that has yet to receive a channel ID
    public struct PendingRegistration: Sendable, Equatable, Codable, Hashable {
        var address: String /// Generic address can be address or msisdn
        var pendingRegistrationInfo: PendingRegistrationInfo

        var deIdentifiedAddress: String {
            switch pendingRegistrationInfo {
            case .email(_):
                return address.maskEmail
            case .sms(_):
                return address.maskPhoneNumber
            }
        }
    }

    /// Obfuscated visual representation of the original address used to register the channel
    public var deIdentifiedAddress: String {
        switch (self) {
        case .pending(let pending): return pending.deIdentifiedAddress
        case .registered(let registered): return registered.deIdentifiedAddress
        }
    }

    /**
     * Channel registration info
     */
    public enum RegistrationInfo: Sendable, Equatable, Codable, Hashable {
        case email(Email)
        case sms(SMS)

        /**
         * Email registration info
         */
        public struct Email: Sendable, Equatable, Codable, Hashable {
            /**
             * Transactional opted-in value
             */
            public let transactionalOptedIn: Date?

            /**
             * Transactional opted-out value
             */
            public let transactionalOptedOut: Date?

            /**
             * Commercial opted-in value - used to determine the email opted-in state
             */
            public let commercialOptedIn: Date?

            /**
             * Commercial opted-out value
             */
            public let commercialOptedOut: Date?


            public init(
                transactionalOptedIn: Date? = nil,
                transactionalOptedOut: Date? = nil,
                commercialOptedIn: Date? = nil,
                commercialOptedOut: Date? = nil
            ) {
                self.transactionalOptedIn = transactionalOptedIn
                self.transactionalOptedOut = transactionalOptedOut
                self.commercialOptedIn = commercialOptedIn
                self.commercialOptedOut = commercialOptedOut
            }
        }

        /**
         * SMS registration info
         */
        public struct SMS: Sendable, Equatable, Codable, Hashable {
            /**
             * Used to determine the SMS opted-in state
             */
            public let isOptIn: Bool

            /**
             * Identifier from which the SMS opt-in message is received
             */
            public let senderID: String
        }

    }

    /**
     * Pending registration info
     */
    public enum PendingRegistrationInfo: Sendable, Equatable, Codable, Hashable {
        case email(Email)
        case sms(SMS)

        /**
         * Pending Email registration info
         */
        public struct Email: Sendable, Equatable, Codable, Hashable {}


        /**
         * Pending SMS registration info
         */
        public struct SMS: Sendable, Equatable, Codable, Hashable {

            /**
             * Identifier from which the SMS opt-in message is received
             */
            public let senderID: String
        }
    }

}

/**
 * Registration options
 */
public enum RegistrationOptions: Sendable, Equatable, Codable, Hashable {
    case email(EmailRegistrationOptions)
    case sms(SMSRegistrationOptions)
}

/**
 * An associative or dissociative update operation
 */
public enum ContactChannelUpdate: Sendable, Equatable, Hashable {
    case disassociated(ContactChannel)
    case associated(ContactChannel, channelID: String? = nil)
}

/**
 * Utility variable for determining the underlying type of a contact channel
 */
public extension ContactChannel {
    var channelType: ChannelType {
        switch (self) {
        case .registered(let registered):
            switch(registered.registrationInfo) {
            case .email(_): return .email
            case .sms(_): return .sms
            }
        case .pending(let pending):
            switch(pending.pendingRegistrationInfo) {
            case .email(_): return .email
            case .sms(_): return .sms
            }
        }
    }
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

