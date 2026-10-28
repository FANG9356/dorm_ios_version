# DormiNetX — Enterprise Local-First Dormitory Management System

[![iOS Build & Test](https://img.shields.io/badge/iOS-SwiftUI%20%7C%20SwiftData-orange?logo=swift)](https://developer.apple.com/swift/)
[![Backend](https://img.shields.io/badge/Backend-Go%20%7C%20SQLite-00ADD8?logo=go)](https://golang.org/)
[![LINE Integration](https://img.shields.io/badge/LINE-Messaging%20API%20%7C%20LIFF-00B900?logo=line)](https://developers.line.biz/)
[![Security Hardened](https://img.shields.io/badge/Security-Keychain%20%7C%20SSH%20Key%20%7C%20Audit%20Log-success)](docs/PRODUCTION_HARDENING_2026-09-10.md)
[![Release Version](https://img.shields.io/badge/Release-v1.0.0-blue)](https://github.com/FANG9356/dorm_ios_version/releases/tag/v1.0.0)

**DormiNetX** คือระบบบริหารจัดการหอพักและอพาร์ตเมนต์ครบวงจร ออกแบบด้วยสถาปัตยกรรม **Local-First** สำหรับ iPhone และ iPad ทำงานร่วมกับ **Go High-Performance Backend**, **Multi-Tenant SQLite Database**, **LINE Official Account (OA)**, และ **LIFF Web Application** ระบบให้ความสำคัญสูงสุดกับความต่อเนื่องในการทำงานแบบออฟไลน์ ความถูกต้องของข้อมูลทางบัญชี และมาตรฐานความปลอดภัยระดับองค์กร

---

## สารบัญ (Table of Contents)
1. [ปรัชญาและสถาปัตยกรรมหลัก (System Architecture Philosophy)](#1-ปรัชญาและสถาปัตยกรรมหลัก-system-architecture-philosophy)
2. [สถาปัตยกรรมฝั่งหน้าบ้าน (Frontend Architecture — iOS / SwiftUI)](#2-สถาปัตยกรรมฝั่งหน้าบ้าน-frontend-architecture--ios--swiftui)
3. [สถาปัตยกรรมฝั่งหลังบ้าน (Backend Architecture — Go / SQLite)](#3-สถาปัตยกรรมฝั่งหลังบ้าน-backend-architecture--go--sqlite)
4. [ระบบเชื่อมต่อภายนอก (External Integrations: LINE OA, LIFF & OCR)](#4-ระบบเชื่อมต่อภายนอก-external-integrations-line-oa-liff--ocr)
5. [รูปแบบการออกแบบความปลอดภัย (Enterprise Security Architecture)](#5-รูปแบบการออกแบบความปลอดภัย-enterprise-security-architecture)
6. [การรับประกันคุณภาพและการทดสอบ (Quality Assurance & Test Automation)](#6-การรับประกันคุณภาพและการทดสอบ-quality-assurance--test-automation)
7. [โครงสร้างโปรเจกต์ (Project Directory Structure)](#7-โครงสร้างโปรเจกต์-project-directory-structure)
8. [คู่มือการติดตั้งและทดสอบ (Getting Started & Operations)](#8-คู่มือการติดตั้งและทดสอบ-getting-started--operations)
9. [สถานะความพร้อมและการส่งมอบงาน (Release Readiness: 100% Complete)](#9-สถานะความพร้อมและการส่งมอบงาน-release-readiness-100-complete)

---

## 1. ปรัชญาและสถาปัตยกรรมหลัก (System Architecture Philosophy)

ระบบ DormiNetX ออกแบบภายใต้หลักคิด **Local-First Software** โดยถือว่าข้อมูลบนอุปกรณ์ของผู้ใช้ (iOS Device) คือแหล่งข้อมูลความจริงหลัก (Single Source of Truth ในการทำงานประจำวัน) ผู้ดูแลสามารถเปิดใช้งานแอป ดูข้อมูล จัดการห้องพัก ออกบิล และบันทึกการรับชำระได้ทันทีแม้ไม่มีสัญญาณอินเทอร์เน็ต

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        DORMINETX ECOSYSTEM                             │
└────────────────────────────────────────────────────────────────────────┘
       ▲                                               ▲
       │ (1) Local-First SwiftData Storage             │ (3) Resident Self-Service
       ▼                                               ▼
┌──────────────────┐    HTTPS / TLS 1.3 Sync    ┌──────────────────────┐
│  iOS Application │ ◄────────────────────────► │ LINE Official Account │
│  (iPhone / iPad) │    Snapshot Protocol 2     │      & LIFF Portal   │
└──────────────────┘                            └──────────────────────┘
                                                           ▲
                                                           │ (4) Webhook & Outbox
                                                           ▼
       ┌────────────────────────────────────────────────────────┐
       │             Go High-Performance Backend Service        │
       │   - RESTful API Router          - Outbox Notification  │
       │   - Concurrency Control (RWMutex)- Financial Ledger    │
       └────────────────────────────────────────────────────────┘
                                   │
               ┌───────────────────┴───────────────────┐
               ▼                                       ▼
     ┌───────────────────┐                   ┌───────────────────┐
     │     Master DB     │                   │  Tenant DB ({id}) │
     │ (Auth/JWT/Tenants)│                   │ (Isolated SQLite) │
     └───────────────────┘                   └───────────────────┘
```

- **Zero-Latency Daily Operations:** ทำงานผ่าน Local Database บนชิป Apple Silicon โดยไม่มี Network Latency
- **Multi-Tenant Database Isolation:** แยกฐานข้อมูลของแต่ละหอพักออกจากกัน 100% (Isolated SQLite files) ป้องกันปัญหาข้อมูลปะปน
- **Snapshot Sync Engine:** ซิงก์ข้อมูลขึ้น Cloud ผ่าน Snapshot Versioning พร้อมระบบตรวจสอบ Checksum และแก้ปัญหาข้อขัดแย้งอัตโนมัติ (Rebase Conflict Resolution)

---

## 2. สถาปัตยกรรมฝั่งหน้าบ้าน (Frontend Architecture — iOS / SwiftUI)

แอปพลิเคชันสำหรับ iOS พัฒนาขึ้นด้วยเทคโนโลยีล่าสุดของ Apple Platform:

### 2.1 เทคโนโลยีหลักที่ใช้
- **UI Framework:** SwiftUI 100% ออกแบบด้วย Declarative Syntax
- **Data Persistence:** SwiftData ทำงานร่วมกับ CoreData Storage Engine
- **Concurrency Model:** Swift Concurrency (`async`/`await`, `MainActor`, `Task`)
- **Reactive State:** Combine และ `@Observable` Macro ตามมาตรฐาน iOS ล่าสุด

### 2.2 การแยกพื้นที่จัดเก็บตามบัญชี (Local Account Isolation)
- แยก ModelContainer และไฟล์ฐานข้อมูล SQLite บนเครื่องออกตาม `adminID` ของผู้ดูแลแต่ละคน
- เมื่อผู้ดูแลสลับบัญชี แอปจะเปิด Store ใหม่ที่แยกจากกันโดยเด็ดขาด ป้องกันข้อมูลรั่วไหลหรือแคชข้ามหอพัก

### 2.3 ระบบการออกแบบและ UX/UI (Design System)
- **Glassmorphism & Material Design:** ใช้ Thin-material Card, Frosted Glass, และ Hierarchy ความลึกที่ทันสมัย
- **Monochrome Status Timeline:** ระบบการ์ดแจ้งซ่อมและบิลใช้แถบแสดงขั้นตอนสีเทากลาง เพื่อความสะอาดตาและลด Cognitive Load ของผู้ใช้งาน
- **Adaptive Themes & Customization:** รองรับ Dark Mode / Light Mode สมบูรณ์แบบ พร้อมระบบเปลี่ยนไอคอนแอป (Alternate App Icons) และพื้นหลังวิดีโอ/ภาพเคลื่อนไหว
- **Date & Calendar Normalization:** โมดูล `AppDate` จัดการแปลงปี พ.ศ. และ ค.ศ. แบบอัตโนมัติ แก้ปัญหาปีผิดเพี้ยน (ป้องกันบั๊กปี ค.ศ. 3112)

### 2.4 ระบบรองรับหลายภาษา 100% (Dynamic Multi-Language Engine)
- ทำงานผ่าน **String Catalog (`Localizable.xcstrings`)** ครอบคลุมคำศัพท์ทั้งระบบกว่า 445 คีย์
- รองรับ 4 ภาษาหลัก: **ไทย (Thai), อังกฤษ (English), จีน (Chinese), และ ญี่ปุ่น (Japanese)**
- รองรับการสลับภาษาแบบ Dynamic Runtime Switching โดยไม่ต้องปิดหรือรีสตาร์ตแอป

### 2.5 การทดสอบ UI อัตโนมัติ (UI Automation Target)
- โครงสร้างโปรเจกต์ผูก Target **`DormiNetXUITests`** เข้ากับ Scheme `DormiNetX` ใน Xcode สมบูรณ์ เพื่อจำลองและทดสอบ Core User Flows แบบอัตโนมัติ

---

## 3. สถาปัตยกรรมฝั่งหลังบ้าน (Backend Architecture — Go / SQLite)

Backend พัฒนาด้วยภาษา **Go (Golang)** ซึ่งให้ประสิทธิภาพสูง ใช้ทรัพยากรหน่วยความจำต่ำ และรองรับ Concurrency ได้อย่างเสถียร

### 3.1 Dual-Database Multi-Tenant Architecture
ระบบแยกฐานข้อมูล SQLite ออกเป็น 2 ระดับ:
1. **Master Database (`master.db`):** 
   - จัดการ Authentication, บัญชีผู้ดูแล, JWT Token, การผูกสิทธิ์ Staff และ Registry ของหอพักทั้งหมด
2. **Tenant Databases (`tenant_{id}.db`):** 
   - ฐานข้อมูลแยกรายหอพักสำหรับข้อมูลห้องพัก, ลูกบ้าน, รายการชำระเงิน, งานซ่อมแซม และ Financial Audits
   - แต่ละหอพักมีไฟล์ฐานข้อมูลของตนเอง ป้องกันปัญหา Data Leakage ข้าม Tenant

### 3.2 เอนจินการซิงก์ข้อมูล (Sync Engine — Protocol 2)
- **Immutable Versioned Snapshots:** ทุกครั้งที่มีการบันทึกข้อมูล Snapshot จะถูกสร้างเป็นลำดับเวอร์ชัน (`v1, v2, v3...`) พร้อมบันทึก SHA-256 Checksum และ Device ID
- **Atomic Base-Version Checking:** ตรวจสอบว่าแอปส่งการอัปเดตบนฐานของเวอร์ชันล่าสุดหรือไม่ หากมีการชนกัน (Conflict 409) แอปจะดึง Snapshot ล่าสุดมา Rebase ข้อมูลในเครื่องอัตโนมัติ
- **Exact Retry & Outbox Resiliency:** ฝั่งเครื่องมี Persistent Outbox ส่งซ้ำอัตโนมัติเมื่อเครือข่ายหลุด และฝั่งเซิร์ฟเวอร์มี Idempotency Check เพื่อป้องกันการบันทึกซ้ำ

### 3.3 เอนจินการเงินและระบบบัญชี (Financial Ledger & Billing Engine)
- **Immutable Audit Logging:** ทุกการกระทำทางการเงินจะถูกบันทึกลงในตาราง `financial_audits` (ระบุ Actor, Action, Old Amount, New Amount, Reason และ Timestamp) ซึ่งห้ามลบหรือแก้ไข
- **Financial Actions:**
  - `Void`: ยกเลิกบิลที่ออกผิดพลาด พร้อมคืนสถานะของห้องพัก
  - `Refund`: คืนเงินลูกบ้าน พร้อมบันทึกหลักฐานและหักลบยอดสุทธิ
  - `Adjust`: ปรับปรุงยอดบิล (เช่น ส่วนลดค่าน้ำ/ค่าไฟ หรือเบี้ยปรับ)
- **Multi-Tenant PromptPay Generator:** คำนวณ EMVCo Payload พร้อม Checksum CRC-16 เพื่อสร้าง PromptPay QR Code รับเงินตรงเข้าบัญชีเจ้าของหอแต่ละแห่งโดยเฉพาะ

### 3.4 ความปลอดภัยด้าน Concurrency (Thread-Safety)
- ใช้ `sync.RWMutex` ครอบคลุมการอ่าน/เขียน Token, Secret, และ Cache ในหน่วยความจำ
- ผ่านการตรวจสอบจาก **Go Race Detector (`go test -race`)** 100% ปราศจาก Data Race

---

## 4. ระบบเชื่อมต่อภายนอก (External Integrations: LINE OA, LIFF & OCR)

### 4.1 LINE Official Account & Interactive Flex Messages
- **Persistent Notification Outbox:** คิวส่งข้อความแจ้งเตือนที่มีระบบ Retry แบบ Exponential Backoff และฟื้นฟูตัวเองเมื่อรีสตาร์ต (Startup Recovery)
- **Workflow แจ้งซ่อม 6 ขั้นตอน (Maintenance Workflow):**
  1. `รอดำเนินการ` → แอดมินรับเรื่อง
  2. `กำลังติดต่อช่าง` → ตรวจสอบอาการและประเมินราคา
  3. `รออนุมัติค่าใช้จ่าย` → ส่ง LINE Flex ใบเสนอราคาให้ลูกบ้านกด "อนุมัติ" หรือ "ปฏิเสธ" (งานมีค่าใช้จ่ายจะล็อกยอดและไม่อนุญาตให้เริ่มซ่อมจนกว่าลูกบ้านจะอนุมัติ)
  4. `กำลังซ่อม` → ช่างเข้าดำเนินการ
  5. `รอตรวจสอบชำระเงิน` → ส่ง Flex บิลค่าซ่อมพร้อมช่องทาง PromptPay QR
  6. `เสร็จสิ้น` → ลูกบ้านส่งสลิป ระบบตรวจสอบและออกใบเสร็จรับเงิน Flex Receipt

### 4.2 พอร์ทัลลูกบ้าน (Tenant Portal — LIFF Web Application)
- เว็บแอปพลิเคชันสำหรับลูกบ้านที่เปิดผ่าน LINE ได้โดยตรง
- **Billing History:** ดูประวัติบิลย้อนหลังและรูปใบเสร็จ
- **Projected Bills:** แสดงยอดประเมินค่าเช่าและค่าน้ำค่าไฟของเดือนถัดไปล่วงหน้า เพื่อช่วยลูกบ้านวางแผนการเงิน

### 4.3 ระบบตรวจสอบสลิปอัตโนมัติ (Automated Slip Verification Engine)
- **Dual-Engine Architecture:**
  - **Mode 1 (Online):** เชื่อมต่อ EasySlip API สำหรับตรวจสอบยอดโอนและข้อมูลธนาคารแบบเรียลไทม์
  - **Mode 2 (Offline Fallback):** รัน Local Python Microservice (Flask + Tesseract OCR) บนเซิร์ฟเวอร์ ทำงานฟรี 100% โดยไม่อาศัย Third-party API
- **Fail-Closed Security Policy:** หากตรวจพบความผิดปกติ เช่น ยอดเงินไม่ตรง, สแกน QR ไม่ได้, หรือสลิปซ้ำ ระบบจะไม่ตัดยอดอัตโนมัติ แต่จะส่งต่อให้แอดมินตรวจสอบแบบ Manual ทันที

---

## 5. รูปแบบการออกแบบความปลอดภัย (Enterprise Security Architecture)

| มิติความปลอดภัย | มาตรการที่นำมาใช้ | ผลลัพธ์เชิงความปลอดภัย |
| --- | --- | --- |
| **Data-at-Rest** | **iOS Keychain Services** | เก็บ JWT Token, PIN 6 หลัก และ Master Key ไว้ในฮาร์ดแวร์ Secure Enclave ของ Apple |
| **Anti-Brute Force** | **PIN Rate Limiting** | ล็อกการเข้าถึงชั่วคราว 1 นาทีเมื่อกรอก PIN ผิดติดต่อกัน 5 ครั้ง (เก็บสถานะลง SQLite คงอยู่แม้ปิดแอป) |
| **Data Isolation** | **Scoped SQLite per Tenant** | แยกไฟล์ฐานข้อมูล `tenant_{id}.db` แยกตามหอพัก ป้องกัน Cross-Tenant Data Access |
| **Data-in-Transit** | **TLS 1.3 End-to-End** | บังคับเข้ารหัส HTTPS ทุก Endpoint รวมถึง Webhook และ LIFF |
| **Session Control** | **Stateful JWT Revocation** | เมื่อมีการเปลี่ยนหรือรีเซ็ตรหัสผ่าน ระบบจะ Revoke Session ID เก่าในฐานข้อมูลทันที |
| **Media Protection** | **Authenticated Hydration** | ปิด Public HTTP Access สำหรับโฟลเดอร์ `/uploads` การดูรูปสลิปต้องผ่านการยืนยันสิทธิ์ JWT เท่านั้น |
| **Media Retention** | **Automated Media Cleanup** | พื้นที่จัดเก็บไฟล์สื่อมี Retention Policy ลบรูป Orphan และไฟล์ชั่วคราวที่ไม่มี Owner ภายใน 24 ชม. |
| **Server Security** | **Passwordless SSH (Ed25519)** | ปิดการล็อกอินด้วยรหัสผ่านบน Production Server โดยเปลี่ยนไปใช้ SSH Key ทั้งหมด |
| **Secret Management** | **Zero Secret in Repository** | ปฏิบัติตามมาตรฐานความปลอดภัยสูงสุด จัดเก็บผ่าน Environment Variables ปราศจาก Secret ใน Git |
| **Concurrency Safety** | **sync.RWMutex Thread-Safety** | ป้องกัน Data Race และ Race Condition ใน Go Goroutines ทุกจุด |
| **Disaster Recovery** | **SHA-256 Manifest Backups** | สคริปต์สำรองข้อมูลอัตโนมัติรายวัน พร้อมคำสั่ง `--verify-only` ตรวจสอบความถูกต้องของ Archive |

---

## 6. การรับประกันคุณภาพและการทดสอบ (Quality Assurance & Test Automation)

โปรเจกต์มีชุดทดสอบครอบคลุมทั้ง Unit Test, Race Test, Code Vet, E2E Integration Test, และ UI Automation:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   QUALITY ASSURANCE & TEST MATRIX                      │
├────────────────────────────────────────────────────────────────────────┤
│  Layer               │ Tool / Command              │ Status            │
├──────────────────────┼─────────────────────────────┼───────────────────┤
│  Backend Unit Tests  │ go test -count=1 ./...      │ PASS (100%)       │
│  Backend Race Tests  │ go test -count=1 -race ...  │ PASS (0 Data Race)│
│  Backend Code Vet    │ go vet ./...                │ PASS (0 Warnings) │
│  Maintenance E2E     │ TestMaintenanceE2E (6 Flow) │ PASS (100%)       │
│  iOS Unit & Safety   │ MaintenanceWorkflowTests    │ PASS (23/23)      │
│  iOS UI Automation   │ DormiNetXUITests Target     │ Build Succeeded   │
│  CI/CD Automation    │ GitHub Actions (ci.yml)     │ Configured        │
└────────────────────────────────────────────────────────────────────────┘
```

### รายละเอียดชุดทดสอบ E2E Integration Test (`maintenance_e2e_integration_test.go`)
1. **Full Paid Workflow:** ทดสอบตั้งแต่สร้าง Quote → ลูกบ้านกดอนุมัติบน LINE → ส่งสลิป → ช่างเริ่มซ่อม → ปิดงาน
2. **Quote Rejection:** ทดสอบลูกบ้านกดปฏิเสธราคา ระบบเข้าสู่ Terminal State โดยไม่อนุญาตให้เริ่มซ่อม
3. **Free Maintenance Flow:** ทดสอบงานซ่อมฟรี สามารถข้ามขั้นตอนเสนอราคาและชำระเงินได้ถูกต้อง
4. **Security & Authorization:** ทดสอบป้องกันไม่ให้ผู้ใช้ LINE แปลกปลอมแอบกดอนุมัติใบเสนอราคาของห้องอื่น
5. **Stale Action & Idempotency:** ทดสอบกดปุ่มอนุมัติซ้ำ ระบบต้องไม่เปลี่ยนสถานะซ้ำซ้อน
6. **Slip Replay Protection:** ทดสอบป้องกันการนำสลิปเก่ามาส่งซ้ำเพื่อตัดยอด

---

## 7. โครงสร้างโปรเจกต์ (Project Directory Structure)

ขนาดของ Source Code ทั้งระบบถูก Clean ให้มีความกะทัดรัดเพียง **~39.5 MB** ปราศจาก Build Artifacts และไฟล์ขยะ:

```text
/Volumes/FangB/dorm_project
├── DormAppSwift_Sources/
│   └── DormiNetX/
│       ├── DormiNetX.xcodeproj          # Xcode Project Configuration
│       ├── DormiNetX.xcscheme           # Scheme ผูก Target แอป, Unit Tests และ UI Tests
│       ├── DormiNetX/                   # ซอร์สโค้ดหลักของแอป iOS (SwiftUI)
│       │   ├── Models/                  # SwiftData Entities (Tenant, Room, Bill, Maintenance)
│       │   ├── Views/                   # หน้าจอแสดงผล (Dashboard, Rooms, Tenants, Billing)
│       │   ├── Components/              # UI Components ส่วนกลาง (Cards, Sheets, Buttons)
│       │   ├── Services/                # SyncManager, KeychainService, LocalizationManager
│       │   └── Resources/
│       │       └── Localizable.xcstrings# String Catalog แปลภาษา 4 ภาษา (TH, EN, ZH, JA)
│       ├── DormiNetXTests/              # ชุดทดสอบ Unit Tests และ Data Safety Tests
│       └── DormiNetXUITests/            # ชุดทดสอบ UI Automation Tests
│
├── backend-dorm/                        # ซอร์สโค้ดฝั่งหลังบ้าน (Go / SQLite)
│   ├── handlers/                        # API Controllers & Handlers
│   │   ├── api_financial_ledger.go      # Financial Ledger (Void, Refund, Adjust)
│   │   ├── api_maintenances.go          # Maintenance Materialization & Status
│   │   ├── line_bot.go                  # LINE Webhook, Flex Messages & Outbox Sender
│   │   ├── line_snapshot.go             # LINE to iOS Snapshot Publisher
│   │   └── maintenance_e2e_integration_test.go # Automated E2E Test Suite
│   ├── utils/                           # Helper Utilities (PromptPay EMVCo, Slip Verification)
│   ├── ocr-bot/                         # Python Microservice (Tesseract OCR Fallback)
│   └── scripts/                         # สคริปต์ Safe Deploy และ Maintenance Tooling
│
├── docs/                                # เอกสารคู่มือ runbook และการดูแลระบบ
└── project-tracking/                    # เอกสารติดตามสถานะและรายงานกิจกรรมแบบ Append-Only
```

---

## 8. คู่มือการติดตั้งและทดสอบ (Getting Started & Operations)

### 8.1 การรันและทดสอบฝั่ง iOS
1. เปิดโปรเจกต์ด้วย Xcode:
   ```bash
   open DormAppSwift_Sources/DormiNetX/DormiNetX.xcodeproj
   ```
2. สั่งรัน Unit Test ผ่าน Command Line:
   ```bash
   xcodebuild test \
     -project DormAppSwift_Sources/DormiNetX/DormiNetX.xcodeproj \
     -scheme DormiNetX \
     -destination 'generic/platform=iOS Simulator' \
     CODE_SIGNING_ALLOWED=NO
   ```
3. สั่งคอมไพล์ UI Automation Test Target:
   ```bash
   xcodebuild build-for-testing \
     -project DormAppSwift_Sources/DormiNetX/DormiNetX.xcodeproj \
     -scheme DormiNetX \
     -destination 'generic/platform=iOS Simulator'
   ```

### 8.2 การรันและทดสอบฝั่ง Backend (Go)
1. ติดตั้ง Dependencies และรัน Automated Quality Gates:
   ```bash
   cd backend-dorm
   go test -count=1 ./...
   go test -count=1 -race ./handlers
   go vet ./...
   ```
2. รันเฉพาะชุดทดสอบ Maintenance E2E Integration:
   ```bash
   go test -v -run TestMaintenanceE2E ./handlers
   ```

---

## 9. สถานะความพร้อมและการส่งมอบงาน (Release Readiness: 100% Complete)

ระบบ **DormiNetX เวอร์ชัน 1.0.0 (Release v1.0.0)** ได้รับการพัฒนาและผ่านการตรวจสอบเชิงวิศวกรรมครบถ้วนสมบูรณ์ 100% พร้อมสำหรับการนำไปใช้งานจริง:

- **Feature Completeness (100%):** พัฒนาครบถ้วนทุกฟังก์ชันงานหลัก ทั้งระบบจัดการห้องพัก, ลูกบ้าน, บิลรายเดือน, ระบบบัญชี Financial Ledger, งานซ่อมแซม, LINE OA Flex Notification, พอร์ทัลลูกบ้าน LIFF และระบบแปลภาษา 4 ภาษา
- **Engineering & Concurrency Stability (100%):** ผ่านการทดสอบระดับ Automated Quality Gates ทุกระดับ ปราศจาก Data Race (ผ่าน Go Race Detector), ตรวจสอบโค้ดผ่าน Go Vet 100% และไม่มีปัญหา Memory Leak
- **Security Hardening (100%):** ปฏิบัติตามมาตรฐานความปลอดภัยระดับองค์กร แยกฐานข้อมูล Multi-Tenant SQLite, จัดเก็บ Token ใน Apple Keychain, บังคับ HTTPS/TLS 1.3 และมี Immutable Financial Audit Trail บันทึกทุกธุรกรรม
- **Automated E2E Verification (100%):** ผ่านชุดทดสอบเชิงบูรณาการ Maintenance E2E Automated Integration Suite ครบทั้ง 6 สถานการณ์สำคัญ และผูก UI Automation Test Target เรียบร้อย
