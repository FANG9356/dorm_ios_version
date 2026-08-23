import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private struct LocalBackupFile: Identifiable {
    let url: URL
    let createdAt: Date
    let size: Int64

    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

private enum LocalBackupConfirmation: Identifiable {
    case restore(LocalBackupFile)
    case restoreImported(URL)
    case delete(LocalBackupFile)
    case resetLocal

    var id: String {
        switch self {
        case .restore(let file): return "restore-\(file.id)"
        case .restoreImported(let url): return "restore-imported-\(url.path)"
        case .delete(let file): return "delete-\(file.id)"
        case .resetLocal: return "reset-local"
        }
    }
}

struct BackupTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var rooms: [Room]
    @Query private var tenants: [DormUser]
    @Query private var payments: [Payment]
    @Query private var maintenanceItems: [Maintenance]
    @Query private var roomTypes: [RoomType]
    @Query private var logs: [LocalSystemLog]

    @State private var backupFiles: [LocalBackupFile] = []
    @State private var isImportingBackup = false
    @State private var isBusy = false
    @State private var confirmation: LocalBackupConfirmation?
    @State private var message: String?
    @State private var errorMessage: String?

    private var backupType: UTType {
        UTType(filenameExtension: "dorminetbackup") ?? .json
    }

    private var currentEmail: String {
        (APIService.shared.currentEmail ?? UserDefaults.standard.string(forKey: "userEmail") ?? "local")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                statusBanner
                actionsCard
                backupListCard
                dangerCard
            }
            .padding(.top, 90)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .task {
            refreshBackupFiles()
        }
        .fileImporter(
            isPresented: $isImportingBackup,
            allowedContentTypes: [.json, backupType],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert(item: $confirmation) { item in
            confirmationAlert(for: item)
        }
    }

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "archivebox.fill")
                        .font(.custom("SukhumvitSet-Bold", size: 28))
                        .foregroundStyle(.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ไฟล์ข้อมูลของระบบนี้")
                            .font(.custom("SukhumvitSet-Bold", size: 20))
                        Text("สำรองข้อมูลไว้ในเครื่อง แยกตามอีเมลหลักของแต่ละระบบ")
                            .font(.custom("SukhumvitSet-Text", size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    BackupMetricView(title: "ห้อง", value: rooms.count, icon: "bed.double.fill")
                    BackupMetricView(title: "ลูกบ้าน", value: tenants.count, icon: "person.2.fill")
                    BackupMetricView(title: "ชำระเงิน", value: payments.count, icon: "dollarsign.circle.fill")
                    BackupMetricView(title: "แจ้งซ่อม", value: maintenanceItems.count, icon: "wrench.and.screwdriver.fill")
                    BackupMetricView(title: "ราคา", value: roomTypes.count, icon: "tag.fill")
                    BackupMetricView(title: "บันทึก", value: logs.count, icon: "doc.text.fill")
                }
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let message {
            BackupStatusBanner(text: message, icon: "checkmark.circle.fill", tint: .green)
        } else if let errorMessage {
            BackupStatusBanner(text: errorMessage, icon: "exclamationmark.triangle.fill", tint: .red)
        }
    }

    private var actionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                BackupSectionHeader(
                    icon: "iphone",
                    title: "ไฟล์สำรองในเครื่อง",
                    subtitle: "สร้างไฟล์จากข้อมูลภายในเครื่องปัจจุบัน แล้วเลือกแชร์เก็บไว้ที่ Files, iCloud Drive หรือ AirDrop ได้"
                )

                HStack(spacing: 10) {
                    BackupActionButton(
                        title: "สร้างไฟล์สำรอง",
                        icon: "archivebox.fill",
                        tint: .primary,
                        isLoading: isBusy,
                        action: createBackup
                    )
                    BackupActionButton(
                        title: "นำเข้าไฟล์",
                        icon: "folder.badge.plus",
                        tint: .primary,
                        isLoading: isBusy,
                        action: { isImportingBackup = true }
                    )
                }
            }
        }
    }

    private var backupListCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                BackupSectionHeader(
                    icon: "list.bullet.rectangle.portrait",
                    title: "รายการในเครื่อง",
                    subtitle: backupFiles.isEmpty ? "ยังไม่มีไฟล์สำรองในเครื่องนี้" : "\(backupFiles.count) ไฟล์สำหรับ \(currentEmail)"
                )

                if backupFiles.isEmpty {
                    BackupEmptyStateView(text: "กดสร้างไฟล์สำรองเพื่อเก็บข้อมูลล่าสุดไว้ในเครื่อง")
                } else {
                    VStack(spacing: 10) {
                        ForEach(backupFiles) { file in
                            LocalBackupRow(
                                file: file,
                                isBusy: isBusy,
                                onRestore: { confirmation = .restore(file) },
                                onDelete: { confirmation = .delete(file) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var dangerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                BackupSectionHeader(
                    icon: "exclamationmark.triangle.fill",
                    title: "ล้างข้อมูลในเครื่อง",
                    subtitle: "ใช้เมื่อแน่ใจว่ามีไฟล์สำรองแล้ว ข้อมูลบนเครื่องนี้จะถูกลบ แต่ไม่กระทบข้อมูลของอีเมลอื่น"
                )

                BackupActionButton(
                    title: "ล้างข้อมูลภายในเครื่อง",
                    icon: "trash.fill",
                    tint: .red,
                    isLoading: isBusy,
                    action: { confirmation = .resetLocal }
                )
            }
        }
    }

    private func createBackup() {
        Task {
            isBusy = true
            defer { isBusy = false }

            do {
                let directory = try backupDirectory()
                let data = try SyncManager.shared.exportLocalBackupData(modelContext: modelContext)
                let fileURL = directory.appendingPathComponent("DormiNet_\(safeEmailSlug())_\(Self.fileStamp()).dorminetbackup")
                try data.write(to: fileURL, options: .atomic)
                refreshBackupFiles()
                showMessage("สร้างไฟล์สำรองไว้ในเครื่องเรียบร้อยแล้ว")
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            confirmation = .restoreImported(url)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func restoreBackup(from url: URL, shouldCopyIntoLocalFolder: Bool) {
        Task {
            isBusy = true
            defer { isBusy = false }

            do {
                let didStart = url.startAccessingSecurityScopedResource()
                defer {
                    if didStart { url.stopAccessingSecurityScopedResource() }
                }

                let data = try Data(contentsOf: url)
                try SyncManager.shared.restoreLocalBackupData(data, modelContext: modelContext)

                if shouldCopyIntoLocalFolder {
                    let destination = try backupDirectory().appendingPathComponent(url.lastPathComponent)
                    if !FileManager.default.fileExists(atPath: destination.path) {
                        try data.write(to: destination, options: .atomic)
                    }
                    refreshBackupFiles()
                }

                modelContext.insert(LocalSystemLog(action: "Local Restore", details: "กู้คืนข้อมูลจากไฟล์ \(url.lastPathComponent)"))
                try modelContext.save()
                showMessage("กู้คืนข้อมูลในเครื่องเรียบร้อยแล้ว")
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func deleteBackup(_ file: LocalBackupFile) {
        do {
            try FileManager.default.removeItem(at: file.url)
            refreshBackupFiles()
            showMessage("ลบไฟล์สำรองแล้ว")
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func resetLocalData() {
        Task {
            isBusy = true
            defer { isBusy = false }

            do {
                for item in rooms { modelContext.delete(item) }
                for item in tenants { modelContext.delete(item) }
                for item in payments { modelContext.delete(item) }
                for item in maintenanceItems { modelContext.delete(item) }
                for item in roomTypes { modelContext.delete(item) }
                for item in logs { modelContext.delete(item) }
                UserDefaults.standard.set(false, forKey: "syncHasPendingLocalChanges")
                UserDefaults.standard.set(0, forKey: "lastSyncVersion")
                try modelContext.save()
                showMessage("ล้างข้อมูลภายในเครื่องของเครื่องนี้เรียบร้อยแล้ว")
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func refreshBackupFiles() {
        do {
            let directory = try backupDirectory()
            backupFiles = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension == "dorminetbackup" }
            .map { url in
                let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                return LocalBackupFile(
                    url: url,
                    createdAt: values.contentModificationDate ?? Date.distantPast,
                    size: Int64(values.fileSize ?? 0)
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
        } catch {
            backupFiles = []
        }
    }

    private func backupDirectory() throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw URLError(.cannotCreateFile)
        }
        let directory = documents
            .appendingPathComponent("DormiNetBackups", isDirectory: true)
            .appendingPathComponent(safeEmailSlug(), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func safeEmailSlug() -> String {
        let raw = currentEmail.isEmpty ? "local" : currentEmail
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return raw.unicodeScalars.map { allowed.contains($0) ? Character($0).description : "_" }.joined()
    }

    private func confirmationAlert(for item: LocalBackupConfirmation) -> Alert {
        switch item {
        case .restore(let file):
            return Alert(
                title: Text("กู้คืนไฟล์นี้?"),
                message: Text("ข้อมูลภายในเครื่องปัจจุบันบนเครื่องนี้จะถูกเขียนทับด้วย \(file.name)"),
                primaryButton: .destructive(Text("กู้คืน")) { restoreBackup(from: file.url, shouldCopyIntoLocalFolder: false) },
                secondaryButton: .cancel(Text("ยกเลิก"))
            )
        case .restoreImported(let url):
            return Alert(
                title: Text("นำเข้าและกู้คืนไฟล์?"),
                message: Text("ข้อมูลภายในเครื่องปัจจุบันบนเครื่องนี้จะถูกเขียนทับด้วย \(url.lastPathComponent)"),
                primaryButton: .destructive(Text("กู้คืน")) { restoreBackup(from: url, shouldCopyIntoLocalFolder: true) },
                secondaryButton: .cancel(Text("ยกเลิก"))
            )
        case .delete(let file):
            return Alert(
                title: Text("ลบไฟล์สำรอง?"),
                message: Text(file.name),
                primaryButton: .destructive(Text("ลบ")) { deleteBackup(file) },
                secondaryButton: .cancel(Text("ยกเลิก"))
            )
        case .resetLocal:
            return Alert(
                title: Text("ล้างข้อมูลในเครื่อง?"),
                message: Text("ข้อมูลภายในเครื่องของเครื่องนี้จะถูกลบ ควรสร้างไฟล์สำรองก่อน"),
                primaryButton: .destructive(Text("ล้างข้อมูล")) { resetLocalData() },
                secondaryButton: .cancel(Text("ยกเลิก"))
            )
        }
    }

    private func showMessage(_ text: String) {
        message = text
        errorMessage = nil
    }

    private func showError(_ text: String) {
        errorMessage = text
        message = nil
    }

    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
}

private struct BackupSectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.custom("SukhumvitSet-Bold", size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                Text(title)
                    .font(.custom("SukhumvitSet-Bold", size: 17))
            }
            Text(subtitle)
                .font(.custom("SukhumvitSet-Text", size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

private struct BackupStatusBanner: View {
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.custom("SukhumvitSet-Bold", size: 13))
                .foregroundStyle(.primary)
                .lineLimit(3)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.12)))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct BackupMetricView: View {
    let title: String
    let value: Int
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.custom("SukhumvitSet-Bold", size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(.ultraThinMaterial))
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.custom("SukhumvitSet-Bold", size: 18))
                Text(title)
                    .font(.custom("SukhumvitSet-Text", size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.thinMaterial))
    }
}

private struct BackupActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(tint)
                } else {
                    Image(systemName: icon)
                        .font(.custom("SukhumvitSet-Bold", size: 15))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.custom("SukhumvitSet-Bold", size: 13))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.thinMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isLoading)
    }
}

private struct BackupEmptyStateView: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
            Text(text)
                .font(.custom("SukhumvitSet-Text", size: 13))
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.thinMaterial))
    }
}

private struct LocalBackupRow: View {
    let file: LocalBackupFile
    let isBusy: Bool
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.ultraThinMaterial))
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name)
                        .font(.custom("SukhumvitSet-Bold", size: 13))
                        .lineLimit(1)
                    Text("\(formattedSize(file.size)) • \(formattedDate(file.createdAt))")
                        .font(.custom("SukhumvitSet-Text", size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                ShareLink(item: file.url) {
                    rowButtonLabel("แชร์", icon: "square.and.arrow.up", tint: .primary)
                }
                .buttonStyle(PressableButtonStyle())

                Button(action: onRestore) {
                    rowButtonLabel("กู้คืน", icon: "arrow.counterclockwise", tint: .primary)
                }
                .buttonStyle(PressableButtonStyle())

                Button(action: onDelete) {
                    rowButtonLabel("ลบ", icon: "trash", tint: .red)
                }
                .buttonStyle(PressableButtonStyle())
            }
            .disabled(isBusy)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.thinMaterial))
    }

    private func rowButtonLabel(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.custom("SukhumvitSet-Bold", size: 11))
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.thinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
