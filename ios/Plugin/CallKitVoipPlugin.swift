import Foundation
import Capacitor
import UIKit
import CallKit
import PushKit

/**
 *  CallKit Voip Plugin provides native PushKit functionality with apple CallKit to capacitor
 */
@objc(CallKitVoipPlugin)
public class CallKitVoipPlugin: CAPPlugin {

    private var provider: CXProvider?
    private let voipRegistry            = PKPushRegistry(queue: nil)
    private var connectionIdRegistry : [UUID: CallConfig] = [:]

    @objc func register(_ call: CAPPluginCall) {
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
        let config = CXProviderConfiguration(localizedName: "Secure Call")
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        // Native call log shows video icon if it was video call.
        config.supportsVideo = true
        // Support generic type to handle *User ID*
        config.supportedHandleTypes = [.generic]
        provider = CXProvider(configuration: config)
        provider?.setDelegate(self, queue: DispatchQueue.main)
        call.resolve()
    }

    public func notifyEvent(eventName: String, uuid: UUID){
        if let config = connectionIdRegistry[uuid] {
            notifyListeners(eventName, data: [
                "id": config.id,
                "media": config.media,
                "name"    : config.name,
                "duration"    : config.duration,
            ])
            connectionIdRegistry[uuid] = nil
        }
    }

    public func incomingCall(id: String, media: String, name: String, duration: String) {
        let update                      = CXCallUpdate()
        update.remoteHandle             = CXHandle(type: .generic, value: name)
        update.hasVideo                 = media == "video"
        update.supportsDTMF             = false
        update.supportsHolding          = true
        update.supportsGrouping         = false
        update.supportsUngrouping       = false
        let uuid = UUID()
        connectionIdRegistry[uuid] = .init(id: id, media: media, name: name, duration: duration)
        self.provider?.reportNewIncomingCall(with: uuid, update: update, completion: { (_) in })
    }




    public func endCall(uuid: UUID) {
        let controller = CXCallController()
        let transaction = CXTransaction(action: CXEndCallAction(call: uuid));controller.request(transaction,completion: { error in })
    }



}


// MARK: CallKit events handler

extension CallKitVoipPlugin: CXProviderDelegate {

    public func providerDidReset(_ provider: CXProvider) {

    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // Notify incoming call accepted
        notifyEvent(eventName: "callAnswered", uuid: action.callUUID)
        endCall(uuid: action.callUUID)
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        // End the call
        notifyEvent(eventName: "callEnded", uuid: action.callUUID)
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        // Report connection started
        notifyEvent(eventName: "callStarted", uuid: action.callUUID)
        action.fulfill()
    }
}

// MARK: PushKit events handler
extension CallKitVoipPlugin: PKPushRegistryDelegate {

    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let parts = pushCredentials.token.map { String(format: "%02.2hhx", $0) }
        let token = parts.joined()
        notifyListeners("registration", data: ["value": token])
    }

    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
         guard let id = payload.dictionaryPayload["id"] as? String else {
             return
         }
         let media = (payload.dictionaryPayload["media"] as? String) ?? "voice"
         let name = (payload.dictionaryPayload["name"] as? String) ?? "Unknown"
         let duration = (payload.dictionaryPayload["duration"] as? String) ?? "0"
        self.incomingCall(id: id, media: media, name: name, duration: duration)
    }

}


extension CallKitVoipPlugin {
    struct CallConfig {
        let id: String
        let media: String
        let name: String
        let duration: String
    }
}
