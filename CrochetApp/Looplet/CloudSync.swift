import Foundation

/// Lightweight mirror of the pattern library + yarn stash to iCloud
/// Key-Value Store (`NSUbiquitousKeyValueStore`).
///
/// This is an ADDITIVE layer on top of the local JSON persistence in
/// `PatternLibrary`. The local JSON files remain the source of truth; KVS is
/// only a best-effort cross-device mirror.
///
/// All calls degrade silently when iCloud is not configured / not signed:
/// `NSUbiquitousKeyValueStore` is always safe to message — without the
/// entitlement it simply does not persist remotely and reads return defaults
/// (empty data, `0` for the timestamp). So local behavior is unchanged whether
/// or not the user has activated the iCloud capability.
///
/// Not isolated to an actor: `NSUbiquitousKeyValueStore` and `NotificationCenter`
/// are thread-safe, and the sole caller (`PatternLibrary`, a SwiftUI
/// `ObservableObject`) drives this from the main thread. The change observer is
/// delivered on `.main`. Keeping it `nonisolated` lets `PatternLibrary` call in
/// synchronously without crossing actor boundaries.
final class CloudSync: @unchecked Sendable {
    static let shared = CloudSync()

    private let store = NSUbiquitousKeyValueStore.default
    private let entriesKey = "cloud.patterns.v1"
    private let yarnKey = "cloud.yarn.v1"
    private let stampKey = "cloud.lastModified.v1"

    private init() {}

    /// Push local data to iCloud KVS with a fresh timestamp.
    /// Has no observable effect if iCloud is unavailable.
    func push(entries: Data, yarn: Data) {
        store.set(entries, forKey: entriesKey)
        store.set(yarn, forKey: yarnKey)
        store.set(Date().timeIntervalSince1970, forKey: stampKey)
        store.synchronize()
    }

    /// Returns the remote payload only if iCloud holds data with a timestamp
    /// strictly newer than `localStamp`, otherwise `nil`.
    func pullIfNewer(localStamp: TimeInterval) -> (entries: Data, yarn: Data)? {
        let remoteStamp = store.double(forKey: stampKey)
        guard remoteStamp > localStamp,
              let e = store.data(forKey: entriesKey),
              let y = store.data(forKey: yarnKey) else { return nil }
        return (e, y)
    }

    /// Timestamp of the data currently in iCloud KVS (0 if none / unavailable).
    var remoteStamp: TimeInterval { store.double(forKey: stampKey) }

    /// Start observing external (other-device) changes; `onChange` is invoked
    /// on the main queue whenever iCloud reports an external update.
    func startObserving(_ onChange: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store, queue: .main
        ) { _ in
            onChange()
        }
        store.synchronize()
    }
}
