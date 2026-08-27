import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 250)
        } detail: {
            ZStack {
                AppTheme.canvas.ignoresSafeArea()
                Group {
                    switch model.section {
                    case .overview:
                        OverviewView()
                    case .cleanup:
                        CleanupPlanView()
                    case .safety:
                        SafetyCenterView()
                    }
                }
                // NavigationSplitView otherwise reuses the underlying NSScrollView
                // and carries the previous page's offset into the newly selected tab.
                .id(model.section)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(alignment: .top) {
                if model.isScanning {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(AppTheme.primary)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            if case .idle = model.scanState {
                model.refresh()
            }
        }
        .alert(item: $model.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("Done"))
            )
        }
        .sheet(isPresented: $model.isCleanupPresented, onDismiss: model.cleanupSheetDidDismiss) {
            CleanupSessionView()
                .environmentObject(model)
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(AppTheme.primary)
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.canvas)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Storage Clearer")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.text)
                    Text("Mac workspace care")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .textCase(.uppercase)
                        .tracking(0.7)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 28)
            .padding(.bottom, 34)

            VStack(spacing: 6) {
                ForEach(AppSection.allCases) { section in
                    Button {
                        model.section = section
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.symbol)
                                .font(.system(size: 15, weight: .medium))
                                .frame(width: 20)
                            Text(section.title)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                        }
                        .foregroundStyle(model.section == section ? AppTheme.text : AppTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(model.section == section ? AppTheme.primarySoft : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 12)

            ViewThatFits(in: .vertical) {
                SidebarSafetyCard(version: model.snapshot?.engineVersion, compact: false)
                SidebarSafetyCard(version: model.snapshot?.engineVersion, compact: true)
            }
            .padding(14)
        }
        .background(AppTheme.sidebar)
    }
}

struct OverviewView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ResettableScrollView(section: .overview) {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: "SMART STORAGE AUDIT",
                    title: "Your Mac, with room to breathe.",
                    subtitle: "A clear view of what is using space — and what is genuinely safe to rebuild."
                ) {
                    ScanButton()
                }

                if let snapshot = model.snapshot {
                    StorageHero(snapshot: snapshot)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
                        MetricTile(
                            icon: "externaldrive.fill",
                            label: "Available now",
                            value: snapshot.disk.freeBytes.storageLabel,
                            detail: snapshot.disk.device
                        )
                        MetricTile(
                            icon: "arrow.down.circle.fill",
                            label: "Safe opportunity",
                            value: snapshot.reclaimableBytes(for: .conservative).storageLabel,
                            detail: "Essential package"
                        )
                        MetricTile(
                            icon: "shippingbox.fill",
                            label: "Docker allocation",
                            value: snapshot.environment.dockerRawBytes.storageLabel,
                            detail: snapshot.environment.dockerReady ? "Docker is available" : "Docker is offline"
                        )
                        MetricTile(
                            icon: "hammer.fill",
                            label: "Workspace size",
                            value: snapshot.environment.worksBytes.storageLabel,
                            detail: "Source files stay protected"
                        )
                    }

                    HStack(alignment: .firstTextBaseline) {
                        SectionTitle(title: "Recommended opportunities", subtitle: "Rebuildable items with the lowest operational risk")
                        Spacer()
                        Button("View full plan") { model.section = .cleanup }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppTheme.primary)
                            .font(.system(size: 12, weight: .semibold))
                    }

                    VStack(spacing: 0) {
                        ForEach(snapshot.actions(for: .conservative)) { action in
                            ActionRow(action: action, included: true)
                            if action.id != snapshot.actions(for: .conservative).last?.id {
                                Divider().overlay(AppTheme.border).padding(.leading, 50)
                            }
                        }
                    }
                    .storageCard(padding: 8)
                } else {
                    ScanPlaceholder(state: model.scanState)
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 32)
            .padding(.bottom, 40)
            .frame(maxWidth: 1240, alignment: .leading)
        }
    }
}

