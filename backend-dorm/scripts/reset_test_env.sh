#!/usr/bin/env bash
# reset_test_env.sh — สคริปต์จัดการรีเซ็ตระบบและเคลียร์การผูก LINE สำหรับการทดสอบ DormiNetX
# ตำแหน่งบนเซิร์ฟเวอร์: /home/fang/dorminet_workspace/reset_test_env.sh
set -euo pipefail

WORKSPACE_DIR="/home/fang/dorminet_workspace"
MASTER_DB="/opt/dormitory/dormitory.db"
TENANT_DIR="/opt/dormitory/dorm_data"
UPLOADS_DIR="/opt/dormitory/uploads"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${WORKSPACE_DIR}/backups/${TIMESTAMP}-reset-backup"

backup_now() {
    echo "📦 กำลังสำรองฐานข้อมูลก่อนดำเนินการที่: ${BACKUP_DIR} ..."
    mkdir -p "${BACKUP_DIR}"
    if sudo test -f "${MASTER_DB}"; then
        sudo cp -p /opt/dormitory/dormitory.db* "${BACKUP_DIR}/" 2>/dev/null || true
    fi
    if sudo test -d "${TENANT_DIR}"; then
        sudo cp -a "${TENANT_DIR}" "${BACKUP_DIR}/"
    fi
    echo "✅ สำรองข้อมูลเรียบร้อยแล้ว"
}

unlink_line() {
    echo "🔗 กำลังเคลียร์การผูก LINE ของลูกบ้านทั้งหมด..."
    backup_now
    sudo sqlite3 "${MASTER_DB}" "DELETE FROM line_links; DELETE FROM line_notification_outbox;"
    if sudo test -d "${TENANT_DIR}"; then
        while IFS= read -r db; do
            echo "   - ปลด LINE ในฐานข้อมูล: $(basename "$db")"
            sudo sqlite3 "$db" "UPDATE users SET line_user_id = '', bot_state = 'none'; DELETE FROM line_notification_outbox;"
        done < <(sudo find "${TENANT_DIR}" -maxdepth 1 -name "tenant_*.db")
    fi
    echo ""
    echo "🎉 ปลดการผูก LINE ของลูกบ้านเรียบร้อยแล้ว!"
    echo "👉 ลูกบ้านสามารถเปิด LIFF เพื่อเชื่อมต่อห้องใหม่ หรือพิมพ์ข้อความหา LINE Official Account เพื่อเริ่มผูกบัญชีใหม่ได้ทันที"
}

