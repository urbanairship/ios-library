import Foundation
import AirshipCore

class MockRemoteDataProvider : NSObject, UARemoteDataProvider {
    
    var isMetadataCurrent = true
    private var subscribers: [String : [UUID]] = [:]
    private var blocks: [UUID : UARemoteDataPublishBlock] = [:]
    
    override init() {
        super.init()
    }
    
    func dispatchPayload(_ payload: UARemoteDataPayload) {
        let blockIds = self.subscribers[payload.type]
        blockIds?.forEach({ blockId in
            self.blocks[blockId]?([payload])
        })
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
                self.subscribers[type] = blocks
            }
        }
    }
    
    func isMetadataCurrent(_ metadata: [AnyHashable : Any]) -> Bool {
        return true
    }
}