struct CleanupPlanView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ResettableScrollView(section: .cleanup) {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: "REVIEW BEFORE ACTION",
                    title: "Build a cleanup you can trust.",
                    subtitle: "Choose a reviewed package. High-risk and personal data never enter these plans."
                ) {
                    ScanButton()
                }

                if let snapshot = model.snapshot {
                    HStack(spacing: 14) {
                        ForEach(CleanupPackage.allCases) { package in
                            PackageCard(
                                package: package,
                                count: snapshot.actions(for: package).count,
                                reclaimable: snapshot.reclaimableBytes(for: package),
                                selected: model.selectedPackage == package
                            ) {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    model.selectedPackage = package
                                }
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(model.selectedPackage.title) plan")
                                        .font(.system(size: 19, weight: .bold, design: .rounded))
                                        .foregroundStyle(AppTheme.text)
                                    Text(model.selectedPackage.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                Text(snapshot.reclaimableBytes(for: model.selectedPackage).storageLabel)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.primary)
                            }
                            .padding(20)

                            Divider().overlay(AppTheme.border)

                            ForEach(snapshot.actions(for: model.selectedPackage)) { action in
                                ActionRow(action: action, included: true)
                            }
                        }
                        .storageCard(padding: 0)
                        .frame(maxWidth: .infinity)

                        ReviewPanel(snapshot: snapshot)
                            .frame(width: 300)
                    }

                    SectionTitle(title: "Manual review", subtitle: "Visible for transparency, excluded from Essential and Deep clean")
                    VStack(spacing: 0) {
                        ForEach(snapshot.actions.filter { !$0.option.contains("A/B") && $0.option != "B/Custom" }) { action in
                            ActionRow(action: action, included: false)
                        }
                    }
                    .storageCard(padding: 8)
                } else {
                    ScanPlaceholder(state: model.scanState)
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 32)
            .padding(.bottom, 40)
            .frame(maxWidth: 1240, alignment: .leading)
        }
    }
}

struct SafetyCenterView: View {
    @EnvironmentObject private var model: AppModel

    private let exclusions = [
        ("person.crop.circle.badge.checkmark", "Personal data", "Photos, Mail, Messages and device backups"),
        ("shippingbox.and.arrow.backward", "Docker volumes", "Persistent databases and orphaned application data"),
        ("folder.fill.badge.checkmark", "Source projects", "Everything inside your Works folders"),
        ("clock.badge.checkmark", "Restore points", "Time Machine and APFS snapshots"),
        ("globe.badge.chevron.backward", "Browser profiles", "Sessions, history and website storage"),
        ("text.bubble.fill", "Codex history", "Task sessions and conversation records")
    ]

    var body: some View {
        ResettableScrollView(section: .safety) {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: "SAFETY BY DESIGN",
                    title: "Protection is part of the product.",
                    subtitle: "Storage Clearer makes destructive boundaries visible and re-checks every changing target."
                ) {
                    ScanButton()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                    ProtectionCard(number: "01", icon: "eye.fill", title: "Audit first", detail: "Every scan and plan is read-only. No cleanup command runs in the background.")
                    ProtectionCard(number: "02", icon: "text.cursor", title: "Exact approval", detail: "The final plan requires a phrase that matches the selected scope exactly.")
                    ProtectionCard(number: "03", icon: "arrow.triangle.2.circlepath", title: "Revalidate", detail: "Simulator, Docker and snapshot targets are checked again immediately before execution.")
                    ProtectionCard(number: "04", icon: "doc.text.magnifyingglass", title: "Keep a record", detail: "Every cleanup command is written to a timestamped log in your user Library.")
                }

                SectionTitle(title: "Always excluded", subtitle: "The commercial packages never touch these categories")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    ForEach(exclusions, id: \.1) { item in
                        HStack(spacing: 14) {
                            Image(systemName: item.0)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 36, height: 36)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.1)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.text)
                                Text(item.2)
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .storageCard(padding: 14)
                    }
                }

                if let snapshot = model.snapshot {
                    HStack(spacing: 18) {
                        SnapshotFact(label: "Time Machine snapshots", value: snapshot.environment.timeMachineSnapshotCount)
                        SnapshotFact(label: "Data APFS snapshots", value: snapshot.environment.apfsSnapshotCount)
                        SnapshotFact(label: "Newest iOS kept", value: snapshot.environment.latestIOSRuntime)
                    }
                    .storageCard()
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 32)
            .padding(.bottom, 40)
            .frame(maxWidth: 1240, alignment: .leading)
        }
    }
}

