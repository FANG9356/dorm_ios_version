import { useState, useEffect } from 'react';
import { API_URL, uploadsUrl } from '../config';
import ConfirmModal from './ConfirmModal';

export default function FinancePage({ addLog, showToast }) { 
  const [users, setUsers] = useState([]);
  const [orderedUsers, setOrderedUsers] = useState([]); 
  const [draggedCard, setDraggedCard] = useState(null); 

  const [rooms, setRooms] = useState([]);
  const [roomTypes, setRoomTypes] = useState([]);
  const [allPayments, setAllPayments] = useState([]);
  const [isHistoryModalOpen, setIsHistoryModalOpen] = useState(false);
  const [isPaymentFormOpen, setIsPaymentFormOpen] = useState(false);
  const [selectedBillingUser, setSelectedBillingUser] = useState(null);
  const [targetMonth, setTargetMonth] = useState(''); 
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [editingPaymentId, setEditingPaymentId] = useState(null);
  const [sysModal, setSysModal] = useState({ isOpen: false, title: '', message: '', isAlert: false, isDanger: false, onConfirm: null, onCancel: null });
  const [isLoading, setIsLoading] = useState(true);
  

  
  // สเตตัสสำหรับเก็บค่าเดือนที่จะพิมพ์รายงาน (ค่าเริ่มต้นคือเดือนปัจจุบัน)
  const [reportMonth, setReportMonth] = useState(new Date().toISOString().slice(0, 7));
  
  const [billData, setBillData] = useState({ rent: '', water: '', electric: '', common: '', late: '', appliance_fee: '', date: new Date().toISOString().split('T')[0], method: 'เงินโอน (Transfer)', slips: [], paid_amount: '' });
  const [previewImages, setPreviewImages] = useState(null);
  const [currentImageIndex, setCurrentImageIndex] = useState(0);

  const [useMeter, setUseMeter] = useState(false);
  const [meterCalc, setMeterCalc] = useState({ wPrev: '', wCurr: '', wRate: '20', ePrev: '', eCurr: '', eRate: '8' });

  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    const handleEsc = (e) => {
      if (e.key === 'Escape') {
        if (sysModal.isOpen) {
          setSysModal(prev => ({ ...prev, isOpen: false }));
        } else if (previewImages) {
          setPreviewImages(null);
        } else if (isPaymentFormOpen) {
          setIsPaymentFormOpen(false);
          setEditingPaymentId(null);
        } else if (isHistoryModalOpen) {
          setIsHistoryModalOpen(false);
        }
      }
    };
    window.addEventListener('keydown', handleEsc, { capture: true });
    return () => window.removeEventListener('keydown', handleEsc, { capture: true });
  }, [sysModal.isOpen, previewImages, isPaymentFormOpen, isHistoryModalOpen]);

  const fetchData = () => {
    return Promise.all([
      fetch(`${API_URL}/users`).then(res => res.json()).then(data => {
        const activeUsers = (data || []).filter(u => u.status === 'กำลังพักอาศัย');
        setUsers(data || []);
        const savedOrder = localStorage.getItem('dorminet_finance_order');
        if (savedOrder && activeUsers.length > 0) {
          const idOrder = JSON.parse(savedOrder);
          activeUsers.sort((a, b) => {
            let indexA = idOrder.indexOf(a.id);
            let indexB = idOrder.indexOf(b.id);
            if (indexA === -1) indexA = 999;
            if (indexB === -1) indexB = 999;
            return indexA - indexB;
          });
        }
        setOrderedUsers(activeUsers); 
      }),
      fetch(`${API_URL}/payments`).then(res => res.json()).then(data => setAllPayments(data || [])),
      fetch(`${API_URL}/rooms`).then(res => res.json()).then(data => setRooms(data || [])),
      fetch(`${API_URL}/room-types`).then(res => res.json()).then(data => setRoomTypes(data || []))
    ]);
  };

  useEffect(() => { 
    setIsLoading(true);
    fetchData().finally(() => setTimeout(() => setIsLoading(false), 800));
    
    const interval = setInterval(() => {
      fetch(`${API_URL}/payments`).then(res => res.json()).then(data => setAllPayments(data || []));
    }, 10000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (useMeter) {
      let wPrevNum = Number(meterCalc.wPrev);
      let wCurrNum = Number(meterCalc.wCurr);
      let ePrevNum = Number(meterCalc.ePrev);
      let eCurrNum = Number(meterCalc.eCurr);

      let wUnits = wCurrNum - wPrevNum;
      if (wCurrNum < wPrevNum && meterCalc.wCurr !== '') {
          wUnits = (10000 - wPrevNum) + wCurrNum;
      }
      
      let eUnits = eCurrNum - ePrevNum;
      if (eCurrNum < ePrevNum && meterCalc.eCurr !== '') {
          eUnits = (10000 - ePrevNum) + eCurrNum;
      }

      const wCost = wUnits * Number(meterCalc.wRate);
      const eCost = eUnits * Number(meterCalc.eRate);
      setBillData(prev => ({ ...prev, water: wCost > 0 ? wCost : (wCost === 0 && meterCalc.wCurr !== '' ? 0 : ''), electric: eCost > 0 ? eCost : (eCost === 0 && meterCalc.eCurr !== '' ? 0 : '') }));
    }
  }, [meterCalc, useMeter]);

  const handleDragStart = (e, index) => {
    if (searchTerm) {
      e.preventDefault();
      return;
    }
    setDraggedCard(index); 
    e.dataTransfer.effectAllowed = "move"; 
  };
  const handleDragEnter = (e, index) => {
    if (searchTerm || draggedCard === null || draggedCard === index) return;
    const newOrder = [...orderedUsers];
    const draggedItem = newOrder[draggedCard];
    newOrder.splice(draggedCard, 1);
    newOrder.splice(index, 0, draggedItem);
    setDraggedCard(index);
    setOrderedUsers(newOrder);
  };
  const handleDragEnd = () => {
    setDraggedCard(null);
    localStorage.setItem('dorminet_finance_order', JSON.stringify(orderedUsers.map(u => u.id)));
  };

  const generateBillingCycles = (start, end, isIndefinite = false) => {
    if (!start) return [];
    if (!isIndefinite && !end) return [];
    
    const cycles = [];
    const startDate = new Date(start); 
    const dueDateDay = startDate.getDate();
    let currentMonth = new Date(startDate.getFullYear(), startDate.getMonth(), 1);
    
    let endMonth;
    if (isIndefinite) {
        const today = new Date();
        endMonth = new Date(today.getFullYear(), today.getMonth() + 6, 1);
    } else {
        const endDate = new Date(end);
        endMonth = new Date(endDate.getFullYear(), endDate.getMonth(), 1);
    }

    while (currentMonth <= endMonth) {
      cycles.push({
        monthId: `${currentMonth.getFullYear()}-${String(currentMonth.getMonth() + 1).padStart(2, '0')}`,
        dueDate: dueDateDay,
        label: currentMonth.toLocaleDateString('th-TH', { month: 'long', year: 'numeric' })
      });
      currentMonth.setMonth(currentMonth.getMonth() + 1);
    }
    return cycles;
  };

  const handlePaymentSubmit = (e, requestedStatus = 'paid') => {
    e.preventDefault();
    setIsSubmitting(true);

    const totalAmount = (Number(billData.rent) || 0) + (Number(billData.appliance_fee) || 0) + (Number(billData.water) || 0) + (Number(billData.electric) || 0) + (Number(billData.common) || 0) + (Number(billData.late) || 0);
    const paidAmount = Number(billData.paid_amount) || 0;
    
    let finalStatus = requestedStatus;
    if (requestedStatus === 'paid') {
        if (paidAmount > 0 && paidAmount < totalAmount) {
            finalStatus = 'partial';
        } else if (paidAmount === 0 && totalAmount > 0) {
            // ถ้ากดยืนยันจ่ายแล้ว แต่ยังไม่ใส่ยอด ให้ถือว่าจ่ายเต็ม
            finalStatus = 'paid';
        } else {
            finalStatus = 'paid';
        }
    }

    const formData = new FormData();
    formData.append('user_id', selectedBillingUser.id);
    formData.append('room_number', selectedBillingUser.room_number);
    formData.append('rent_fee', billData.rent || 0);
    formData.append('water_fee', billData.water || 0);
    formData.append('electric_fee', billData.electric || 0);
    formData.append('common_fee', billData.common || 0);
    formData.append('late_fee', Number(billData.late) || 0);
    formData.append('appliance_fee', Number(billData.appliance_fee) || 0);
    formData.append('amount', totalAmount);
    formData.append('month', targetMonth);
    formData.append('date', billData.date);
    formData.append('method', billData.method);
    formData.append('payment_status', finalStatus);
    formData.append('paid_amount', Number(billData.paid_amount) || (finalStatus === 'paid' ? totalAmount : 0));
    
    // [เพิ่มใหม่] ส่งเลขมิเตอร์ขึ้นไปบันทึก
    formData.append('water_meter_prev', useMeter ? meterCalc.wPrev : 0);
    formData.append('water_meter_curr', useMeter ? meterCalc.wCurr : 0);
    formData.append('electric_meter_prev', useMeter ? meterCalc.ePrev : 0);
    formData.append('electric_meter_curr', useMeter ? meterCalc.eCurr : 0);

    if (billData.slips && billData.slips.length > 0) {
      billData.slips.forEach(file => formData.append('slips', file));
    }

    if (editingPaymentId) {
      formData.append('payment_id', editingPaymentId);
    }

    const method = editingPaymentId ? 'PUT' : 'POST';

    fetch(`${API_URL}/payments`, { method, body: formData })
      .then(async res => {
        if (!res.ok) {
           const errText = await res.text();
           throw new Error(errText);
        }
        addLog('Payment', editingPaymentId ? `แก้ไขบิลห้อง ${selectedBillingUser.room_number}` : `บันทึกรับเงินห้อง ${selectedBillingUser.room_number} ยอดรวม: ${totalAmount} บาท`);
        fetchData(); 
        setIsPaymentFormOpen(false); 
        setEditingPaymentId(null);
        setBillData({ rent: '', water: '', electric: '', common: '', late: '', appliance_fee: '', date: new Date().toISOString().split('T')[0], method: 'เงินโอน (Transfer)', slips: [], paid_amount: '' });
        setUseMeter(false);
        showToast(editingPaymentId ? 'อัปเดตข้อมูลสำเร็จ' : 'บันทึกการชำระเงินเรียบร้อยแล้ว', 'success');
      })
      .catch((err) => {
        console.error(err);
        showToast('เกิดข้อผิดพลาดในการบันทึกข้อมูล: บิลนี้อาจถูกชำระไปแล้ว', 'error');
      })
      .finally(() => setIsSubmitting(false));
  };

  const printHtml = async (htmlContent) => {
    // ใช้คำสั่ง PrintHtml ของ Go ถ้ารันผ่านโปรแกรม Wails (PC)
    if (window.go && window.go.main && window.go.main.App && window.go.main.App.PrintHtml) {
        try {
            await window.go.main.App.PrintHtml(htmlContent);
            return;
        } catch(e) {
            console.error("Wails Print failed, falling back to Web Print", e);
        }
    }

    const styleMatch = htmlContent.match(/<style[^>]*>([\s\S]*?)<\/style>/i);
    let styleContent = styleMatch ? styleMatch[1] : '';
    styleContent = styleContent.replace(/body\s*\{/gi, '#print-container {');
    
    const bodyMatch = htmlContent.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
    const bodyContent = bodyMatch ? bodyMatch[1] : htmlContent;

    const printContainer = document.createElement('div');
    printContainer.id = "print-container";
    
    const styleEl = document.createElement('style');
    styleEl.innerHTML = `
      #print-container {
        position: absolute;
        left: -9999px;
        top: -9999px;
        background: white;
      }
      @media print {
        body * {
          visibility: hidden;
        }
        #print-container, #print-container * {
          visibility: visible;
        }
        #print-container {
          position: absolute;
          left: 0;
          top: 0;
          width: 100%;
        }
      }
      ${styleContent}
    `;
    printContainer.appendChild(styleEl);
    
    const contentEl = document.createElement('div');
    contentEl.innerHTML = bodyContent;
    printContainer.appendChild(contentEl);
    
    document.body.appendChild(printContainer);
    
    setTimeout(() => {
      window.print();
      setTimeout(() => {
        if(document.body.contains(printContainer)) {
           document.body.removeChild(printContainer);
        }
      }, 1000);
    }, 500);
  };

  // เปลี่ยนหัวตาราง CSV เป็นภาษาไทย และดึงชื่อผู้เช่ามาใส่
  const exportToCSV = () => {
    const headers = ["ห้องพัก", "ชื่อ-สกุลผู้เช่า", "ยอดชำระรวม (บาท)", "ค่าเช่า", "ค่าเครื่องใช้ไฟฟ้า", "ค่าน้ำ", "ค่าไฟ", "ส่วนกลาง", "ค่าปรับ", "รอบบิลเดือน", "วันที่ชำระเงิน", "ช่องทางการชำระ"];
    const rows = allPayments.map(p => {
      const user = users.find(u => u.id === p.user_id) || {};
      const fullName = user.first_name ? `${user.prefix || ''}${user.first_name} ${user.last_name || ''}` : 'ไม่ระบุข้อมูล';
      return [ p.room_number, fullName, p.amount, p.rent_fee, p.appliance_fee, p.water_fee, p.electric_fee, p.common_fee, p.late_fee, p.month, p.payment_date, p.method ];
    });
    
    const csvContent = "data:text/csv;charset=utf-8,\uFEFF" + [headers.join(","), ...rows.map(e => e.map(item => `"${item}"`).join(","))].join("\n");
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `dorminet_finance_export_${new Date().getTime()}.csv`);
    document.body.appendChild(link);
    link.click();
    addLog('Export', 'ส่งออกข้อมูลการเงินเป็นไฟล์ CSV');
    showToast('ดาวน์โหลดไฟล์ CSV สำเร็จ', 'success');
  };

  // ฟังก์ชันพิมพ์รายงานสรุปยอดแบบละเอียดจัดเต็ม เป็นภาษาไทย และออกแนวนอน
  const printMonthlyReport = () => {
    if (!reportMonth) {
      showToast('กรุณาเลือกรอบเดือนที่ต้องการพิมพ์รายงาน', 'error');
      return;
    }

    const currentPayments = allPayments.filter(p => p.month === reportMonth);
    const dateStr = new Date().toLocaleString('th-TH', { dateStyle: 'long', timeStyle: 'short' });
    
    let sumRent = 0, sumAppliance = 0, sumWater = 0, sumElectric = 0, sumCommon = 0, sumLate = 0, sumTotal = 0;

    const tableRows = currentPayments.map((p, index) => {
      const user = users.find(u => u.id === p.user_id) || {};
      const fullName = user.first_name ? `${user.prefix || ''}${user.first_name} ${user.last_name || ''}` : 'ไม่ระบุ';

      sumRent += Number(p.rent_fee) || 0;
      let rowAppliance = Number(p.appliance_fee) || 0;
      sumAppliance += rowAppliance;
      sumWater += Number(p.water_fee) || 0;
      sumElectric += Number(p.electric_fee) || 0;
      sumCommon += Number(p.common_fee) || 0;
      sumLate += Number(p.late_fee) || 0;
      sumTotal += Number(p.amount) || 0;

      return `
        <tr>
          <td class="text-center">${index + 1}</td>
          <td class="text-center"><strong>${p.room_number}</strong></td>
          <td>${fullName}</td>
          <td class="text-right">${(Number(p.rent_fee) || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td>
          <td class="text-right">${rowAppliance.toLocaleString(undefined, {minimumFractionDigits: 2})}</td>
          <td class="text-right">${(Number(p.water_fee) || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td>
          <td class="text-right">${(Number(p.electric_fee) || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td>
          <td class="text-right">${(Number(p.common_fee) || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td>
          <td class="text-right">${(Number(p.late_fee) || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td>
          <td class="text-right total-col"><strong>${(Number(p.amount) || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</strong></td>
          <td class="text-center">${p.payment_date}</td>
          <td class="text-center text-small">${p.method}</td>
        </tr>
      `;
    }).join('');

    printHtml(`
      <html>
        <head>
          <title>รายงานสรุปยอดรายเดือน - DormiNet</title>
          <link href="https://fonts.googleapis.com/css2?family=Sarabun:wght@400;600;700&display=swap" rel="stylesheet">
          <style>
            @page { size: A4 landscape; margin: 15mm; }
            body { font-family: 'Sarabun', sans-serif; padding: 20px; color: #1e293b; }
            .header { text-align: center; border-bottom: 2px solid #e2e8f0; padding-bottom: 15px; margin-bottom: 20px; }
            .header h1 { margin: 0; font-size: 28px; color: #0f172a; }
            table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; }
            th { background-color: #f1f5f9; padding: 10px 6px; text-align: center; border-bottom: 2px solid #94a3b8; border-top: 2px solid #94a3b8; }
            td { padding: 8px 6px; border-bottom: 1px solid #e2e8f0; }
            .text-right { text-align: right; }
            .text-center { text-align: center; }
            .text-small { font-size: 11px; color: #64748b; }
            .total-col { color: #059669; }
            .summary-row td { background-color: #ecfdf5; font-weight: bold; border-bottom: 2px solid #10b981; border-top: 2px solid #10b981; padding: 12px 6px; }
            .summary-label { text-align: right; font-size: 16px; }
            .footer { margin-top: 30px; font-size: 12px; color: #94a3b8; display: flex; justify-content: space-between; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>รายงานสรุปการรับชำระเงินประจำเดือน</h1>
            <p style="margin: 8px 0 0 0; font-size: 16px;"><strong>รอบบิล (ปี-เดือน):</strong> ${reportMonth}</p>
          </div>
          <table>
            <thead>
              <tr>
                <th width="4%">ลำดับ</th>
                <th width="7%">ห้องพัก</th>
                <th width="12%" style="text-align: left;">ชื่อ-สกุลผู้เช่า</th>
                <th width="8%" class="text-right">ค่าเช่า</th>
                <th width="8%" class="text-right">บริการเสริม</th>
                <th width="8%" class="text-right">ค่าน้ำ</th>
                <th width="8%" class="text-right">ค่าไฟ</th>
                <th width="8%" class="text-right">ส่วนกลาง</th>
                <th width="7%" class="text-right">ค่าปรับ</th>
                <th width="10%" class="text-right">ยอดรวม (บาท)</th>
                <th width="10%">วันที่ชำระ</th>
                <th width="10%">ช่องทาง</th>
              </tr>
            </thead>
            <tbody>
              ${currentPayments.length === 0 ? '<tr><td colspan="12" class="text-center" style="padding: 30px;">ไม่มีข้อมูลการรับชำระเงินในเดือนที่เลือก</td></tr>' : tableRows}
              ${currentPayments.length > 0 ? `
                <tr class="summary-row">
                  <td colspan="3" class="summary-label">รวมยอดรับสุทธิประจำเดือนนี้:</td>
                  <td class="text-right">${sumRent.toLocaleString(undefined, {minimumFractionDigits: 2})}</td>
                  <td class="text-right">${sumAppliance.toLocaleString(undefined, {minimumFractionDigits: 2})}</td>
                  <td class="text-right">${sumWater.toLocaleString(undefined, {minimumFractionDigits: 2})}</td>
                  <td class="text-right">${sumElectric.toLocaleString(undefined, {minimumFractionDigits: 2})}</td>
                  <td class="text-right">${sumCommon.toLocaleString(undefined, {minimumFractionDigits: 2})}</td>
                  <td class="text-right">${sumLate.toLocaleString(undefined, {minimumFractionDigits: 2})}</td>
                  <td class="text-right" style="font-size: 16px; color: #047857;">${sumTotal.toLocaleString(undefined, {minimumFractionDigits: 2})}</td>
                  <td colspan="2"></td>
                </tr>
              ` : ''}
            </tbody>
          </table>
          <div class="footer">
            <span>พิมพ์จากระบบ: DormiNet</span>
            <span>วันที่และเวลาที่พิมพ์: ${dateStr}</span>
          </div>
        </body>
      </html>
    `);
    addLog('Print', `พิมพ์รายงานสรุปยอดรายเดือน: ${reportMonth}`);
  };

  const printReceipt = (payment, cycleLabel) => {
    const receiptNo = `DORMINET-${payment.payment_date.replace(/-/g, '')}-${String(payment.id).padStart(4, '0')}`;
    const printDate = new Date().toLocaleString('th-TH', { dateStyle: 'long', timeStyle: 'short' });

    printHtml(`
      <html>
        <head>
          <title>ใบเสร็จรับเงิน - หอพัก DormiNet</title>
          <link href="https://fonts.googleapis.com/css2?family=Sarabun:wght@300;400;500;700&display=swap" rel="stylesheet">
          <style>
            body { font-family: 'Sarabun', sans-serif; padding: 40px; color: #1e293b; max-width: 800px; margin: 0 auto; }
            .header-container { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #cbd5e1; padding-bottom: 20px; margin-bottom: 30px; }
            .header-left h1 { margin: 0; font-size: 36px; color: #0f172a; font-weight: 700; letter-spacing: 1px; }
            .header-left p { margin: 5px 0 0 0; font-size: 16px; color: #64748b; }
            .header-right { text-align: right; }
            .header-right h2 { margin: 0; font-size: 28px; color: #2563eb; }
            .header-right p { margin: 5px 0 0 0; font-size: 14px; }
            .info-grid { display: flex; justify-content: space-between; margin-bottom: 30px; background: #f8fafc; padding: 20px; border-radius: 8px; border: 1px solid #e2e8f0; }
            .info-col p { margin: 8px 0; font-size: 16px; }
            table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
            th { background-color: #f1f5f9; padding: 12px; text-align: left; font-size: 16px; border-bottom: 2px solid #94a3b8; }
            td { padding: 15px 12px; border-bottom: 1px solid #e2e8f0; font-size: 16px; }
            .text-right { text-align: right; }
            .text-center { text-align: center; }
            .total-row td { font-weight: bold; font-size: 18px; background: #f8fafc; border-bottom: 2px solid #94a3b8; }
            .total-amount { color: #059669; font-size: 22px; }
            .signature-section { display: flex; justify-content: space-around; margin-top: 80px; text-align: center; }
            .sig-box { width: 220px; }
            .sig-line { border-bottom: 1px dashed #64748b; height: 40px; margin-bottom: 10px; }
            .footer { text-align: center; font-size: 14px; color: #94a3b8; margin-top: 60px; border-top: 1px solid #e2e8f0; padding-top: 20px; }
          </style>
        </head>
        <body>
          <div class="header-container">
            <div class="header-left">
              <h1>หอพัก DormiNet</h1>
              <p>ระบบบริหารจัดการหอพักและที่อยู่อาศัย</p>
            </div>
            <div class="header-right">
              <h2>ใบเสร็จรับเงิน</h2>
              <p><strong>เลขที่เอกสาร:</strong> ${receiptNo}</p>
              <p><strong>วันที่พิมพ์:</strong> ${printDate}</p>
            </div>
          </div>
          <div class="info-grid">
            <div class="info-col">
              <p><strong>ได้รับเงินจาก:</strong> ${selectedBillingUser.prefix}${selectedBillingUser.first_name} ${selectedBillingUser.last_name}</p>
              <p><strong>หมายเลขห้องพัก:</strong> ${selectedBillingUser.room_number}</p>
            </div>
            <div class="info-col text-right">
              <p><strong>ประจำรอบบิล:</strong> ${cycleLabel}</p>
              <p><strong>วันที่ชำระเงินจริง:</strong> ${payment.payment_date}</p>
              <p><strong>ช่องทางการชำระ:</strong> ${payment.method}</p>
            </div>
          </div>
          <table>
            <thead><tr><th class="text-center" width="10%">ลำดับ</th><th width="60%">รายการ</th><th class="text-right" width="30%">จำนวนเงิน (บาท)</th></tr></thead>
            <tbody>
              <tr><td class="text-center">1</td><td>ค่าเช่าห้องพัก</td><td class="text-right">${(payment.rent_fee || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr><td class="text-center">2</td><td>ค่าเครื่องใช้ไฟฟ้า/บริการเสริม</td><td class="text-right">${(payment.appliance_fee || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr><td class="text-center">3</td><td>ค่าบริการน้ำประปา</td><td class="text-right">${(payment.water_fee || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr><td class="text-center">4</td><td>ค่าบริการไฟฟ้า</td><td class="text-right">${(payment.electric_fee || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr><td class="text-center">5</td><td>ค่าส่วนกลาง (Wi-Fi, ไฟทางเดิน)</td><td class="text-right">${(payment.common_fee || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr><td class="text-center">6</td><td>ค่าปรับล่าช้า</td><td class="text-right">${(payment.late_fee || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr class="total-row"><td colspan="2" class="text-right">ยอดชำระสุทธิ (Grand Total)</td><td class="text-right total-amount">${payment.amount.toLocaleString(undefined, {minimumFractionDigits: 2})} บาท</td></tr>
            </tbody>
          </table>
          <div class="signature-section">
            <div class="sig-box"><div class="sig-line"></div><p>ผู้ชำระเงิน</p></div>
            <div class="sig-box"><div class="sig-line"></div><p>ผู้รับเงิน / ผู้จัดการหอพัก DormiNet</p></div>
          </div>
          <div class="footer"><p>ขอขอบคุณที่ใช้บริการหอพัก DormiNet</p></div>
        </body>
      </html>
    `);
  };

  const printInvoice = (cycleLabel) => {
    const totalAmount = (Number(billData.rent) || 0) + (Number(billData.appliance_fee) || 0) + (Number(billData.water) || 0) + (Number(billData.electric) || 0) + (Number(billData.common) || 0) + (Number(billData.late) || 0);
    const invoiceNo = `INV-${new Date().toISOString().slice(0, 10).replace(/-/g, '')}-${selectedBillingUser.room_number}`;
    const printDate = new Date().toLocaleString('th-TH', { dateStyle: 'long', timeStyle: 'short' });

    printHtml(`
      <html>
        <head>
          <title>ใบแจ้งหนี้ - หอพัก DormiNet</title>
          <link href="https://fonts.googleapis.com/css2?family=Sarabun:wght@400;700&display=swap" rel="stylesheet">
          <style>
            body { font-family: 'Sarabun', sans-serif; padding: 40px; color: #1e293b; max-width: 800px; margin: 0 auto; }
            .header { display: flex; justify-content: space-between; border-bottom: 2px solid #e2e8f0; padding-bottom: 15px; margin-bottom: 30px; }
            .header h1 { margin: 0; font-size: 32px; color: #0f172a; }
            .header h2 { margin: 0; font-size: 24px; color: #f59e0b; }
            .content-box { background: #f8fafc; padding: 20px; border-radius: 8px; margin-bottom: 20px; border: 1px solid #e2e8f0; display: flex; justify-content: space-between;}
            table { width: 100%; border-collapse: collapse; }
            th { background-color: #f1f5f9; padding: 12px; text-align: left; font-size: 16px; border-bottom: 2px solid #cbd5e1; }
            td { padding: 15px 12px; border-bottom: 1px solid #e2e8f0; font-size: 16px; }
            .total-row td { font-size: 20px; font-weight: bold; background: #fffbeb; }
            .total-amount { color: #d97706; }
            .footer { text-align: center; color: #64748b; font-size: 14px; margin-top: 40px; }
          </style>
        </head>
        <body>
          <div class="header">
            <div><h1>หอพัก DormiNet</h1><p>ระบบบริหารจัดการหอพักและที่อยู่อาศัย</p></div>
            <div style="text-align: right;"><h2>ใบแจ้งหนี้ (INVOICE)</h2><p><strong>เลขที่:</strong> ${invoiceNo}</p><p><strong>วันที่ออกเอกสาร:</strong> ${printDate}</p></div>
          </div>
          <div class="content-box">
            <div>
              <p><strong>เรียน (ผู้เช่า):</strong> ${selectedBillingUser.prefix}${selectedBillingUser.first_name} ${selectedBillingUser.last_name}</p>
              <p><strong>หมายเลขห้องพัก:</strong> ${selectedBillingUser.room_number}</p>
            </div>
            <div style="text-align: right;">
              <p><strong>ค่าบริการประจำรอบเดือน:</strong> <br/>${cycleLabel}</p>
            </div>
          </div>
          <table>
            <thead><tr><th>ลำดับ</th><th>รายการ (Description)</th><th style="text-align: right;">จำนวนเงิน (บาท)</th></tr></thead>
            <tbody>
              <tr><td>1</td><td>ค่าเช่าห้องพัก</td><td style="text-align: right;">${Number(billData.rent || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr><td>2</td><td>ค่าเครื่องใช้ไฟฟ้า/บริการเสริม</td><td style="text-align: right;">${Number(billData.appliance_fee || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr><td>3</td><td>ค่าบริการน้ำประปา</td><td style="text-align: right;">${Number(billData.water || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr><td>4</td><td>ค่าบริการไฟฟ้า</td><td style="text-align: right;">${Number(billData.electric || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr><td>5</td><td>ค่าส่วนกลาง (Wi-Fi, ไฟทางเดิน)</td><td style="text-align: right;">${Number(billData.common || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr><td>6</td><td>ค่าปรับล่าช้า</td><td style="text-align: right;">${Number(billData.late || 0).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr class="total-row"><td colspan="2" style="text-align: right;">ยอดที่ต้องชำระรวมทั้งสิ้น</td><td style="text-align: right;" class="total-amount">${totalAmount.toLocaleString(undefined, {minimumFractionDigits: 2})} บาท</td></tr>
            </tbody>
          </table>
          <div class="footer">
            <p>กรุณาชำระเงินภายในวันที่กำหนด เพื่อหลีกเลี่ยงค่าปรับ</p>
            <p>เอกสารฉบับนี้ถูกสร้างโดยระบบอัตโนมัติ DormiNet Management System</p>
          </div>
        </body>
      </html>
    `);
    addLog('Print', `สร้างใบแจ้งหนี้ห้อง ${selectedBillingUser.room_number} รอบเดือน ${cycleLabel}`);
  };

  const checkPayment = (userId, monthId) => allPayments.find(p => p.user_id === userId && p.month === monthId);
  const currentMonthString = `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, '0')}`;

  const filteredOrderedUsers = orderedUsers.filter(user => 
    (user.room_number || '').toLowerCase().includes((searchTerm || '').toLowerCase()) ||
    (user.first_name || '').toLowerCase().includes((searchTerm || '').toLowerCase())
  );

  const pushInvoicesToLINE = async () => {
    setSysModal({
      isOpen: true,
      title: 'ส่งบิลแจ้งหนี้เข้า LINE',
      message: 'ยืนยันส่งบิลแจ้งหนี้เข้า LINE ของลูกบ้านทุกห้องที่มีสถานะ "รอชำระ" ใช่หรือไม่?',
      isAlert: false,
      isDanger: false,
      onConfirm: async () => {
        setSysModal(prev => ({ ...prev, isOpen: false }));
        try {
          const token = localStorage.getItem('dorminet_token');
          const res = await fetch(`${API_URL}/admin/push-invoices`, {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${token}` }
          });
          const data = await res.json();
          if (res.ok) {
            setSysModal({
              isOpen: true,
              title: 'สำเร็จ',
              message: `ส่งใบแจ้งหนี้สำเร็จทั้งหมด ${data.pushed_count} ห้อง`,
              isAlert: true,
              isDanger: false,
              onConfirm: () => setSysModal(prev => ({ ...prev, isOpen: false })),
              onCancel: () => setSysModal(prev => ({ ...prev, isOpen: false }))
            });
            addLog('Notification', `ส่งบิลแจ้งหนี้ผ่าน LINE จำนวน ${data.pushed_count} ห้อง`);
          } else {
            setSysModal({
              isOpen: true,
              title: 'ข้อผิดพลาด',
              message: 'เกิดข้อผิดพลาด: ' + data.error,
              isAlert: true,
              isDanger: true,
              onConfirm: () => setSysModal(prev => ({ ...prev, isOpen: false })),
              onCancel: () => setSysModal(prev => ({ ...prev, isOpen: false }))
            });
          }
        } catch (err) {
          console.error(err);
          setSysModal({
            isOpen: true,
            title: 'ข้อผิดพลาด',
            message: 'เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์',
            isAlert: true,
            isDanger: true,
            onConfirm: () => setSysModal(prev => ({ ...prev, isOpen: false })),
            onCancel: () => setSysModal(prev => ({ ...prev, isOpen: false }))
          });
        }
      },
      onCancel: () => setSysModal(prev => ({ ...prev, isOpen: false }))
    });
  };

  return (
    <>
      <div className="animate-fade-in">
        <div className="flex flex-col xl:flex-row justify-between items-start xl:items-center mb-6 gap-4">
          <div className="flex-1 max-w-sm">
          <div className="flex gap-2 w-full mb-4">
            <input type="text" placeholder="ค้นหาห้องหรือชื่อ..." value={searchTerm} onChange={e => setSearchTerm(e.target.value)} className="flex-1 bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2 rounded text-sm outline-none focus:ring-2 focus:ring-blue-500 transition-all" />
          </div>
          </div>
          
          <div className="grid grid-cols-2 lg:flex lg:flex-row gap-2 self-end xl:self-auto w-full md:w-auto mt-4 xl:mt-0">
            <div className="flex items-center gap-2 bg-white dark:bg-slate-800 border border-slate-300 rounded-lg px-3 py-2 w-full lg:w-[220px] h-[38px] justify-center shadow-sm">
              <span className="text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest whitespace-nowrap">รอบบิล:</span>
              <input 
                type="month" 
                value={reportMonth} 
                onChange={(e) => setReportMonth(e.target.value)} 
                className="bg-transparent text-sm outline-none font-mono text-slate-700 dark:text-slate-200 cursor-pointer w-full"
              />
            </div>
            <button onClick={pushInvoicesToLINE} className="w-full lg:w-[140px] h-[38px] shrink-0 bg-[#06C755] text-white rounded-lg text-[10px] font-bold tracking-widest hover:bg-[#05a546] transition-all shadow-md hover:shadow-lg hover:-translate-y-0.5 flex items-center justify-center">
              ส่งบิลไปที่ LINE
            </button>
            <button onClick={printMonthlyReport} className="w-full lg:w-[140px] h-[38px] shrink-0 bg-slate-900 text-white rounded-lg text-xs font-bold tracking-widest hover:bg-slate-800 transition-all shadow-md hover:shadow-lg hover:-translate-y-0.5 flex items-center justify-center">
              พิมพ์รายงาน
            </button>
            <button onClick={exportToCSV} className="w-full lg:w-[140px] h-[38px] shrink-0 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 border border-slate-300 rounded-lg text-xs font-bold tracking-widest hover:bg-slate-50 dark:bg-slate-700/50 transition-all shadow-sm hover:-translate-y-0.5 flex items-center justify-center">
              ดาวน์โหลด CSV
            </button>
          </div>
        </div>
        
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
          {isLoading ? (
            Array.from({ length: 10 }).map((_, i) => (
              <div key={`skeleton-${i}`} className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-lg p-5">
                <div className="flex justify-between items-start mb-3">
                  <div className="h-8 bg-slate-200 rounded w-16 animate-pulse"></div>
                  <div className="h-5 bg-slate-200 rounded w-16 animate-pulse"></div>
                </div>
                <div className="h-4 bg-slate-200 rounded w-32 mb-2 animate-pulse"></div>
                <div className="h-3 bg-slate-200 rounded w-24 mt-3 animate-pulse"></div>
              </div>
            ))
          ) : filteredOrderedUsers.length === 0 ? (
            <div className="col-span-full py-20 flex flex-col items-center justify-center text-slate-400 dark:text-slate-300">
              <svg className="w-12 h-12 text-slate-300 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
              </svg>
              <span className="font-bold text-sm">ไม่พบห้องพักที่กำลังพักอาศัย หรือไม่พบข้อมูลที่ค้นหา</span>
            </div>
          ) : (
            filteredOrderedUsers.map((user, index) => (
              <div 
                key={user.id} 
                draggable={!searchTerm}
                onDragStart={(e) => handleDragStart(e, index)}
                onDragEnter={(e) => handleDragEnter(e, index)}
                onDragEnd={handleDragEnd}
                onDragOver={(e) => e.preventDefault()}
                onClick={() => { setSelectedBillingUser(user); setIsHistoryModalOpen(true); }}
                className={`bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-lg p-5 relative transition-all cursor-pointer hover:border-slate-300 hover:shadow-sm ${draggedCard === index && !searchTerm ? 'opacity-50 border-dashed border-blue-400' : ''}`}
              >
                <div className="flex justify-between items-start mb-3">
                  <div className="font-mono text-2xl font-black text-slate-800 dark:text-slate-100">{user.room_number}</div>
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded border uppercase tracking-wider text-slate-500 dark:text-slate-400 dark:text-slate-300 bg-slate-50 dark:bg-slate-700/50 border-slate-200 dark:border-slate-700/50">ดูข้อมูล</span>
                </div>
                <div className="text-xs font-bold text-slate-700 dark:text-slate-200 mb-2">{user.prefix}{user.first_name} {user.last_name}</div>
                <div className="text-[10px] text-slate-500 dark:text-slate-400 dark:text-slate-300 border-t border-slate-100 dark:border-slate-700/50 pt-2 mt-1 uppercase font-mono tracking-wide">
                  ครบกำหนด: วันที่ {new Date(user.move_in_date).getDate()} / รายเดือน
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {isHistoryModalOpen && selectedBillingUser && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4 z-50 animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-lg shadow-xl w-full max-w-4xl overflow-hidden border border-slate-200 dark:border-slate-700/50 flex flex-col max-h-[90vh]">
            <div className="bg-slate-50 dark:bg-slate-700/50 px-6 py-4 border-b border-slate-200 dark:border-slate-700/50 flex justify-between items-center">
              <div><h3 className="text-sm font-bold text-slate-800 dark:text-slate-100 uppercase tracking-widest">ประวัติการชำระเงิน</h3><p className="text-[10px] text-slate-500 dark:text-slate-400 dark:text-slate-300 font-mono mt-0.5 uppercase">ห้อง {selectedBillingUser.room_number} | {selectedBillingUser.first_name}</p></div>
              <button onClick={() => setIsHistoryModalOpen(false)} className="text-slate-400 dark:text-slate-300 hover:text-slate-600 dark:text-slate-300 text-2xl transition-colors">&times;</button>
            </div>
            
            <div className="flex-1 overflow-y-auto p-8 space-y-4">
              {generateBillingCycles(selectedBillingUser.move_in_date, selectedBillingUser.contract_end_date, selectedBillingUser.indefinite_contract === 1).map((cycle, index) => {
                const payment = checkPayment(selectedBillingUser.id, cycle.monthId);
                const isFuture = cycle.monthId > currentMonthString;
                
                return (
                  <div key={cycle.monthId} className={`flex flex-col lg:flex-row items-start lg:items-center justify-between p-5 rounded-xl border transition-all hover:shadow-md gap-4 ${payment ? 'bg-white dark:bg-slate-800 border-emerald-200 shadow-sm' : isFuture ? 'bg-slate-50 dark:bg-slate-700/50 border-slate-200 dark:border-slate-700/50 opacity-60' : 'bg-white dark:bg-slate-800 border-red-200 shadow-sm'}`}>
                    <div className="flex items-center gap-6">
                      <div className={`w-10 h-10 rounded-full flex items-center justify-center font-black text-xs shadow-sm ${payment ? 'bg-emerald-100 text-emerald-600' : 'bg-slate-100 text-slate-400 dark:text-slate-300'}`}>{index + 1}</div>
                      <div className="w-32"><div className="text-[10px] font-bold text-slate-400 dark:text-slate-300 uppercase tracking-widest">รอบบิลเดือน</div><div className={`font-bold ${isFuture && !payment ? 'text-slate-500 dark:text-slate-400 dark:text-slate-300' : 'text-slate-800 dark:text-slate-100'}`}>{cycle.label}</div></div>
                      <div><div className="text-[10px] font-bold text-slate-400 dark:text-slate-300 uppercase tracking-widest">กำหนดชำระ</div><div className="font-mono font-bold text-slate-600 dark:text-slate-300">วันที่ {cycle.dueDate}</div></div>
                    </div>

                    <div className="flex flex-col lg:flex-row items-start lg:items-center gap-4 w-full lg:w-auto justify-end">
                      <div className="text-left lg:text-right w-full lg:w-auto border-t lg:border-t-0 border-slate-100 dark:border-slate-700/50 pt-3 lg:pt-0 mt-2 lg:mt-0 lg:mr-2">
                         <div className={`text-[10px] font-black uppercase tracking-widest ${payment ? (payment.payment_status === 'checking' ? 'text-amber-500' : (payment.payment_status === 'partial' ? 'text-blue-500' : (payment.payment_status === 'pending' ? 'text-red-500' : 'text-emerald-600'))) : isFuture ? 'text-slate-400 dark:text-slate-300' : 'text-red-500'}`}>
                            {payment ? (payment.payment_status === 'checking' ? 'รอตรวจสอบสลิป' : (payment.payment_status === 'partial' ? 'ชำระบางส่วน' : (payment.payment_status === 'pending' ? 'รอชำระเงิน' : 'ชำระแล้ว'))) : isFuture ? 'ยังไม่ถึงรอบบิล' : 'รอชำระเงิน'}
                         </div>
                         {payment && (
                           <>
                             <div className="text-sm font-bold text-slate-700 dark:text-slate-200">{payment.amount.toLocaleString()} ฿</div>
                             {payment.payment_status === 'partial' && (
                               <div className="text-[10px] font-bold text-blue-600 mt-0.5">จ่ายแล้ว: {(payment.paid_amount || 0).toLocaleString()} ฿</div>
                             )}
                             <div className="text-[9px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-0.5 bg-slate-100 px-2 py-0.5 rounded">{payment.method}</div>
                           </>
                         )}
                      </div>

                      {payment ? (
                        <div className="grid grid-cols-2 gap-2 justify-end w-full lg:w-auto">
                          <button onClick={() => {
                            setEditingPaymentId(payment.id);
                            setBillData({
                              rent: payment.rent_fee || 0,
                              water: payment.water_fee || 0,
                              electric: payment.electric_fee || 0,
                              common: payment.common_fee || 0,
                              late: payment.late_fee || 0,
                              appliance_fee: payment.appliance_fee || 0,
                              date: payment.payment_date || new Date().toISOString().split('T')[0],
                              method: payment.method || 'เงินโอน (Transfer)',
                              paid_amount: payment.paid_amount || '',
                              slips: []
                            });
                            setTargetMonth(cycle.monthId);
                            if (payment.water_meter_curr || payment.electric_meter_curr) {
                              setUseMeter(true);
                              setMeterCalc({ wPrev: payment.water_meter_prev || '', wCurr: payment.water_meter_curr || '', wRate: '20', ePrev: payment.electric_meter_prev || '', eCurr: payment.electric_meter_curr || '', eRate: '8' });
                            } else {
                              setUseMeter(false);
                            }
                            setIsPaymentFormOpen(true);
                          }} className="bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-slate-300 px-4 py-2 rounded-lg text-[10px] font-bold hover:bg-slate-50 dark:bg-slate-700/50 uppercase tracking-widest shadow-sm transition-all whitespace-nowrap">แก้ไข</button>
                          
                          <button onClick={() => printReceipt(payment, cycle.label)} className="bg-white dark:bg-slate-800 text-blue-600 border border-blue-200 px-4 py-2 rounded-lg text-[10px] font-bold hover:bg-blue-50 uppercase tracking-widest shadow-sm transition-all whitespace-nowrap">พิมพ์ใบเสร็จ</button>
                          
                          {payment.slip_path && (
                              <button onClick={() => {
                                if (payment.slip_path_array && payment.slip_path_array.length > 0) {
                                  setPreviewImages(payment.slip_path_array.map(p => uploadsUrl(p)));
                                  setCurrentImageIndex(0);
                                } else {
                                  setPreviewImages([uploadsUrl(payment.slip_path)]);
                                  setCurrentImageIndex(0);
                                }
                              }} className="bg-slate-900 text-white border border-slate-800 px-4 py-2 rounded-lg text-[10px] font-bold hover:bg-slate-700 uppercase tracking-widest shadow-sm transition-all whitespace-nowrap">ดูหลักฐาน</button>
                          )}
                          
                          {payment.slip_path && payment.payment_status === 'checking' && (
                            <>
                              <button onClick={() => {
                                setSysModal({
                                  isOpen: true,
                                  title: 'ยืนยันรับชำระเงิน',
                                  message: 'คุณต้องการยืนยันการรับชำระเงินบิลนี้ใช่หรือไม่? ระบบจะส่งใบเสร็จรับเงินให้ลูกบ้านทาง LINE อัตโนมัติ',
                                  isAlert: false,
                                  isDanger: false,
                                  onConfirm: async () => {
                                    setSysModal(prev => ({ ...prev, isOpen: false }));
                                    try {
                                      const token = localStorage.getItem('dorminet_token');
                                      const res = await fetch(`${API_URL}/payments`, {
                                        method: 'PATCH',
                                        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
                                        body: JSON.stringify({ payment_id: payment.id, amount: payment.amount, payment_status: 'paid' })
                                      });
                                      fetchData();
                                      setSysModal({
                                        isOpen: true,
                                        title: 'สำเร็จ',
                                        message: 'ยืนยันรับชำระเงินเรียบร้อยแล้ว',
                                        isAlert: true,
                                        isDanger: false,
                                        onConfirm: () => setSysModal(prev => ({ ...prev, isOpen: false })),
                                        onCancel: () => setSysModal(prev => ({ ...prev, isOpen: false }))
                                      });
                                    } catch (err) {
                                      console.error(err);
                                      setSysModal({
                                        isOpen: true,
                                        title: 'ข้อผิดพลาด',
                                        message: 'เกิดข้อผิดพลาดในการยืนยัน',
                                        isAlert: true,
                                        isDanger: true,
                                        onConfirm: () => setSysModal(prev => ({ ...prev, isOpen: false })),
                                        onCancel: () => setSysModal(prev => ({ ...prev, isOpen: false }))
                                      });
                                    }
                                  },
                                  onCancel: () => setSysModal(prev => ({ ...prev, isOpen: false }))
                                });
                              }} className="bg-emerald-600 text-white border border-emerald-700 px-4 py-2 rounded-lg text-[10px] font-bold hover:bg-emerald-700 uppercase tracking-widest shadow-sm transition-all whitespace-nowrap">ยืนยันรับชำระ</button>

                              <button onClick={() => {
                                setSysModal({
                                  isOpen: true,
                                  title: 'ปฏิเสธสลิปโอนเงิน',
                                  message: 'คุณต้องการปฏิเสธสลิปนี้และแจ้งให้ลูกบ้านส่งใหม่ใช่หรือไม่?',
                                  isAlert: false,
                                  isDanger: true,
                                  onConfirm: async () => {
                                    setSysModal(prev => ({ ...prev, isOpen: false }));
                                    try {
                                      const token = localStorage.getItem('dorminet_token');
                                      const res = await fetch(`${API_URL}/payments`, {
                                        method: 'PATCH',
                                        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
                                        body: JSON.stringify({ payment_id: payment.id, amount: payment.amount, payment_status: 'rejected' })
                                      });
                                      fetchData();
                                      setSysModal({
                                        isOpen: true,
                                        title: 'สำเร็จ',
                                        message: 'ปฏิเสธสลิปและแจ้งเตือนลูกบ้านแล้ว',
                                        isAlert: true,
                                        isDanger: false,
                                        onConfirm: () => setSysModal(prev => ({ ...prev, isOpen: false })),
                                        onCancel: () => setSysModal(prev => ({ ...prev, isOpen: false }))
                                      });
                                    } catch (err) {
                                      console.error(err);
                                    }
                                  },
                                  onCancel: () => setSysModal(prev => ({ ...prev, isOpen: false }))
                                });
                              }} className="bg-rose-500 text-white border border-rose-600 px-4 py-2 rounded-lg text-[10px] font-bold hover:bg-rose-600 uppercase tracking-widest shadow-sm transition-all whitespace-nowrap">ปฏิเสธสลิป</button>
                           </>
                          )}

                          <button onClick={() => {
                            setSysModal({
                              isOpen: true,
                              title: 'ยืนยันการลบบิล',
                              message: 'คุณต้องการลบบิลค่าเช่าของเดือนนี้ใช่หรือไม่? การกระทำนี้ไม่สามารถย้อนกลับได้ และถ้าหากลูกบ้านชำระแล้วจะต้องขอให้ชำระหรือออกบิลใหม่',
                              isAlert: false,
                              isDanger: true,
                              onConfirm: async () => {
                                setSysModal(prev => ({ ...prev, isOpen: false }));
                                try {
                                  const token = localStorage.getItem('dorminet_token');
                                  const res = await fetch(`${API_URL}/payments?payment_id=${payment.id}`, {
                                    method: 'DELETE',
                                    headers: { 'Authorization': `Bearer ${token}` }
                                  });
                                  if (!res.ok) throw new Error('Delete failed');
                                  fetchData();
                                  showToast('ลบบิลเรียบร้อยแล้ว', 'success');
                                } catch (err) {
                                  console.error(err);
                                  showToast('เกิดข้อผิดพลาดในการลบ', 'error');
                                }
                              },
                              onCancel: () => setSysModal(prev => ({ ...prev, isOpen: false }))
                            });
                          }} className="bg-white dark:bg-slate-800 text-red-500 border border-red-200 px-4 py-2 rounded-lg text-[10px] font-bold hover:bg-red-50 uppercase tracking-widest shadow-sm transition-all whitespace-nowrap">ลบบิล</button>
                        </div>
                      ) : (
                        <button onClick={() => { 
                          setTargetMonth(cycle.monthId); 
                          const userRoom = rooms.find(r => r.room_number === selectedBillingUser.room_number);
                          let basePrice = 0, defaultWater = '', defaultElectric = '', defaultCommon = '', defaultLate = '';
                          if (userRoom) {
                              const rType = roomTypes.find(rt => rt.name === userRoom.room_type);
                              if (rType) {
                                  basePrice = rType.price;
                                  defaultWater = rType.water_fee > 0 ? rType.water_fee : '';
                                  defaultElectric = rType.electric_fee > 0 ? rType.electric_fee : '';
                                  defaultCommon = rType.common_fee > 0 ? rType.common_fee : '';
                                  defaultLate = rType.late_fee > 0 ? rType.late_fee : '';
                              }
                          }
                          
                          // [เพิ่มใหม่] ค้นหาเลขมิเตอร์เดือนก่อนหน้าของห้องนี้
                          const roomHistory = allPayments.filter(p => p.room_number === selectedBillingUser.room_number);
                          const lastBill = roomHistory.length > 0 ? roomHistory.reduce((prev, current) => (prev.id > current.id) ? prev : current) : null;
                          const lastWater = lastBill && lastBill.water_meter_curr ? lastBill.water_meter_curr : '';
                          const lastElectric = lastBill && lastBill.electric_meter_curr ? lastBill.electric_meter_curr : '';
                          
                          setMeterCalc({ wPrev: lastWater, wCurr: '', wRate: '20', ePrev: lastElectric, eCurr: '', eRate: '8' });
                          
                          setBillData({ rent: basePrice, water: defaultWater, electric: defaultElectric, common: defaultCommon, late: defaultLate, appliance_fee: selectedBillingUser.additional_appliance_fee > 0 ? selectedBillingUser.additional_appliance_fee : '', date: new Date().toISOString().split('T')[0], method: 'เงินโอน (Transfer)', slips: [], paid_amount: '' });
                          setIsPaymentFormOpen(true); 
                        }} className={`px-6 py-2.5 rounded-lg text-[10px] font-bold uppercase tracking-widest transition-all shadow-md ${isFuture ? 'bg-slate-300 text-slate-600 dark:text-slate-300 hover:bg-slate-400' : 'bg-blue-600 text-white hover:bg-blue-700 hover:shadow-lg hover:-translate-y-0.5'}`}>ออกบิล / รับชำระ</button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {isPaymentFormOpen && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4 z-[60] animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-lg shadow-xl w-full max-w-lg overflow-hidden border border-slate-200 dark:border-slate-700/50 max-h-[95vh] flex flex-col">
            
            <div className="bg-slate-50 dark:bg-slate-700/50 px-6 py-4 border-b border-slate-200 dark:border-slate-700/50 flex justify-between items-center">
              <div>
                <h3 className="text-sm font-bold text-slate-800 dark:text-slate-100 uppercase tracking-widest">{editingPaymentId ? 'แก้ไขประวัติการชำระเงิน' : 'บันทึกการชำระเงิน'}</h3>
                <p className="text-[10px] text-slate-500 dark:text-slate-400 dark:text-slate-300 font-mono mt-0.5">ห้อง {selectedBillingUser.room_number} | รอบบิล {targetMonth}</p>
              </div>
              <button type="button" onClick={() => {
                setIsPaymentFormOpen(false);
                setEditingPaymentId(null);
                setBillData({ rent: '', water: '', electric: '', common: '', late: '', appliance_fee: '', date: new Date().toISOString().split('T')[0], method: 'เงินโอน (Transfer)', slips: [], paid_amount: '' });
              }} className="text-slate-400 dark:text-slate-300 hover:text-slate-600 dark:text-slate-300 font-bold text-xl">&times;</button>
            </div>

            <div className="overflow-y-auto p-6">
              <div className="space-y-5">
                
                <div className="bg-slate-50 dark:bg-slate-700/50 p-4 rounded-lg border border-slate-200 dark:border-slate-700/50">
                  <div className="flex items-center gap-2 mb-4">
                    <input type="checkbox" id="useMeterCheck" checked={useMeter} onChange={e => setUseMeter(e.target.checked)} className="w-4 h-4 text-blue-600 rounded focus:ring-blue-500 cursor-pointer" />
                    <label htmlFor="useMeterCheck" className="text-xs font-bold text-slate-700 dark:text-slate-200 cursor-pointer uppercase tracking-widest">โหมดคำนวณจากมิเตอร์น้ำ-ไฟ</label>
                  </div>
                  
                  {useMeter && (
                    <div className="grid grid-cols-3 gap-3 animate-fade-in">
                      <div className="col-span-3 border-b border-slate-200 dark:border-slate-700/50 pb-1 mb-1"><span className="text-[10px] font-bold text-blue-600 uppercase">ระบบน้ำประปา</span></div>
                      <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">เลขเดือนก่อน</label><input type="number" className="w-full border p-2 rounded text-xs font-mono outline-none" value={meterCalc.wPrev} onChange={e => setMeterCalc({...meterCalc, wPrev: e.target.value})} placeholder="0" /></div>
                      <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">เลขเดือนนี้</label><input type="number" className="w-full border p-2 rounded text-xs font-mono outline-none" value={meterCalc.wCurr} onChange={e => setMeterCalc({...meterCalc, wCurr: e.target.value})} placeholder="0" /></div>
                      <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">ราคา/หน่วย</label><input type="number" className="w-full border p-2 rounded text-xs font-mono outline-none bg-white dark:bg-slate-800" value={meterCalc.wRate} onChange={e => setMeterCalc({...meterCalc, wRate: e.target.value})} /></div>

                      <div className="col-span-3 border-b border-slate-200 dark:border-slate-700/50 pb-1 mb-1 mt-2"><span className="text-[10px] font-bold text-amber-500 uppercase">ระบบไฟฟ้า</span></div>
                      <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">เลขเดือนก่อน</label><input type="number" className="w-full border p-2 rounded text-xs font-mono outline-none" value={meterCalc.ePrev} onChange={e => setMeterCalc({...meterCalc, ePrev: e.target.value})} placeholder="0" /></div>
                      <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">เลขเดือนนี้</label><input type="number" className="w-full border p-2 rounded text-xs font-mono outline-none" value={meterCalc.eCurr} onChange={e => setMeterCalc({...meterCalc, eCurr: e.target.value})} placeholder="0" /></div>
                      <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">ราคา/หน่วย</label><input type="number" className="w-full border p-2 rounded text-xs font-mono outline-none bg-white dark:bg-slate-800" value={meterCalc.eRate} onChange={e => setMeterCalc({...meterCalc, eRate: e.target.value})} /></div>
                    </div>
                  )}
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">ค่าเช่า</label><input type="number" required className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2 rounded-md font-mono text-sm focus:ring-2 focus:ring-blue-500 outline-none transition-all" value={billData.rent} onChange={e => setBillData({...billData, rent: e.target.value})} placeholder="0" /></div>
                  <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">ค่าเครื่องใช้ไฟฟ้า {selectedBillingUser.additional_appliances ? `(${selectedBillingUser.additional_appliances})` : ''}</label><input type="number" className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2 rounded-md font-mono text-sm focus:ring-2 focus:ring-blue-500 outline-none transition-all" value={billData.appliance_fee} onChange={e => setBillData({...billData, appliance_fee: e.target.value})} placeholder="0" /></div>
                  <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">ค่าน้ำ</label><input type="number" className={`w-full border px-3 py-2 rounded-md font-mono text-sm outline-none transition-all ${useMeter ? 'bg-slate-100 border-slate-200 dark:border-slate-700/50 text-slate-500 dark:text-slate-400 dark:text-slate-300' : 'bg-white dark:bg-slate-800 border-slate-300 focus:ring-2 focus:ring-blue-500'}`} value={billData.water} onChange={e => setBillData({...billData, water: e.target.value})} placeholder="0" readOnly={useMeter} /></div>
                  <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">ค่าไฟ</label><input type="number" className={`w-full border px-3 py-2 rounded-md font-mono text-sm outline-none transition-all ${useMeter ? 'bg-slate-100 border-slate-200 dark:border-slate-700/50 text-slate-500 dark:text-slate-400 dark:text-slate-300' : 'bg-white dark:bg-slate-800 border-slate-300 focus:ring-2 focus:ring-blue-500'}`} value={billData.electric} onChange={e => setBillData({...billData, electric: e.target.value})} placeholder="0" readOnly={useMeter} /></div>
                  <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">ส่วนกลาง (Wi-Fi ฯลฯ)</label><input type="number" className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2 rounded-md font-mono text-sm focus:ring-2 focus:ring-blue-500 outline-none transition-all" value={billData.common} onChange={e => setBillData({...billData, common: e.target.value})} placeholder="0" /></div>
                  <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">ค่าปรับล่าช้า</label><input type="number" className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2 rounded-md font-mono text-sm focus:ring-2 focus:ring-red-500 text-red-600 outline-none transition-all" value={billData.late} onChange={e => setBillData({...billData, late: e.target.value})} placeholder="0" /></div>
                </div>

                <div className="bg-blue-50/50 p-4 rounded-lg border border-blue-100 flex justify-between items-center">
                  <span className="text-sm font-bold text-blue-800">ยอดชำระสุทธิ (รวม)</span>
                  <span className="text-3xl font-black text-blue-700 font-mono">
                    {((Number(billData.rent)||0) + (Number(billData.appliance_fee)||0) + (Number(billData.water)||0) + (Number(billData.electric)||0) + (Number(billData.common)||0) + (Number(billData.late)||0)).toLocaleString()} ฿
                  </span>
                </div>

                <div className="grid grid-cols-2 gap-4 pt-2">
                  <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">วันที่ทำรายการ</label><input type="date" className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2 rounded-md text-xs font-mono outline-none focus:border-blue-500" value={billData.date} onChange={e => setBillData({...billData, date: e.target.value})} /></div>
                  <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">ช่องทางชำระเงิน</label><select className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2 rounded-md text-xs font-bold outline-none focus:border-blue-500" value={billData.method} onChange={e => setBillData({...billData, method: e.target.value})}><option>เงินโอน (Transfer)</option><option>เงินสด (Cash)</option></select></div>
                  <div className="col-span-2"><label className="block text-[10px] font-bold text-blue-600 uppercase mb-1">ยอดเงินที่ชำระมาแล้ว (บาท) - ปล่อยว่างถ้าชำระเต็มจำนวน</label><input type="number" className="w-full bg-white dark:bg-slate-800 border border-blue-200 focus:border-blue-500 px-3 py-2 rounded-md font-mono text-sm outline-none transition-all" value={billData.paid_amount} onChange={e => setBillData({...billData, paid_amount: e.target.value})} placeholder="เว้นว่างไว้หากลูกบ้านชำระเต็มจำนวนแล้ว" /></div>
                </div>

                <div>
                  <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">แนบรูปสลิปหลักฐาน (ถ้ามี) {editingPaymentId ? '- จะถูกเพิ่มต่อท้ายของเดิม' : ''}</label>
                  <input type="file" accept="image/*" multiple className="text-xs text-slate-500 dark:text-slate-400 dark:text-slate-300 block w-full file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-[10px] file:font-bold file:bg-slate-100 file:text-slate-700 dark:text-slate-200 hover:file:bg-slate-200 transition-all border border-slate-200 dark:border-slate-700/50 p-1" onChange={e => {
                    const files = Array.from(e.target.files);
                    setBillData({...billData, slips: files});
                  }} />
                  {billData.slips && billData.slips.length > 0 && (
                    <div className="mt-2 flex gap-2 flex-wrap">
                      {billData.slips.map((file, idx) => (
                        <div key={idx} className="relative w-16 h-16 rounded overflow-hidden border border-slate-200 dark:border-slate-700/50">
                           <img src={URL.createObjectURL(file)} className="w-full h-full object-cover" />
                        </div>
                      ))}
                    </div>
                  )}
                </div>
                <div className="flex gap-2 pt-4 border-t border-slate-200 dark:border-slate-700/50">
                  <button type="button" disabled={isSubmitting} onClick={() => {setIsPaymentFormOpen(false); setUseMeter(false);}} className="bg-slate-100 text-slate-600 dark:text-slate-300 px-3 py-2.5 rounded text-[10px] font-bold uppercase tracking-widest hover:bg-slate-200 transition-colors disabled:opacity-50">ยกเลิก</button>
                  <button type="button" disabled={isSubmitting} onClick={() => printInvoice(targetMonth)} className="bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 border border-slate-300 px-3 py-2.5 rounded text-[10px] font-bold uppercase tracking-widest hover:bg-slate-50 dark:bg-slate-700/50 transition-colors whitespace-nowrap disabled:opacity-50">พิมพ์</button>
                  <button type="button" disabled={isSubmitting} onClick={(e) => handlePaymentSubmit(e, 'pending')} className="bg-amber-500 text-white px-3 py-2.5 rounded text-[10px] font-bold uppercase tracking-widest hover:bg-amber-600 transition-colors whitespace-nowrap disabled:opacity-50 shadow-sm">
                    {isSubmitting ? 'รอ...' : 'ออกบิล'}
                  </button>
                  <button type="button" disabled={isSubmitting} onClick={(e) => handlePaymentSubmit(e, 'paid')} className={`flex-1 text-white py-2.5 rounded text-[10px] font-bold uppercase tracking-widest transition-colors shadow-sm ${isSubmitting ? 'bg-slate-400 cursor-not-allowed' : 'bg-emerald-600 hover:bg-emerald-700'}`}>
                    {isSubmitting ? 'กำลังดำเนินการ...' : 'รับชำระแล้ว'}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {previewImages && previewImages.length > 0 && (
        <div className="fixed inset-0 bg-slate-950/95 flex items-center justify-center p-4 z-[80] animate-fade-in cursor-pointer" onClick={() => setPreviewImages(null)}>
          <div className="relative max-w-4xl w-full flex items-center justify-center" onClick={(e) => e.stopPropagation()}>
            <button onClick={() => setPreviewImages(null)} className="absolute -top-12 right-0 md:-right-8 text-white hover:text-red-500 text-4xl font-light transition-colors">&times;</button>
            
            {previewImages.length > 1 && (
              <button onClick={(e) => { e.stopPropagation(); setCurrentImageIndex(prev => prev === 0 ? previewImages.length - 1 : prev - 1); }} className="absolute -left-4 md:-left-12 text-white hover:text-blue-400 text-6xl p-4 transition-colors">&lsaquo;</button>
            )}
            
            <img src={previewImages[currentImageIndex]} alt="Payment Slip Preview" className="max-h-[85vh] object-contain rounded-xl shadow-2xl border border-slate-700" />
            
            {previewImages.length > 1 && (
              <button onClick={(e) => { e.stopPropagation(); setCurrentImageIndex(prev => prev === previewImages.length - 1 ? 0 : prev + 1); }} className="absolute -right-4 md:-right-12 text-white hover:text-blue-400 text-6xl p-4 transition-colors">&rsaquo;</button>
            )}
            
            {previewImages.length > 1 && (
              <div className="absolute -bottom-12 left-0 right-0 text-center text-white text-sm font-mono tracking-widest bg-slate-900/50 py-1 rounded-full w-24 mx-auto backdrop-blur-sm border border-slate-700">
                {currentImageIndex + 1} / {previewImages.length}
              </div>
            )}
          </div>
        </div>
      )}
      
      <ConfirmModal
        isOpen={sysModal.isOpen}
        title={sysModal.title}
        message={sysModal.message}
        isAlert={sysModal.isAlert}
        isDanger={sysModal.isDanger}
        onConfirm={sysModal.onConfirm}
        onCancel={sysModal.onCancel}
        confirmText="ตกลง"
        cancelText="ยกเลิก"
      />
    </>
  );
}