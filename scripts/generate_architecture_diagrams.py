#!/usr/bin/env python3
"""
Generate DormiNetX UML Activity Swimlane Diagrams & Single-Page PDF
Outputs:
1. docs/system_architecture.drawio (Pure Draw.io / diagrams.net XML)
2. docs/system_architecture.html (Standalone Interactive HTML with Vector SVG & Pan-Zoom)
3. docs/system_architecture.svg (Pure Vector SVG with Title & Legend)
4. docs/system_architecture.pdf (Single-Page Publication-Grade Vector PDF)
"""

import os
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

def create_drawio_xml():
    lanes = [
        {"id": "lane_user", "name": "User (Admin / Tenant)", "x": 20, "w": 260},
        {"id": "lane_frontend", "name": "Frontend (iOS App &amp; LINE LIFF)", "x": 280, "w": 280},
        {"id": "lane_backend", "name": "Backend (Go REST API :4283)", "x": 560, "w": 280},
        {"id": "lane_services", "name": "Services (Python OCR &amp; LINE API)", "x": 840, "w": 280},
        {"id": "lane_server", "name": "Server &amp; DB (Debian Linux / SQLite)", "x": 1120, "w": 260},
    ]

    total_h = 1680
    header_h = 44
    lane_y = 90

    xml_lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<mxfile host="app.diagrams.net" modified="2026-11-13T17:15:00.000Z" agent="Antigravity" version="21.0.0" type="device">',
        '  <diagram id="dorminetx_activity_swimlane" name="DormiNetX Architecture Flow">',
        '    <mxGraphModel dx="1422" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1420" pageHeight="1880" background="#ffffff" math="0" shadow="0">',
        '      <root>',
        '        <mxCell id="0" />',
        '        <mxCell id="1" parent="0" />',
    ]

    # Title Banner in Draw.io
    xml_lines.append(
        '        <mxCell id="title_banner" value="&lt;b style=&quot;font-size:16px;&quot;&gt;DormiNetX Multi-Tier Architecture &amp;amp; Operational Flowchart&lt;/b&gt;&lt;br&gt;&lt;span style=&quot;font-size:12px;color:#555;&quot;&gt;Standard UML 2.5 Activity Diagram with Swimlanes | 3-Tier Architecture (Frontend, Backend, Server &amp;amp; DB)&lt;/span&gt;" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8f9fa;strokeColor=#000000;strokeWidth=1.5;align=center;" vertex="1" parent="1">'
    )
    xml_lines.append('          <mxGeometry x="20" y="20" width="1360" height="55" as="geometry" />')
    xml_lines.append('        </mxCell>')

    # Add Swimlane Containers
    for lane in lanes:
        xml_lines.append(
            f'        <mxCell id="{lane["id"]}" value="{lane["name"]}" style="swimlane;whiteSpace=wrap;html=1;startSize={header_h};'
            f'fillColor=#f8f9fa;strokeColor=#000000;strokeWidth=1.5;fontFamily=Helvetica;fontSize=13;fontStyle=1;fontColor=#000000;'
            f'collapsible=0;dropTarget=0;" vertex="1" parent="1">'
        )
        xml_lines.append(
            f'          <mxGeometry x="{lane["x"]}" y="{lane_y}" width="{lane["w"]}" height="{total_h}" as="geometry" />'
        )
        xml_lines.append('        </mxCell>')

    def add_node(nid, label, style, x, y, w, h, parent="1"):
        xml_lines.append(
            f'        <mxCell id="{nid}" value="{label}" style="{style}" vertex="1" parent="{parent}">'
        )
        xml_lines.append(
            f'          <mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry" />'
        )
        xml_lines.append('        </mxCell>')

    def add_edge(eid, source, target, label="", style_extra=""):
        base_style = "edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#000000;strokeWidth=1.5;fontFamily=Helvetica;fontSize=11;fontColor=#000000;"
        style = base_style + style_extra
        xml_lines.append(
            f'        <mxCell id="{eid}" value="{label}" style="{style}" edge="1" parent="1" source="{source}" target="{target}">'
        )
        xml_lines.append('          <mxGeometry relative="1" as="geometry" />')
        xml_lines.append('        </mxCell>')

    STYLE_START = "ellipse;whiteSpace=wrap;html=1;aspect=fixed;fillColor=#000000;strokeColor=#000000;"
    STYLE_ACTION = "rounded=1;whiteSpace=wrap;html=1;arcSize=14;fillColor=#ffffff;strokeColor=#000000;strokeWidth=1.5;fontFamily=Helvetica;fontSize=11;fontColor=#000000;"
    STYLE_DECISION = "rhombus;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;strokeWidth=1.5;fontFamily=Helvetica;fontSize=10;fontColor=#000000;"
    STYLE_SYNC_BAR = "shape=line;strokeWidth=6;strokeColor=#000000;fillColor=none;"
    STYLE_END = "ellipse;whiteSpace=wrap;html=1;aspect=fixed;fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;"
    STYLE_END_INNER = "shape=cross;whiteSpace=wrap;html=1;strokeColor=#000000;strokeWidth=2;fillColor=none;"
    STYLE_ACTOR = "shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;html=1;outlineConnect=0;strokeColor=#000000;strokeWidth=1.5;fillColor=none;"

    # Offset dy = 70 to accommodate title banner
    dy = 70

    # Phase 1: Authentication & App Launch
    add_node("node_start", "", STYLE_START, 138, 80 + dy, 24, 24)
    add_node("node_open_app", "Launch DormiNetX<br>(iOS App / LINE Webview)", STYLE_ACTION, 50, 130 + dy, 200, 44)
    add_node("dec_token", "Valid Token in<br>Keychain Cache?", STYLE_DECISION, 340, 122 + dy, 160, 60)
    add_node("node_enter_cred", "Enter Email &amp; Password", STYLE_ACTION, 50, 215 + dy, 200, 44)
    add_node("dec_forgot", "Forgot<br>Password?", STYLE_DECISION, 70, 290 + dy, 160, 54)
    add_node("node_req_otp", "Request OTP via Email", STYLE_ACTION, 50, 375 + dy, 200, 40)
    add_node("node_reset_pwd", "Verify OTP &amp; Reset Password", STYLE_ACTION, 50, 440 + dy, 200, 40)
    add_node("node_submit_login", "POST /api/v1/login<br>(JSON Body)", STYLE_ACTION, 320, 295 + dy, 200, 44)
    add_node("node_verify_hash", "Validate Argon2id Hash<br>&amp; Rate-Limiter", STYLE_ACTION, 600, 295 + dy, 200, 44)
    add_node("node_query_admin", "SELECT * FROM admins<br>in Master DB (master.db)", STYLE_ACTION, 1150, 295 + dy, 200, 44)
    add_node("dec_auth_valid", "Credentials<br>Valid?", STYLE_DECISION, 620, 370 + dy, 160, 54)
    add_node("node_jwt_issue", "Issue Signed JWT<br>(AdminID, Role, TenantDB)", STYLE_ACTION, 600, 450 + dy, 200, 44)
    add_node("node_store_token", "Store JWT in iOS Keychain<br>&amp; Initialize Local Session", STYLE_ACTION, 320, 450 + dy, 200, 44)
    add_node("node_init_swiftdata", "Load SwiftData Cache<br>(account_1.store / SQLite)", STYLE_ACTION, 320, 525 + dy, 200, 44)

    # Phase 2: Operations & Local-First Sync
    add_node("actor_admin", "Admin", STYLE_ACTOR, 65, 595 + dy, 30, 50)
    add_node("node_crud_dorm", "Record Meter / Contract /<br>Room CRUD Action", STYLE_ACTION, 110, 595 + dy, 140, 46)
    add_node("node_save_local", "Save Mutation in SwiftData<br>(Instant 0ms UI, isDirty=true)", STYLE_ACTION, 320, 595 + dy, 200, 46)
    add_node("node_calc_hash", "SyncManager Computes<br>SHA-256 Checksum", STYLE_ACTION, 320, 670 + dy, 200, 44)
    add_node("node_post_sync", "POST /api/v1/sync Snapshot<br>(Bearer JWT)", STYLE_ACTION, 600, 670 + dy, 200, 44)
    add_node("node_route_tenant", "TenantHelper Context Switch<br>(Resolve tenant_1.db)", STYLE_ACTION, 600, 745 + dy, 200, 44)
    add_node("node_write_wal", "Execute SQLite WAL Transaction<br>(tenant_1.db Isolated Schema)", STYLE_ACTION, 1150, 745 + dy, 200, 44)
    add_node("node_log_sync", "Write Sync Snapshot State<br>(sync_snapshots in master.db)", STYLE_ACTION, 1150, 820 + dy, 200, 44)

    # Sync Bar: Fork
    add_node("bar_fork", "", STYLE_SYNC_BAR, 60, 895 + dy, 1260, 10)

    # Phase 3: Automated Invoicing & LINE Dispatch
    add_node("node_calc_bill", "Go Billing Engine Calculates<br>Rent + Water/Power Usage", STYLE_ACTION, 600, 935 + dy, 200, 46)
    add_node("node_gen_qr", "Generate EMVCo PromptPay<br>Standard QR Payload", STYLE_ACTION, 600, 1010 + dy, 200, 46)
    add_node("node_line_dispatch", "Dispatch Flex Message Carousel<br>via LINE Messaging API", STYLE_ACTION, 880, 1010 + dy, 200, 46)
    add_node("node_tenant_receive", "Tenant Receives Bill &amp; QR<br>on LINE Official Account", STYLE_ACTION, 50, 1010 + dy, 200, 46)

    # Phase 4: Payment Transfer & Dual-Engine OCR
    add_node("node_tenant_pay", "Tenant Transfers Funds &amp;<br>Uploads Bank Slip Image", STYLE_ACTION, 50, 1090 + dy, 200, 46)
    add_node("node_liff_upload", "LINE LIFF Webview POSTs Slip<br>to /api/v1/bills/:id/pay", STYLE_ACTION, 320, 1090 + dy, 200, 46)
    add_node("node_save_upload", "Store Physical Image File in<br>/opt/dormitory/uploads/", STYLE_ACTION, 1150, 1090 + dy, 200, 46)
    add_node("node_call_ocr", "Go API Calls Python OCR<br>Microservice (127.0.0.1:5001)", STYLE_ACTION, 600, 1170 + dy, 200, 46)
    add_node("node_run_ocr", "Dual Engine Verification:<br>PaddleOCR + Tesseract", STYLE_ACTION, 880, 1170 + dy, 200, 46)
    add_node("dec_ocr_valid", "Slip Valid &amp;<br>Amount Match &amp;<br>Ref Unique?", STYLE_DECISION, 900, 1245 + dy, 160, 65)
    add_node("node_ocr_fail", "Flag Suspicious Slip &amp;<br>Alert Landlord for Manual Review", STYLE_ACTION, 600, 1255 + dy, 200, 46)
    add_node("node_update_paid", "UPDATE bills SET status='paid'<br>in tenant_1.db", STYLE_ACTION, 1150, 1345 + dy, 200, 46)
    add_node("node_audit_log", "Append Immutable Record to<br>financial_audits (master.db)", STYLE_ACTION, 1150, 1420 + dy, 200, 46)

    # Sync Bar: Join
    add_node("bar_join", "", STYLE_SYNC_BAR, 60, 1495 + dy, 1260, 10)

    # Phase 5: Dual Confirmation & Completion
    add_node("node_line_receipt", "Send Digital Receipt &amp; Thank You<br>via LINE Flex Message", STYLE_ACTION, 880, 1535 + dy, 200, 46)
    add_node("node_tenant_receipt", "Tenant Receives Confirmation<br>in LINE Chat", STYLE_ACTION, 50, 1535 + dy, 200, 46)
    add_node("node_apns_push", "Dispatch APNs Push Notification<br>to Landlord Device", STYLE_ACTION, 600, 1535 + dy, 200, 46)
    add_node("node_admin_reflect", "Admin Dashboard Reflects<br>Payment (Real-time Metric)", STYLE_ACTION, 320, 1535 + dy, 200, 46)

    # Terminal Node
    add_node("node_end", "", STYLE_END, 485, 1630 + dy, 30, 30)
    add_node("node_end_inner", "", STYLE_END_INNER, 489, 1634 + dy, 22, 22)

    # Edges
    add_edge("e1", "node_start", "node_open_app")
    add_edge("e2", "node_open_app", "dec_token")
    add_edge("e3", "dec_token", "node_enter_cred", "No", ";strokeColor=#b85450;fontColor=#b85450;")
    add_edge("e4", "dec_token", "node_init_swiftdata", "Yes", ";strokeColor=#82b366;fontColor=#274e13;")
    add_edge("e5", "node_enter_cred", "dec_forgot")
    add_edge("e6", "dec_forgot", "node_req_otp", "Yes", ";strokeColor=#b85450;fontColor=#b85450;")
    add_edge("e7", "dec_forgot", "node_submit_login", "No", ";strokeColor=#82b366;fontColor=#274e13;")
    add_edge("e8", "node_req_otp", "node_reset_pwd")
    add_edge("e9", "node_reset_pwd", "node_enter_cred")
    add_edge("e10", "node_submit_login", "node_verify_hash")
    add_edge("e11", "node_verify_hash", "node_query_admin")
    add_edge("e12", "node_query_admin", "dec_auth_valid")
    add_edge("e13", "dec_auth_valid", "node_enter_cred", "Invalid", ";strokeColor=#b85450;fontColor=#b85450;")
    add_edge("e14", "dec_auth_valid", "node_jwt_issue", "Valid", ";strokeColor=#82b366;fontColor=#274e13;")
    add_edge("e15", "node_jwt_issue", "node_store_token")
    add_edge("e16", "node_store_token", "node_init_swiftdata")

    # Ops & Sync Edges
    add_edge("e17", "actor_admin", "node_crud_dorm")
    add_edge("e18", "node_crud_dorm", "node_save_local")
    add_edge("e19", "node_init_swiftdata", "node_save_local")
    add_edge("e20", "node_save_local", "node_calc_hash")
    add_edge("e21", "node_calc_hash", "node_post_sync")
    add_edge("e22", "node_post_sync", "node_route_tenant")
    add_edge("e23", "node_route_tenant", "node_write_wal")
    add_edge("e24", "node_write_wal", "node_log_sync")
    add_edge("e25", "node_log_sync", "bar_fork")

    # Invoicing & LINE Edges
    add_edge("e26", "bar_fork", "node_calc_bill")
    add_edge("e27", "node_calc_bill", "node_gen_qr")
    add_edge("e28", "node_gen_qr", "node_line_dispatch")
    add_edge("e29", "node_line_dispatch", "node_tenant_receive")

    # Payment & OCR Edges
    add_edge("e30", "node_tenant_receive", "node_tenant_pay")
    add_edge("e31", "node_tenant_pay", "node_liff_upload")
    add_edge("e32", "node_liff_upload", "node_save_upload")
    add_edge("e33", "node_liff_upload", "node_call_ocr")
    add_edge("e34", "node_call_ocr", "node_run_ocr")
    add_edge("e35", "node_run_ocr", "dec_ocr_valid")
    add_edge("e36", "dec_ocr_valid", "node_ocr_fail", "No", ";strokeColor=#b85450;fontColor=#b85450;")
    add_edge("e37", "node_ocr_fail", "node_tenant_pay")
    add_edge("e38", "dec_ocr_valid", "node_update_paid", "Yes", ";strokeColor=#82b366;fontColor=#274e13;")
    add_edge("e39", "node_update_paid", "node_audit_log")
    add_edge("e40", "node_audit_log", "bar_join")

    # Confirmation & End Edges
    add_edge("e41", "bar_join", "node_line_receipt")
    add_edge("e42", "node_line_receipt", "node_tenant_receipt")
    add_edge("e43", "bar_join", "node_apns_push")
    add_edge("e44", "node_apns_push", "node_admin_reflect")
    add_edge("e45", "node_tenant_receipt", "node_end")
    add_edge("e46", "node_admin_reflect", "node_end")

    xml_lines.extend([
        '      </root>',
        '    </mxGraphModel>',
        '  </diagram>',
        '</mxfile>'
    ])

    return "\n".join(xml_lines)