struct ResettableScrollView<Content: View>: View {
    let section: AppSection
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 1)
                    content
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scrollIndicators(.visible)
            .id(section)
        }
    }
}

struct SidebarSafetyCard: View {
    let version: String?
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 12) {
            Label("Protected by review", systemImage: "checkmark.shield.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
            if !compact {
                Text("Nothing is removed until you review a refreshed plan and type its approval phrase.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let version {
                Text("Engine \(version)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 12 : 15)
        .background(Color.black.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct PageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.primary)
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            accessory
        }
    }
}

struct ScanButton: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button(action: model.refresh) {
            HStack(spacing: 8) {
                if model.isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text(model.isScanning ? "Scanning…" : "Scan again")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(model.isScanning)
    }
}

struct StorageHero: View {
    let snapshot: AuditSnapshot

    var body: some View {
        HStack(spacing: 30) {
            StorageRing(fraction: snapshot.disk.usedFraction)
                .frame(width: 154, height: 154)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle().fill(AppTheme.primary).frame(width: 7, height: 7)
                    Text("AUDIT COMPLETE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.primary)
                }
                Text("\(snapshot.disk.usedBytes.storageLabel) in use")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)
                Text("of \(snapshot.disk.totalBytes.storageLabel) total capacity")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)

                HStack(spacing: 18) {
                    Label("Source-safe", systemImage: "checkmark.circle.fill")
                    Label("No auto-delete", systemImage: "hand.raised.fill")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.top, 6)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text("LOW-RISK OPPORTUNITY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.secondaryText)
                Text(snapshot.reclaimableBytes(for: .conservative).storageLabel)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primary)
                Text("estimated before final revalidation")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .storageCard(padding: 26, elevated: true)
    }
}

struct StorageRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 13))
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    AngularGradient(colors: [AppTheme.primary, Color.cyan.opacity(0.85), AppTheme.primary], center: .center),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(fraction * 100))%")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)
                Text("USED")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
}

struct MetricTile: View {
    let icon: String
    let label: String
    let value: String
    let detail: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 38, height: 38)
                .background(AppTheme.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.8))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .storageCard(padding: 14)
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
}

