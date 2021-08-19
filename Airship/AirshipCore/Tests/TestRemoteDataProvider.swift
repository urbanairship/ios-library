import Foundation
import AirshipCore

class TestRemoteDataProvider : NSObject, UARemoteDataProvider {
    var remoteDataRefreshInterval: TimeInterval = 0
    func setRefreshInterval(_ refreshInterval: TimeInterval) {
        remoteDataRefreshInterval = refreshInterval
    }
    
    var isMetadataCurrent = true
    var subscribers: [String : [UUID]] = [:]
    var blocks: [UUID : UARemoteDataPublishBlock] = [:]
    
    override init() {
        super.init()
    }
    
    func dispatchPayload(_ payload: UARemoteDataPayload) {
        let blockIds = self.subscribers[payload.type]
        blockIds?.forEach({ blockId in
            self.blocks[blockId]?([payload])
        })
    }
    
    func dispatchPayloads(_ payloads: [UARemoteDataPayload]) {
        var blockIdMap: [UUID : [UARemoteDataPayload]] = [:]
        
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
    
    
    func subscribe(withTypes payloadTypes: [String], block publishBlock: @escaping UARemoteDataPublishBlock) -> UADisposable {
        let blockID = UUID()
        self.blocks[blockID] = publishBlock
        
        payloadTypes.forEach { type in
            var blocks = self.subscribers[type] ?? []
            blocks.append(blockID)
            self.subscribers[type] = blocks
        }
        
        return UADisposable {
            self.blocks[blockID] = nil
            payloadTypes.forEach { type in
                var blocks = self.subscribers[type] ?? []
                blocks.removeAll { $0 == blockID }
                self.subscribers[type] = blocks.isEmpty ? nil : blocks
            }
        }
    }
    
    func isMetadataCurrent(_ metadata: [AnyHashable : Any]) -> Bool {
        return true
    }
}
