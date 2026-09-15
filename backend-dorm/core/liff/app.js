(() => {
  "use strict";

  const LIFF_ID = "2010525486-cUOKPsCJ";
  const loading = document.getElementById("loading");
  const notice = document.getElementById("notice");
  const form = document.getElementById("link-form");
  const phone = document.getElementById("phone");
  const lineName = document.getElementById("line-name");
  const verifyButton = document.getElementById("verify-button");
  const confirmation = document.getElementById("confirmation");
  const confirmationText = document.getElementById("confirmation-text");
  const linkButton = document.getElementById("link-button");
  const backButton = document.getElementById("back-button");
  const steps = document.querySelectorAll(".step");

  let verified = null;

  function showNotice(message, success = false) {
    notice.textContent = message;
    notice.className = success ? "status status-success" : "status";
    notice.hidden = !message;
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

  function showStep(index) {
    steps.forEach((step, stepIndex) => step.classList.toggle("is-active", stepIndex === index));
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

  async function initialize() {
    try {
      if (!window.liff) throw new Error("ไม่สามารถโหลดระบบ LINE ได้ กรุณาลองใหม่อีกครั้ง");

      await window.liff.init({ liffId: LIFF_ID });
      if (!window.liff.isLoggedIn()) {
        window.liff.login({ redirectUri: window.location.href });
        return;
      }

      const profile = await window.liff.getProfile();
      lineName.textContent = `บัญชี LINE: ${profile.displayName}`;
      loading.hidden = true;
      form.hidden = false;
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
      form.hidden = true;
      confirmation.hidden = false;
      showStep(1);
    } catch (error) {
      showNotice(error.message || "ตรวจสอบข้อมูลไม่สำเร็จ");
    } finally {
      setBusy(verifyButton, false, "กำลังค้นหาห้อง…", "ค้นหาห้องของฉัน");
    }
  });

  backButton.addEventListener("click", () => {
    verified = null;
    confirmation.hidden = true;
    form.hidden = false;
    showStep(0);
    showNotice("");
  });

  linkButton.addEventListener("click", async () => {
    if (!verified) return;
    const accessToken = window.liff && window.liff.getAccessToken();
    if (!accessToken) {
      showNotice("เซสชัน LINE หมดอายุ กรุณาปิดแล้วเปิดหน้านี้ใหม่");
      return;
    }

    setBusy(linkButton, true, "กำลังผูกบัญชี…", "ยืนยันการผูกบัญชี");
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

      confirmation.hidden = true;
      showNotice(`ผูกบัญชี LINE กับห้อง ${data.room_number} สำเร็จแล้ว`, true);
      if (window.liff.isInClient()) {
        window.setTimeout(() => window.liff.closeWindow(), 2200);
      }
    } catch (error) {
      showNotice(error.message || "ผูกบัญชีไม่สำเร็จ กรุณาลองใหม่");
      setBusy(linkButton, false, "กำลังผูกบัญชี…", "ยืนยันการผูกบัญชี");
    }
  });

  phone.addEventListener("input", () => showNotice(""));

  initialize();
})();
