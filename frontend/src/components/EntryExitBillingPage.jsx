import { useState, useEffect } from 'react';
import { API_URL } from '../config';
import ConfirmModal from './ConfirmModal';
export default function EntryExitBillingPage({ addLog, showToast }) {
  const [users, setUsers] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [roomTypes, setRoomTypes] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  const [selectedUser, setSelectedUser] = useState(null);
  const [modalMode, setModalMode] = useState(null); 
  const [confirmConfig, setConfirmConfig] = useState({ isOpen: false, id: null, name: '' });

  useEffect(() => {
    const handleEsc = (e) => {
      if (e.key === 'Escape') {
        setModalMode(null);
        setConfirmConfig(prev => ({ ...prev, isOpen: false }));
      }
    };
    window.addEventListener('keydown', handleEsc, { capture: true });
    return () => window.removeEventListener('keydown', handleEsc, { capture: true });
  }, []);

  const [orderedUsers, setOrderedUsers] = useState([]);
  const [draggedUserIndex, setDraggedUserIndex] = useState(null);

  const [moveInData, setMoveInData] = useState({ advanceRent: 0, deposit: 0, keycard: 0, other: 0, note: '' });
  const [moveOutData, setMoveOutData] = useState({ originalDeposit: 0, damage: 0, cleaning: 0, unpaidBills: 0, note: '' });

  const fetchData = () => {
    return Promise.all([
      fetch(`${API_URL}/users`).then(res => res.json()).then(data => {
        const fetchedUsers = data || [];
        setUsers(fetchedUsers);
        
        const savedOrder = localStorage.getItem('dorminet_entryexit_order');
        if (savedOrder && fetchedUsers.length > 0) {
          const idOrder = JSON.parse(savedOrder);
          fetchedUsers.sort((a, b) => {
            let indexA = idOrder.indexOf(a.id);
            let indexB = idOrder.indexOf(b.id);
            if (indexA === -1) indexA = 999;
            if (indexB === -1) indexB = 999;
            return indexA - indexB;
          });
        }
        setOrderedUsers(fetchedUsers);
      }),
      fetch(`${API_URL}/rooms`).then(res => res.json()).then(data => setRooms(data || [])),
      fetch(`${API_URL}/room-types`).then(res => res.json()).then(data => setRoomTypes(data || []))
    ]);
  };

  useEffect(() => { 
    setIsLoading(true);
    fetchData().finally(() => setTimeout(() => setIsLoading(false), 800));
  }, []);

  // [เพิ่มใหม่] ตรวจสอบ URL Parameters เพื่อเปิด Popup อัตโนมัติ (เช่น มาจากการกดเพิ่มลูกบ้าน)
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const action = params.get('action');
    const userId = params.get('user_id');

    if (!isLoading && action && userId && users.length > 0) {
      const targetUser = users.find(u => u.id.toString() === userId);
      if (targetUser) {
        // ใช้ setTimeout เพื่อให้แน่ใจว่าโหลด UI เสร็จก่อน
        setTimeout(() => {
          if (action === 'move_in') openMoveIn(targetUser);
          if (action === 'move_out') openMoveOut(targetUser);
        }, 300);
      }
      // ล้าง URL ออกเพื่อไม่ให้เปิดซ้ำตอนกด Refresh
      window.history.replaceState({}, document.title, window.location.pathname);
    }
  }, [users, isLoading]);

  const handleDragStart = (e, index) => {
    if (searchTerm) {
      e.preventDefault();
      return;
    }
    setDraggedUserIndex(index);
    e.dataTransfer.effectAllowed = "move";
  };
  
  const handleDragEnter = (e, index) => {
    if (searchTerm || draggedUserIndex === null || draggedUserIndex === index) return;
    const newOrder = [...orderedUsers];
    const draggedItem = newOrder[draggedUserIndex];
    newOrder.splice(draggedUserIndex, 1);
    newOrder.splice(index, 0, draggedItem);
    setDraggedUserIndex(index);
    setOrderedUsers(newOrder);
  };
  
  const handleDragEnd = () => {
    setDraggedUserIndex(null);
    localStorage.setItem('dorminet_entryexit_order', JSON.stringify(orderedUsers.map(u => u.id)));
  };

  const executeDeleteUser = () => {
    const { id, name } = confirmConfig;
    setConfirmConfig({ ...confirmConfig, isOpen: false });
    fetch(`${API_URL}/users?id=${id}`, { method: 'DELETE' }).then(async (res) => {
      if (!res.ok) {
        showToast('ลบไม่สำเร็จ', 'error');
        return;
      }
      addLog('Delete', `ลบประวัติลูกบ้านที่ย้ายออก: ${name}`);
      fetchData();
      showToast('ลบประวัติลูกบ้านสำเร็จ', 'success');
    });
  };

  const handleDeleteUser = (id, name) => {
    setConfirmConfig({ isOpen: true, id, name });
  };

  const openMoveIn = (user) => {
    setSelectedUser(user);
    let basePrice = 0;
    const userRoom = rooms.find(r => r.room_number === user.room_number);
    if (userRoom) {
      const rType = roomTypes.find(rt => rt.name === userRoom.room_type);
      if (rType) basePrice = rType.price;
    }
    
    setMoveInData({
      advanceRent: basePrice, 
      deposit: user.deposit || 0, 
      keycard: 100, 
      other: 0,
      note: 'ค่าแรกเข้าและเงินประกันความเสียหาย'
    });
    setModalMode('move_in');
  };

  const openMoveOut = (user) => {
    setSelectedUser(user);
    setMoveOutData({
      originalDeposit: user.deposit || 0,
      damage: 0,
      cleaning: 500, 
      unpaidBills: 0,
      note: 'คืนเงินประกันหลังจากหักค่าใช้จ่ายแล้ว'
    });
    setModalMode('move_out');
  };

  // [อัปเดต] ดีไซน์ใบเสร็จแรกเข้าแบบใหม่
  const printMoveInBill = (e) => {
    e.preventDefault();
    const total = Number(moveInData.advanceRent) + Number(moveInData.deposit) + Number(moveInData.keycard) + Number(moveInData.other);
    const dateStr = new Date().toLocaleString('th-TH', { dateStyle: 'long', timeStyle: 'short' });
    const billNo = `MI-${new Date().toISOString().slice(0,10).replace(/-/g, '')}-${selectedUser.room_number}`;

    const printWin = window.open('', '_blank', 'width=900,height=800');
    printWin.document.write(`
      <html>
        <head>
          <title>ใบเสร็จแรกเข้า - ${selectedUser.room_number}</title>
          <link href="https://fonts.googleapis.com/css2?family=Sarabun:wght@300;400;500;700&display=swap" rel="stylesheet">
          <style>
            body { font-family: 'Sarabun', sans-serif; padding: 40px; color: #1e293b; max-width: 800px; margin: 0 auto; }
            .header-container { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #cbd5e1; padding-bottom: 20px; margin-bottom: 30px; }
            .header-left h1 { margin: 0; font-size: 36px; color: #0f172a; font-weight: 700; letter-spacing: 1px; }
            .header-left p { margin: 5px 0 0 0; font-size: 16px; color: #64748b; }
            .header-right { text-align: right; }
            .header-right h2 { margin: 0; font-size: 24px; color: #3b82f6; }
            .header-right p { margin: 5px 0 0 0; font-size: 14px; }
            .info-grid { display: flex; justify-content: space-between; margin-bottom: 30px; background: #f8fafc; padding: 20px; border-radius: 8px; border: 1px solid #e2e8f0; }
            .info-col p { margin: 8px 0; font-size: 16px; }
            table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
            th { background-color: #f1f5f9; padding: 12px; text-align: left; font-size: 16px; border-bottom: 2px solid #94a3b8; }
            td { padding: 15px 12px; border-bottom: 1px solid #e2e8f0; font-size: 16px; }
            .text-right { text-align: right; }
            .text-center { text-align: center; }
            .total-row td { font-weight: bold; font-size: 18px; background: #eff6ff; border-bottom: 2px solid #94a3b8; }
            .total-amount { color: #2563eb; font-size: 22px; }
            .signature-section { display: flex; justify-content: space-around; margin-top: 60px; text-align: center; }
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
              <h2>ใบเสร็จรับเงิน (ค่าแรกเข้า)</h2>
              <p><strong>เลขที่เอกสาร:</strong> ${billNo}</p>
              <p><strong>วันที่ออกเอกสาร:</strong> ${dateStr}</p>
            </div>
          </div>
          <div class="info-grid">
            <div class="info-col">
              <p><strong>ได้รับเงินจาก:</strong> ${selectedUser.prefix}${selectedUser.first_name} ${selectedUser.last_name}</p>
              <p><strong>หมายเลขห้องพัก:</strong> ${selectedUser.room_number}</p>
            </div>
            <div class="info-col text-right">
              <p><strong>หมายเหตุ:</strong> ${moveInData.note || '-'}</p>
            </div>
          </div>
          <table>
            <thead><tr><th class="text-center" width="10%">ลำดับ</th><th width="60%">รายการ</th><th class="text-right" width="30%">จำนวนเงิน (บาท)</th></tr></thead>
            <tbody>
              <tr><td class="text-center">1</td><td>ค่าเช่าล่วงหน้า (Advance Rent)</td><td class="text-right">${Number(moveInData.advanceRent).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr><td class="text-center">2</td><td>เงินประกันความเสียหาย (Security Deposit)</td><td class="text-right">${Number(moveInData.deposit).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr><td class="text-center">3</td><td>ค่าคีย์การ์ด / กุญแจ (Keycard)</td><td class="text-right">${Number(moveInData.keycard).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr><td class="text-center">4</td><td>ค่าใช้จ่ายอื่นๆ (Others)</td><td class="text-right">${Number(moveInData.other).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr class="total-row"><td colspan="2" class="text-right">รวมรับชำระทั้งสิ้น (Grand Total)</td><td class="text-right total-amount">${total.toLocaleString(undefined, {minimumFractionDigits: 2})} บาท</td></tr>
            </tbody>
          </table>
          <div class="signature-section">
            <div class="sig-box"><div class="sig-line"></div><p>ผู้ชำระเงิน (ผู้เช่า)</p></div>
            <div class="sig-box"><div class="sig-line"></div><p>ผู้รับเงิน (ผู้จัดการหอพัก DormiNet)</p></div>
          </div>
          <div class="footer">
            <p>ขอขอบคุณที่ไว้วางใจเลือกใช้บริการหอพัก DormiNet</p>
            <p>เอกสารฉบับนี้ถูกสร้างโดยระบบอัตโนมัติ DormiNet Management System</p>
          </div>
          <script>window.onload = function() { setTimeout(function() { window.print(); }, 500); }</script>
        </body>
      </html>
    `);
    printWin.document.close();
    
    // [เพิ่มใหม่] บันทึกบิลแรกเข้าในฐานข้อมูล
    const formData = new FormData();
    formData.append('user_id', selectedUser.id);
    formData.append('room_number', selectedUser.room_number);
    formData.append('amount', total);
    formData.append('month', new Date().toISOString().slice(0, 7)); // yyyy-mm
    formData.append('date', new Date().toISOString().split('T')[0]); // yyyy-mm-dd
    formData.append('payment_plan', 'move_in');
    formData.append('payment_status', 'paid');
    formData.append('method', 'เงินโอน (Transfer)'); // ค่าปริยาย

    fetch(`${API_URL}/payments`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${localStorage.getItem('dorminet_token')}` },
      body: formData
    }).catch(err => console.error('Failed to record move in payment:', err));

    addLog('Print', `พิมพ์ใบเสร็จแรกเข้า ห้อง ${selectedUser.room_number} จำนวน ${total} บาท`);
    showToast('สร้างใบเสร็จแรกเข้าเรียบร้อย', 'success');
    setModalMode(null);
  };

  // [อัปเดต] ดีไซน์ใบเสร็จย้ายออกแบบใหม่
  const printMoveOutBill = (e) => {
    e.preventDefault();
    const deductions = Number(moveOutData.damage) + Number(moveOutData.cleaning) + Number(moveOutData.unpaidBills);
    const netRefund = Number(moveOutData.originalDeposit) - deductions;
    const dateStr = new Date().toLocaleString('th-TH', { dateStyle: 'long', timeStyle: 'short' });
    const billNo = `MO-${new Date().toISOString().slice(0,10).replace(/-/g, '')}-${selectedUser.room_number}`;

    const printWin = window.open('', '_blank', 'width=900,height=800');
    printWin.document.write(`
      <html>
        <head>
          <title>ใบคืนเงินประกัน - ${selectedUser.room_number}</title>
          <link href="https://fonts.googleapis.com/css2?family=Sarabun:wght@300;400;500;700&display=swap" rel="stylesheet">
          <style>
            body { font-family: 'Sarabun', sans-serif; padding: 40px; color: #1e293b; max-width: 800px; margin: 0 auto; }
            .header-container { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #cbd5e1; padding-bottom: 20px; margin-bottom: 30px; }
            .header-left h1 { margin: 0; font-size: 36px; color: #0f172a; font-weight: 700; letter-spacing: 1px; }
            .header-left p { margin: 5px 0 0 0; font-size: 16px; color: #64748b; }
            .header-right { text-align: right; }
            .header-right h2 { margin: 0; font-size: 24px; color: #ea580c; }
            .header-right p { margin: 5px 0 0 0; font-size: 14px; }
            .info-grid { display: flex; justify-content: space-between; margin-bottom: 30px; background: #fffbeb; padding: 20px; border-radius: 8px; border: 1px solid #fde68a; }
            .info-col p { margin: 8px 0; font-size: 16px; }
            table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
            th { background-color: #f1f5f9; padding: 12px; text-align: left; font-size: 16px; border-bottom: 2px solid #94a3b8; }
            td { padding: 15px 12px; border-bottom: 1px solid #e2e8f0; font-size: 16px; }
            .text-right { text-align: right; }
            .text-center { text-align: center; }
            .deduct-row td { color: #dc2626; }
            .total-row td { font-weight: bold; font-size: 18px; background: #f0fdf4; border-top: 2px solid #86efac; border-bottom: 2px solid #86efac; }
            .total-amount { color: #16a34a; font-size: 22px; }
            .signature-section { display: flex; justify-content: space-around; margin-top: 60px; text-align: center; }
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
              <h2>เอกสารสรุปคืนเงินประกัน (ย้ายออก)</h2>
              <p><strong>เลขที่เอกสาร:</strong> ${billNo}</p>
              <p><strong>วันที่ออกเอกสาร:</strong> ${dateStr}</p>
            </div>
          </div>
          <div class="info-grid">
            <div class="info-col">
              <p><strong>คืนเงินให้แก่:</strong> ${selectedUser.prefix}${selectedUser.first_name} ${selectedUser.last_name}</p>
              <p><strong>หมายเลขห้องพัก:</strong> ${selectedUser.room_number}</p>
            </div>
            <div class="info-col text-right">
              <p><strong>หมายเหตุ:</strong> ${moveOutData.note || '-'}</p>
            </div>
          </div>
          <table>
            <thead><tr><th class="text-center" width="10%">ลำดับ</th><th width="60%">รายการ</th><th class="text-right" width="30%">จำนวนเงิน (บาท)</th></tr></thead>
            <tbody>
              <tr><td class="text-center">1</td><td>เงินประกันตั้งต้น (Original Deposit)</td><td class="text-right">${Number(moveOutData.originalDeposit).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr class="deduct-row"><td class="text-center">2</td><td>หัก: ค่าความเสียหาย (Damage Deduction)</td><td class="text-right">- ${Number(moveOutData.damage).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr class="deduct-row"><td class="text-center">3</td><td>หัก: ค่าทำความสะอาด (Cleaning Fee)</td><td class="text-right">- ${Number(moveOutData.cleaning).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr class="deduct-row"><td class="text-center">4</td><td>หัก: ค่าน้ำ/ค่าไฟ/ยอดค้างชำระ (Unpaid Bills)</td><td class="text-right">- ${Number(moveOutData.unpaidBills).toLocaleString(undefined, {minimumFractionDigits: 2})}</td></tr>
              <tr class="total-row">
                <td colspan="2" class="text-right">ยอดเงินคืนสุทธิ (Net Refund)</td>
                <td class="text-right total-amount">${netRefund > 0 ? netRefund.toLocaleString(undefined, {minimumFractionDigits: 2}) : '0.00'} บาท</td>
              </tr>
            </tbody>
          </table>
          <div class="signature-section">
            <div class="sig-box"><div class="sig-line"></div><p>ผู้รับเงินคืน (ผู้เช่าย้ายออก)</p></div>
            <div class="sig-box"><div class="sig-line"></div><p>ผู้จ่ายเงิน (ผู้จัดการหอพัก DormiNet)</p></div>
          </div>
          <div class="footer">
            <p>ขอขอบคุณที่เคยเป็นส่วนหนึ่งของครอบครัวหอพัก DormiNet ขอให้โชคดีค่ะ</p>
            <p>เอกสารฉบับนี้ถูกสร้างโดยระบบอัตโนมัติ DormiNet Management System</p>
          </div>
          <script>window.onload = function() { setTimeout(function() { window.print(); }, 500); }</script>
        </body>
      </html>
    `);
    printWin.document.close();
    addLog('Print', `พิมพ์ใบคืนเงินย้ายออก ห้อง ${selectedUser.room_number} สุทธิ ${netRefund > 0 ? netRefund : 0} บาท`);
    showToast('สร้างใบคืนเงินย้ายออกเรียบร้อย', 'success');
    setModalMode(null);
  };

  const filteredUsers = orderedUsers.filter(user => 
    (user.room_number || '').toLowerCase().includes((searchTerm || '').toLowerCase()) ||
    (user.first_name || '').toLowerCase().includes((searchTerm || '').toLowerCase())
  );

  return (
    <>
      <div className="animate-fade-in space-y-6">
      <div className="flex flex-col xl:flex-row justify-between items-center gap-4 border-b border-slate-200 dark:border-slate-700/50 pb-4">
        <div>
          <h2 className="text-xl font-bold text-slate-800 dark:text-slate-100 uppercase tracking-wide">จัดการบิลแรกเข้า & ย้ายออก</h2>
          <p className="text-[10px] text-slate-400 dark:text-slate-300 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300 font-bold uppercase tracking-widest mt-1">Entry & Exit Billing System</p>
        </div>
        <input type="text" placeholder="ค้นหาเลขห้อง หรือชื่อผู้เช่า..." value={searchTerm} onChange={e => setSearchTerm(e.target.value)} className="w-full md:w-80 bg-white dark:bg-slate-800 border border-slate-300 p-2.5 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 shadow-sm" />
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
              <div className="flex gap-2 mt-3 pt-2 border-t border-slate-100 dark:border-slate-700/50">
                <div className="h-8 bg-slate-200 rounded flex-1 animate-pulse"></div>
                <div className="h-8 bg-slate-200 rounded flex-1 animate-pulse"></div>
              </div>
            </div>
          ))
        ) : filteredUsers.length === 0 ? (
          <div className="col-span-full py-20 flex flex-col items-center justify-center text-slate-400 dark:text-slate-300 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300">
            <svg className="w-12 h-12 text-slate-300 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
            </svg>
            <span className="font-bold text-sm">ไม่พบข้อมูลบิลแรกเข้าและย้ายออก หรือไม่พบข้อมูลที่ค้นหา</span>
          </div>
        ) : (
          filteredUsers.map((user, index) => {
            const isMovedOut = user.status === 'ย้ายออกแล้ว';
            return (
                <div 
                  key={user.id} 
                  draggable={!searchTerm}
                  onDragStart={(e) => handleDragStart(e, index)}
                  onDragEnter={(e) => handleDragEnter(e, index)}
                  onDragEnd={handleDragEnd}
                  onDragOver={(e) => e.preventDefault()}
                  className={`bg-white dark:bg-slate-800 border rounded-lg p-5 relative transition-all cursor-pointer hover:shadow-sm ${isMovedOut ? 'border-orange-200' : 'border-slate-200 dark:border-slate-700/50 hover:border-slate-300'} ${draggedUserIndex === index && !searchTerm ? 'opacity-50 border-dashed border-blue-400' : ''}`}
                >
                    <div className="flex justify-between items-start mb-3">
                        <div className="font-mono text-2xl font-black text-slate-800 dark:text-slate-100">{user.room_number}</div>
                        <div className="flex items-center gap-2">
                          <span className={`text-[10px] font-bold px-2 py-0.5 rounded border tracking-widest uppercase ${isMovedOut ? 'bg-orange-50 text-orange-600 border-orange-200' : 'bg-emerald-50 text-emerald-600 border-emerald-200'}`}>{user.status}</span>
                          {isMovedOut && (
                            <button onClick={(e) => { e.stopPropagation(); handleDeleteUser(user.id, user.first_name); }} className="text-white bg-red-500 hover:bg-red-600 rounded px-2 py-1 text-[10px] font-bold shadow-sm transition-all flex items-center gap-1" title="ลบข้อมูลลูกบ้านที่ย้ายออกแล้ว">
                              <svg className="w-3 h-3" fill="none" stroke="currentColor" strokeWidth="3" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
                              ลบ
                            </button>
                          )}
                        </div>
                    </div>
                    <div className="text-xs font-bold text-slate-700 dark:text-slate-200 mb-2">{user.prefix}{user.first_name} {user.last_name}</div>
                    
                    <div className="flex gap-2 border-t border-slate-100 dark:border-slate-700/50 pt-2 mt-1">
                        {!isMovedOut && (
                          <button onClick={() => openMoveIn(user)} className="flex-1 bg-blue-50 text-blue-600 hover:bg-blue-100 border border-blue-100 px-3 py-2 rounded-lg text-[10px] font-bold uppercase tracking-widest transition-colors">
                              {user.status === 'กำลังพักอาศัย' ? 'พิมพ์บิลแรกเข้าซ้ำ' : 'ออกบิลแรกเข้า'}
                          </button>
                        )}
                        {user.status !== 'จอง' && (
                          <button onClick={() => openMoveOut(user)} className="flex-1 bg-amber-50 text-amber-600 hover:bg-amber-100 border border-amber-100 px-3 py-2 rounded-lg text-[10px] font-bold uppercase tracking-widest transition-colors">
                              {isMovedOut ? 'พิมพ์บิลย้ายออกซ้ำ' : 'ออกบิลย้ายออก'}
                          </button>
                        )}
                    </div>
                </div>
            );
          })
        )}
      </div>
    </div>

      {/* Modal บิลแรกเข้า */}
      {modalMode === 'move_in' && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4 z-50 animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-lg overflow-hidden border border-slate-200 dark:border-slate-700/50">
            <div className="bg-blue-50 px-6 py-4 border-b border-blue-100 flex justify-between items-center">
              <h3 className="font-bold text-blue-800 uppercase">ออกบิลแรกเข้า (Move-In)</h3>
              <button onClick={() => setModalMode(null)} className="text-blue-400 hover:text-blue-700 font-bold text-xl">&times;</button>
            </div>
            <form onSubmit={printMoveInBill} className="p-6 space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">ค่าเช่าล่วงหน้า (บาท)</label><input type="number" required className="w-full bg-white dark:bg-slate-800 border border-slate-300 p-2 text-sm rounded-md outline-none focus:ring-2 focus:ring-blue-500" value={moveInData.advanceRent} onChange={e => setMoveInData({...moveInData, advanceRent: e.target.value})} /></div>
                <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">เงินประกัน (บาท)</label><input type="number" required className="w-full bg-white dark:bg-slate-800 border border-slate-300 p-2 text-sm rounded-md outline-none focus:ring-2 focus:ring-blue-500" value={moveInData.deposit} onChange={e => setMoveInData({...moveInData, deposit: e.target.value})} /></div>
                <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">ค่าคีย์การ์ด/กุญแจ</label><input type="number" className="w-full bg-white dark:bg-slate-800 border border-slate-300 p-2 text-sm rounded-md outline-none focus:ring-2 focus:ring-blue-500" value={moveInData.keycard} onChange={e => setMoveInData({...moveInData, keycard: e.target.value})} /></div>
                <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">ค่าอื่นๆ</label><input type="number" className="w-full bg-white dark:bg-slate-800 border border-slate-300 p-2 text-sm rounded-md outline-none focus:ring-2 focus:ring-blue-500" value={moveInData.other} onChange={e => setMoveInData({...moveInData, other: e.target.value})} /></div>
              </div>
              <div className="bg-blue-50 p-4 rounded-lg flex justify-between items-center mt-2">
                <span className="text-xs font-bold text-blue-800">ยอดชำระทั้งหมด:</span>
                <span className="text-2xl font-black text-blue-600 font-mono">{(Number(moveInData.advanceRent) + Number(moveInData.deposit) + Number(moveInData.keycard) + Number(moveInData.other)).toLocaleString()} ฿</span>
              </div>
              <div className="flex gap-3 pt-4">
                <button type="button" onClick={() => setModalMode(null)} className="flex-1 bg-slate-100 text-slate-600 dark:text-slate-300 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300 py-3 rounded-lg text-xs font-bold uppercase hover:bg-slate-200">ยกเลิก</button>
                <button type="submit" className="flex-1 bg-blue-600 text-white py-3 rounded-lg text-xs font-bold uppercase tracking-widest hover:bg-blue-700 shadow-md">พิมพ์ใบเสร็จ</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal บิลย้ายออก */}
      {modalMode === 'move_out' && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4 z-50 animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-lg overflow-hidden border border-slate-200 dark:border-slate-700/50">
            <div className="bg-amber-50 px-6 py-4 border-b border-amber-100 flex justify-between items-center">
              <h3 className="font-bold text-amber-800 uppercase">ออกบิลย้ายออก / คืนเงิน (Move-Out)</h3>
              <button onClick={() => setModalMode(null)} className="text-amber-400 hover:text-amber-700 font-bold text-xl">&times;</button>
            </div>
            <form onSubmit={printMoveOutBill} className="p-6 space-y-4">
              <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">เงินประกันตั้งต้น (บาท)</label><input type="number" required className="w-full bg-slate-100 border border-slate-300 p-2 text-sm rounded-md outline-none text-slate-500 dark:text-slate-400 dark:text-slate-300 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300" value={moveOutData.originalDeposit} readOnly /></div>
              <div className="grid grid-cols-2 gap-4">
                <div><label className="block text-[10px] font-bold text-red-500 uppercase mb-1">หัก: ค่าเสียหาย</label><input type="number" className="w-full bg-white dark:bg-slate-800 border border-red-200 p-2 text-sm rounded-md outline-none focus:ring-2 focus:ring-red-500 text-red-600" value={moveOutData.damage} onChange={e => setMoveOutData({...moveOutData, damage: e.target.value})} /></div>
                <div><label className="block text-[10px] font-bold text-red-500 uppercase mb-1">หัก: ค่าทำความสะอาด</label><input type="number" className="w-full bg-white dark:bg-slate-800 border border-red-200 p-2 text-sm rounded-md outline-none focus:ring-2 focus:ring-red-500 text-red-600" value={moveOutData.cleaning} onChange={e => setMoveOutData({...moveOutData, cleaning: e.target.value})} /></div>
                <div className="col-span-2"><label className="block text-[10px] font-bold text-red-500 uppercase mb-1">หัก: ยอดค้างชำระอื่นๆ (น้ำ/ไฟ)</label><input type="number" className="w-full bg-white dark:bg-slate-800 border border-red-200 p-2 text-sm rounded-md outline-none focus:ring-2 focus:ring-red-500 text-red-600" value={moveOutData.unpaidBills} onChange={e => setMoveOutData({...moveOutData, unpaidBills: e.target.value})} /></div>
              </div>
              <div className="bg-amber-50 p-4 rounded-lg flex justify-between items-center mt-2 border border-amber-100">
                <span className="text-xs font-bold text-amber-800">ยอดเงินคืนสุทธิ:</span>
                <span className="text-2xl font-black text-amber-600 font-mono">{(Number(moveOutData.originalDeposit) - Number(moveOutData.damage) - Number(moveOutData.cleaning) - Number(moveOutData.unpaidBills)).toLocaleString()} ฿</span>
              </div>
              <div className="flex gap-3 pt-4">
                <button type="button" onClick={() => setModalMode(null)} className="flex-1 bg-slate-100 text-slate-600 dark:text-slate-300 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300 py-3 rounded-lg text-xs font-bold uppercase hover:bg-slate-200">ยกเลิก</button>
                <button type="submit" className="flex-1 bg-amber-500 text-white py-3 rounded-lg text-xs font-bold uppercase tracking-widest hover:bg-amber-600 shadow-md">พิมพ์ใบคืนเงิน</button>
              </div>
            </form>
          </div>
        </div>
      )}

      <ConfirmModal
        isOpen={confirmConfig.isOpen}
        title="ยืนยันการลบประวัติลูกบ้าน"
        message={
          <div className="space-y-2">
            <p>คุณยืนยันที่จะลบประวัติของลูกบ้าน <span className="font-bold text-slate-800 dark:text-slate-100">"{confirmConfig.name}"</span> (ย้ายออกแล้ว) ใช่หรือไม่?</p>
            <p className="text-red-600 font-medium">การกระทำนี้จะลบข้อมูลที่เกี่ยวข้องออกทั้งหมด</p>
          </div>
        }
        confirmText="ยืนยันการลบ"
        onConfirm={executeDeleteUser}
        onCancel={() => setConfirmConfig({ ...confirmConfig, isOpen: false })}
        isDanger={true}
      />
    </>
  );
}