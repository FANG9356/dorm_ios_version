import { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { API_URL, uploadsUrl } from '../config';

export default function MaintenancePage({ addLog, showToast }) {
  const [issues, setIssues] = useState([]);
  const [rooms, setRooms] = useState([]);
  
  // New States for Layout
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedRoom, setSelectedRoom] = useState('all');
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  
  const [formData, setFormData] = useState({ room_number: '', issue: '' });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [costPrompt, setCostPrompt] = useState({ isOpen: false, id: null, currentCost: '', paymentMethod: '', slipFile: null });
  const [deletePrompt, setDeletePrompt] = useState({ isOpen: false, id: null });
  const [previewImage, setPreviewImage] = useState(null);
  const [previewIndex, setPreviewIndex] = useState(0);

  const handlePrevImage = (e) => {
    e.stopPropagation();
    setPreviewIndex((prev) => (prev === 0 ? previewImage.length - 1 : prev - 1));
  };

  const handleNextImage = (e) => {
    e.stopPropagation();
    setPreviewIndex((prev) => (prev === previewImage.length - 1 ? 0 : prev + 1));
  };

  useEffect(() => {
    const handleEsc = (e) => {
      if (e.key === 'Escape') {
        setCostPrompt(prev => ({ ...prev, isOpen: false, id: null, currentCost: '', paymentMethod: '', slipFile: null }));
        setDeletePrompt(prev => ({ ...prev, isOpen: false }));
        setIsAddModalOpen(false);
        setPreviewImage(null);
        setPreviewIndex(0);
      }
    };
    window.addEventListener('keydown', handleEsc, { capture: true });
    return () => window.removeEventListener('keydown', handleEsc, { capture: true });
  }, []);

  const fetchIssues = () => {
    fetch(`${API_URL}/maintenances`, { headers: { 'Authorization': 'Bearer ' + localStorage.getItem('dorminet_token') } })
      .then(res => res.json())
      .then(data => setIssues(data || []));
  };

  useEffect(() => {
    fetchIssues();
    fetch(`${API_URL}/rooms`, { headers: { 'Authorization': 'Bearer ' + localStorage.getItem('dorminet_token') } })
      .then(res => res.json())
      .then(data => setRooms((data || []).sort((a,b)=>a.room_number.localeCompare(b.room_number))));

    const interval = setInterval(fetchIssues, 3000); // Auto refresh every 3 seconds
    return () => clearInterval(interval);
  }, []);

  const openAddModal = () => {
    setFormData({ room_number: selectedRoom !== 'all' ? selectedRoom : '', issue: '' });
    setIsAddModalOpen(true);
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!formData.room_number) return showToast('กรุณาเลือกห้องพัก', 'error');
    setIsSubmitting(true);

    fetch(`${API_URL}/maintenances`, {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + localStorage.getItem('dorminet_token')
      },
      body: JSON.stringify(formData)
    }).then(res => {
      if (res.ok) {
        showToast('บันทึกแจ้งซ่อมสำเร็จ', 'success');
        setFormData({ room_number: '', issue: '' });
        fetchIssues();
        addLog('Create', `รับแจ้งซ่อมห้อง ${formData.room_number}`);
        setIsAddModalOpen(false);
      }
    }).finally(() => setIsSubmitting(false));
  };

  const confirmPayment = (id, cost) => {
    const fd = new FormData();
    fd.append('id', id);
    fd.append('status', 'เสร็จสิ้น');
    fd.append('cost', cost || 0);
    fd.append('payment_method', 'โอนเงิน');
    
    fetch(`${API_URL}/maintenances`, {
      method: 'PUT',
      headers: { 'Authorization': 'Bearer ' + localStorage.getItem('dorminet_token') },
      body: fd
    })
      .then(res => {
        if (res.ok) {
          showToast('ยืนยันสลิปสำเร็จ', 'success');
          fetchIssues();
        } else {
          showToast('ยืนยันไม่สำเร็จ', 'error');
        }
      })
      .catch(err => {
        console.error(err);
        showToast('เกิดข้อผิดพลาดในการเชื่อมต่อ', 'error');
      });
  };


  const updateStatus = (id, newStatus, currentCost) => {
    if (newStatus === 'เสร็จสิ้น') {
      setCostPrompt({ isOpen: true, id, currentCost: currentCost || '', paymentMethod: '', slipFile: null });
      return;
    }
    submitStatusUpdate(id, newStatus, currentCost);
  };

  const submitStatusUpdate = (id, newStatus, cost, paymentMethod = '', slipFile = null) => {
    if (slipFile || paymentMethod) {
      const fd = new FormData();
      fd.append('id', id);
      fd.append('status', newStatus);
      fd.append('cost', cost || 0);
      fd.append('payment_method', paymentMethod);
      if (slipFile) fd.append('slip', slipFile);

      fetch(`${API_URL}/maintenances`, {
        method: 'PUT',
        headers: { 'Authorization': 'Bearer ' + localStorage.getItem('dorminet_token') },
        body: fd
      }).then(res => {
        if (res.ok) {
          showToast('อัปเดตสถานะการซ่อมสำเร็จ', 'success');
          fetchIssues();
        }
      });
    } else {
      fetch(`${API_URL}/maintenances`, {
        method: 'PUT',
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + localStorage.getItem('dorminet_token')
        },
        body: JSON.stringify({ id, status: newStatus, cost: parseFloat(cost) || 0 })
      }).then(res => {
        if (res.ok) {
          showToast('อัปเดตสถานะการซ่อมสำเร็จ', 'success');
          fetchIssues();
        }
      });
    }
  };

  const confirmCost = (e) => {
    e.preventDefault();
    submitStatusUpdate(costPrompt.id, 'เสร็จสิ้น', costPrompt.currentCost, costPrompt.paymentMethod, costPrompt.slipFile);
    setCostPrompt({ isOpen: false, id: null, currentCost: '', paymentMethod: '', slipFile: null });
  };

  const handleDelete = (id) => {
    fetch(`${API_URL}/maintenances?id=${id}`, {
      method: 'DELETE',
      headers: { 'Authorization': 'Bearer ' + localStorage.getItem('dorminet_token') }
    }).then(res => {
      if (res.ok) {
        showToast('ลบรายการแจ้งซ่อมสำเร็จ', 'success');
        fetchIssues();
      }
    }).finally(() => {
      setDeletePrompt({ isOpen: false, id: null });
    });
  };

  const filteredRooms = rooms.filter(r => (r.room_number || '').toLowerCase().includes((searchTerm || '').toLowerCase()));
  const displayedIssues = selectedRoom === 'all' ? issues : issues.filter(i => i.room_number === selectedRoom);

  return (
    <div className="animate-fade-in flex flex-col lg:flex-row gap-6 h-auto lg:h-[calc(100vh-140px)]">
      
      {/* ฝั่งซ้าย: รายชื่อห้อง */}
      <div className="w-full lg:w-1/3 flex flex-col bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-xl shadow-sm overflow-hidden h-[400px] lg:h-full">
        <div className="p-4 border-b border-slate-100 dark:border-slate-700/50 bg-slate-50 dark:bg-slate-700/50">
          <h3 className="font-bold text-slate-800 dark:text-slate-100 uppercase tracking-wide mb-3">เลือกห้องพัก</h3>
          <input 
            type="text" 
            placeholder="ค้นหาเลขห้อง..." 
            value={searchTerm} 
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2 text-sm rounded-lg outline-none focus:ring-2 focus:ring-blue-500 shadow-sm"
          />
        </div>
        <div className="flex-1 overflow-y-auto p-2 space-y-2">
          {/* ตัวเลือกทั้งหมด */}
          <div 
            onClick={() => setSelectedRoom('all')}
            className={`p-3 rounded-lg cursor-pointer border transition-all flex justify-between items-center ${selectedRoom === 'all' ? 'bg-blue-50 border-blue-300 shadow-sm' : 'bg-white dark:bg-slate-800 border-transparent hover:border-slate-200 dark:border-slate-700/50 hover:bg-slate-50 dark:bg-slate-700/50'}`}
          >
            <div>
              <span className={`font-bold ${selectedRoom === 'all' ? 'text-blue-700' : 'text-slate-700 dark:text-slate-200'}`}>รายการทั้งหมด</span>
              <p className="text-[10px] text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest mt-0.5">All Rooms</p>
            </div>
            <div className="bg-slate-200 text-slate-600 dark:text-slate-300 px-2 py-0.5 rounded-full text-xs font-bold">{issues.length}</div>
          </div>

          <hr className="my-2 border-slate-100 dark:border-slate-700/50" />

          {/* รายชื่อห้อง */}
          {filteredRooms.map(room => {
            const roomIssues = issues.filter(i => i.room_number === room.room_number);
            const pendingIssues = roomIssues.filter(i => i.status !== 'เสร็จสิ้น').length;
            
            return (
              <div 
                key={room.id} 
                onClick={() => setSelectedRoom(room.room_number)}
                className={`p-3 rounded-lg cursor-pointer border transition-all flex justify-between items-center ${selectedRoom === room.room_number ? 'bg-blue-50 border-blue-300 shadow-sm' : 'bg-white dark:bg-slate-800 border-transparent hover:border-slate-200 dark:border-slate-700/50 hover:bg-slate-50 dark:bg-slate-700/50'}`}
              >
                <div>
                  <span className={`font-mono font-black ${selectedRoom === room.room_number ? 'text-blue-700' : 'text-slate-700 dark:text-slate-200'}`}>ห้อง {room.room_number}</span>
                  <p className="text-[10px] text-slate-400 dark:text-slate-300 mt-0.5">ประเภท: {room.room_type}</p>
                </div>
                {pendingIssues > 0 && (
                  <div className="bg-amber-100 border border-amber-200 text-amber-600 px-2 py-0.5 rounded-full text-xs font-bold animate-pulse">{pendingIssues}</div>
                )}
              </div>
            );
          })}
        </div>
      </div>

      {/* ฝั่งขวา: รายการแจ้งซ่อม */}
      <div className="w-full lg:w-2/3 flex flex-col bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-xl shadow-sm min-h-[600px] lg:min-h-0 lg:h-full overflow-hidden">
        <div className="p-4 lg:p-6 border-b border-slate-100 dark:border-slate-700/50 bg-slate-50 dark:bg-slate-700/50 flex justify-between items-center">
          <div>
            <h2 className="text-2xl font-black text-slate-800 dark:text-slate-100 tracking-tight">
              {selectedRoom === 'all' ? 'กระดานซ่อมบำรุงรวม' : `ห้อง ${selectedRoom}`}
            </h2>
            <p className="text-xs text-slate-500 dark:text-slate-400 dark:text-slate-300 font-medium mt-1">รายการที่รอดำเนินการ: {displayedIssues.filter(i => i.status === 'รอดำเนินการ').length} รายการ</p>
          </div>
          <button onClick={openAddModal} className="bg-blue-600 text-white px-4 py-2.5 rounded-lg text-xs font-bold uppercase tracking-widest shadow-md hover:bg-blue-700 transition-all flex items-center gap-2">
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 4v16m8-8H4" /></svg>
            เพิ่มการแจ้งซ่อม
          </button>
        </div>

        <div className="flex-1 p-6 overflow-y-auto bg-slate-50/50 space-y-4">
          {displayedIssues.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-full text-slate-400 dark:text-slate-300 opacity-60">
              <svg className="w-16 h-16 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
              <p className="font-bold uppercase tracking-widest text-sm">ไม่มีรายการแจ้งซ่อม</p>
            </div>
          ) : (
            displayedIssues.map(item => {
              let statusColor = "bg-slate-100 text-slate-600 dark:text-slate-300";
              if (item.status === "รอดำเนินการ") statusColor = "bg-red-50 border-red-200 text-red-600";
              if (item.status === "กำลังติดต่อช่าง") statusColor = "bg-purple-50 border-purple-200 text-purple-600";
              if (item.status === "กำลังซ่อม") statusColor = "bg-amber-50 border-amber-200 text-amber-600";
              if (item.status === "รอตรวจสอบชำระเงิน") statusColor = "bg-blue-50 border-blue-200 text-blue-600";
              if (item.status === "เสร็จสิ้น") statusColor = "bg-emerald-50 border-emerald-200 text-emerald-600";

              return (
                <div key={item.id} className={`relative p-5 rounded-xl border ${item.status === 'เสร็จสิ้น' ? 'border-emerald-100 bg-white dark:bg-slate-800' : 'border-slate-200 dark:border-slate-700/50 bg-white dark:bg-slate-800 shadow-sm hover:shadow-md'} transition-all flex flex-col md:flex-row justify-between items-start md:items-center gap-4`}>
                  
                  {/* Delete button */}
                  <button onClick={() => setDeletePrompt({ isOpen: true, id: item.id })} className="absolute top-4 right-4 text-slate-300 hover:text-red-500 hover:bg-red-50 p-1.5 rounded-lg transition-colors" title="ลบรายการ">
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M6 18L18 6M6 6l12 12" /></svg>
                  </button>

                  <div className="flex-1 pr-8">
                    <div className="flex items-center gap-3 mb-2">
                      <span className="font-mono text-xl font-black text-slate-800 dark:text-slate-100">{item.room_number}</span>
                      <span className={`text-[9px] font-bold uppercase tracking-widest px-2 py-0.5 rounded border ${statusColor}`}>{item.status}</span>
                    </div>
                    <p className="text-sm text-slate-600 dark:text-slate-300 font-medium">{item.issue}</p>
                    <div className="flex gap-4 mt-3 flex-wrap items-center">
                      <span className="text-[10px] text-slate-400 dark:text-slate-300 font-mono">แจ้งเมื่อ: {item.reported_at}</span>
                      {item.resolved_at && <span className="text-[10px] text-emerald-500 font-mono">ซ่อมเสร็จ: {item.resolved_at}</span>}
                      {item.cost > 0 && <span className="text-[10px] text-amber-600 font-bold">ค่าใช้จ่าย: {item.cost} ฿</span>}
                      {item.payment_method && <span className="text-[10px] text-blue-600 font-bold">ชำระ: {item.payment_method}</span>}
                    </div>
                  </div>
                  
                  <div className="flex gap-2 w-full md:w-auto">
                    {item.issue_image && (
                      <button onClick={() => setPreviewImage(item.issue_image.split(',').map(path => `${API_URL.replace('/api', '')}${path}`))} className="flex-1 md:flex-none px-4 py-2 bg-indigo-100 text-indigo-700 text-[10px] font-bold uppercase rounded-lg hover:bg-indigo-200 transition-colors flex items-center justify-center whitespace-nowrap">
                        ดูภาพปัญหา {item.issue_image.split(',').length > 1 ? `(${item.issue_image.split(',').length} ภาพ)` : ''}
                      </button>
                    )}
                    {item.status === 'รอดำเนินการ' && <button onClick={() => updateStatus(item.id, 'กำลังติดต่อช่าง', item.cost)} className="flex-1 md:flex-none px-4 py-2 bg-purple-100 text-purple-700 text-[10px] font-bold uppercase rounded-lg hover:bg-purple-200 transition-colors whitespace-nowrap">รับงานช่าง</button>}
                    {item.status === 'กำลังติดต่อช่าง' && <button onClick={() => updateStatus(item.id, 'กำลังซ่อม', item.cost)} className="flex-1 md:flex-none px-4 py-2 bg-amber-100 text-amber-700 text-[10px] font-bold uppercase rounded-lg hover:bg-amber-200 transition-colors whitespace-nowrap">ซ่อม</button>}
                    {item.status === 'กำลังซ่อม' && <button onClick={() => updateStatus(item.id, 'เสร็จสิ้น', item.cost)} className="flex-1 md:flex-none px-4 py-2 bg-emerald-600 text-white text-[10px] font-bold uppercase rounded-lg hover:bg-emerald-700 shadow-md transition-colors whitespace-nowrap">ปิดงานซ่อม</button>}
                    {item.status === 'รอตรวจสอบชำระเงิน' && <button onClick={() => confirmPayment(item.id, item.cost)} className="flex-1 md:flex-none px-4 py-2 bg-blue-600 text-white text-[10px] font-bold uppercase rounded-lg hover:bg-blue-700 shadow-md transition-colors whitespace-nowrap">ยืนยันสลิป</button>}
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* Add Maintenance Modal */}
      {isAddModalOpen && createPortal(
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4 z-[9999] animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-xl w-full max-w-md overflow-hidden border border-slate-200 dark:border-slate-700/50">
            <div className="bg-slate-50 dark:bg-slate-700/50 px-6 py-4 border-b border-slate-200 dark:border-slate-700/50 flex justify-between items-center">
              <div>
                <h3 className="font-bold text-slate-800 dark:text-slate-100 uppercase tracking-wide">เพิ่มรายการแจ้งซ่อม</h3>
                <p className="text-[10px] text-slate-500 dark:text-slate-400 dark:text-slate-300">บันทึกปัญหาเพื่อส่งให้ช่างดำเนินการ</p>
              </div>
              <button onClick={() => setIsAddModalOpen(false)} className="text-slate-400 dark:text-slate-300 hover:text-slate-700 dark:text-slate-200 font-bold text-xl">&times;</button>
            </div>
            <form onSubmit={handleSubmit} className="p-6 space-y-4">
              <div>
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest mb-1.5">หมายเลขห้อง</label>
                <select required value={formData.room_number} onChange={e => setFormData({...formData, room_number: e.target.value})} className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-300 p-3 rounded-lg text-sm font-mono outline-none focus:ring-2 focus:ring-blue-500">
                  <option value="" disabled>-- เลือกห้องพัก --</option>
                  {rooms.map(r => (
                    <option key={r.id} value={r.room_number}>ห้อง {r.room_number}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest mb-1.5">รายละเอียดปัญหา</label>
                <textarea required value={formData.issue} onChange={e => setFormData({...formData, issue: e.target.value})} rows="4" className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-300 p-3 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none" placeholder="เช่น แอร์ไม่เย็น, หลอดไฟขาด..."></textarea>
              </div>
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={() => setIsAddModalOpen(false)} className="flex-1 bg-slate-100 text-slate-600 dark:text-slate-300 py-3 rounded-lg text-xs font-bold uppercase transition-all hover:bg-slate-200">ยกเลิก</button>
                <button type="submit" disabled={isSubmitting} className="flex-1 bg-blue-600 text-white py-3 rounded-lg text-xs font-bold uppercase tracking-widest shadow-md hover:bg-blue-700 transition-all disabled:opacity-50">
                  {isSubmitting ? 'กำลังบันทึก...' : 'บันทึกแจ้งซ่อม'}
                </button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}

      {/* Delete Prompt Modal */}
      {deletePrompt.isOpen && createPortal(
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center z-[9999] p-4">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-xl w-full max-w-sm overflow-hidden animate-fade-in-up border border-slate-200 dark:border-slate-700/50">
            <div className="p-6">
              <div className="w-12 h-12 bg-red-100 text-red-600 rounded-full flex items-center justify-center mb-4 mx-auto">
                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1-1v3M4 7h16" /></svg>
              </div>
              <h3 className="text-lg font-black text-slate-800 dark:text-slate-100 text-center mb-2">ลบรายการแจ้งซ่อม?</h3>
              <p className="text-sm text-slate-500 dark:text-slate-400 dark:text-slate-300 text-center mb-6">คุณแน่ใจหรือไม่ที่จะลบรายการแจ้งซ่อมนี้? ข้อมูลจะไม่สามารถกู้คืนได้</p>
              <div className="flex gap-3">
                <button onClick={() => setDeletePrompt({ isOpen: false, id: null })} type="button" className="flex-1 py-2.5 bg-slate-100 text-slate-700 dark:text-slate-200 font-bold rounded-xl text-sm hover:bg-slate-200">ยกเลิก</button>
                <button onClick={() => handleDelete(deletePrompt.id)} type="button" className="flex-1 py-2.5 bg-red-600 text-white font-bold rounded-xl text-sm hover:bg-red-700 shadow-md">ลบทิ้ง</button>
              </div>
            </div>
          </div>
        </div>,
        document.body
      )}

      {/* Image Preview Modal */}
      {previewImage && previewImage.length > 0 && createPortal(
        <div className="fixed inset-0 z-[60] bg-slate-900/95 backdrop-blur-sm flex items-center justify-center p-4" onClick={() => { setPreviewImage(null); setPreviewIndex(0); }}>
          <button onClick={() => { setPreviewImage(null); setPreviewIndex(0); }} className="absolute top-4 right-4 bg-black/50 text-white rounded-full w-10 h-10 flex items-center justify-center hover:bg-black/70 transition-colors z-[70]">
            &times;
          </button>
          
          <div className="relative max-w-5xl w-full h-full flex items-center justify-center">
            {previewImage.length > 1 && (
              <button onClick={handlePrevImage} className="absolute left-2 md:left-4 bg-black/50 hover:bg-black/80 text-white rounded-full w-12 h-12 flex items-center justify-center transition-colors z-[70]">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 19l-7-7 7-7" /></svg>
              </button>
            )}
            
            <img src={previewImage[previewIndex]} alt={`Preview ${previewIndex+1}`} className="max-w-full max-h-[90vh] object-contain rounded-xl shadow-2xl" onClick={(e) => e.stopPropagation()} />
            
            {previewImage.length > 1 && (
              <button onClick={handleNextImage} className="absolute right-2 md:right-4 bg-black/50 hover:bg-black/80 text-white rounded-full w-12 h-12 flex items-center justify-center transition-colors z-[70]">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" /></svg>
              </button>
            )}
            
            {previewImage.length > 1 && (
              <div className="absolute bottom-6 left-1/2 -translate-x-1/2 bg-black/60 text-white px-5 py-2 rounded-full text-sm font-bold tracking-widest z-[70]">
                {previewIndex + 1} / {previewImage.length}
              </div>
            )}
          </div>
        </div>,
        document.body
      )}

      {/* Cost Prompt Modal */}
      {costPrompt.isOpen && createPortal(
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center z-[9999] p-4">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-xl w-full max-w-md overflow-hidden animate-fade-in-up border border-slate-200 dark:border-slate-700/50">
            <div className="bg-slate-50 dark:bg-slate-700/50 px-6 py-4 border-b border-slate-200 dark:border-slate-700/50 flex justify-between items-center">
              <h3 className="font-bold text-slate-800 dark:text-slate-100 uppercase tracking-wide">ระบุค่าใช้จ่ายการซ่อม</h3>
              <button onClick={() => setCostPrompt({ isOpen: false, id: null, currentCost: '' })} className="text-slate-400 dark:text-slate-300 hover:text-slate-700 dark:text-slate-200 font-bold text-xl">&times;</button>
            </div>
            <form onSubmit={confirmCost} className="p-6">
              <p className="text-xs text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-4">กรุณาระบุค่าใช้จ่ายในการซ่อมแซม (บาท) หากซ่อมฟรีให้ใส่ 0</p>
              <div className="mb-6">
                <input 
                  type="number" 
                  min="0"
                  required
                  value={costPrompt.currentCost} 
                  onChange={(e) => setCostPrompt({...costPrompt, currentCost: e.target.value})}
                  className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-4 py-3 rounded-xl text-lg font-bold outline-none focus:ring-2 focus:ring-blue-500 mb-4"
                  placeholder="0"
                  autoFocus
                />

                {Number(costPrompt.currentCost) > 0 && (
                  <div className="space-y-4 border-t border-slate-100 dark:border-slate-700/50 pt-4 mt-2 animate-fade-in-up">
                    <div>
                      <label className="block text-xs font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1.5">ช่องทางการชำระเงิน</label>
                      <select required value={costPrompt.paymentMethod} onChange={(e) => setCostPrompt({...costPrompt, paymentMethod: e.target.value})} className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-300 p-2.5 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                        <option value="" disabled>-- เลือกช่องทาง --</option>
                        <option value="เงินโอน">เงินโอน</option>
                        <option value="เงินสด">เงินสด</option>
                      </select>
                    </div>
                    {costPrompt.paymentMethod === 'เงินโอน' && (
                      <div>
                        <label className="block text-xs font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1.5">แนบสลิป (ไม่บังคับ)</label>
                        <input type="file" accept="image/*" onChange={(e) => setCostPrompt({...costPrompt, slipFile: e.target.files[0]})} className="w-full text-sm text-slate-500 dark:text-slate-400 dark:text-slate-300 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-xs file:font-bold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100 cursor-pointer" />
                      </div>
                    )}
                  </div>
                )}
              </div>
              <div className="flex gap-3">
                <button onClick={() => setCostPrompt({ isOpen: false, id: null, currentCost: '', paymentMethod: '', slipFile: null })} type="button" className="flex-1 py-3 bg-slate-100 text-slate-700 dark:text-slate-200 font-bold rounded-xl text-sm hover:bg-slate-200 transition-colors">ยกเลิก</button>
                <button type="submit" className="flex-1 py-3 bg-blue-600 text-white font-bold rounded-xl text-sm hover:bg-blue-700 transition-colors shadow-md">ยืนยัน</button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}

    </div>
  );
}