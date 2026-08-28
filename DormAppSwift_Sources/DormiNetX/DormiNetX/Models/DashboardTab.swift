import Foundation

enum DashboardTab: String, CaseIterable, Identifiable {
    case overview = "ภาพรวมระบบ"
    case tenants = "จัดการลูกบ้าน"
    case finance = "การเงินและชำระเงิน"
    case bills = "บิลค่าใช้จ่าย (เข้า-ออก)"
    case rooms = "จัดการห้องพัก"
    case pricing = "ตั้งค่าราคา"
    case transfers = "หลักฐานการโอน"
    case maintenance = "แจ้งซ่อม"
    case adminManagement = "จัดการผู้ดูแลระบบ"
    case securityToken = "โทเคนเข้าสู่ระบบ"
    case language = "จัดการภาษา"
    case appIcon = "ไอคอนแอพ"
    case appBackground = "พื้นหลังแอพ"
    case backup = "สำรองและกู้คืนข้อมูล"
    case systemLogs = "บันทึกระบบ"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .tenants: return "person.2.fill"
        case .finance: return "dollarsign.circle.fill"
        case .bills: return "doc.text.fill"
        case .rooms: return "bed.double.fill"
        case .pricing: return "tag.fill"
        case .transfers: return "photo.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .adminManagement: return "person.badge.key.fill"
        case .securityToken: return "lock.shield.fill"
        case .language: return "globe.asia.australia.fill"
        case .appIcon: return "app.fill"
        case .appBackground: return "photo.on.rectangle.angled"
        case .backup: return "archivebox.fill"
        case .systemLogs: return "doc.text.magnifyingglass"
        }
    }
    
    var isSettingsMenu: Bool {
        switch self {
        case .adminManagement, .securityToken, .language, .appIcon, .appBackground, .backup, .systemLogs:
            return true
        default:
            return false
        }
    }
}
