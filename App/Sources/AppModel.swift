import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot: AuditSnapshot?
    @Published var scanState: ScanState = .idle
    @Published var section: AppSection = .overview
    @Published var selectedPackage: CleanupPackage = .conservative
    @Published var notice: AppNotice?
    @Published var cleanupRun: CleanupRunState?
    @Published var cleanupApprovalText = ""
    @Published var isCleanupPresented = false

    private let service: CLIService?
    private let startupError: Error?
    private var cleanupProcess: CleanupProcess?
    private var cleanupEventsTask: Task<Void, Never>?

    init() {
        do {
            service = try CLIService.resolve()
            startupError = nil
        } catch {
            service = nil
            startupError = error
        }
    }

    var isScanning: Bool { scanState == .scanning }

    func refresh() {
        guard !isScanning else { return }
        guard let service else {
            scanState = .failed(startupError?.localizedDescription ?? "Storage engine unavailable.")
            return
        }

        scanState = .scanning
        Task {
            do {
                snapshot = try await service.audit()
                scanState = .loaded(Date())
            } catch {
                scanState = .failed(error.localizedDescription)
            }
        }
    }

    var approvalPhraseMatches: Bool {
        guard let phrase = cleanupRun?.approvalPhrase else { return false }
        return cleanupApprovalText == phrase
    }

    func beginProtectedCleanup() {
        guard let service else {
            notice = AppNotice(title: "Engine unavailable", message: startupError?.localizedDescription ?? "Storage engine unavailable.")
            return
        }
        guard let snapshot else {
            notice = AppNotice(title: "Run a scan first", message: "A current read-only audit is required before building a cleanup plan.")
            return
        }

        if cleanupProcess != nil {
            isCleanupPresented = true
            return
        }

        let package = selectedPackage
        cleanupApprovalText = ""
        cleanupRun = CleanupRunState(
            cleanupPackage: package,
            estimate: snapshot.reclaimableBytes(for: package)
        )
        isCleanupPresented = true

        do {
            let process = try service.startIntegratedCleanup(package: package)
            cleanupProcess = process
            cleanupEventsTask = Task { [weak self] in
                for await event in process.events {
                    guard let self else { return }
                    self.handleCleanupEvent(event)
                }
            }
        } catch {
            cleanupRun?.phase = .failed(error.localizedDescription)
        }
    }

    func submitCleanupApproval() {
        guard approvalPhraseMatches,
              let phrase = cleanupRun?.approvalPhrase,
              let cleanupProcess else { return }

        // Lock the sheet before the phrase enters the engine. From here onward,
        // revalidation and cleanup must be allowed to finish without interruption.
        cleanupRun?.phase = .running
        do {
            try cleanupProcess.sendApproval(phrase)
        } catch {
            cleanupRun?.phase = .failed(error.localizedDescription)
            cleanupProcess.cancelBeforeApproval()
        }
    }

    func cancelCleanupReview() {
        guard cleanupRun?.phase.isRunningCommands != true else { return }
        cleanupRun?.phase = .cancelled
        cleanupProcess?.cancelBeforeApproval()
        isCleanupPresented = false
    }

    func closeCleanupResult() {
        guard cleanupRun?.phase.isRunningCommands != true else { return }
        isCleanupPresented = false
    }

    func cleanupSheetDidDismiss() {
        guard cleanupRun?.phase.isRunningCommands != true else {
            isCleanupPresented = true
            return
        }
        if cleanupRun?.phase.isTerminal != true {
            cleanupProcess?.cancelBeforeApproval()
        }
        cleanupEventsTask?.cancel()
        cleanupEventsTask = nil
        cleanupProcess = nil
        cleanupRun = nil
        cleanupApprovalText = ""
    }

    private func handleCleanupEvent(_ event: CleanupProcessEvent) {
        guard cleanupRun != nil else { return }
        switch event {
        case .output(let text):
            cleanupRun?.transcript.append(text)
            if let transcript = cleanupRun?.transcript, transcript.count > 180_000 {
                cleanupRun?.transcript = String(transcript.suffix(150_000))
            }
        case .approvalRequired(let phrase):
            cleanupRun?.approvalPhrase = phrase
            cleanupRun?.phase = .awaitingApproval
        case .executionStarted:
            cleanupRun?.phase = .running
        case .logPath(let path):
            cleanupRun?.logPath = path
        case .cancelled:
            cleanupRun?.phase = .cancelled
        case .finished(let status):
            let previousPhase = cleanupRun?.phase
            cleanupProcess = nil
            cleanupEventsTask = nil

            if previousPhase == .cancelled {
                return
            }
            if status == 0, previousPhase == .running {
                cleanupRun?.phase = .succeeded
                refresh()
            } else if status == 0 {
                cleanupRun?.phase = .cancelled
            } else {
                cleanupRun?.phase = .failed("Storage engine exited with status \(status). Review the session output for details.")
            }
        }
    }
}

struct AppNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
