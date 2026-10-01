import SwiftUI

struct LanguageSettingsTabView: View {
    @AppStorage("appLanguageCode") private var appLanguageCode = AppLanguageOption.system.id
    @Environment(\.colorScheme) private var colorScheme


    private let options = AppLanguageOption.all

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("จัดการภาษา")
                    .font(.custom("SukhumvitSet-Bold", size: 30))
                    .foregroundStyle(.primary)

                Text("เลือกภาษาหลักที่ต้องการใช้ในแอพ")
                    .font(.custom("SukhumvitSet-Text", size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 6)

            GlassCard {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(currentOption.accent.opacity(colorScheme == .dark ? 0.18 : 0.1))
                            .frame(width: 74, height: 74)

                        Image(systemName: currentOption.icon)
                            .font(.custom("SukhumvitSet-Bold", size: 30))
                            .foregroundStyle(currentOption.accent)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Label("ภาษาที่ใช้อยู่", systemImage: "character.book.closed.fill")
                            .font(.custom("SukhumvitSet-Bold", size: 18))
                            .foregroundStyle(.primary)

                        Text(currentOption.title)
                            .font(.custom("SukhumvitSet-Bold", size: 26))
                            .foregroundStyle(.primary)

                        Text(currentOption.currentDescription)
                            .font(.custom("SukhumvitSet-Text", size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }

            VStack(spacing: 12) {
                ForEach(options) { option in
                    languageOptionRow(option)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 126)
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: appLanguageCode)
    }

    private var currentOption: AppLanguageOption {
        options.first { $0.id == appLanguageCode } ?? .system
    }

    private func languageOptionRow(_ option: AppLanguageOption) -> some View {
        Button {
            apply(option)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(option.accent.opacity(colorScheme == .dark ? 0.16 : 0.1))
                        .frame(width: 48, height: 48)

                    Image(systemName: option.icon)
                        .font(.custom("SukhumvitSet-Bold", size: 19))
                        .foregroundStyle(option.accent)
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

                Spacer(minLength: 0)

                if option.id == appLanguageCode {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.custom("SukhumvitSet-Bold", size: 22))
                        .foregroundStyle(option.accent)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.custom("SukhumvitSet-Bold", size: 15))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(option.id == appLanguageCode ? option.accent.opacity(0.38) : Color.white.opacity(colorScheme == .dark ? 0.16 : 0.34), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(option.id == appLanguageCode)
    }

    private func apply(_ option: AppLanguageOption) {
        appLanguageCode = option.id

    }
}

private struct AppLanguageOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let currentDescription: String
    let icon: String
    let accent: Color

    static let system = AppLanguageOption(
        id: "system",
        title: "ตามระบบ",
        subtitle: "ใช้ภาษาตามการตั้งค่าของ iPhone",
        currentDescription: "แอพจะอ้างอิงภาษาหลักจากเครื่องนี้",
        icon: "iphone",
        accent: .indigo
    )

    static let thai = AppLanguageOption(
        id: "th",
        title: "ภาษาไทย",
        subtitle: "เหมาะกับการใช้งานหลักในหอพัก",
        currentDescription: "แอพจะแสดงผลโดยยึดภาษาไทยเป็นหลัก",
        icon: "textformat",
        accent: .blue
    )

    static let english = AppLanguageOption(
        id: "en",
        title: "ภาษาอังกฤษ",
        subtitle: "ใช้ภาษาอังกฤษเป็นภาษาหลักของแอพ",
        currentDescription: "แอพจะแสดงภาษาอังกฤษในส่วนที่รองรับการแปล",
        icon: "globe",
        accent: .purple
    )

    static let all: [AppLanguageOption] = [.system, .thai, .english]
}
