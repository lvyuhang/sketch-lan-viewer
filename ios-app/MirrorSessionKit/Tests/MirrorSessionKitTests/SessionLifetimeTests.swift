import XCTest
@testable import MirrorSessionKit
import ExceptionCatcher
import Foundation

final class SessionLifetimeTests: XCTestCase {

    func testGateRejectsCancelledTask() {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let live = MirrorSessionGate.liveSession(
            taskCancelled: true,
            capturedGeneration: 1,
            currentGeneration: 1,
            session: session
        )
        XCTAssertNil(live)
    }

    func testGateRejectsStaleGeneration() {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let live = MirrorSessionGate.liveSession(
            taskCancelled: false,
            capturedGeneration: 1,
            currentGeneration: 2,
            session: session
        )
        XCTAssertNil(live)
    }

    func testGateRejectsNilSession() {
        let live = MirrorSessionGate.liveSession(
            taskCancelled: false,
            capturedGeneration: 3,
            currentGeneration: 3,
            session: nil
        )
        XCTAssertNil(live)
    }

    func testGateAllowsMatchingLiveSession() {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let live = MirrorSessionGate.liveSession(
            taskCancelled: false,
            capturedGeneration: 4,
            currentGeneration: 4,
            session: session
        )
        XCTAssertTrue(live === session)
    }

    /// Reproduces the production crash pattern WITHOUT the gate:
    /// sleep → invalidateAndCancel → session.data throws NSException.
    func testOldPatternThrowsNSExceptionOnInvalidatedSession() async {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config)
        let url = URL(string: "http://127.0.0.1:1/")!

        // Let a "catalog refresh" style worker capture the session, then tear it down
        // while the worker is conceptually past sleep (we invalidate first, then call).
        session.invalidateAndCancel()

        var caughtName: String?
        let exception = LVCatchException {
            // This is what MirrorClient.catalogTask did after the 4s sleep.
            // URLSession raises NSException; Swift Error bridging never sees it.
            let semaphore = DispatchSemaphore(value: 0)
            session.dataTask(with: url) { _, _, _ in
                semaphore.signal()
            }.resume()
            // dataTask(with:) itself may throw synchronously via ObjC exception
            // on some OS versions; on others the exception fires when the task
            // is created. Either way LVCatchException must observe it.
            _ = semaphore.wait(timeout: .now() + 0.2)
        }

        // Prefer asserting the known exception; if the platform only fails async,
        // fall back to creating via the async API under the catcher.
        if let exception {
            caughtName = exception.name.rawValue
        } else {
            let asyncEx = LVCatchException {
                let box = ViolationBox(session: session, url: url)
                box.fireSyncCreate()
            }
            caughtName = asyncEx?.name.rawValue
        }

        XCTAssertEqual(
            caughtName,
            "NSGenericException",
            "Old pattern must surface the invalidated-session NSException (got \(caughtName ?? "nil"))"
        )
        if let exception {
            XCTAssertTrue(
                exception.reason?.contains("invalidated") == true
                    || exception.reason?.contains("Invalidated") == true,
                exception.reason ?? ""
            )
        }
    }

    /// Fixed pattern: bump generation + nil session before invalidate;
    /// sleeping worker re-checks the gate and never touches the dead session.
    func testNewPatternSkipsInvalidatedSessionAfterSleep() async {
        let life = MirrorSessionLifetime()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config)
        let generation = life.adopt(session)

        let didTouchSession = ViolationFlag()
        let worker = Task {
            // catalogTask: sleep ~ then fetch — use a short sleep for the test
            try? await Task.sleep(nanoseconds: 150_000_000)
            if let live = life.liveSession(matching: generation, taskCancelled: Task.isCancelled) {
                didTouchSession.value = true
                _ = try? await live.data(from: URL(string: "http://127.0.0.1:1/")!)
            }
        }

        // Tear down mid-sleep (connect/disconnect/reconnect).
        try? await Task.sleep(nanoseconds: 30_000_000)
        worker.cancel()
        life.teardown()

        await worker.value
        XCTAssertFalse(didTouchSession.value, "Gate must prevent session.data on invalidated URLSession")
        XCTAssertNil(life.session)
        XCTAssertEqual(life.generation, generation &+ 1)
    }

    /// Rapid reconnects must not let an older generation worker proceed.
    func testStaleGenerationAfterReconnect() async {
        let life = MirrorSessionLifetime()
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false

        let first = URLSession(configuration: config)
        let gen1 = life.adopt(first)

        let staleTouched = ViolationFlag()
        let staleWorker = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            if let live = life.liveSession(matching: gen1, taskCancelled: Task.isCancelled) {
                staleTouched.value = true
                _ = try? await live.data(from: URL(string: "http://127.0.0.1:1/")!)
            }
        }

        // Reconnect: teardown old, adopt new
        try? await Task.sleep(nanoseconds: 20_000_000)
        life.teardown()
        let second = URLSession(configuration: config)
        let gen2 = life.adopt(second)
        XCTAssertNotEqual(gen1, gen2)

        await staleWorker.value
        XCTAssertFalse(staleTouched.value)

        // New generation still works until torn down
        XCTAssertNotNil(life.liveSession(matching: gen2, taskCancelled: false))
        life.teardown()
        second.invalidateAndCancel()
    }
}

/// Mutable box safe enough for single-writer test flags.
private final class ViolationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var raw = false
    var value: Bool {
        get { lock.lock(); defer { lock.unlock() }; return raw }
        set { lock.lock(); raw = newValue; lock.unlock() }
    }
}

/// Forces a synchronous URLSessionTask create on an invalidated session.
private final class ViolationBox: NSObject {
    let session: URLSession
    let url: URL
    init(session: URLSession, url: URL) {
        self.session = session
        self.url = url
    }
    func fireSyncCreate() {
        // dataTask(with:) validates session state and raises NSException when invalidated.
        _ = session.dataTask(with: url)
    }
}
