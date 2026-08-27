import Foundation

enum CLIServiceError: LocalizedError {
    case scriptNotFound
    case auditFailed(String)
    case invalidResponse(String)
    case cleanupLaunchFailed(String)
    case cleanupSessionEnded
    case cleanupInputFailed(String)

    var errorDescription: String? {
        switch self {
        case .scriptNotFound:
            "The storage-clearer engine could not be found. Launch the app from the project folder or build the app bundle with scripts/package_app.sh."
        case .auditFailed(let message):
            "The storage scan failed. \(message)"
        case .invalidResponse(let message):
            "The storage engine returned an unreadable response. \(message)"
        case .cleanupLaunchFailed(let message):
            "The protected cleanup session could not start. \(message)"
        case .cleanupSessionEnded:
            "The protected cleanup session has already ended."
        case .cleanupInputFailed(let message):
            "The approval phrase could not be sent to the storage engine. \(message)"
        }
    }
}

enum CleanupProcessEvent: Sendable {
    case output(String)
    case approvalRequired(String)
    case executionStarted
    case logPath(String)
    case cancelled
    case finished(Int32)
}

final class CleanupProcess: @unchecked Sendable {
    let events: AsyncStream<CleanupProcessEvent>

    private let process: Process
    private let inputHandle: FileHandle
    private let outputHandle: FileHandle
    private let continuation: AsyncStream<CleanupProcessEvent>.Continuation
    private let lock = NSLock()
    private var buffer = Data()
    private var didFinish = false

    init(scriptURL: URL, package: CleanupPackage) throws {
        let input = Pipe()
        let output = Pipe()
        let streamPair = Self.makeEventStream()

        process = Process()
        inputHandle = input.fileHandleForWriting
        outputHandle = output.fileHandleForReading
        events = streamPair.stream
        continuation = streamPair.continuation

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path, "app-run", package.engineChoice]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output

        var environment = ProcessInfo.processInfo.environment
        environment["SC_NO_ANIMATION"] = "1"
        environment["SC_APP_PROTOCOL"] = "1"
        process.environment = environment

        do {
            try process.run()
        } catch {
            inputHandle.closeFile()
            outputHandle.closeFile()
            continuation.finish()
            throw CLIServiceError.cleanupLaunchFailed(error.localizedDescription)
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            self?.readOutputUntilExit()
        }
    }

    func sendApproval(_ phrase: String) throws {
        guard process.isRunning else {
            throw CLIServiceError.cleanupSessionEnded
        }
        do {
            try inputHandle.write(contentsOf: Data("\(phrase)\n".utf8))
            try inputHandle.close()
        } catch {
            throw CLIServiceError.cleanupInputFailed(error.localizedDescription)
        }
    }

    func cancelBeforeApproval() {
        guard process.isRunning else { return }
        inputHandle.closeFile()
        process.terminate()
    }

    private static func makeEventStream() -> (
        stream: AsyncStream<CleanupProcessEvent>,
        continuation: AsyncStream<CleanupProcessEvent>.Continuation
    ) {
        var capturedContinuation: AsyncStream<CleanupProcessEvent>.Continuation?
        let stream = AsyncStream<CleanupProcessEvent> { continuation in
            capturedContinuation = continuation
        }
        return (stream, capturedContinuation!)
    }

    private func readOutputUntilExit() {
        while true {
            // availableData returns as soon as the pipe has bytes. readData(ofLength:)
            // may wait for the requested buffer size, which would hide the approval
            // event while the engine is intentionally paused for user input.
            let data = outputHandle.availableData
            if data.isEmpty { break }
            consume(data)
        }
        process.waitUntilExit()
        flushBuffer()
        finish(status: process.terminationStatus)
    }

    private func consume(_ data: Data) {
        var lines: [String] = []
        lock.lock()
        buffer.append(data)
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.subdata(in: buffer.startIndex..<newlineIndex)
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
            lines.append(String(decoding: lineData, as: UTF8.self))
        }
        lock.unlock()

        lines.forEach(emitLine)
    }

    private func flushBuffer() {
        lock.lock()
        let remaining = buffer
        buffer.removeAll(keepingCapacity: false)
        lock.unlock()
        guard !remaining.isEmpty else { return }
        emitLine(String(decoding: remaining, as: UTF8.self))
    }

    private func emitLine(_ rawLine: String) {
        let line = rawLine.trimmingCharacters(in: .newlines)
        let prefix = "@@STORAGE_CLEARER:"
        guard line.hasPrefix(prefix), line.hasSuffix("@@") else {
            continuation.yield(.output(rawLine + "\n"))
            return
        }

        let payload = line.dropFirst(prefix.count).dropLast(2)
        guard let separator = payload.firstIndex(of: ":") else { return }
        let event = String(payload[..<separator])
        let value = String(payload[payload.index(after: separator)...])
        switch event {
        case "approval":
            continuation.yield(.approvalRequired(value))
        case "execution-started":
            continuation.yield(.executionStarted)
        case "log-path":
            continuation.yield(.logPath(value))
        case "cancelled":
            continuation.yield(.cancelled)
        default:
            break
        }
    }

    private func finish(status: Int32) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        lock.unlock()

        inputHandle.closeFile()
        outputHandle.closeFile()
        continuation.yield(.finished(status))
        continuation.finish()
    }
}

struct CLIService: Sendable {
    let scriptURL: URL

    static func resolve() throws -> CLIService {
        let fileManager = FileManager.default
        var candidates: [URL] = []

        if let override = ProcessInfo.processInfo.environment["STORAGE_CLEARER_CLI"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override))
        }
        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("storage-clearer.sh"))
        }
        candidates.append(URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("storage-clearer.sh"))

        var cursor = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.deletingLastPathComponent()
        for _ in 0..<6 {
            candidates.append(cursor.appendingPathComponent("storage-clearer.sh"))
            cursor.deleteLastPathComponent()
        }

        guard let scriptURL = candidates.first(where: { fileManager.isExecutableFile(atPath: $0.path) }) else {
            throw CLIServiceError.scriptNotFound
        }
        return CLIService(scriptURL: scriptURL.standardizedFileURL)
    }

    func audit() async throws -> AuditSnapshot {
        let path = scriptURL.path
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let output = Pipe()
            let errors = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [path, "app-data"]
            process.standardOutput = output
            process.standardError = errors
            var environment = ProcessInfo.processInfo.environment
            environment["SC_NO_ANIMATION"] = "1"
            process.environment = environment

            do {
                try process.run()
            } catch {
                throw CLIServiceError.auditFailed(error.localizedDescription)
            }
            process.waitUntilExit()

            let data = output.fileHandleForReading.readDataToEndOfFile()
            let errorData = errors.fileHandleForReading.readDataToEndOfFile()
            if process.terminationStatus != 0 {
                let message = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                throw CLIServiceError.auditFailed(message?.isEmpty == false ? message! : "Exit code \(process.terminationStatus).")
            }

            do {
                return try JSONDecoder().decode(AuditSnapshot.self, from: data)
            } catch {
                throw CLIServiceError.invalidResponse(error.localizedDescription)
            }
        }.value
    }

    func startIntegratedCleanup(package: CleanupPackage) throws -> CleanupProcess {
        try CleanupProcess(scriptURL: scriptURL, package: package)
    }
}
