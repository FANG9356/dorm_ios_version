import SwiftUI

struct AppIconSettingsTabView: View {
    @AppStorage("selectedHomeIconName") private var selectedHomeIconName: String = "default"
    @Environment(\.colorScheme) private var colorScheme
    @State private var isChanging = false


    private let options: [HomeIconOption] = [
        HomeIconOption(id: "default", title: "มาตรฐาน", subtitle: "โทนหลักของ DormiNet", previewAssetName: "AppIconPreviewDefault", alternateName: nil, accent: .indigo),
        HomeIconOption(id: "light", title: "โทนสว่าง", subtitle: "เหมาะกับหน้าจอสว่าง", previewAssetName: "AppIconPreviewLight", alternateName: "AppIconLight", accent: .blue),
        HomeIconOption(id: "dark", title: "โทนมืด", subtitle: "เข้ากับพื้นหลังมืด", previewAssetName: "AppIconPreviewDark", alternateName: "AppIconDark", accent: .purple),
        HomeIconOption(id: "minimal", title: "มินิมอล", subtitle: "เรียบ ขาวดำ ใช้งานได้ทุกธีม", previewAssetName: "AppIconPreviewMinimal", alternateName: "AppIconMinimal", accent: .gray)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("หน้าปกแอพ")
                    .font(.custom("SukhumvitSet-Bold", size: 30))
                    .foregroundStyle(.primary)

                Text("เลือกไอคอนที่จะแสดงบนหน้า Home Screen ของ iPhone")
                    .font(.custom("SukhumvitSet-Text", size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 6)

            GlassCard {
                HStack(spacing: 16) {
                    previewImage(currentOption, size: 72, radius: 18)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("ไอคอนที่ใช้อยู่", systemImage: "app.badge")
                            .font(.custom("SukhumvitSet-Bold", size: 18))
                            .foregroundStyle(.primary)

                        Text(currentOption.title)
                            .font(.custom("SukhumvitSet-Bold", size: 26))
                            .foregroundStyle(.primary)

                        Text("ระบบอาจแสดงข้อความยืนยันหลังเลือก")
                            .font(.custom("SukhumvitSet-Text", size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(options) { option in
                    iconOptionCard(option)
                }
            }
        }
        .padding(.top, 126)
        .padding(.horizontal, 20)
        .onAppear {
            selectedHomeIconName = optionID(for: AppIconManager.currentIconName)
        }
    }

    private var currentOption: HomeIconOption {
        options.first { $0.id == selectedHomeIconName } ?? options[0]
    }

    private func iconOptionCard(_ option: HomeIconOption) -> some View {
        Button {
            apply(option)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    previewImage(option, size: 58, radius: 14)

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(isSelected(option) ? option.accent.opacity(0.18) : Color.primary.opacity(0.06))
                            .frame(width: 30, height: 30)

                        if isChanging && isSelected(option) {
                            ProgressView()
                                .scaleEffect(0.72)
                        } else if isSelected(option) {
                            Image(systemName: "checkmark")
                                .font(.custom("SukhumvitSet-Bold", size: 13))
                                .foregroundStyle(option.accent)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.custom("SukhumvitSet-Bold", size: 17))
                        .foregroundStyle(.primary)

                    Text(option.subtitle)
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isSelected(option) ? option.accent.opacity(0.42) : Color.white.opacity(0.16), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isChanging || isSelected(option))
    }

    private func isSelected(_ option: HomeIconOption) -> Bool {
        selectedHomeIconName == option.id
    }

    private func apply(_ option: HomeIconOption) {
        guard AppIconManager.supportsAlternateIcons else {

            return
        }

        isChanging = true


        Task {
            let result = await AppIconManager.setIcon(option.alternateName)
            await MainActor.run {
                isChanging = false
                switch result {
                case .success:
                    selectedHomeIconName = option.id

                case .failure(let error):
                    selectedHomeIconName = optionID(for: AppIconManager.currentIconName)

                }
            }
        }
    }

    private func optionID(for alternateName: String?) -> String {
        options.first { $0.alternateName == alternateName }?.id ?? "default"
    }

    private func previewImage(_ option: HomeIconOption, size: CGFloat, radius: CGFloat) -> some View {
        Image(option.previewAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.36), lineWidth: 1)
            )
            .shadow(color: option.accent.opacity(colorScheme == .dark ? 0.22 : 0.16), radius: 10, x: 0, y: 6)
    }
}

private struct HomeIconOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let previewAssetName: String
    let alternateName: String?
    let accent: Color
}
