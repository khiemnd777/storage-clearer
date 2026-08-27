import Foundation

struct AuditSnapshot: Codable, Sendable {
    let schemaVersion: Int
    let engineVersion: String
    let disk: DiskSnapshot
    let environment: EnvironmentSnapshot
    let packages: CleanupPackages
    let actions: [CleanupAction]

    func actions(for package: CleanupPackage) -> [CleanupAction] {
        let included = Set(packages.ids(for: package))
        return actions.filter { included.contains($0.id) }
    }

    func reclaimableBytes(for package: CleanupPackage) -> Int64 {
        actions(for: package).reduce(0) { $0 + max(0, $1.estimateBytes) }
    }
}

struct DiskSnapshot: Codable, Sendable {
    let device: String
    let totalBytes: Int64
    let usedBytes: Int64
    let freeBytes: Int64

    var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }
}

struct EnvironmentSnapshot: Codable, Sendable {
    let dockerReady: Bool
    let dockerRawBytes: Int64
    let worksBytes: Int64
    let timeMachineSnapshotCount: String
    let apfsSnapshotCount: String
    let latestIOSRuntime: String
}

struct CleanupPackages: Codable, Sendable {
    let A: [String]
    let B: [String]

    func ids(for package: CleanupPackage) -> [String] {
        switch package {
        case .conservative: A
        case .complete: B
        }
    }
}

struct CleanupAction: Codable, Identifiable, Sendable {
    let id: String
    let label: String
    let risk: RiskLevel
    let option: String
    let estimate: String
    let estimateBytes: Int64
    let reason: String
    let executable: Bool

    var symbol: String {
        switch id {
        case "time-machine-snapshots", "time-machine-thin": "clock.arrow.circlepath"
        case "docker-build-cache": "shippingbox"
        case "docker-unused-images": "square.3.layers.3d.down.right"
        case "docker-stopped-containers": "stop.circle"
        case "docker-unused-volumes": "externaldrive.badge.xmark"
        case "dev-caches": "hammer"
        case "simulator-old-runtimes": "iphone.gen3.slash"
        case "simulator-unavailable-devices": "iphone.gen3.badge.exclamationmark"
        case "browser-site-data": "globe"
        case "works-generated": "folder.badge.gearshape"
        case "ai-assistant-caches": "sparkles"
        case "codex-sessions": "text.bubble"
        default: "internaldrive"
        }
    }
}

enum RiskLevel: String, Codable, Sendable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case unknown = "UNKNOWN"
}

enum CleanupPackage: String, CaseIterable, Identifiable, Sendable {
    case conservative = "A"
    case complete = "B"

    var id: String { rawValue }
    var title: String { self == .conservative ? "Essential" : "Deep clean" }
    var subtitle: String {
        self == .conservative
            ? "Rebuildable files and unavailable simulators"
            : "Essential plus older iOS runtimes"
    }
    var engineChoice: String { rawValue }
}

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case cleanup
    case safety

    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: "Overview"
        case .cleanup: "Cleanup plan"
        case .safety: "Safety center"
        }
    }
    var symbol: String {
        switch self {
        case .overview: "chart.donut"
        case .cleanup: "sparkles.rectangle.stack"
        case .safety: "checkmark.shield"
        }
    }
}

enum ScanState: Equatable {
    case idle
    case scanning
    case loaded(Date)
    case failed(String)
}

enum CleanupRunPhase: Equatable, Sendable {
    case preparing
    case awaitingApproval
    case running
    case succeeded
    case failed(String)
    case cancelled

    var isRunningCommands: Bool {
        self == .running
    }

    var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .cancelled:
            true
        default:
            false
        }
    }
}

struct CleanupRunState: Sendable {
    let cleanupPackage: CleanupPackage
    let estimate: Int64
    var phase: CleanupRunPhase = .preparing
    var approvalPhrase: String?
    var transcript = ""
    var logPath: String?
}

extension Int64 {
    var storageLabel: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.isAdaptive = true
        formatter.includesUnit = true
        return formatter.string(fromByteCount: self)
    }
}
