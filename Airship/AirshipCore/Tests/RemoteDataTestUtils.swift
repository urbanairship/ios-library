
import Foundation

@testable
import AirshipCore

@objc
public class RemoteDataTestUtils: NSObject {
    @objc(generatePayloadWithType:timestamp:data:source:)
    public class func generatePayload(
        type: String,
        timestamp: Date,
        data: [AnyHashable: Any],
        source: RemoteDataSource
    ) -> RemoteDataPayload {
        return RemoteDataPayload(
            type: type,
            timestamp: timestamp,
            data: try! AirshipJSON.wrap(data),
            remoteDataInfo: RemoteDataInfo(url: URL(string: "someurl")!, lastModifiedTime: nil, source: source)
        )
    }

    public class func generatePayload(
        type: String,
        timestamp: Date,
        data: [AnyHashable: Any],
        remoteDataInfo: RemoteDataInfo
    ) -> RemoteDataPayload {
        return RemoteDataPayload(
            type: type,
            timestamp: timestamp,
            data: try! AirshipJSON.wrap(data),
            remoteDataInfo: remoteDataInfo
        )
    }

    @objc(generatePayloadWithType:timestamp:data:source:lastModified:)
    public class func generatePayload(
        type: String,
        timestamp: Date,
        data: [AnyHashable: Any],
        source: RemoteDataSource,
        lastModified: String
    ) -> RemoteDataPayload {
        return RemoteDataPayload(
            type: type,
            timestamp: timestamp,
            data: try! AirshipJSON.wrap(data),
            remoteDataInfo: RemoteDataInfo(url: URL(string: "someurl")!, lastModifiedTime: lastModified, source: source)
        )
    }
}
