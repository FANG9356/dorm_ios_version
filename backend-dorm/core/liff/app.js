(() => {
  "use strict";

  const LIFF_ID = "2010525486-cUOKPsCJ";
  const loading = document.getElementById("loading");
  const notice = document.getElementById("notice");
  const form = document.getElementById("link-form");
  const phone = document.getElementById("phone");
  const lineName = document.getElementById("line-name");
  const pageTitle = document.getElementById("page-title");
  const shell = document.querySelector(".shell");
  const onboarding = document.querySelector(".onboarding-steps");
  const profilePicture = document.getElementById("profile-picture");
  const profileFallback = document.getElementById("profile-fallback");
  const onboardingSteps = document.querySelectorAll(".step-item");
  const stepList = document.querySelector(".step-list");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const verifyButton = document.getElementById("verify-button");
  const confirmation = document.getElementById("confirmation");
  const confirmationText = document.getElementById("confirmation-text");
  const linkButton = document.getElementById("link-button");
  const backButton = document.getElementById("back-button");
  const residentDashboard = document.getElementById("resident-dashboard");
  const residentRoom = document.getElementById("resident-room");
  const residentRoomType = document.getElementById("resident-room-type");
  const residentStatus = document.getElementById("resident-status");
  const residentName = document.getElementById("resident-name");
  const residentMoveIn = document.getElementById("resident-move-in");
  const residentContract = document.getElementById("resident-contract");
  const outstandingAmount = document.getElementById("outstanding-amount");
  const outstandingCount = document.getElementById("outstanding-count");
  const billingWarning = document.getElementById("billing-warning");
  const invoiceList = document.getElementById("invoice-list");
  const invoiceTemplate = document.getElementById("invoice-template");
  const noBill = document.getElementById("no-bill");
  const closeButton = document.getElementById("close-button");

  let verified = null;
  let progressIndex = 0;

  function showNotice(message, success = false) {
    notice.textContent = message;
    notice.className = success ? "status status-success" : "status";
    notice.hidden = !message;
  }

  function setProgress(index) {
    onboardingSteps.forEach((step, stepIndex) => {
      step.classList.toggle("is-complete", stepIndex < index);
      step.classList.toggle("is-active", stepIndex === index);
    });
    stepList.classList.remove("progress-0", "progress-1", "progress-2", "progress-3");
    stepList.classList.add(`progress-${Math.max(0, Math.min(index, onboardingSteps.length))}`);
    progressIndex = index;
  }

  function wait(milliseconds) {
    return new Promise((resolve) => window.setTimeout(resolve, reduceMotion ? 0 : milliseconds));
  }

  async function animateProgressTo(targetIndex) {
    const direction = targetIndex >= progressIndex ? 1 : -1;
    while (progressIndex !== targetIndex) {
      setProgress(progressIndex + direction);
      await wait(230);
    }
  }

  async function swapContent(outgoing, incoming) {
    outgoing.classList.add("content-out");
    await wait(170);
    outgoing.hidden = true;
    outgoing.classList.remove("content-out");
    incoming.hidden = false;
    incoming.classList.add("content-in");
    await wait(420);
    incoming.classList.remove("content-in");
  }

  function setBusy(button, busy, busyText, readyText) {
    if (!button.dataset.readyContent) button.dataset.readyContent = button.innerHTML;
    button.disabled = busy;
    if (busy) {
      button.textContent = busyText;
    } else if (button.dataset.readyContent) {
      button.innerHTML = button.dataset.readyContent;
    } else {
      button.textContent = readyText;
    }
  }

  async function parseResponse(response) {
    const text = await response.text();
    if (!text) return {};
    try {
      return JSON.parse(text);
    } catch (_) {
      return { error: "เซิร์ฟเวอร์ตอบกลับไม่ถูกต้อง" };
    }
  }

  function gregorianYear(year) {
    return year > 2400 ? year - 543 : year;
  }

  function dateFromStoredValue(value) {
    if (!value) return "ไม่ระบุ";
    const match = String(value).match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (!match) return null;
    return new Date(gregorianYear(Number(match[1])), Number(match[2]) - 1, Number(match[3]));
  }

  function formatDate(value) {
    if (!value) return "ไม่ระบุ";
    const date = dateFromStoredValue(value);
    if (!date) return value;
    return new Intl.DateTimeFormat("th-TH", { day: "numeric", month: "short", year: "numeric" }).format(date);
  }

  function formatPeriod(value) {
    const match = String(value || "").match(/^(\d{4})-(\d{2})$/);
    if (!match) return value || "ไม่ระบุ";
    const date = new Date(gregorianYear(Number(match[1])), Number(match[2]) - 1, 1);
    return new Intl.DateTimeFormat("th-TH", { month: "long", year: "numeric" }).format(date);
  }

  function normalizedPeriod(value) {
    const match = String(value || "").match(/^(\d{4})-(\d{2})$/);
    if (!match) return String(value || "");
    return `${gregorianYear(Number(match[1]))}-${match[2]}`;
  }

  function formatDateTime(value) {
    if (!value) return "ไม่ระบุเวลาอัปเดต";
    let normalized = String(value);
    const yearMatch = normalized.match(/^(\d{4})-/);
    if (yearMatch && Number(yearMatch[1]) > 2400) {
      normalized = `${gregorianYear(Number(yearMatch[1]))}${normalized.slice(4)}`;
    }
    const date = new Date(normalized);
    if (Number.isNaN(date.getTime())) return `อัปเดต ${formatDate(value)}`;
    const formatted = new Intl.DateTimeFormat("th-TH", {
      day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit"
    }).format(date);
    return `อัปเดต ${formatted} น.`;
  }

  function formatMoney(value) {
    return `${new Intl.NumberFormat("th-TH", { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Number(value) || 0)} บาท`;
  }

  function residentStatusLabel(value) {
    if (value === "จอง") return "จองแล้ว";
    return "กำลังพักอาศัย";
  }

  function paymentStatusLabel(value, outstanding) {
    const labels = {
      paid: "ชำระแล้ว",
      partial: "ชำระบางส่วน",
      checking: "รอตรวจสอบ",
      pending: "รอชำระ"
    };
    return labels[value] || (outstanding ? "รอชำระ" : "ปิดยอดแล้ว");
  }

  function appendInvoiceRow(parent, label, value, className = "") {
    const row = document.createElement("div");
    const term = document.createElement("dt");
    const description = document.createElement("dd");
    term.textContent = label;
    description.textContent = value;
    if (className) row.className = className;
    row.append(term, description);
    parent.appendChild(row);
  }

  function renderInvoice(invoice, index) {
    const fragment = invoiceTemplate.content.cloneNode(true);
    const item = fragment.querySelector(".invoice-item");
    item.open = index === 0;
    fragment.querySelector(".invoice-number").textContent = invoice.invoice_number ? `เลขที่บิล ${invoice.invoice_number}` : "ไม่ระบุเลขที่บิล";
    fragment.querySelector(".invoice-period").textContent = `รอบบิล ${formatPeriod(invoice.period)}`;
    fragment.querySelector(".invoice-balance").textContent = formatMoney(invoice.balance);
    fragment.querySelector(".invoice-status").textContent = paymentStatusLabel(invoice.status, invoice.outstanding);
    fragment.querySelector(".invoice-updated").textContent = formatDateTime(invoice.updated_at);

    const meta = fragment.querySelector(".invoice-meta");
    appendInvoiceRow(meta, "ครบกำหนด", formatDate(invoice.due_date));
    if (Number(invoice.installment_phase) > 0) {
      appendInvoiceRow(meta, "งวดที่", String(invoice.installment_phase));
    }
    if (invoice.payment_date) {
      appendInvoiceRow(meta, "วันที่รับชำระ", formatDate(invoice.payment_date));
    }

    const lines = fragment.querySelector(".invoice-lines");
    const lineList = document.createElement("dl");
    const standardLines = [
      ["ค่าเช่าห้อง", invoice.rent_fee],
      ["ค่าน้ำประปา", invoice.water_fee],
      ["ค่าไฟฟ้า", invoice.electric_fee],
      ["ค่าส่วนกลาง", invoice.common_fee],
      ["ค่าปรับ", invoice.late_fee]
    ];
    const optionalLines = [
      ["ค่ามัดจำ", invoice.deposit_fee],
      ["ค่าอุปกรณ์เพิ่มเติม", invoice.appliance_fee],
      ["รายการอื่น ๆ", invoice.other_fee]
    ];
    standardLines.forEach(([label, value]) => appendInvoiceRow(lineList, label, formatMoney(value)));
    optionalLines.forEach(([label, value]) => {
      if (Math.abs(Number(value) || 0) >= 0.01) appendInvoiceRow(lineList, label, formatMoney(value));
    });
    lines.appendChild(lineList);

    const totals = fragment.querySelector(".invoice-totals");
    appendInvoiceRow(totals, "ยอดบิล", formatMoney(invoice.amount));
    appendInvoiceRow(totals, "ชำระแล้ว", formatMoney(invoice.paid_amount));
    appendInvoiceRow(totals, "ยอดคงเหลือ", formatMoney(invoice.balance), "invoice-total-balance");
    return fragment;
  }

  function renderResidentDashboard(data) {
    const resident = data.resident;
    const billing = data.billing || {};
    if (!resident || !resident.room_number) throw new Error("ข้อมูลลูกบ้านไม่สมบูรณ์ กรุณาติดต่อผู้ดูแลหอพัก");

    pageTitle.textContent = "ข้อมูลของฉัน";
    residentRoom.textContent = resident.room_number;
    residentRoomType.textContent = resident.room_type || "ห้องพัก";
    residentStatus.textContent = residentStatusLabel(resident.status);
    residentName.textContent = resident.full_name || "ไม่ระบุ";
    residentMoveIn.textContent = formatDate(resident.move_in_date);
    residentContract.textContent = resident.indefinite_contract ? "ไม่มีกำหนด" : formatDate(resident.contract_end_date);

    const balance = Number(billing.outstanding_amount) || 0;
    const count = Number(billing.outstanding_count) || 0;
    outstandingAmount.textContent = formatMoney(balance);
    outstandingCount.textContent = count > 0 ? `${count} ใบแจ้งหนี้ที่ยังไม่ปิดยอด · เรียงล่าสุดก่อน` : "ไม่มีรายการค้างชำระ";

    const invoices = Array.isArray(billing.invoices) ? billing.invoices : [];
    const periods = invoices.map((invoice) => normalizedPeriod(invoice.period)).filter(Boolean);
    const hasRepeatedPeriod = new Set(periods).size !== periods.length;
    billingWarning.textContent = hasRepeatedPeriod
      ? "พบใบแจ้งหนี้มากกว่า 1 ใบในรอบเดียวกัน กรุณาตรวจสอบกับผู้ดูแลหอพัก"
      : "";
    billingWarning.hidden = !hasRepeatedPeriod;
    invoiceList.replaceChildren();
    invoices.forEach((invoice, index) => invoiceList.appendChild(renderInvoice(invoice, index)));
    noBill.hidden = invoices.length > 0;
  }

  async function initialize() {
    try {
      if (!window.liff) throw new Error("ไม่สามารถโหลดระบบ LINE ได้ กรุณาลองใหม่อีกครั้ง");

      await window.liff.init({ liffId: LIFF_ID });
      if (!window.liff.isLoggedIn()) {
        window.liff.login({ redirectUri: window.location.href });
        return;
      }

      const profile = await window.liff.getProfile();
      lineName.textContent = profile.displayName || "ลูกบ้าน";
      if (profile.pictureUrl) {
        profilePicture.src = profile.pictureUrl;
        profilePicture.hidden = false;
        profileFallback.hidden = true;
      }

      const accessToken = window.liff.getAccessToken();
      if (!accessToken) throw new Error("เซสชัน LINE หมดอายุ กรุณาปิดแล้วเปิดหน้านี้ใหม่");
      const response = await fetch("/api/liff/status", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({ access_token: accessToken })
      });
      const data = await parseResponse(response);
      if (!response.ok) throw new Error(data.error || "ตรวจสอบสถานะการเชื่อมต่อไม่สำเร็จ");
      if (data.linked) {
        renderResidentDashboard(data);
        onboarding.hidden = true;
        shell.classList.add("is-linked");
        document.body.classList.add("dashboard-mode");
        await swapContent(loading, residentDashboard);
        return;
      }
      await swapContent(loading, form);
    } catch (error) {
      loading.hidden = true;
      showNotice(error.message || "เปิดหน้าผูกบัญชีไม่สำเร็จ กรุณาลองใหม่");
    }
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    phone.blur();
    showNotice("");

    const normalizedPhone = phone.value.replace(/[^0-9]/g, "");
    if (normalizedPhone.length < 9 || normalizedPhone.length > 10) {
      showNotice("กรุณากรอกเบอร์โทรศัพท์ 9–10 หลัก");
      return;
    }

    setBusy(verifyButton, true, "กำลังค้นหาห้อง…", "ค้นหาห้องของฉัน");
    try {
      const response = await fetch("/api/liff/verify-tenant", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({ phone: normalizedPhone })
      });
      const data = await parseResponse(response);
      if (!response.ok) throw new Error(data.error || "ตรวจสอบข้อมูลไม่สำเร็จ");
      if (!data.room_number) throw new Error("ไม่พบหมายเลขห้อง กรุณาติดต่อผู้ดูแลหอพัก");

      verified = { roomNumber: data.room_number, phone: normalizedPhone };
      confirmationText.textContent = `คุณ ${data.masked_name} · ห้อง ${data.room_number}`;
      await animateProgressTo(2);
      await swapContent(form, confirmation);
    } catch (error) {
      showNotice(error.message || "ตรวจสอบข้อมูลไม่สำเร็จ");
    } finally {
      setBusy(verifyButton, false, "กำลังค้นหาห้อง…", "ค้นหาห้องของฉัน");
    }
  });

  backButton.addEventListener("click", async () => {
    verified = null;
    showNotice("");
    await animateProgressTo(0);
    await swapContent(confirmation, form);
    phone.focus({ preventScroll: true });
  });

  linkButton.addEventListener("click", async () => {
    if (!verified) return;
    const accessToken = window.liff && window.liff.getAccessToken();
    if (!accessToken) {
      showNotice("เซสชัน LINE หมดอายุ กรุณาปิดแล้วเปิดหน้านี้ใหม่");
      return;
    }

    setBusy(linkButton, true, "กำลังเชื่อมต่อบัญชี…", "เชื่อมต่อบัญชี");
    showNotice("");
    try {
      const response = await fetch("/api/liff/link", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({
          access_token: accessToken,
          room_number: verified.roomNumber,
          phone: verified.phone
        })
      });
      const data = await parseResponse(response);
      if (!response.ok) throw new Error(data.error || "ผูกบัญชีไม่สำเร็จ");

      await animateProgressTo(onboardingSteps.length);
      confirmation.hidden = true;
      showNotice(`ผูกบัญชี LINE กับห้อง ${data.room_number} สำเร็จแล้ว`, true);
      if (window.liff.isInClient()) {
        window.setTimeout(() => window.liff.closeWindow(), 2200);
      }
    } catch (error) {
      showNotice(error.message || "ผูกบัญชีไม่สำเร็จ กรุณาลองใหม่");
      setBusy(linkButton, false, "กำลังเชื่อมต่อบัญชี…", "เชื่อมต่อบัญชี");
    }
  });

  phone.addEventListener("input", () => showNotice(""));

  closeButton.addEventListener("click", () => {
    if (window.liff && window.liff.isInClient()) {
      window.liff.closeWindow();
      return;
    }
    window.close();
  });

  initialize();
})();
