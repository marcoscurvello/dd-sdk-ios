import Foundation

/// `Encodable` representation of log. It gets sanitized before encoding.
internal struct Log: Encodable {
    enum Status: String, Encodable {
        case debug = "DEBUG"
        case info = "INFO"
        case notice = "NOTICE"
        case warn = "WARN"
        case error = "ERROR"
        case critical = "CRITICAL"
    }

    let date: Date
    let status: Status
    let message: String
    let serviceName: String
    let loggerName: String
    let loggerVersion: String
    let threadName: String
    let applicationVersion: String
    let userInfo: UserInfo
    let networkConnectionInfo: NetworkConnectionInfo
    let mobileCarrierInfo: CarrierInfo?
    let attributes: [String: EncodableValue]?
    let tags: [String]?

    func encode(to encoder: Encoder) throws {
        let sanitizedLog = LogSanitizer().sanitize(log: self)
        try LogEncoder().encode(sanitizedLog, to: encoder)
    }
}

/// Encodes `Log` to given encoder.
internal struct LogEncoder {
    /// Coding keys for permanent `Log` attributes.
    enum StaticCodingKeys: String, CodingKey {
        case date
        case status
        case message
        case serviceName = "service"
        case tags = "ddtags"

        // MARK: - Application info

        case applicationVersion = "application.version"

        // MARK: - Logger info

        case loggerName = "logger.name"
        case loggerVersion = "logger.version"
        case threadName = "logger.thread_name"

        // MARK: - User info

        case userId = "usr.id"
        case userName = "usr.name"
        case userEmail = "usr.email"

        // MARK: - Network connection info

        case networkReachability = "network.client.reachability"
        case networkAvailableInterfaces = "network.client.available_interfaces"
        case networkConnectionSupportsIPv4 = "network.client.supports_ipv4"
        case networkConnectionSupportsIPv6 = "network.client.supports_ipv6"
        case networkConnectionIsExpensive = "network.client.is_expensive"
        case networkConnectionIsConstrained = "network.client.is_constrained"

        // MARK: - Mobile carrier info

        case mobileNetworkCarrierName = "network.client.sim_carrier.name"
        case mobileNetworkCarrierISOCountryCode = "network.client.sim_carrier.iso_country"
        case mobileNetworkCarrierRadioTechnology = "network.client.sim_carrier.technology"
        case mobileNetworkCarrierAllowsVoIP = "network.client.sim_carrier.allows_voip"
    }

    /// Coding keys for dynamic `Log` attributes specified by user.
    private struct DynamicCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
        init(_ string: String) { self.stringValue = string }
    }

    func encode(_ log: Log, to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StaticCodingKeys.self)
        try container.encode(log.date, forKey: .date)
        try container.encode(log.status, forKey: .status)
        try container.encode(log.message, forKey: .message)
        try container.encode(log.serviceName, forKey: .serviceName)

        // Encode logger info
        try container.encode(log.loggerName, forKey: .loggerName)
        try container.encode(log.loggerVersion, forKey: .loggerVersion)
        try container.encode(log.threadName, forKey: .threadName)

        // Encode application info
        try container.encode(log.applicationVersion, forKey: .applicationVersion)

        // Encode user info
        try log.userInfo.id.ifNotNil { try container.encode($0, forKey: .userId) }
        try log.userInfo.name.ifNotNil { try container.encode($0, forKey: .userName) }
        try log.userInfo.email.ifNotNil { try container.encode($0, forKey: .userEmail) }

        // Encode network info
        try container.encode(log.networkConnectionInfo.reachability, forKey: .networkReachability)
        try container.encode(log.networkConnectionInfo.availableInterfaces, forKey: .networkAvailableInterfaces)
        try container.encode(log.networkConnectionInfo.supportsIPv4, forKey: .networkConnectionSupportsIPv4)
        try container.encode(log.networkConnectionInfo.supportsIPv6, forKey: .networkConnectionSupportsIPv6)
        try container.encode(log.networkConnectionInfo.isExpensive, forKey: .networkConnectionIsExpensive)
        try log.networkConnectionInfo.isConstrained.ifNotNil {
            try container.encode($0, forKey: .networkConnectionIsConstrained)
        }

        // Encode mobile carrier info
        if let carrierInfo = log.mobileCarrierInfo {
            try carrierInfo.carrierName.ifNotNil {
                try container.encode($0, forKey: .mobileNetworkCarrierName)
            }
            try carrierInfo.carrierISOCountryCode.ifNotNil {
                try container.encode($0, forKey: .mobileNetworkCarrierISOCountryCode)
            }
            try container.encode(carrierInfo.radioAccessTechnology, forKey: .mobileNetworkCarrierRadioTechnology)
            try container.encode(carrierInfo.carrierAllowsVOIP, forKey: .mobileNetworkCarrierAllowsVoIP)
        }

        // Encode custom user attributes
        if let attributes = log.attributes {
            var attributesContainer = encoder.container(keyedBy: DynamicCodingKey.self)
            try attributes.forEach { try attributesContainer.encode($0.value, forKey: DynamicCodingKey($0.key)) }
        }

        // Encode tags
        if let tags = log.tags {
            let tagsString = tags.joined(separator: ",")
            try container.encode(tagsString, forKey: .tags)
        }
    }
}