clear_data_keep_admin() {
    echo "🧹 กำลังรีเซ็ตข้อมูลหอพักทั้งหมด (เก็บบัญชี Admin เดิมไว้)..."
    backup_now
    echo "⏹️ สั่งหยุด dormitory.service ชั่วคราว..."
    sudo systemctl stop dormitory.service

    echo "🗑️ ล้างประวัติ Sync Snapshots, Delivery Logs และ LINE Links ใน Master DB..."
    sudo sqlite3 "${MASTER_DB}" "DELETE FROM sync_snapshots; DELETE FROM line_links; DELETE FROM line_delivery_logs; DELETE FROM line_notification_outbox; VACUUM;"

    if sudo test -d "${TENANT_DIR}"; then
        while IFS= read -r db; do
            echo "🗑️ ล้างข้อมูลในฐานข้อมูล: $(basename "$db")"
            sudo sqlite3 "$db" "DELETE FROM users; DELETE FROM rooms; DELETE FROM room_types; DELETE FROM payments; DELETE FROM maintenances; DELETE FROM financial_audits; DELETE FROM deposit_refunds; DELETE FROM room_conditions; DELETE FROM system_logs; DELETE FROM line_notification_outbox; VACUUM;"
        done < <(sudo find "${TENANT_DIR}" -maxdepth 1 -name "tenant_*.db")
    fi

    echo "🗑️ ล้างไฟล์สลิปและรูปภาพที่อัปโหลด..."
    sudo rm -rf ${UPLOADS_DIR}/* 2>/dev/null || true
    sudo mkdir -p ${UPLOADS_DIR}
    sudo chmod 755 ${UPLOADS_DIR}

    echo "▶️ สั่งเริ่ม dormitory.service ใหม่..."
    sudo systemctl start dormitory.service
    sleep 2

    if curl --fail --silent http://127.0.0.1:4283/api/system/ping >/dev/null 2>&1; then
        echo ""
        echo "🎉 ล้างข้อมูลระบบบนเซิร์ฟเวอร์เรียบร้อยแล้ว! (บัญชี Admin เดิมยังคงอยู่ ล็อกอินได้ตามปกติ)"
        echo ""
        echo "⚠️ คำเตือนสำคัญมากสำหรับแอป iOS (Local-First):"
        echo "   ต้องลบแอป DormiNetX ออกจาก iPhone (Delete App) แล้วติดตั้งใหม่"
        echo "   เพื่อล้าง SwiftData บนเครื่องให้สะอาด ไม่เช่นนั้นเครื่องจะส่งข้อมูลเดิมกลับขึ้นมาบนเซิร์ฟเวอร์!"
    else
        echo "❌ เซิร์ฟเวอร์ไม่ตอบสนอง กรุณาตรวจสอบ logs ด้วย: sudo journalctl -u dormitory.service -n 30"
    fi
}

factory_reset() {
    echo "💥 คำเตือน: คุณกำลังจะล้างระบบ 100% แบบโรงงาน (ลบทั้ง Admin, ห้อง, และลูกบ้านทั้งหมด)!"
    read -rp "ยืนยันจะทำ Factory Reset หรือไม่? (พิมพ์ y เพื่อยืนยัน): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        bash "${WORKSPACE_DIR}/clean_reset_production.sh"
        echo ""
        echo "🎉 ทำ Factory Reset เรียบร้อยแล้ว!"
        echo "👉 ให้ลบแอป DormiNetX บน iPhone แล้วติดตั้งใหม่ เพื่อลงทะเบียน Admin ใหม่ตั้งแต่หน้าแรก"
    else
        echo "❌ ยกเลิกการทำ Factory Reset"
    fi
}

show_status() {
    echo "📊 === ตรวจสอบสถานะข้อมูลปัจจุบัน ==="
    if test -f "${MASTER_DB}"; then
        echo -n "👤 จำนวน Admin: "
        sqlite3 "${MASTER_DB}" "SELECT count(*) FROM admins;" 2>/dev/null || echo "0"
        echo -n "🔄 จำนวน Sync Snapshots: "
        sqlite3 "${MASTER_DB}" "SELECT count(*) FROM sync_snapshots;" 2>/dev/null || echo "0"
        echo -n "📱 จำนวน LINE ที่ผูกอยู่ (line_links): "
        sqlite3 "${MASTER_DB}" "SELECT count(*) FROM line_links WHERE status = 'linked';" 2>/dev/null || echo "0"
    fi
    if test -d "${TENANT_DIR}"; then
        while IFS= read -r db; do
            echo "--- ฐานข้อมูล $(basename "$db") ---"
            echo -n "🚪 จำนวนห้องพัก: "
            sqlite3 "$db" "SELECT count(*) FROM rooms;" 2>/dev/null || echo "0"
            echo -n "👥 จำนวนลูกบ้าน: "
            sqlite3 "$db" "SELECT count(*) FROM users;" 2>/dev/null || echo "0"
            echo -n "🧾 จำนวนบิล/การชำระเงิน: "
            sqlite3 "$db" "SELECT count(*) FROM payments;" 2>/dev/null || echo "0"
            echo -n "🛠️ จำนวนงานแจ้งซ่อม: "
            sqlite3 "$db" "SELECT count(*) FROM maintenances;" 2>/dev/null || echo "0"
        done < <(find "${TENANT_DIR}" -maxdepth 1 -name "tenant_*.db")
    fi
}

action="${1:-menu}"
case "$action" in
    line|unlink|1)
        unlink_line
        ;;
    data|clear|2)
        clear_data_keep_admin
        ;;
    factory|full|3)
        factory_reset
        ;;
    status|stat|4)
        show_status
        ;;
    menu)
        echo "================================================="
        echo "      เครื่องมือรีเซ็ตระบบสำหรับทดสอบ DormiNetX      "
        echo "================================================="
        echo "1) ปลดการผูก LINE ลูกบ้านทั้งหมด (Unlink LINE Only)"
        echo "2) รีเซ็ตข้อมูลหอพักทั้งหมดจาก 0 (เก็บบัญชี Admin เดิมไว้)"
        echo "3) รีเซ็ตเกลี้ยง 100% แบบโรงงาน (Factory Reset รวม Admin)"
        echo "4) ดูสถานะและจำนวนข้อมูลปัจจุบัน (Status)"
        echo "5) ยกเลิก / ออก (Exit)"
        echo "-------------------------------------------------"
        read -rp "กรุณาเลือกตัวเลือก [1-5]: " choice
        case "$choice" in
            1) unlink_line ;;
            2) clear_data_keep_admin ;;
            3) factory_reset ;;
            4) show_status ;;
            *) echo "ยกเลิกการทำงาน" ;;
        esac
        ;;
    *)
        echo "การใช้งาน: $0 [line | data | factory | status]"
        exit 1
        ;;
esac
