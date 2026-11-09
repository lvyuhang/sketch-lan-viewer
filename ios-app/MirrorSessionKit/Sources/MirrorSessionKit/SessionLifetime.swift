import Foundation

/// Decides whether a background MirrorClient worker may still touch a URLSession.
///
/// After `invalidateAndCancel()`, creating a new URLSessionTask throws an
/// Objective-C `NSException` (`Task created in a session that has been invalidated`)
/// that Swift `do/catch` cannot catch and aborts the process. Workers that sleep
/// (catalog refresh ~4s, USB poll, reconnect) must re-check this gate after every
/// `await` before calling `session.data` / `webSocketTask`.
public enum MirrorSessionGate {
    /// - Parameters:
    ///   - taskCancelled: `Task.isCancelled` after the latest await
    ///   - capturedGeneration: generation when the worker started
    ///   - currentGeneration: owner's generation (bumped in teardown before invalidate)
    ///   - session: owner's current session reference (nil after teardown)
    public static func liveSession(
        taskCancelled: Bool,
        capturedGeneration: UInt64,
        currentGeneration: UInt64,
        session: URLSession?
    ) -> URLSession? {
        guard !taskCancelled else { return nil }
        guard capturedGeneration == currentGeneration else { return nil }
        return session
    }
}

/// Owns one URLSession plus a monotonically increasing generation used to fence
/// stale MirrorClient tasks across reconnect / disconnect.
public final class MirrorSessionLifetime: @unchecked Sendable {
    private let lock = NSLock()
    private var generationValue: UInt64 = 0
    private var sessionValue: URLSession?

    public init() {}

    public var generation: UInt64 {
        lock.lock(); defer { lock.unlock() }
        return generationValue
    }

    public var session: URLSession? {
        lock.lock(); defer { lock.unlock() }
        return sessionValue
    }

    /// Install a freshly created session for a new connect. Returns the generation
    /// workers must capture. Does not bump generation (call `teardown()` first).
    @discardableResult
    public func adopt(_ session: URLSession) -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        sessionValue = session
        return generationValue
    }

    /// Bump generation, drop the reference, then invalidate. Safe to call repeatedly.
    public func teardown() {
        lock.lock()
        generationValue &+= 1
        let dying = sessionValue
        sessionValue = nil
        lock.unlock()
        dying?.invalidateAndCancel()
    }

    public func liveSession(matching capturedGeneration: UInt64, taskCancelled: Bool = Task.isCancelled) -> URLSession? {
        lock.lock()
        let current = generationValue
        let session = sessionValue
        lock.unlock()
        return MirrorSessionGate.liveSession(
            taskCancelled: taskCancelled,
            capturedGeneration: capturedGeneration,
            currentGeneration: current,
            session: session
        )
    }
}