def generate_pure_svg():
    # Offset dy = 70 for title banner
    dy = 70

    svg = f"""<svg id="diagramSvg" viewBox="0 0 1420 1860" width="1420" height="1860" xmlns="http://www.w3.org/2000/svg" style="background:#ffffff; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1.5 L 8 5 L 0 8.5 z" fill="#000000" />
    </marker>
    <marker id="arrow-green" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1.5 L 8 5 L 0 8.5 z" fill="#2e7d32" />
    </marker>
    <marker id="arrow-red" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1.5 L 8 5 L 0 8.5 z" fill="#c62828" />
    </marker>
  </defs>

  <!-- Title Banner -->
  <g id="title_banner">
    <rect x="20" y="20" width="1360" height="55" rx="6" fill="#f8f9fa" stroke="#000000" stroke-width="1.5" />
    <text x="700" y="42" text-anchor="middle" font-size="16" font-weight="700" fill="#111827">DormiNetX Multi-Tier Architecture &amp; Operational Flowchart</text>
    <text x="700" y="61" text-anchor="middle" font-size="12" fill="#4b5563">Standard UML 2.5 Activity Diagram with Swimlanes | 3-Tier Architecture (Frontend, Backend, Server &amp; DB)</text>
  </g>

  <!-- Swimlane Grid &amp; Headers -->
  <g id="swimlanes">
    <!-- Outer Border -->
    <rect x="20" y="90" width="1360" height="1680" fill="#ffffff" stroke="#000000" stroke-width="1.5" />

    <!-- Lane 0: User -->
    <rect x="20" y="90" width="260" height="44" fill="#f8f9fa" stroke="#000000" stroke-width="1.5" />
    <text x="150" y="117" text-anchor="middle" font-size="13" font-weight="700" fill="#000000">User (Admin / Tenant)</text>
    <line x1="280" y1="90" x2="280" y2="1770" stroke="#000000" stroke-width="1.5" />

    <!-- Lane 1: Frontend -->
    <rect x="280" y="90" width="280" height="44" fill="#f8f9fa" stroke="#000000" stroke-width="1.5" />
    <text x="420" y="117" text-anchor="middle" font-size="13" font-weight="700" fill="#000000">Frontend (iOS App &amp; LINE LIFF)</text>
    <line x1="560" y1="90" x2="560" y2="1770" stroke="#000000" stroke-width="1.5" />

    <!-- Lane 2: Backend -->
    <rect x="560" y="90" width="280" height="44" fill="#f8f9fa" stroke="#000000" stroke-width="1.5" />
    <text x="700" y="117" text-anchor="middle" font-size="13" font-weight="700" fill="#000000">Backend (Go REST API :4283)</text>
    <line x1="840" y1="90" x2="840" y2="1770" stroke="#000000" stroke-width="1.5" />

    <!-- Lane 3: Services -->
    <rect x="840" y="90" width="280" height="44" fill="#f8f9fa" stroke="#000000" stroke-width="1.5" />
    <text x="980" y="117" text-anchor="middle" font-size="13" font-weight="700" fill="#000000">Services (Python OCR &amp; LINE API)</text>
    <line x1="1120" y1="90" x2="1120" y2="1770" stroke="#000000" stroke-width="1.5" />

    <!-- Lane 4: Server &amp; DB -->
    <rect x="1120" y="90" width="260" height="44" fill="#f8f9fa" stroke="#000000" stroke-width="1.5" />
    <text x="1250" y="117" text-anchor="middle" font-size="13" font-weight="700" fill="#000000">Server &amp; DB (Debian Linux / SQLite)</text>
  </g>

  <!-- Connectors -->
  <g id="connectors" fill="none" stroke-width="1.5">
    <!-- e1: Start -> Open App -->
    <path d="M 150 {92+dy} L 150 {130+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e2: Open App -> Token Decision -->
    <path d="M 250 {152+dy} L 340 {152+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e3: Token Decision [No] -> Enter Email -->
    <path d="M 420 {182+dy} L 420 {237+dy} L 250 {237+dy}" stroke="#c62828" marker-end="url(#arrow-red)" />
    <text x="340" y="{232+dy}" font-size="11" font-weight="600" fill="#c62828">No (Unauthenticated)</text>

    <!-- e4: Token Decision [Yes] -> Load SwiftData -->
    <path d="M 500 {152+dy} L 535 {152+dy} L 535 {547+dy} L 520 {547+dy}" stroke="#2e7d32" marker-end="url(#arrow-green)" />
    <text x="540" y="{340+dy}" font-size="11" font-weight="600" fill="#2e7d32" transform="rotate(90, 540, {340+dy})">Yes (Valid Token)</text>

    <!-- e5: Enter Email -> Forgot Password? -->
    <path d="M 150 {260+dy} L 150 {290+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e6: Forgot Password [Yes] -> Request OTP -->
    <path d="M 150 {344+dy} L 150 {375+dy}" stroke="#c62828" marker-end="url(#arrow-red)" />
    <text x="156" y="{362+dy}" font-size="11" font-weight="600" fill="#c62828">Yes</text>

    <!-- e7: Forgot Password [No] -> Submit Login -->
    <path d="M 230 {317+dy} L 320 {317+dy}" stroke="#2e7d32" marker-end="url(#arrow-green)" />
    <text x="260" y="{311+dy}" font-size="11" font-weight="600" fill="#2e7d32">No</text>

    <!-- e8: Request OTP -> Verify OTP -->
    <path d="M 150 {415+dy} L 150 {440+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e9: Reset Password -> Loop back to Enter Email -->
    <path d="M 50 {460+dy} L 35 {460+dy} L 35 {237+dy} L 50 {237+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e10: Submit Login -> Validate Argon2id -->
    <path d="M 520 {317+dy} L 600 {317+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e11: Validate Argon2id -> Query Admins Master DB -->
    <path d="M 800 {317+dy} L 1150 {317+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e12: Query Admins -> Credentials Valid? -->
    <path d="M 1250 {341+dy} L 1250 {397+dy} L 780 {397+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e13: Credentials Valid [Invalid] -> Back to Enter Cred -->
    <path d="M 700 {370+dy} L 700 {248+dy} L 250 {248+dy}" stroke="#c62828" marker-end="url(#arrow-red)" />
    <text x="610" y="{243+dy}" font-size="11" font-weight="600" fill="#c62828">Invalid (401)</text>

    <!-- e14: Credentials Valid [Valid] -> Issue JWT -->
    <path d="M 700 {424+dy} L 700 {450+dy}" stroke="#2e7d32" marker-end="url(#arrow-green)" />
    <text x="706" y="{440+dy}" font-size="11" font-weight="600" fill="#2e7d32">Valid (200)</text>

    <!-- e15: Issue JWT -> Store in Keychain -->
    <path d="M 600 {472+dy} L 520 {472+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e16: Store in Keychain -> Load SwiftData -->
    <path d="M 420 {494+dy} L 420 {525+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e17: Admin Actor -> Record Action -->
    <path d="M 95 {620+dy} L 110 {620+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e18: Record Action -> Save in SwiftData -->
    <path d="M 250 {620+dy} L 320 {620+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e19: Load SwiftData -> Save Mutation -->
    <path d="M 420 {569+dy} L 420 {595+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e20: Save Mutation -> Compute Hash -->
    <path d="M 420 {641+dy} L 420 {670+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e21: Compute Hash -> POST Sync -->
    <path d="M 520 {692+dy} L 600 {692+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e22: POST Sync -> TenantHelper Switch -->
    <path d="M 700 {714+dy} L 700 {745+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e23: TenantHelper Switch -> Write WAL to tenant_1.db -->
    <path d="M 800 {768+dy} L 1150 {768+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e24: Write WAL -> Log Sync State master.db -->
    <path d="M 1250 {789+dy} L 1250 {820+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e25: Log Sync State -> Fork Bar -->
    <path d="M 1250 {864+dy} L 1250 {895+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e26: Fork Bar -> Calculate Bill Engine -->
    <path d="M 700 {905+dy} L 700 {935+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e27: Calculate Bill -> Generate PromptPay QR -->
    <path d="M 700 {981+dy} L 700 {1010+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e28: Generate QR -> Dispatch LINE API -->
    <path d="M 800 {1033+dy} L 880 {1033+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e29: Dispatch LINE API -> Tenant Receives Bill -->
    <path d="M 880 {1045+dy} L 250 {1045+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e30: Tenant Receives Bill -> Tenant Transfers Funds -->
    <path d="M 150 {1056+dy} L 150 {1090+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e31: Tenant Transfers Funds -> LINE LIFF POST Slip -->
    <path d="M 250 {1113+dy} L 320 {1113+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e32: LINE LIFF POST Slip -> Store Image File in uploads -->
    <path d="M 520 {1105+dy} L 1150 {1105+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e33: LINE LIFF POST Slip -> Go API Calls Python OCR -->
    <path d="M 420 {1134+dy} L 420 {1193+dy} L 600 {1193+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e34: Go API Calls Python OCR -> Dual Engine PaddleOCR + Tesseract -->
    <path d="M 800 {1193+dy} L 880 {1193+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e35: Dual OCR -> Slip Valid? -->
    <path d="M 980 {1216+dy} L 980 {1245+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e36: Slip Valid [No] -> Flag Suspicious Slip -->
    <path d="M 900 {1277+dy} L 800 {1277+dy}" stroke="#c62828" marker-end="url(#arrow-red)" />
    <text x="835" y="{1271+dy}" font-size="11" font-weight="600" fill="#c62828">No (Mismatch)</text>

    <!-- e37: Flag Suspicious -> Loop to Tenant for Re-upload -->
    <path d="M 600 {1277+dy} L 270 {1277+dy} L 270 {1125+dy} L 250 {1125+dy}" stroke="#c62828" marker-end="url(#arrow-red)" />

    <!-- e38: Slip Valid [Yes] -> UPDATE bills status='paid' -->
    <path d="M 1060 {1277+dy} L 1250 {1277+dy} L 1250 {1345+dy}" stroke="#2e7d32" marker-end="url(#arrow-green)" />
    <text x="1080" y="{1271+dy}" font-size="11" font-weight="600" fill="#2e7d32">Yes (Verified)</text>

    <!-- e39: UPDATE bills -> Append Immutable Audit Log -->
    <path d="M 1250 {1389+dy} L 1250 {1420+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e40: Append Audit Log -> Join Bar -->
    <path d="M 1250 {1464+dy} L 1250 {1495+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e41: Join Bar -> Send LINE Receipt -->
    <path d="M 980 {1505+dy} L 980 {1535+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e42: Send LINE Receipt -> Tenant Receives Confirmation -->
    <path d="M 880 {1558+dy} L 250 {1558+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e43: Join Bar -> Dispatch APNs Push -->
    <path d="M 700 {1505+dy} L 700 {1535+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e44: Dispatch APNs Push -> Admin Dashboard Metric -->
    <path d="M 600 {1558+dy} L 520 {1558+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e45: Tenant Receives Conf -> End Node -->
    <path d="M 150 {1581+dy} L 150 {1645+dy} L 485 {1645+dy}" stroke="#000000" marker-end="url(#arrow)" />

    <!-- e46: Admin Dashboard Metric -> End Node -->
    <path d="M 420 {1581+dy} L 420 {1645+dy} L 485 {1645+dy}" stroke="#000000" marker-end="url(#arrow)" />
  </g>

  <!-- Sync Bars (Fork &amp; Join) -->
  <g id="sync_bars">
    <rect x="60" y="{895+dy}" width="1260" height="10" fill="#000000" rx="2" />
    <text x="70" y="{888+dy}" font-size="11" font-weight="700" fill="#555555">FORK (PARALLEL EXECUTION)</text>

    <rect x="60" y="{1495+dy}" width="1260" height="10" fill="#000000" rx="2" />
    <text x="70" y="{1488+dy}" font-size="11" font-weight="700" fill="#555555">JOIN (SYNCHRONIZED COMPLETION)</text>
  </g>

  <!-- Nodes &amp; Elements -->
  <g id="nodes">
    <!-- Start Node -->
    <circle cx="150" cy="{80+dy}" r="12" fill="#000000" stroke="#000000" stroke-width="1.5" />

    <!-- node_open_app -->
    <g class="diagram-node" data-title="Launch DormiNetX">
      <rect x="50" y="{130+dy}" width="200" height="44" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="150" y="{148+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Launch DormiNetX</text>
      <text x="150" y="{163+dy}" text-anchor="middle" font-size="10" fill="#555555">(iOS App / LINE Webview)</text>
    </g>

    <!-- dec_token -->
    <g class="diagram-node" data-title="Token Check">
      <polygon points="420,{122+dy} 500,{152+dy} 420,{182+dy} 340,{152+dy}" fill="#fff2cc" stroke="#d6b656" stroke-width="1.5" />
      <text x="420" y="{148+dy}" text-anchor="middle" font-size="10" font-weight="600" fill="#000000">Valid Token in</text>
      <text x="420" y="{161+dy}" text-anchor="middle" font-size="10" font-weight="600" fill="#000000">Keychain Cache?</text>
    </g>

    <!-- node_enter_cred -->
    <g class="diagram-node" data-title="Enter Credentials">
      <rect x="50" y="{215+dy}" width="200" height="44" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="150" y="{242+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Enter Email &amp; Password</text>
    </g>

    <!-- dec_forgot -->
    <g class="diagram-node" data-title="Forgot Password">
      <polygon points="150,{290+dy} 230,{317+dy} 150,{344+dy} 70,{317+dy}" fill="#fff2cc" stroke="#d6b656" stroke-width="1.5" />
      <text x="150" y="{314+dy}" text-anchor="middle" font-size="10" font-weight="600" fill="#000000">Forgot</text>
      <text x="150" y="{327+dy}" text-anchor="middle" font-size="10" font-weight="600" fill="#000000">Password?</text>
    </g>

    <!-- node_req_otp -->
    <g class="diagram-node" data-title="Request OTP">
      <rect x="50" y="{375+dy}" width="200" height="40" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="150" y="{400+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Request OTP via Email</text>
    </g>

    <!-- node_reset_pwd -->
    <g class="diagram-node" data-title="Reset Password">
      <rect x="50" y="{440+dy}" width="200" height="40" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="150" y="{465+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Verify OTP &amp; Reset Password</text>
    </g>

    <!-- node_submit_login -->
    <g class="diagram-node" data-title="Submit Login">
      <rect x="320" y="{295+dy}" width="200" height="44" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="420" y="{313+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">POST /api/v1/login</text>
      <text x="420" y="{328+dy}" text-anchor="middle" font-size="10" fill="#555555">(JSON Payload)</text>
    </g>

    <!-- node_verify_hash -->
    <g class="diagram-node" data-title="Validate Hash">
      <rect x="600" y="{295+dy}" width="200" height="44" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="700" y="{313+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Validate Argon2id Hash</text>
      <text x="700" y="{328+dy}" text-anchor="middle" font-size="10" fill="#555555">&amp; Check IP Rate-Limiter</text>
    </g>

    <!-- node_query_admin -->
    <g class="diagram-node" data-title="Query Master DB">
      <rect x="1150" y="{295+dy}" width="200" height="44" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="1250" y="{313+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">SELECT * FROM admins</text>
      <text x="1250" y="{328+dy}" text-anchor="middle" font-size="10" fill="#555555">in Master DB (master.db)</text>
    </g>

    <!-- dec_auth_valid -->
    <g class="diagram-node" data-title="Auth Decision">
      <polygon points="700,{370+dy} 780,{397+dy} 700,{424+dy} 620,{397+dy}" fill="#fff2cc" stroke="#d6b656" stroke-width="1.5" />
      <text x="700" y="{394+dy}" text-anchor="middle" font-size="10" font-weight="600" fill="#000000">Credentials</text>
      <text x="700" y="{407+dy}" text-anchor="middle" font-size="10" font-weight="600" fill="#000000">Valid?</text>
    </g>

    <!-- node_jwt_issue -->
    <g class="diagram-node" data-title="Issue JWT">
      <rect x="600" y="{450+dy}" width="200" height="44" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="700" y="{468+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Issue Signed JWT Token</text>
      <text x="700" y="{483+dy}" text-anchor="middle" font-size="10" fill="#555555">(AdminID, Role, TenantDB)</text>
    </g>

    <!-- node_store_token -->
    <g class="diagram-node" data-title="Store Keychain">
      <rect x="320" y="{450+dy}" width="200" height="44" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="420" y="{468+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Store JWT in iOS Keychain</text>
      <text x="420" y="{483+dy}" text-anchor="middle" font-size="10" fill="#555555">&amp; Cache Local Session</text>
    </g>

    <!-- node_init_swiftdata -->
    <g class="diagram-node" data-title="Load SwiftData Cache">
      <rect x="320" y="{525+dy}" width="200" height="44" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="420" y="{543+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Load SwiftData Cache</text>
      <text x="420" y="{558+dy}" text-anchor="middle" font-size="10" fill="#555555">(account_1.store / SQLite)</text>
    </g>

    <!-- Actor Admin -->
    <g id="actor_admin" transform="translate(65, {595+dy})">
      <circle cx="15" cy="10" r="8" fill="none" stroke="#000000" stroke-width="1.5" />
      <line x1="15" y1="18" x2="15" y2="36" stroke="#000000" stroke-width="1.5" />
      <line x1="5" y1="24" x2="25" y2="24" stroke="#000000" stroke-width="1.5" />
      <line x1="15" y1="36" x2="5" y2="52" stroke="#000000" stroke-width="1.5" />
      <line x1="15" y1="36" x2="25" y2="52" stroke="#000000" stroke-width="1.5" />
      <text x="15" y="65" text-anchor="middle" font-size="11" font-weight="700" fill="#000000">Admin</text>
    </g>

    <!-- node_crud_dorm -->
    <g class="diagram-node" data-title="CRUD Dormitory Action">
      <rect x="110" y="{595+dy}" width="140" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="180" y="{614+dy}" text-anchor="middle" font-size="10" font-weight="600" fill="#000000">Record Meter Reading,</text>
      <text x="180" y="{629+dy}" text-anchor="middle" font-size="10" font-weight="600" fill="#000000">Contract or Room CRUD</text>
    </g>

    <!-- node_save_local -->
    <g class="diagram-node" data-title="Save SwiftData Local">
      <rect x="320" y="{595+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="420" y="{614+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Save Mutation in SwiftData</text>
      <text x="420" y="{629+dy}" text-anchor="middle" font-size="10" fill="#555555">(Instant 0ms UI, isDirty=true)</text>
    </g>

    <!-- node_calc_hash -->
    <g class="diagram-node" data-title="Compute Checksum">
      <rect x="320" y="{670+dy}" width="200" height="44" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="420" y="{688+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">SyncManager Computes</text>
      <text x="420" y="{703+dy}" text-anchor="middle" font-size="10" fill="#555555">SHA-256 Checksum</text>
    </g>

    <!-- node_post_sync -->
    <g class="diagram-node" data-title="POST Sync Snapshot">
      <rect x="600" y="{670+dy}" width="200" height="44" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="700" y="{688+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">POST /api/v1/sync Snapshot</text>
      <text x="700" y="{703+dy}" text-anchor="middle" font-size="10" fill="#555555">(Bearer JWT Authorization)</text>
    </g>

    <!-- node_route_tenant -->
    <g class="diagram-node" data-title="Route TenantHelper">
      <rect x="600" y="{745+dy}" width="200" height="44" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="700" y="{763+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">TenantHelper Context Switch</text>
      <text x="700" y="{778+dy}" text-anchor="middle" font-size="10" fill="#555555">(Resolve tenant_1.db)</text>
    </g>

    <!-- node_write_wal -->
    <g class="diagram-node" data-title="Execute WAL Transaction">
      <rect x="1150" y="{745+dy}" width="200" height="44" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="1250" y="{763+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Execute SQLite WAL Trans.</text>
      <text x="1250" y="{778+dy}" text-anchor="middle" font-size="10" fill="#555555">(tenant_1.db Isolated Schema)</text>
    </g>

    <!-- node_log_sync -->
    <g class="diagram-node" data-title="Log Snapshot Master DB">
      <rect x="1150" y="{820+dy}" width="200" height="44" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="1250" y="{838+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Write Sync Snapshot State</text>
      <text x="1250" y="{853+dy}" text-anchor="middle" font-size="10" fill="#555555">(sync_snapshots in master.db)</text>
    </g>

    <!-- node_calc_bill -->
    <g class="diagram-node" data-title="Calculate Bill">
      <rect x="600" y="{935+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="700" y="{954+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Go Billing Engine Calculates</text>
      <text x="700" y="{969+dy}" text-anchor="middle" font-size="10" fill="#555555">Rent + Utility Meter Usage</text>
    </g>

    <!-- node_gen_qr -->
    <g class="diagram-node" data-title="Generate PromptPay QR">
      <rect x="600" y="{1010+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="700" y="{1029+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Generate EMVCo PromptPay</text>
      <text x="700" y="{1044+dy}" text-anchor="middle" font-size="10" fill="#555555">Standard Dynamic QR Payload</text>
    </g>

    <!-- node_line_dispatch -->
    <g class="diagram-node" data-title="Dispatch LINE Message">
      <rect x="880" y="{1010+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="980" y="{1029+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Dispatch Flex Carousel</text>
      <text x="980" y="{1044+dy}" text-anchor="middle" font-size="10" fill="#555555">via LINE Messaging API</text>
    </g>

    <!-- node_tenant_receive -->
    <g class="diagram-node" data-title="Tenant Receives Bill">
      <rect x="50" y="{1010+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="150" y="{1029+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Tenant Receives Bill &amp; QR</text>
      <text x="150" y="{1044+dy}" text-anchor="middle" font-size="10" fill="#555555">on LINE Official Account</text>
    </g>

    <!-- node_tenant_pay -->
    <g class="diagram-node" data-title="Tenant Pays &amp; Uploads">
      <rect x="50" y="{1090+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="150" y="{1109+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Tenant Transfers Funds &amp;</text>
      <text x="150" y="{1124+dy}" text-anchor="middle" font-size="10" fill="#555555">Uploads Bank Slip Image</text>
    </g>

    <!-- node_liff_upload -->
    <g class="diagram-node" data-title="LINE LIFF Upload">
      <rect x="320" y="{1090+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="420" y="{1109+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">LINE LIFF Webview POSTs Slip</text>
      <text x="420" y="{1124+dy}" text-anchor="middle" font-size="10" fill="#555555">to /api/v1/bills/:id/pay</text>
    </g>

    <!-- node_save_upload -->
    <g class="diagram-node" data-title="Save Upload File">
      <rect x="1150" y="{1090+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="1250" y="{1109+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Store Physical Image File</text>
      <text x="1250" y="{1124+dy}" text-anchor="middle" font-size="10" fill="#555555">in /opt/dormitory/uploads/</text>
    </g>

    <!-- node_call_ocr -->
    <g class="diagram-node" data-title="Call Python OCR">
      <rect x="600" y="{1170+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="700" y="{1189+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Go API Calls Python OCR</text>
      <text x="700" y="{1204+dy}" text-anchor="middle" font-size="10" fill="#555555">Microservice (127.0.0.1:5001)</text>
    </g>

    <!-- node_run_ocr -->
    <g class="diagram-node" data-title="Run Dual OCR">
      <rect x="880" y="{1170+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="980" y="{1189+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Dual Engine Verification:</text>
      <text x="980" y="{1204+dy}" text-anchor="middle" font-size="10" fill="#555555">PaddleOCR + Tesseract</text>
    </g>

    <!-- dec_ocr_valid -->
    <g class="diagram-node" data-title="OCR Decision">
      <polygon points="980,{1245+dy} 1060,{1277+dy} 980,{1310+dy} 900,{1277+dy}" fill="#fff2cc" stroke="#d6b656" stroke-width="1.5" />
      <text x="980" y="{1270+dy}" text-anchor="middle" font-size="10" font-weight="600" fill="#000000">Slip Valid &amp;</text>
      <text x="980" y="{1283+dy}" text-anchor="middle" font-size="10" font-weight="600" fill="#000000">Amount Match &amp; Ref?</text>
    </g>

    <!-- node_ocr_fail -->
    <g class="diagram-node" data-title="Flag Invalid Slip">
      <rect x="600" y="{1255+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#c62828" stroke-width="1.5" />
      <text x="700" y="{1274+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#c62828">Flag Suspicious Slip</text>
      <text x="700" y="{1289+dy}" text-anchor="middle" font-size="10" fill="#555555">&amp; Alert Landlord for Review</text>
    </g>

    <!-- node_update_paid -->
    <g class="diagram-node" data-title="Update Bill Paid">
      <rect x="1150" y="{1345+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="1250" y="{1364+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">UPDATE bills SET status='paid'</text>
      <text x="1250" y="{1379+dy}" text-anchor="middle" font-size="10" fill="#555555">in isolated tenant_1.db</text>
    </g>

    <!-- node_audit_log -->
    <g class="diagram-node" data-title="Financial Audit Log">
      <rect x="1150" y="{1420+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="1250" y="{1439+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Append Immutable Record to</text>
      <text x="1250" y="{1454+dy}" text-anchor="middle" font-size="10" fill="#555555">financial_audits (master.db)</text>
    </g>

    <!-- node_line_receipt -->
    <g class="diagram-node" data-title="Send LINE Receipt">
      <rect x="880" y="{1535+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="980" y="{1554+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Send Digital Receipt</text>
      <text x="980" y="{1569+dy}" text-anchor="middle" font-size="10" fill="#555555">via LINE Flex Message</text>
    </g>

    <!-- node_tenant_receipt -->
    <g class="diagram-node" data-title="Tenant Receives Conf">
      <rect x="50" y="{1535+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="150" y="{1554+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Tenant Receives Conf</text>
      <text x="150" y="{1569+dy}" text-anchor="middle" font-size="10" fill="#555555">in LINE Chat</text>
    </g>

    <!-- node_apns_push -->
    <g class="diagram-node" data-title="APNs Push Landlord">
      <rect x="600" y="{1535+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="700" y="{1554+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Dispatch APNs Push</text>
      <text x="700" y="{1569+dy}" text-anchor="middle" font-size="10" fill="#555555">Notification to Landlord Device</text>
    </g>

    <!-- node_admin_reflect -->
    <g class="diagram-node" data-title="Admin Dashboard Metric">
      <rect x="320" y="{1535+dy}" width="200" height="46" rx="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
      <text x="420" y="{1554+dy}" text-anchor="middle" font-size="11" font-weight="600" fill="#000000">Admin Dashboard Updates</text>
      <text x="420" y="{1569+dy}" text-anchor="middle" font-size="10" fill="#555555">(Real-time Revenue Metric)</text>
    </g>

    <!-- End Node (Bullseye / Circled Cross) -->
    <g id="node_end" transform="translate(500, {1645+dy})">
      <circle cx="0" cy="0" r="14" fill="#ffffff" stroke="#000000" stroke-width="2" />
      <circle cx="0" cy="0" r="8" fill="#000000" stroke="#000000" stroke-width="1" />
    </g>
  </g>

  <!-- Legend Banner at Bottom -->
  <g id="legend_banner" transform="translate(20, 1790)">
    <rect x="0" y="0" width="1360" height="50" rx="6" fill="#f8f9fa" stroke="#000000" stroke-width="1.5" />
    <text x="20" y="30" font-size="12" font-weight="700" fill="#111827">UML 2.5 Standard Notation:</text>
    
    <!-- Item 1: Start -->
    <circle cx="210" cy="25" r="7" fill="#000000" stroke="#000000" stroke-width="1" />
    <text x="225" y="29" font-size="11" fill="#374151">Initial Node (Start)</text>

    <!-- Item 2: Action -->
    <rect x="370" y="16" width="22" height="18" rx="4" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
    <text x="400" y="29" font-size="11" fill="#374151">Action State (Process)</text>

    <!-- Item 3: Decision -->
    <polygon points="560,25 570,16 580,25 570,34" fill="#fff2cc" stroke="#d6b656" stroke-width="1.5" />
    <text x="590" y="29" font-size="11" fill="#374151">Decision Node (Branch)</text>

    <!-- Item 4: Sync Bar -->
    <rect x="740" y="23" width="28" height="5" fill="#000000" rx="1" />
    <text x="778" y="29" font-size="11" fill="#374151">Sync Bar (Fork / Join)</text>

    <!-- Item 5: End -->
    <circle cx="930" cy="25" r="8" fill="#ffffff" stroke="#000000" stroke-width="1.5" />
    <circle cx="930" cy="25" r="4" fill="#000000" stroke="#000000" stroke-width="1" />
    <text x="948" y="29" font-size="11" fill="#374151">Activity Final Node (End)</text>

    <!-- Item 6: Actor -->
    <g transform="translate(1120, 15)">
      <circle cx="7" cy="5" r="4" fill="none" stroke="#000000" stroke-width="1.2" />
      <line x1="7" y1="9" x2="7" y2="17" stroke="#000000" stroke-width="1.2" />
      <line x1="2" y1="12" x2="12" y2="12" stroke="#000000" stroke-width="1.2" />
      <line x1="7" y1="17" x2="2" y2="23" stroke="#000000" stroke-width="1.2" />
      <line x1="7" y1="17" x2="12" y2="23" stroke="#000000" stroke-width="1.2" />
    </g>
    <text x="1140" y="29" font-size="11" fill="#374151">Actor (Human Initiator)</text>
  </g>
</svg>"""
    return svg