struct ActionRow: View {
    let action: CleanupAction
    let included: Bool

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: action.symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(included ? AppTheme.primary : AppTheme.secondaryText)
                .frame(width: 36, height: 36)
                .background(included ? AppTheme.primarySoft : Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(action.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    RiskBadge(risk: action.risk)
                }
                Text(action.reason)
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(action.estimate)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(included ? AppTheme.text : AppTheme.secondaryText)
                Text(included ? "Included" : action.option)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(included ? AppTheme.primary : AppTheme.secondaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct RiskBadge: View {
    let risk: RiskLevel

    private var color: Color {
        switch risk {
        case .low: AppTheme.primary
        case .medium: AppTheme.warning
        case .high: AppTheme.danger
        case .unknown: AppTheme.secondaryText
        }
    }

    var body: some View {
        Text(risk.rawValue)
            .font(.system(size: 8, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct PackageCard: View {
    let package: CleanupPackage
    let count: Int
    let reclaimable: Int64
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                ZStack {
                    Circle()
                        .stroke(selected ? AppTheme.primary : AppTheme.border, lineWidth: 2)
                    if selected {
                        Circle().fill(AppTheme.primary).padding(5)
                    }
                }
                .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(package.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.text)
                    Text("\(count) reviewed actions")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Text(reclaimable.storageLabel)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? AppTheme.primary : AppTheme.text)
            }
            .padding(18)
            .background(selected ? AppTheme.primarySoft : AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? AppTheme.primary.opacity(0.45) : AppTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

struct ReviewPanel: View {
    @EnvironmentObject private var model: AppModel
    let snapshot: AuditSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.primary)
            VStack(alignment: .leading, spacing: 6) {
                Text("Protected in-app cleanup")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)
                Text("Review, approve and follow cleanup progress without leaving Storage Clearer.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 9) {
                SafetyLine(icon: "arrow.clockwise", text: "Audit refreshes before execution")
                SafetyLine(icon: "text.cursor", text: "Approval phrase is required")
                SafetyLine(icon: "doc.text", text: "Commands are logged")
            }

            Divider().overlay(AppTheme.border)

            Text("The engine will refresh Package \(model.selectedPackage.engineChoice), show the exact plan, and wait for its matching approval phrase.")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                model.beginProtectedCleanup()
            } label: {
                HStack {
                    Text("Review & clean in app")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .storageCard(padding: 20, elevated: true)
    }
}

struct CleanupSessionView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if let run = model.cleanupRun {
                VStack(spacing: 0) {
                    cleanupHeader(run)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 22)

                    Divider().overlay(AppTheme.border)

                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                CleanupFact(
                                    label: "Reviewed package",
                                    value: "Package \(run.cleanupPackage.engineChoice) · \(run.cleanupPackage.title)"
                                )
                                CleanupFact(label: "Current estimate", value: run.estimate.storageLabel)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Engine output")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Spacer()
                                    if let logPath = run.logPath {
                                        Label("Log created", systemImage: "doc.text.fill")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(AppTheme.primary)
                                            .help(logPath)
                                    }
                                }
                                CleanupTranscriptView(text: run.transcript)
                            }

                            phaseControls(run)
                        }
                        .padding(26)
                    }
                    .scrollIndicators(.visible)
                }
                .background(AppTheme.canvas)
                .interactiveDismissDisabled(run.phase.isRunningCommands)
            } else {
                ProgressView()
                    .frame(width: 640, height: 480)
                    .background(AppTheme.canvas)
            }
        }
        .frame(
            minWidth: 640,
            idealWidth: 760,
            maxWidth: 860,
            minHeight: 420,
            idealHeight: 660,
            maxHeight: 780
        )
    }

    @ViewBuilder
    private func cleanupHeader(_ run: CleanupRunState) -> some View {
        HStack(spacing: 15) {
            Image(systemName: headerSymbol(for: run.phase))
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(headerColor(for: run.phase))
                .frame(width: 44, height: 44)
                .background(headerColor(for: run.phase).opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle(for: run.phase))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)
                Text(headerSubtitle(for: run.phase))
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()

            if run.phase == .preparing || run.phase == .running {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.primary)
            }
        }
    }

    @ViewBuilder
    private func phaseControls(_ run: CleanupRunState) -> some View {
        switch run.phase {
        case .preparing:
            HStack {
                Label("Refreshing the audit and building an exact plan. Nothing has been removed.", systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Button("Cancel", action: model.cancelCleanupReview)
                    .buttonStyle(.bordered)
            }

        case .awaitingApproval:
            VStack(alignment: .leading, spacing: 12) {
                Text("Type this exact phrase to approve the refreshed scope")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.text)

                Text(run.approvalPhrase ?? "")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.primary)
                    .textSelection(.enabled)

                TextField("Exact approval phrase", text: $model.cleanupApprovalText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .onSubmit(model.submitCleanupApproval)

                HStack(spacing: 12) {
                    Label("Rebuildable files may be permanently removed after revalidation.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppTheme.warning)
                    Spacer()
                    Button("Cancel", action: model.cancelCleanupReview)
                        .buttonStyle(.bordered)
                    Button(action: model.submitCleanupApproval) {
                        Label("Run approved cleanup", systemImage: "trash.fill")
                    }
                    .buttonStyle(DestructiveButtonStyle())
                    .disabled(!model.approvalPhraseMatches)
                    .opacity(model.approvalPhraseMatches ? 1 : 0.45)
                }
            }
            .storageCard(padding: 16, elevated: true)

        case .running:
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.primary)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Revalidating targets and running the approved plan")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    Text("Keep Storage Clearer open. This window will unlock when the engine finishes.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
            }
            .storageCard(padding: 15, elevated: true)

        case .succeeded:
            HStack(spacing: 12) {
                Label("Cleanup finished. The storage overview is refreshing.", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                Spacer()
                Button("Done", action: model.closeCleanupResult)
                    .buttonStyle(PrimaryButtonStyle())
            }

        case .failed(let message):
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.danger)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Close", action: model.closeCleanupResult)
                    .buttonStyle(.bordered)
            }

        case .cancelled:
            HStack {
                Label("Session cancelled. Nothing was removed.", systemImage: "xmark.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Button("Close", action: model.closeCleanupResult)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func headerTitle(for phase: CleanupRunPhase) -> String {
        switch phase {
        case .preparing: "Refreshing cleanup plan"
        case .awaitingApproval: "Approval required"
        case .running: "Cleanup in progress"
        case .succeeded: "Cleanup complete"
        case .failed: "Cleanup needs attention"
        case .cancelled: "Cleanup cancelled"
        }
    }

    private func headerSubtitle(for phase: CleanupRunPhase) -> String {
        switch phase {
        case .preparing: "The engine is auditing current targets again before asking for approval."
        case .awaitingApproval: "Verify the refreshed plan and enter its exact phrase to continue."
        case .running: "Only the approved package is executing; all commands are recorded."
        case .succeeded: "The approved package finished and its execution record is available below."
        case .failed: "No further command will run. Review the output to understand what happened."
        case .cancelled: "The protected session ended before cleanup execution."
        }
    }

    private func headerSymbol(for phase: CleanupRunPhase) -> String {
        switch phase {
        case .preparing: "arrow.triangle.2.circlepath"
        case .awaitingApproval: "text.cursor"
        case .running: "gearshape.2.fill"
        case .succeeded: "checkmark.shield.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "xmark.shield.fill"
        }
    }

    private func headerColor(for phase: CleanupRunPhase) -> Color {
        switch phase {
        case .failed: AppTheme.danger
        case .awaitingApproval: AppTheme.warning
        case .cancelled: AppTheme.secondaryText
        default: AppTheme.primary
        }
    }
}

