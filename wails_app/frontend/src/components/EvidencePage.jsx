import { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { API_URL, uploadsUrl } from '../config';
import ConfirmModal from './ConfirmModal';
export default function EvidencePage({ addLog, showToast }) {
  const [users, setUsers] = useState([]);
  const [selectedUser, setSelectedUser] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  
  const [activeTab, setActiveTab] = useState('slips');
  const [slips, setSlips] = useState([]);
  const [conditions, setConditions] = useState([]);
  const [maintenances, setMaintenances] = useState([]);
  const [isUploading, setIsUploading] = useState(false);
  
  // [เปลี่ยนชื่อ State] จาก previewImage เป็น previewMedia เพื่อให้ครอบคลุมวิดีโอ
  const [previewMedia, setPreviewMedia] = useState(null);
  const [confirmConfig, setConfirmConfig] = useState({ isOpen: false, type: '', id: null, path: '' });
  const [editModal, setEditModal] = useState({ isOpen: false, paymentId: null, currentAmount: '' });
  const [editMaintenanceModal, setEditMaintenanceModal] = useState({ isOpen: false, id: null, currentCost: '', paymentMethod: '' });

  useEffect(() => {
    const handleEsc = (e) => {
      if (e.key === 'Escape') {
        setPreviewMedia(null);
        setEditModal(prev => ({ ...prev, isOpen: false, paymentId: null, currentAmount: '' }));
        setEditMaintenanceModal(prev => ({ ...prev, isOpen: false, id: null, currentCost: '', paymentMethod: '' }));
        setConfirmConfig(prev => ({ ...prev, isOpen: false }));
      }
    };
    window.addEventListener('keydown', handleEsc, { capture: true });
    return () => window.removeEventListener('keydown', handleEsc, { capture: true });
  }, []);

  useEffect(() => {
    fetch(`${API_URL}/users`)
      .then(res => res.json())
      .then(data => {
        const activeUsers = (data || []).filter(u => u.status === 'กำลังพักอาศัย' || u.status === 'จอง');
        activeUsers.sort((a, b) => a.room_number.localeCompare(b.room_number));
        setUsers(activeUsers);
      });
  }, []);

  const fetchConditions = () => {
    fetch(`${API_URL}/evidence/room-conditions?user_id=${selectedUser.id}`)
      .then(res => res.json())
      .then(data => setConditions(data || []));
  };

  useEffect(() => {
    if (!selectedUser) return;
    
    const fetchData = () => {
      if (activeTab === 'slips') {
        fetch(`${API_URL}/payments`)
          .then(res => res.json())
          .then(data => {
            const userSlips = (data || []).filter(p => p.user_id === selectedUser.id && p.slip_path && p.slip_path.trim() !== '');
            setSlips(userSlips);
          });
      } else if (activeTab === 'conditions') {
        fetchConditions();
      } else if (activeTab === 'maintenances') {
        fetch(`${API_URL}/maintenances`)
          .then(res => res.json())
          .then(data => {
            const maintSlips = (data || []).filter(m => m.room_number === selectedUser.room_number && m.slip_path && m.slip_path.trim() !== '');
            setMaintenances(maintSlips);
          });
      }
    };
    
    fetchData();
    const interval = setInterval(fetchData, 3000); // Auto refresh every 3 seconds for fast feedback
    
    return () => clearInterval(interval);
  }, [selectedUser, activeTab]);

  // [ฟังก์ชันช่วย] เช็กว่าชื่อไฟล์นี้เป็นวิดีโอหรือไม่
  const isVideoFile = (filename) => {
    if (!filename) return false;
    return /\.(mp4|mov|webm|ogg)$/i.test(filename);
  };

  const executeDelete = () => {
    const { type, id, path } = confirmConfig;
    setConfirmConfig({ ...confirmConfig, isOpen: false });

    if (type === 'slip') {
      fetch(`${API_URL}/payments?payment_id=${id}&filename=${path}`, { method: 'DELETE' })
      .then(async (res) => {
        if (!res.ok) throw new Error("Delete failed");
        showToast("ลบสลิปสำเร็จ", "success");
        addLog("Delete", `ลบสลิปโอนเงิน ${path} ของห้อง ${selectedUser.room_number}`);
        fetch(`${API_URL}/payments`).then(r => r.json()).then(data => {
          const userSlips = (data || []).filter(p => p.user_id === selectedUser.id && p.slip_path && p.slip_path.trim() !== '');
          setSlips(userSlips);
        });
      }).catch(err => {
        console.error(err);
        showToast("ลบสลิปไม่สำเร็จ", "error");
      });
    } else if (type === 'condition') {
      fetch(`${API_URL}/evidence/room-conditions?id=${id}`, { method: 'DELETE' })
      .then(async (res) => {
        if (!res.ok) throw new Error("Delete failed");
        showToast("ลบหลักฐานสภาพห้องสำเร็จ", "success");
        addLog("Delete", `ลบหลักฐานสภาพห้อง ${path} ของห้อง ${selectedUser.room_number}`);
        fetchConditions();
      }).catch(err => {
        console.error(err);
        showToast("ลบหลักฐานไม่สำเร็จ", "error");
      });
    } else if (type === 'maintenance') {
      fetch(`${API_URL}/maintenances?id=${id}&filename=${path}`, { method: 'DELETE' })
      .then(async (res) => {
        if (!res.ok) throw new Error("Delete failed");
        showToast("ลบสลิปค่าซ่อมบำรุงสำเร็จ", "success");
        addLog("Delete", `ลบสลิปซ่อมบำรุง ${path} ของห้อง ${selectedUser.room_number}`);
        fetch(`${API_URL}/maintenances`).then(r => r.json()).then(data => {
          const maintSlips = (data || []).filter(m => m.room_number === selectedUser.room_number && m.slip_path && m.slip_path.trim() !== '');
          setMaintenances(maintSlips);
        });
      }).catch(err => {
        console.error(err);
        showToast("ลบสลิปไม่สำเร็จ", "error");
      });
    }
  };

  const handleDeleteSlip = (paymentId, filename) => setConfirmConfig({ isOpen: true, type: 'slip', id: paymentId, path: filename });
  const handleDeleteCondition = (id, filepath) => setConfirmConfig({ isOpen: true, type: 'condition', id, path: filepath });
  const handleDeleteMaintenanceSlip = (id, filename) => setConfirmConfig({ isOpen: true, type: 'maintenance', id, path: filename });

  // [อัปเดต] รองรับการดึงไฟล์หลายไฟล์จาก Input
  const handleConditionUpload = (e) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    setIsUploading(true);
    const formData = new FormData();
    formData.append('user_id', selectedUser.id);
    formData.append('room_number', selectedUser.room_number);

    // วนลูปยัดไฟล์ทั้งหมดใส่ FormData
    for (let i = 0; i < files.length; i++) {
      formData.append('files', files[i]);
    }

    fetch(`${API_URL}/evidence/room-conditions`, { method: 'POST', body: formData })
      .then(res => {
        if (res.ok) {
          showToast(`อัปโหลดหลักฐานสำเร็จ (${files.length} ไฟล์)`, 'success');
          fetchConditions(); 
        } else {
          showToast('ไฟล์ใหญ่เกินไป หรือเกิดข้อผิดพลาด', 'error');
        }
      })
      .catch(err => {
        console.error(err);
        showToast('เกิดข้อผิดพลาดในการเชื่อมต่อ', 'error');
      })
      .finally(() => {
        setIsUploading(false);
        e.target.value = null; 
      });
  };

  // ฟังก์ชันอัปโหลดสลิปเพิ่มเติม
  const handleSlipUpload = (e) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    setIsUploading(true);
    const formData = new FormData();
    formData.append('user_id', selectedUser.id);
    formData.append('room_number', selectedUser.room_number);
    formData.append('month', 'แนบเพิ่มเติม (Evidence)'); // ใช้รอบบิลเฉพาะกิจ
    formData.append('amount', '0');
    
    // วนลูปยัดไฟล์ทั้งหมดใส่ FormData
    for (let i = 0; i < files.length; i++) {
      formData.append('slips', files[i]);
    }

    fetch(`${API_URL}/payments`, { method: 'POST', body: formData })
      .then(res => {
        if (res.ok) {
          showToast(`อัปโหลดสลิปสำเร็จ (${files.length} ไฟล์)`, 'success');
          // Reload slips
          fetch(`${API_URL}/payments`)
            .then(r => r.json())
            .then(data => {
              const userSlips = (data || []).filter(p => p.user_id === selectedUser.id && p.slip_path && p.slip_path.trim() !== '');
              setSlips(userSlips);
            })
            .catch(err => console.error(err));
        } else {
          showToast('ไฟล์ใหญ่เกินไป หรือเกิดข้อผิดพลาด', 'error');
        }
      })
      .catch(err => {
        console.error(err);
        showToast('เกิดข้อผิดพลาดในการเชื่อมต่อ', 'error');
      })
      .finally(() => {
        setIsUploading(false);
        e.target.value = null; 
      });
  };

  const handleOpenEdit = (paymentId, currentAmount) => {
    setEditModal({ isOpen: true, paymentId, currentAmount: currentAmount ? currentAmount.toString() : '0' });
  };

  const handleSaveEdit = (e) => {
    e.preventDefault();
    const amountVal = Number(editModal.currentAmount);
    if (isNaN(amountVal) || amountVal < 0) {
      showToast('จำนวนเงินไม่ถูกต้อง', 'error');
      return;
    }
    fetch(`${API_URL}/payments`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ payment_id: editModal.paymentId, amount: amountVal })
    }).then(res => {
      if (res.ok) {
        showToast('แก้ไขยอดเงินสำเร็จ', 'success');
        setEditModal({ isOpen: false, paymentId: null, currentAmount: '' });
        fetch(`${API_URL}/payments`)
          .then(r => r.json())
          .then(data => {
            const userSlips = (data || []).filter(p => p.user_id === selectedUser.id && p.slip_path && p.slip_path.trim() !== '');
            setSlips(userSlips);
          })
          .catch(err => console.error(err));
      } else {
        showToast('แก้ไขยอดเงินไม่สำเร็จ', 'error');
      }
    }).catch(err => {
      console.error(err);
      showToast('เกิดข้อผิดพลาดในการเชื่อมต่อ', 'error');
    });
  };

  const handleConfirmMaintenanceSlip = (id, cost) => {
    const formData = new FormData();
    formData.append('id', id);
    formData.append('status', 'เสร็จสิ้น');
    formData.append('cost', cost || 0);
    formData.append('payment_method', 'โอนเงิน');

    fetch(`${API_URL}/maintenances`, {
      method: 'PUT',
      headers: { 'Authorization': 'Bearer ' + localStorage.getItem('dorminet_token') },
      body: formData
    })
      .then(res => {
        if (res.ok) {
          showToast('ยืนยันสลิปค่าซ่อมบำรุงสำเร็จ', 'success');
          // Refresh maintenances
          fetch(`${API_URL}/maintenances`, { headers: { 'Authorization': 'Bearer ' + localStorage.getItem('dorminet_token') } })
            .then(r => r.json())
            .then(data => {
              const maintSlips = (data || []).filter(m => m.room_number === selectedUser.room_number && m.slip_path && m.slip_path.trim() !== '');
              setMaintenances(maintSlips);
            })
            .catch(err => console.error(err));
        } else {
          showToast('เกิดข้อผิดพลาด', 'error');
        }
      })
      .catch(err => {
        console.error(err);
        showToast('เกิดข้อผิดพลาดในการเชื่อมต่อ', 'error');
      });
  };
  const handleEditMaintenanceSubmit = (e) => {
    e.preventDefault();
    const costVal = Number(editMaintenanceModal.currentCost);
    if (costVal < 0) return showToast('ราคาต้องไม่ติดลบ', 'error');

    const formData = new FormData();
    formData.append('id', editMaintenanceModal.id);
    formData.append('status', 'เสร็จสิ้น');
    formData.append('cost', costVal);
    if (editMaintenanceModal.paymentMethod) {
      formData.append('payment_method', editMaintenanceModal.paymentMethod);
    }

    fetch(`${API_URL}/maintenances`, {
      method: 'PUT',
      headers: { 'Authorization': 'Bearer ' + localStorage.getItem('dorminet_token') },
      body: formData
    }).then(res => {
      if (res.ok) {
        showToast('อัปเดตราคาสำเร็จ', 'success');
        setEditMaintenanceModal({ isOpen: false, id: null, currentCost: '' });
        fetch(`${API_URL}/maintenances`, { headers: { 'Authorization': 'Bearer ' + localStorage.getItem('dorminet_token') } })
          .then(r => r.json())
          .then(data => {
            setMaintenances(data.filter(m => m.room_number === selectedUser.room_number && m.slip_path && m.slip_path.trim() !== '') || []);
          })
          .catch(err => console.error(err));
      } else {
        showToast('อัปเดตราคาไม่สำเร็จ', 'error');
      }
    }).catch(err => {
      console.error(err);
      showToast('เกิดข้อผิดพลาดในการเชื่อมต่อ', 'error');
    });
  };

  const filteredUsers = users.filter(u => 
    (u.room_number || '').toLowerCase().includes((searchTerm || '').toLowerCase()) || 
    (u.first_name || '').toLowerCase().includes((searchTerm || '').toLowerCase())
  );

  return (
    <div className="animate-fade-in flex flex-col lg:flex-row gap-6 h-auto lg:h-[calc(100vh-140px)]">
      
      {/* ฝั่งซ้าย: รายชื่อห้อง */}
      <div className="w-full lg:w-1/3 flex flex-col bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-xl shadow-sm overflow-hidden h-[400px] lg:h-full">
        <div className="p-4 border-b border-slate-100 dark:border-slate-700/50 bg-slate-50 dark:bg-slate-700/50">
          <h3 className="font-bold text-slate-800 dark:text-slate-100 uppercase tracking-wide mb-3">เลือกลูกบ้าน</h3>
          <input 
            type="text" 
            placeholder="ค้นหาเลขห้อง / ชื่อ..." 
            value={searchTerm} 
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2 text-sm rounded-lg outline-none focus:ring-2 focus:ring-blue-500 shadow-sm"
          />
        </div>
        <div className="flex-1 overflow-y-auto p-2 space-y-2">
          {filteredUsers.map(user => (
            <div 
              key={user.id} 
              onClick={() => setSelectedUser(user)}
              className={`p-3 rounded-lg cursor-pointer border transition-all flex justify-between items-center ${selectedUser?.id === user.id ? 'bg-blue-50 border-blue-300 shadow-sm' : 'bg-white dark:bg-slate-800 border-transparent hover:border-slate-200 dark:border-slate-700/50 hover:bg-slate-50 dark:bg-slate-700/50'}`}
            >
              <div>
                <span className={`font-mono font-black ${selectedUser?.id === user.id ? 'text-blue-700' : 'text-slate-700 dark:text-slate-200'}`}>{user.room_number}</span>
                <p className="text-xs text-slate-500 dark:text-slate-400 dark:text-slate-300 flex items-center gap-1.5">
                  {user.first_name} {user.last_name}
                  {user.status === 'จอง' && (
                    <span className="bg-amber-500/10 text-amber-600 px-1.5 py-0.5 rounded text-[8px] font-black uppercase tracking-wider border border-amber-500/20">จอง</span>
                  )}
                </p>
              </div>
              <svg className={`w-4 h-4 ${selectedUser?.id === user.id ? 'text-blue-500' : 'text-slate-300'}`} fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" /></svg>
            </div>
          ))}
        </div>
      </div>

      {/* ฝั่งขวา: พื้นที่แสดงหลักฐาน */}
      <div className="w-full lg:w-2/3 flex flex-col bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-xl shadow-sm min-h-[600px] lg:min-h-0 lg:h-full overflow-hidden">
        {!selectedUser ? (
          <div className="flex-1 flex flex-col items-center justify-center text-slate-400 dark:text-slate-300 opacity-60 p-10">
            <svg className="w-16 h-16 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>
            <p className="font-bold uppercase tracking-widest text-sm text-center">กรุณาเลือกห้องพักทางด้านซ้าย</p>
            <p className="text-xs mt-1 text-center">เพื่อดูหลักฐานสลิปโอนเงิน หรือรูป/วิดีโอสภาพห้อง</p>
          </div>
        ) : (
          <>
            <div className="p-4 lg:p-6 border-b border-slate-100 dark:border-slate-700/50 flex flex-col xl:flex-row justify-between items-start xl:items-end gap-4 bg-slate-50 dark:bg-slate-700/50">
              <div>
                <h2 className="text-2xl font-black text-slate-800 dark:text-slate-100 font-mono">ห้อง {selectedUser.room_number}</h2>
                <p className="text-sm text-slate-500 dark:text-slate-400 dark:text-slate-300 font-medium mt-1">ผู้เช่า: {selectedUser.prefix}{selectedUser.first_name} {selectedUser.last_name}</p>
              </div>
              <div className="flex bg-white dark:bg-slate-800 rounded-lg p-1 border border-slate-200 dark:border-slate-700/50 shadow-sm w-full xl:w-auto overflow-x-auto scrollbar-none snap-x gap-1 after:content-[''] after:w-px after:flex-shrink-0">
                <button onClick={() => setActiveTab('slips')} className={`whitespace-nowrap flex-shrink-0 snap-start px-4 py-2 text-xs font-bold uppercase tracking-widest rounded-md transition-all ${activeTab === 'slips' ? 'bg-blue-600 text-white shadow' : 'text-slate-500 dark:text-slate-400 dark:text-slate-300 hover:bg-slate-100'}`}>สลิปโอนเงิน</button>
                <button onClick={() => setActiveTab('conditions')} className={`whitespace-nowrap flex-shrink-0 snap-start px-4 py-2 text-xs font-bold uppercase tracking-widest rounded-md transition-all ${activeTab === 'conditions' ? 'bg-amber-500 text-white shadow' : 'text-slate-500 dark:text-slate-400 dark:text-slate-300 hover:bg-slate-100'}`}>สภาพห้องก่อนเข้าอยู่</button>
                <button onClick={() => setActiveTab('maintenances')} className={`whitespace-nowrap flex-shrink-0 snap-start px-4 py-2 text-xs font-bold uppercase tracking-widest rounded-md transition-all ${activeTab === 'maintenances' ? 'bg-purple-600 text-white shadow' : 'text-slate-500 dark:text-slate-400 dark:text-slate-300 hover:bg-slate-100'}`}>สลิปค่าซ่อมบำรุง</button>
              </div>
            </div>

            <div className="flex-1 p-6 overflow-y-auto bg-slate-50/50">
              
              {/* แท็บ สลิปโอนเงิน */}
              {activeTab === 'slips' && (
                <div className="animate-fade-in space-y-6">
                  <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 bg-blue-50 p-4 rounded-lg border border-blue-200">
                    <div className="flex-1 min-w-0 pr-0 sm:pr-2">
                      <p className="text-sm font-bold text-blue-800">หลักฐานการโอนเงิน (สลิป)</p>
                      <p className="text-xs text-blue-600/70 mt-1">อัปโหลดสลิปเพิ่มเติม (รองรับการเลือกหลายไฟล์พร้อมกัน)</p>
                    </div>
                    <label className={`cursor-pointer bg-blue-600 text-white px-4 py-2 rounded-lg text-xs font-bold uppercase tracking-widest shadow-md hover:bg-blue-700 transition-all flex-shrink-0 whitespace-nowrap w-full sm:w-auto text-center flex items-center justify-center ${isUploading ? 'opacity-50 pointer-events-none' : ''}`}>
                      {isUploading ? 'กำลังอัปโหลด...' : '+ เพิ่มไฟล์หลักฐาน'}
                      <input type="file" multiple accept="image/*,video/*" className="hidden" onChange={handleSlipUpload} disabled={isUploading} />
                    </label>
                  </div>
                  <div className="grid grid-cols-2 lg:grid-cols-3 gap-4 animate-fade-in">
                    {slips.length === 0 ? (
                      <div className="col-span-full py-10 text-center text-slate-400 dark:text-slate-300 font-bold uppercase tracking-widest text-xs">ไม่พบประวัติการอัปโหลดสลิปของห้องนี้</div>
                    ) : (
                    slips.flatMap(slip => {
                      const slipImages = (slip.slip_path_array && slip.slip_path_array.length > 0) 
                        ? slip.slip_path_array 
                        : (slip.slip_path ? [slip.slip_path] : []);
                      
                      return slipImages.map((path, idx) => (
                        <div key={`${slip.id}-${idx}`} className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-xl p-3 shadow-sm group">
                          <div className="aspect-[3/4] bg-slate-100 rounded-lg overflow-hidden relative cursor-pointer group" onClick={() => setPreviewMedia(uploadsUrl(path))}>
                            <img src={uploadsUrl(path)} alt="Slip" className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
                            <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center">
                              <svg className="w-8 h-8 text-white opacity-0 group-hover:opacity-100 drop-shadow-md transition-opacity" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7" /></svg>
                            </div>
                            <button 
                              onClick={(e) => {
                                e.stopPropagation();
                                handleDeleteSlip(slip.id, path);
                              }}
                              className="absolute top-2 right-2 bg-red-600 hover:bg-red-700 text-white rounded-full w-5 h-5 flex items-center justify-center shadow-md border border-white/20 transition-colors z-10 text-xs font-black"
                              title="ลบสลิป"
                            >
                              &times;
                            </button>
                          </div>
                          <div className="mt-3">
                            <p className="text-[10px] font-bold text-slate-400 dark:text-slate-300 uppercase tracking-widest">รอบบิล: {slip.month} {idx > 0 ? `(#${idx+1})` : ''}</p>
                            <div className="flex items-center gap-2 mt-0.5">
                              <p className="text-sm font-bold text-slate-700 dark:text-slate-200">{slip.amount.toLocaleString()} บาท</p>
                              <button onClick={() => handleOpenEdit(slip.id, slip.amount)} className="text-blue-500 hover:text-blue-700 transition-colors" title="แก้ไขยอดเงิน">
                                <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" /></svg>
                              </button>
                            </div>
                            <p className="text-[9px] text-slate-400 dark:text-slate-300 mt-1 font-mono">{slip.payment_date}</p>
                          </div>
                        </div>
                      ));
                    })
                  )}
                  </div>
                </div>
              )}

              {/* แท็บ สภาพห้องก่อนเข้าอยู่ */}
              {activeTab === 'conditions' && (
                <div className="animate-fade-in space-y-6">
                  <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 bg-amber-50 p-4 rounded-lg border border-amber-200">
                    <div className="flex-1 min-w-0 pr-0 sm:pr-2">
                      <p className="text-sm font-bold text-amber-800">หลักฐานสภาพห้องก่อนส่งมอบ</p>
                      <p className="text-xs text-amber-600/70 mt-1">รองรับทั้งรูปถ่ายและวิดีโอ (เลือกได้ทีละหลายไฟล์)</p>
                    </div>
                    {/* [อัปเดต] เติม multiple ให้เลือกได้หลายไฟล์ และ accept ทั้งรูปและวิดีโอ */}
                    <label className={`cursor-pointer bg-amber-500 text-white px-4 py-2 rounded-lg text-xs font-bold uppercase tracking-widest shadow-md hover:bg-amber-600 transition-all flex-shrink-0 whitespace-nowrap w-full sm:w-auto text-center flex items-center justify-center ${isUploading ? 'opacity-50 pointer-events-none' : ''}`}>
                      {isUploading ? 'กำลังอัปโหลด...' : '+ เพิ่มไฟล์หลักฐาน'}
                      <input type="file" multiple accept="image/*,video/*" className="hidden" onChange={handleConditionUpload} disabled={isUploading} />
                    </label>
                  </div>

                  <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
                    {conditions.length === 0 ? (
                      <div className="col-span-full py-10 text-center text-slate-400 dark:text-slate-300 font-bold uppercase tracking-widest text-xs">ยังไม่มีการบันทึกหลักฐานสภาพห้อง</div>
                    ) : (
                      conditions.map(cond => {
                        const isVideo = isVideoFile(cond.image_path);
                        return (
                          <div key={cond.id} className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-xl p-2 shadow-sm group">
                            <div className="aspect-square bg-slate-100 rounded-lg overflow-hidden relative cursor-pointer" onClick={() => setPreviewMedia(uploadsUrl(cond.image_path))}>
                              
                              {/* [อัปเดต] เช็กว่าเป็นวิดีโอหรือรูป เพื่อเลือกแท็กแสดงผลให้ถูกต้อง */}
                              {isVideo ? (
                                <video src={uploadsUrl(cond.image_path)} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
                              ) : (
                                <img src={uploadsUrl(cond.image_path)} alt="Room Condition" className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
                              )}
                              
                              {/* ป้ายแปะบอกว่าเป็นวิดีโอ */}
                              {isVideo && (
                                <div className="absolute top-2 right-2 bg-black/60 backdrop-blur-sm rounded px-1.5 py-0.5 text-[8px] text-white font-bold tracking-widest border border-white/20 shadow-sm">VIDEO</div>
                              )}

                              <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center">
                                <svg className="w-8 h-8 text-white opacity-0 group-hover:opacity-100 drop-shadow-md transition-opacity" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                  {isVideo ? (
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                                  ) : (
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7" />
                                  )}
                                </svg>
                              </div>
                              <button 
                                onClick={(e) => {
                                  e.stopPropagation();
                                  handleDeleteCondition(cond.id, cond.image_path);
                                }}
                                className="absolute top-2 right-2 bg-red-600 hover:bg-red-700 text-white rounded-full w-5 h-5 flex items-center justify-center shadow-md border border-white/20 transition-colors z-10 text-xs font-black"
                                title="ลบหลักฐาน"
                              >
                                &times;
                              </button>
                            </div>
                            <p className="text-[9px] text-center text-slate-400 dark:text-slate-300 mt-2 font-mono pb-1">อัปโหลดเมื่อ: <br/>{cond.uploaded_at}</p>
                          </div>
                        );
                      })
                    )}
                  </div>
                </div>
              )}

              {/* แท็บ สลิปค่าซ่อมบำรุง */}
              {activeTab === 'maintenances' && (
                <div className="animate-fade-in space-y-6">
                  <div className="flex justify-between items-center bg-purple-50 p-4 rounded-lg border border-purple-200">
                    <div>
                      <p className="text-sm font-bold text-purple-800">สลิปค่าซ่อมบำรุง</p>
                      <p className="text-xs text-purple-600/70 mt-1">หลักฐานการชำระเงินค่าซ่อมแซมภายในห้องพัก</p>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 lg:grid-cols-3 gap-4 animate-fade-in">
                    {maintenances.length === 0 ? (
                      <div className="col-span-full py-10 text-center text-slate-400 dark:text-slate-300 font-bold uppercase tracking-widest text-xs">ไม่พบสลิปค่าซ่อมบำรุงของห้องนี้</div>
                    ) : (
                      maintenances.map((m) => (
                        <div key={m.id} className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-xl p-3 shadow-sm group">
                          <div className="aspect-[3/4] bg-slate-100 rounded-lg overflow-hidden relative cursor-pointer group" onClick={() => setPreviewMedia(uploadsUrl(m.slip_path))}>
                            <img src={uploadsUrl(m.slip_path)} alt="Maintenance Slip" className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
                            <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center">
                              <svg className="w-8 h-8 text-white opacity-0 group-hover:opacity-100 drop-shadow-md transition-opacity" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7" /></svg>
                            </div>
                            {m.status === 'รอตรวจสอบชำระเงิน' ? (
                              <div className="absolute top-2 left-2 flex gap-1">
                                <button
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    handleConfirmMaintenanceSlip(m.id, m.cost);
                                  }}
                                  className="bg-emerald-600 hover:bg-emerald-700 text-white rounded px-2 py-1 flex items-center justify-center shadow-md border border-white/20 transition-colors z-10 text-[10px] font-bold uppercase tracking-widest"
                                  title="ยืนยันสลิป"
                                >
                                  ยืนยันสลิป
                                </button>
                              </div>
                            ) : (
                              <div className="absolute top-2 left-2 bg-emerald-100 text-emerald-700 border border-emerald-300 rounded px-2 py-1 flex items-center justify-center shadow-md z-10 text-[10px] font-bold uppercase tracking-widest">
                                ยืนยันแล้ว
                              </div>
                            )}
                            <button 
                              onClick={(e) => {
                                e.stopPropagation();
                                handleDeleteMaintenanceSlip(m.id, m.slip_path);
                              }}
                              className="absolute top-2 right-2 bg-red-600 hover:bg-red-700 text-white rounded-full w-5 h-5 flex items-center justify-center shadow-md border border-white/20 transition-colors z-10 text-xs font-black"
                              title="ลบสลิป"
                            >
                              &times;
                            </button>
                          </div>
                          <div className="mt-3 px-1">
                            <p className="text-xs font-bold text-slate-700 dark:text-slate-200 truncate">{m.issue}</p>
                            <div className="flex justify-between items-center mt-1">
                              <div className="flex items-center gap-2 mt-0.5">
                                <span className="text-[10px] text-purple-600 font-black">{m.cost ? m.cost.toLocaleString() : '0'} ฿</span>
                                <button onClick={(e) => { e.stopPropagation(); setEditMaintenanceModal({ isOpen: true, id: m.id, currentCost: m.cost ? m.cost.toString() : '0', paymentMethod: m.payment_method || '' }); }} className="text-blue-500 hover:text-blue-700 transition-colors" title="แก้ไขราคา">
                                  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" /></svg>
                                </button>
                              </div>
                              <span className="text-[10px] text-slate-400 dark:text-slate-300 font-mono">{m.resolved_at}</span>
                            </div>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              )}
            </div>
          </>
        )}
      </div>

      {/* [อัปเดต] Modal แก้ไขราคาสลิปค่าซ่อมบำรุง */}
      {editMaintenanceModal.isOpen && createPortal(
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4 z-[9999] animate-fade-in"
             tabIndex="-1"
             onKeyDown={(e) => {
               if (e.key === 'Escape') setEditMaintenanceModal(prev => ({ ...prev, isOpen: false, id: null, currentCost: '', paymentMethod: '' }));
             }}>
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-xl w-full max-w-sm overflow-hidden border border-slate-200 dark:border-slate-700/50">
            <div className="bg-slate-50 dark:bg-slate-700/50 px-6 py-4 border-b border-slate-200 dark:border-slate-700/50 flex justify-between items-center">
              <h3 className="font-bold text-slate-800 dark:text-slate-100 tracking-wide uppercase">แก้ไขราคาสลิป</h3>
              <button onClick={() => setEditMaintenanceModal({ isOpen: false, id: null, currentCost: '', paymentMethod: '' })} className="text-slate-400 dark:text-slate-300 hover:text-slate-700 dark:text-slate-200 font-bold text-xl">&times;</button>
            </div>
            <form onSubmit={handleEditMaintenanceSubmit} className="p-6 space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-2 uppercase">ราคา (บาท)</label>
                <input required type="number" step="0.01" className="w-full bg-white dark:bg-slate-800 border border-slate-300 p-3 text-lg font-bold text-slate-800 dark:text-slate-100 focus:ring-2 focus:ring-blue-500 outline-none rounded-md transition-all" value={editMaintenanceModal.currentCost} onChange={e => setEditMaintenanceModal({...editMaintenanceModal, currentCost: e.target.value})} placeholder="0" />
              </div>
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={() => setEditMaintenanceModal({ isOpen: false, id: null, currentCost: '', paymentMethod: '' })} className="flex-1 bg-slate-100 text-slate-500 dark:text-slate-400 dark:text-slate-300 py-3 rounded-lg text-xs font-bold uppercase transition-all hover:bg-slate-200">ยกเลิก</button>
                <button type="submit" className="flex-1 bg-blue-600 text-white py-3 rounded-lg text-xs font-bold uppercase tracking-widest shadow-md transition-all hover:bg-blue-700">บันทึกราคา</button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}
      {previewMedia && createPortal(
        <div className="fixed inset-0 bg-slate-950/95 flex items-center justify-center p-4 z-[100] animate-fade-in cursor-pointer" onClick={() => setPreviewMedia(null)}>
          <div className="relative max-w-4xl w-full flex justify-center">
            <button onClick={() => setPreviewMedia(null)} className="absolute -top-12 right-0 md:-right-8 text-white hover:text-red-500 text-4xl font-light transition-colors">&times;</button>
            
            {/* โชว์ Player ถ้านามสกุลเป็นวิดีโอ */}
            {isVideoFile(previewMedia) ? (
              <video 
                src={previewMedia} 
                controls 
                autoPlay 
                className="max-h-[85vh] object-contain rounded-lg shadow-2xl border border-slate-700 w-full" 
                onClick={(e) => e.stopPropagation()} 
              />
            ) : (
              <img 
                src={previewMedia} 
                alt="Preview" 
                className="max-h-[85vh] object-contain rounded-lg shadow-2xl border border-slate-700" 
                onClick={(e) => e.stopPropagation()} 
              />
            )}
          </div>
        </div>,
        document.body
      )}

      {editModal.isOpen && createPortal(
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4 z-[9999] animate-fade-in"
             tabIndex="-1"
             onKeyDown={(e) => {
               if (e.key === 'Escape') setEditModal(prev => ({ ...prev, isOpen: false, paymentId: null, currentAmount: '' }));
             }}>
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-xl w-full max-w-sm overflow-hidden border border-slate-200 dark:border-slate-700/50">
            <div className="bg-slate-50 dark:bg-slate-700/50 px-6 py-4 border-b border-slate-200 dark:border-slate-700/50 flex justify-between items-center">
              <h3 className="font-bold text-slate-800 dark:text-slate-100 tracking-wide uppercase">แก้ไขยอดเงินสลิป</h3>
              <button onClick={() => setEditModal({ isOpen: false, paymentId: null, currentAmount: '' })} className="text-slate-400 dark:text-slate-300 hover:text-slate-700 dark:text-slate-200 font-bold text-xl">&times;</button>
            </div>
            <form onSubmit={handleSaveEdit} className="p-6 space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-2 uppercase">ยอดเงิน (บาท)</label>
                <input required type="number" step="0.01" className="w-full bg-white dark:bg-slate-800 border border-slate-300 p-3 text-lg font-bold text-slate-800 dark:text-slate-100 focus:ring-2 focus:ring-blue-500 outline-none rounded-md transition-all" value={editModal.currentAmount} onChange={e => setEditModal({...editModal, currentAmount: e.target.value})} placeholder="0" />
              </div>
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={() => setEditModal({ isOpen: false, paymentId: null, currentAmount: '' })} className="flex-1 bg-slate-100 text-slate-500 dark:text-slate-400 dark:text-slate-300 py-3 rounded-lg text-xs font-bold uppercase transition-all hover:bg-slate-200">ยกเลิก</button>
                <button type="submit" className="flex-1 bg-blue-600 text-white py-3 rounded-lg text-xs font-bold uppercase tracking-widest shadow-md transition-all hover:bg-blue-700">บันทึกข้อมูล</button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}

      <ConfirmModal
        isOpen={confirmConfig.isOpen}
        title={confirmConfig.type === 'slip' ? 'ยืนยันการลบสลิปโอนเงิน' : 'ยืนยันการลบหลักฐานสภาพห้อง'}
        message="คุณต้องการลบไฟล์นี้ออกจากระบบใช่หรือไม่? ข้อมูลที่ถูกลบจะไม่สามารถกู้คืนได้"
        onConfirm={executeDelete}
        onCancel={() => setConfirmConfig({ ...confirmConfig, isOpen: false })}
      />
    </div>
  );
}