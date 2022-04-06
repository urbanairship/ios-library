import Foundation
import AirshipCore

class MockRemoteDataProvider : NSObject, RemoteDataProvider {
    
    public var remoteDataRefreshInterval: TimeInterval = 0
    var isMetadataCurrent = true
    var subscribers: [String : [UUID]] = [:]
    var blocks: [UUID : (([RemoteDataPayload]) -> Void)] = [:]
    
    override init() {
        super.init()
    }
    
    func dispatchPayload(_ payload: RemoteDataPayload) {
        let blockIds = self.subscribers[payload.type]
        blockIds?.forEach({ blockId in
            self.blocks[blockId]?([payload])
        })
    }
    
    func dispatchPayloads(_ payloads: [RemoteDataPayload]) {
        var blockIdMap: [UUID : [RemoteDataPayload]] = [:]
        
        payloads.forEach { payload in
            self.subscribers[payload.type]?.forEach { blockId in
                blockIdMap[blockId] = blockIdMap[blockId] ?? []
                blockIdMap[blockId]?.append(payload)
            }
        }
        
        blockIdMap.forEach { blockId, payloads in
            self.blocks[blockId]?(payloads)
        }
    }
    
    
    public func subscribe(types: [String], block publishBlock: @escaping ([RemoteDataPayload]) -> Void) -> Disposable {
        let blockID = UUID()
        self.blocks[blockID] = publishBlock
        
        types.forEach { type in
            var blocks = self.subscribers[type] ?? []
            blocks.append(blockID)
            self.subscribers[type] = blocks
        }
        
        return Disposable {
            self.blocks[blockID] = nil
            types.forEach { type in
                var blocks = self.subscribers[type] ?? []
                blocks.removeAll { $0 == blockID }
                self.subscribers[type] = blocks.isEmpty ? nil : blocks
            }
        }
    }
    
    func isMetadataCurrent(_ metadata: [AnyHashable : Any]) -> Bool {
        return true
    }
    
    func attemptRemoteDataRefresh(completionHandler: @escaping () -> Void) {}
}
