import Foundation

@objc public class CallKitVoip: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