def generate_interactive_html(svg_content):
    html_page = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>DormiNetX Architecture &amp; Operational Flowchart</title>
  <style>
    * {{
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: #f1f3f5;
      color: #212529;
      display: flex;
      flex-direction: column;
      height: 100vh;
      overflow: hidden;
    }}
    header {{
      background: #ffffff;
      border-bottom: 1px solid #dee2e6;
      padding: 12px 24px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-shrink: 0;
      box-shadow: 0 1px 3px rgba(0,0,0,0.05);
    }}
    .title-area h1 {{
      font-size: 18px;
      font-weight: 700;
      color: #111827;
      margin-bottom: 3px;
    }}
    .title-area p {{
      font-size: 13px;
      color: #6b7280;
    }}
    .controls {{
      display: flex;
      gap: 8px;
      align-items: center;
    }}
    .btn {{
      background: #ffffff;
      border: 1px solid #d1d5db;
      padding: 6px 12px;
      border-radius: 6px;
      font-size: 13px;
      font-weight: 500;
      color: #374151;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      text-decoration: none;
      transition: all 0.15s ease;
    }}
    .btn:hover {{
      background: #f9fafb;
      border-color: #9ca3af;
      color: #111827;
    }}
    .btn-primary {{
      background: #1f2937;
      border-color: #1f2937;
      color: #ffffff;
    }}
    .btn-primary:hover {{
      background: #111827;
      border-color: #111827;
      color: #ffffff;
    }}
    .search-box {{
      position: relative;
    }}
    .search-input {{
      border: 1px solid #d1d5db;
      padding: 6px 12px;
      border-radius: 6px;
      font-size: 13px;
      width: 220px;
      outline: none;
    }}
    .search-input:focus {{
      border-color: #3b82f6;
      box-shadow: 0 0 0 2px rgba(59,130,246,0.2);
    }}
    #viewer-container {{
      flex: 1;
      overflow: auto;
      position: relative;
      background: #e5e7eb;
      display: flex;
      justify-content: center;
      align-items: flex-start;
      padding: 24px;
      user-select: none;
    }}
    .svg-wrapper {{
      background: #ffffff;
      box-shadow: 0 4px 20px rgba(0,0,0,0.08);
      border-radius: 4px;
      transform-origin: top center;
      transition: transform 0.1s ease-out;
      cursor: grab;
    }}
    .svg-wrapper:active {{
      cursor: grabbing;
    }}
    .node-highlight rect, .node-highlight polygon {{
      stroke: #2563eb !important;
      stroke-width: 3px !important;
      filter: drop-shadow(0 0 6px rgba(37,99,235,0.4));
    }}
    @media print {{
      header {{ display: none; }}
      body {{ background: #ffffff; overflow: visible; height: auto; }}
      #viewer-container {{ padding: 0; background: #ffffff; overflow: visible; display: block; }}
      .svg-wrapper {{ box-shadow: none; transform: none !important; width: 100% !important; }}
      svg {{ width: 100% !important; height: auto !important; }}
    }}
  </style>
</head>
<body>

  <header>
    <div class="title-area">
      <h1>DormiNetX Multi-Tier Architecture &amp; Activity Swimlane</h1>
      <p>Standard UML Activity Cross-Functional Diagram (Frontend, Backend, Services, Server &amp; Database)</p>
    </div>
    <div class="controls">
      <div class="search-box">
        <input type="text" id="searchInput" class="search-input" placeholder="Find component or step...">
      </div>
      <button class="btn" onclick="zoomIn()">Zoom In (+)</button>
      <button class="btn" onclick="zoomOut()">Zoom Out (-)</button>
      <button class="btn" onclick="resetZoom()">100%</button>
      <button class="btn" onclick="fitWidth()">Fit Width</button>
      <a href="system_architecture.drawio" download="system_architecture.drawio" class="btn">Download .drawio</a>
      <a href="system_architecture.pdf" download="system_architecture.pdf" class="btn btn-primary">Download PDF (Single Page)</a>
    </div>
  </header>

  <div id="viewer-container">
    <div id="svgWrapper" class="svg-wrapper">
      {svg_content}
    </div>
  </div>

  <script>
    let scale = 1.0;
    const wrapper = document.getElementById('svgWrapper');
    const container = document.getElementById('viewer-container');

    function applyZoom() {{
      wrapper.style.transform = `scale(${{scale}})`;
    }}

    function zoomIn() {{
      scale = Math.min(scale + 0.15, 2.5);
      applyZoom();
    }}

    function zoomOut() {{
      scale = Math.max(scale - 0.15, 0.4);
      applyZoom();
    }}

    function resetZoom() {{
      scale = 1.0;
      applyZoom();
    }}

    function fitWidth() {{
      const availableWidth = container.clientWidth - 48;
      scale = availableWidth / 1420;
      applyZoom();
    }}

    // Search & highlight
    document.getElementById('searchInput').addEventListener('input', function(e) {{
      const query = e.target.value.trim().toLowerCase();
      const nodes = document.querySelectorAll('.diagram-node');
      nodes.forEach(node => {{
        const text = node.textContent.toLowerCase();
        if (query && text.includes(query)) {{
          node.classList.add('node-highlight');
        }} else {{
          node.classList.remove('node-highlight');
        }}
      }});
    }});

    // Drag to pan
    let isPanning = false;
    let startX, startY, scrollLeft, scrollTop;

    container.addEventListener('mousedown', (e) => {{
      if (e.target.closest('button') || e.target.closest('input') || e.target.closest('a')) return;
      isPanning = true;
      startX = e.pageX - container.offsetLeft;
      startY = e.pageY - container.offsetTop;
      scrollLeft = container.scrollLeft;
      scrollTop = container.scrollTop;
    }});

    window.addEventListener('mouseup', () => {{
      isPanning = false;
    }});

    window.addEventListener('mousemove', (e) => {{
      if (!isPanning) return;
      e.preventDefault();
      const x = e.pageX - container.offsetLeft;
      const y = e.pageY - container.offsetTop;
      const walkX = (x - startX) * 1.5;
      const walkY = (y - startY) * 1.5;
      container.scrollLeft = scrollLeft - walkX;
      container.scrollTop = scrollTop - walkY;
    }});

    // Mouse wheel zoom with Ctrl or Alt
    container.addEventListener('wheel', (e) => {{
      if (e.ctrlKey || e.metaKey) {{
        e.preventDefault();
        if (e.deltaY < 0) {{
          zoomIn();
        }} else {{
          zoomOut();
        }}
      }}
    }}, {{ passive: false }});

    // Auto fit width on load if window is narrow
    window.addEventListener('DOMContentLoaded', () => {{
      if (window.innerWidth < 1480) {{
        fitWidth();
      }}
    }});
  </script>
</body>
</html>
"""
    return html_page


if __name__ == "__main__":
    docs_dir = "/Volumes/FangB/dorm_project/docs"
    os.makedirs(docs_dir, exist_ok=True)

    drawio_path = os.path.join(docs_dir, "system_architecture.drawio")
    svg_path = os.path.join(docs_dir, "system_architecture.svg")
    html_path = os.path.join(docs_dir, "system_architecture.html")
    pdf_path = os.path.join(docs_dir, "system_architecture.pdf")

    print("1. Generating Draw.io XML...")
    with open(drawio_path, "w", encoding="utf-8") as f:
        f.write(create_drawio_xml())

    print("2. Generating Pure SVG...")
    svg_data = generate_pure_svg()
    # Validate XML
    ET.fromstring(svg_data)
    with open(svg_path, "w", encoding="utf-8") as f:
        f.write(svg_data)

    print("3. Generating Interactive HTML...")
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(generate_interactive_html(svg_data))

    print("4. Converting SVG to Single-Page Publication PDF...")
    rsvg_cmd = ["/opt/homebrew/bin/rsvg-convert", "-f", "pdf", "-o", pdf_path, svg_path]
    subprocess.run(rsvg_cmd, check=True)

    # Mirror all generated files to /Volumes/FangB/ and /Volumes/FangB/dorminet_server/
    targets = [
        "/Volumes/FangB",
        "/Volumes/FangB/dorminet_server"
    ]

    files_to_copy = [
        ("system_architecture.drawio", drawio_path),
        ("system_architecture.html", html_path),
        ("system_architecture.svg", svg_path),
        ("system_architecture.pdf", pdf_path),
    ]

    for target_dir in targets:
        if os.path.exists(target_dir):
            for fname, src_fpath in files_to_copy:
                dest = os.path.join(target_dir, fname)
                shutil.copy2(src_fpath, dest)
            print(f"Copied all files to {target_dir}/")

    print("All architecture files and single-page PDF generated and verified successfully!")