struct CleanupFact: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storageCard(padding: 13)
    }
}

struct CleanupTranscriptView: View {
    let text: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                Text(text.isEmpty ? "Starting protected engine session…" : text)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(14)
                Color.clear
                    .frame(height: 1)
                    .id("cleanup-log-end")
            }
            .frame(maxWidth: .infinity, minHeight: 150, idealHeight: 220, maxHeight: 280)
            .background(Color.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
            .onChange(of: text) { _ in
                proxy.scrollTo("cleanup-log-end", anchor: .bottom)
            }
        }
    }
}

struct SafetyLine: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(AppTheme.secondaryText)
    }
}

struct ProtectionCard: View {
    let number: String
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                Spacer()
                Text(number)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.65))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .storageCard()
    }
}

struct SnapshotFact: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ScanPlaceholder: View {
    let state: ScanState

    var body: some View {
        VStack(spacing: 16) {
            switch state {
            case .scanning:
                ProgressView()
                    .controlSize(.large)
                    .tint(AppTheme.primary)
                Text("Auditing storage without changing anything…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(AppTheme.warning)
                Text("The scan could not finish")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            default:
                Image(systemName: "internaldrive")
                    .font(.system(size: 26))
                    .foregroundStyle(AppTheme.primary)
                Text("Ready for a read-only scan")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .storageCard()
    }
}
