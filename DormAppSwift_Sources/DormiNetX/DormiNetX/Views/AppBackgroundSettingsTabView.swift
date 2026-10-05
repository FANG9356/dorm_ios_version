import PhotosUI
import SwiftUI

struct AppBackgroundSettingsTabView: View {
    @AppStorage(AppBackgroundManager.kindKey) private var backgroundKind = AppBackgroundKind.system.rawValue
    @AppStorage(AppBackgroundManager.fileNameKey) private var backgroundFileName = ""
    @AppStorage(AppBackgroundManager.updateTokenKey) private var backgroundUpdateToken = ""
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedImageItem: PhotosPickerItem?
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var isImporting = false


    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("พื้นหลังแอพ")
                    .font(.custom("SukhumvitSet-Bold", size: 30))
                    .foregroundStyle(.primary)

                Text("เลือกรูปหรือวิดีโอจากเครื่องเพื่อใช้เป็นพื้นหลังของทุกหน้า")
                    .font(.custom("SukhumvitSet-Text", size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 6)

            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 14) {
                        backgroundPreview
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.42), lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 8) {
                            Label("พื้นหลังที่ใช้อยู่", systemImage: currentIconName)
                                .font(.custom("SukhumvitSet-Bold", size: 18))
                                .foregroundStyle(.primary)

                            Text(LocalizedStringKey(currentTitle))
                                .font(.custom("SukhumvitSet-Bold", size: 25))
                                .foregroundStyle(.primary)

                            Text(LocalizedStringKey(currentSubtitle))
                                .font(.custom("SukhumvitSet-Text", size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                        Spacer(minLength: 0)
                    }

                    if isImporting {
                        HStack(spacing: 10) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("กำลังนำเข้าไฟล์...")
                                .font(.custom("SukhumvitSet-Medium", size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }

            VStack(spacing: 12) {
                PhotosPicker(selection: $selectedImageItem, matching: .images, photoLibrary: .shared()) {
                    actionRow(
                        icon: "photo.fill",
                        title: "เลือกรูปภาพ",
                        subtitle: "ใช้รูปจาก Photos เป็นพื้นหลัง",
                        accent: .blue
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(isImporting)

                PhotosPicker(selection: $selectedVideoItem, matching: .videos, photoLibrary: .shared()) {
                    actionRow(
                        icon: "play.rectangle.fill",
                        title: "เลือกวิดีโอ",
                        subtitle: "เล่นวนแบบไม่มีเสียงอยู่หลังทุกหน้า",
                        accent: .purple
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(isImporting)

                Button {
                    resetToSystemBackground()
                } label: {
                    actionRow(
                        icon: "sparkles",
                        title: "ใช้พื้นหลังระบบ",
                        subtitle: "กลับไปใช้พื้นหลังเดิมที่เปลี่ยนตามธีม",
                        accent: .gray
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(isImporting)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 126)
        .padding(.horizontal, 20)
        .onChange(of: selectedImageItem) { _, newItem in
            importSelectedItem(newItem, kind: .image)
        }
        .onChange(of: selectedVideoItem) { _, newItem in
            importSelectedItem(newItem, kind: .video)
        }
    }

    private var currentKind: AppBackgroundKind {
        AppBackgroundKind(rawValue: backgroundKind) ?? .system
    }

    private var currentTitle: String {
        switch currentKind {
        case .system: return "พื้นหลังระบบ"
        case .image: return "รูปภาพในเครื่อง"
        case .video: return "วิดีโอในเครื่อง"
        }
    }

    private var currentSubtitle: String {
        switch currentKind {
        case .system:
            return "ใช้พื้นหลังเดิมของ DormiNet และเปลี่ยนตามธีม"
        case .image:
            return "ไฟล์ถูกเก็บไว้ภายในเครื่องนี้เท่านั้น"
        case .video:
            return "วิดีโอเล่นวนแบบปิดเสียงและเก็บไว้ภายในเครื่องนี้"
        }
    }

    private var currentIconName: String {
        switch currentKind {
        case .system: return "sparkles"
        case .image: return "photo.fill"
        case .video: return "play.rectangle.fill"
        }
    }

    @ViewBuilder
    private var backgroundPreview: some View {
        switch currentKind {
        case .image:
            if let url = AppBackgroundManager.url(for: backgroundFileName),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                systemPreview
            }
        case .video:
            if let url = AppBackgroundManager.url(for: backgroundFileName) {
                LoopingBackgroundVideoView(url: url)
                    .allowsHitTesting(false)
            } else {
                systemPreview
            }
        case .system:
            systemPreview
        }
    }

    private var systemPreview: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.12, green: 0.12, blue: 0.17), .purple.opacity(0.52), .orange.opacity(0.34)]
                    : [.white, .blue.opacity(0.18), .purple.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "sparkles")
                .font(.custom("SukhumvitSet-Bold", size: 26))
                .foregroundStyle(.white.opacity(colorScheme == .dark ? 0.9 : 0.7))
        }
    }

    private func actionRow(icon: String, title: String, subtitle: String, accent: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(colorScheme == .dark ? 0.16 : 0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.custom("SukhumvitSet-Bold", size: 19))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.custom("SukhumvitSet-Bold", size: 17))
                    .foregroundStyle(.primary)

                Text(LocalizedStringKey(subtitle))
                    .font(.custom("SukhumvitSet-Text", size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.custom("SukhumvitSet-Bold", size: 15))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.38), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func importSelectedItem(_ item: PhotosPickerItem?, kind: AppBackgroundKind) {
        guard let item else { return }

        isImporting = true


        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw CocoaError(.fileReadUnknown)
                }

                let fileName: String
                switch kind {
                case .image:
                    fileName = try AppBackgroundManager.saveImageData(data)
                case .video:
                    fileName = try AppBackgroundManager.saveVideoData(data)
                case .system:
                    fileName = ""
                }

                await MainActor.run {
                    backgroundFileName = fileName
                    backgroundKind = kind.rawValue
                    backgroundUpdateToken = UUID().uuidString
                    isImporting = false

                }
            } catch {
                await MainActor.run {
                    isImporting = false

                }
            }
        }
    }

    private func resetToSystemBackground() {
        AppBackgroundManager.clearStoredBackgrounds()
        backgroundKind = AppBackgroundKind.system.rawValue
        backgroundFileName = ""
        backgroundUpdateToken = UUID().uuidString

    }
}
