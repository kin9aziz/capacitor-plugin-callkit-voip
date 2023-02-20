import Foundation
import Capacitor
import UIKit
import CallKit
import PushKit

/**
 *  CallKit Voip Plugin provides native PushKit functionality with apple CallKit to ionic capacitor
 */
@objc(CallKitVoipPlugin)
public class CallKitVoipPlugin: CAPPlugin {

    private var provider: CXProvider?
    private let voipRegistry            = PKPushRegistry(queue: nil)
    private var connectionIdRegistry : [UUID: CallConfig] = [:]

    @objc func register(_ call: CAPPluginCall) {
        // config PushKit
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]

        let config = CXProviderConfiguration(localizedName: "Ihorizon Call")
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportsVideo = true
        config.supportedHandleTypes = [.generic, .phoneNumber]

        provider = CXProvider(configuration: config)
        provider?.setDelegate(self, queue: DispatchQueue.main)

        call.resolve()
    }

    @objc func incomingCall(_ call: CAPPluginCall) {
        // TODO
    }

    public func notifyEvent(eventName: String, uuid: UUID){
        if let config = connectionIdRegistry[uuid] {
            notifyListeners(eventName, data: [
                "connectionId": config.connectionId,
                "connectionType": config.connectionType,
                "username"    : config.username
            ])
            connectionIdRegistry[uuid] = nil
        }
    }

    public func startIncomingCall(connectionId: String, connectionType: String, username: String) {
        let update                      = CXCallUpdate()
        update.remoteHandle             = CXHandle(type: .generic, value: username)
        update.hasVideo                 = connectionType == "video"
        update.supportsDTMF             = false
        update.supportsHolding          = true
        update.supportsGrouping         = false
        update.supportsUngrouping       = false

        let uuid = UUID()
        connectionIdRegistry[uuid] = .init(connectionId: connectionId, connectionType: connectionType, username: username)
        self.provider?.reportNewIncomingCall(with: uuid, update: update, completion: { (_) in })
    }




    public func endCall(uuid: UUID) {
        let controller = CXCallController()
        let transaction = CXTransaction(action:
                                            CXEndCallAction(call: uuid));controller.request(transaction,completion: { error in })
    }

}


// MARK: CallKit events handler

extension CallKitVoipPlugin: CXProviderDelegate {

    public func providerDidReset(_ provider: CXProvider) {
        print("provider did reset")
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("call answered")
        notifyEvent(eventName: "callAnswered", uuid: action.callUUID)
//        endCall(uuid: action.callUUID)
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        notifyEvent(eventName: "callStarted", uuid: action.callUUID)
        action.fulfill()
    }
}

// MARK: PushKit events handler
extension CallKitVoipPlugin: PKPushRegistryDelegate {

    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let parts = pushCredentials.token.map { String(format: "%02.2hhx", $0) }
        let token = parts.joined()
        notifyListeners("registration", data: ["token": token])
    }

    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {

        guard let connectionId = payload.dictionaryPayload["ConnectionId"] as? String else {
            return
        }
        let connectionType = (payload.dictionaryPayload["ConnectionType"] as? String) ?? "voice"
        let username = (payload.dictionaryPayload["Username"] as? String) ?? "Unknown"
        self.startIncomingCall(connectionId: connectionId, connectionType: connectionType, username: username)
    }

}


extension CallKitVoipPlugin {
    struct CallConfig {
        let connectionId   : String
        let connectionType : String
        let username       : String
    }
}
