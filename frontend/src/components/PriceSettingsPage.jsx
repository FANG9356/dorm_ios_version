import { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { API_URL } from '../config';
import ConfirmModal from './ConfirmModal';
export default function PriceSettingsPage({ addLog, showToast }) {
  const [roomTypes, setRoomTypes] = useState([]);
  const [rooms, setRooms] = useState([]); // [เพิ่มใหม่] ดึงข้อมูลห้องมาเพื่อเช็ก
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isEdit, setIsEdit] = useState(false);
  const [currentType, setCurrentType] = useState({ id: null, name: '', price: '', water_fee: '', electric_fee: '', common_fee: '', late_fee: '' });
  const [isSubmitting, setIsSubmitting] = useState(false); 
  const [confirmConfig, setConfirmConfig] = useState({ isOpen: false, id: null, name: '' });

  useEffect(() => {
    const handleEsc = (e) => {
      if (e.key === 'Escape' && isModalOpen) {
        setIsModalOpen(false);
      }
    };
    window.addEventListener('keydown', handleEsc);
    return () => window.removeEventListener('keydown', handleEsc);
  }, [isModalOpen]); 

  const fetchData = () => {
    fetch(`${API_URL}/room-types`).then(res => res.json()).then(data => setRoomTypes(data || []));
    fetch(`${API_URL}/rooms`).then(res => res.json()).then(data => setRooms(data || [])); // ดึงข้อมูลห้อง
  };

  useEffect(() => { fetchData(); }, []);

  const handleOpenAdd = () => {
    setIsEdit(false);
    setCurrentType({ id: null, name: '', price: '', water_fee: '', electric_fee: '', common_fee: '', late_fee: '' });
    setIsModalOpen(true);
  };

  const handleOpenEdit = (rt) => {
    setIsEdit(true);
    setCurrentType(rt);
    setIsModalOpen(true);
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    setIsSubmitting(true); 
    
    fetch(`${API_URL}/room-types`, { 
      method: isEdit ? 'PUT' : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...currentType, price: Number(currentType.price), water_fee: Number(currentType.water_fee || 0), electric_fee: Number(currentType.electric_fee || 0), common_fee: Number(currentType.common_fee || 0), late_fee: Number(currentType.late_fee || 0) }),
    }).then(async (res) => {
      if (!res.ok) {
        showToast('บันทึกไม่สำเร็จ (ชื่อประเภทอาจซ้ำกัน)', 'error'); 
      } else {
        addLog(isEdit ? 'Update' : 'Create', `${isEdit ? 'แก้ไข' : 'เพิ่ม'}ราคาห้องพัก: ${currentType.name} = ${currentType.price} บาท`);
        fetchData(); // โหลดใหม่ทั้งคู่
        setIsModalOpen(false);
        showToast('บันทึกราคาห้องพักเรียบร้อย', 'success'); 
      }
    }).finally(() => {
      setIsSubmitting(false); 
    });
  };

  const executeDelete = () => {
    const { id, name } = confirmConfig;
    setConfirmConfig({ ...confirmConfig, isOpen: false });
    fetch(`${API_URL}/room-types?id=${id}`, { method: 'DELETE' }).then(async (res) => { 
      if (!res.ok) {
        const text = await res.text();
        showToast(text || 'ลบไม่สำเร็จ', 'error');
        return;
      }
      addLog('Delete', `ลบประเภทห้องพัก: ${name}`);
      fetchData();
      showToast('ลบประเภทห้องพักสำเร็จ', 'success'); 
    });
  };

  const handleDelete = (id, name) => {
    // [เพิ่มใหม่] เช็กก่อนว่ามีห้องไหนใช้ประเภทนี้อยู่ไหม
    const isUsed = rooms.some(room => room.room_type === name);
    if (isUsed) {
      showToast(`ไม่สามารถลบได้! มีห้องพักที่กำลังใช้ประเภท "${name}" อยู่ในระบบ`, 'error');
      return;
    }
    setConfirmConfig({ isOpen: true, id, name });
  };

  return (
    <>
      <div className="animate-fade-in">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-6 gap-4">
          <p className="text-sm font-medium text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest underline decoration-blue-200 underline-offset-4">
            จัดการประเภทและราคาค่าเช่ามาตรฐาน
          </p>
          <button onClick={handleOpenAdd} className="self-end sm:self-auto w-[140px] h-[38px] shrink-0 bg-slate-900 text-white rounded-lg text-xs font-bold tracking-widest hover:bg-slate-800 transition-all shadow-md hover:shadow-lg hover:-translate-y-0.5 flex items-center justify-center">
            เพิ่มประเภทห้อง
          </button>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
          {roomTypes.map((rt) => (
            <div key={rt.id} className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-lg p-5 relative transition-all cursor-pointer hover:border-slate-300 hover:shadow-sm text-left group">
              <div className="flex justify-between items-start mb-3">
                <div className="font-mono text-2xl font-black text-slate-800 dark:text-slate-100">{rt.name}</div>
              </div>
              <div className="text-xs font-bold text-emerald-600 mb-2 uppercase tracking-wide">
                {rt.price.toLocaleString()} ฿ <span className="text-[10px] font-bold text-slate-400 dark:text-slate-300">/ เดือน</span>
              </div>
              
              <div className="flex gap-2 mt-1 pt-2 border-t border-slate-100 dark:border-slate-700/50">
                <button onClick={() => handleOpenEdit(rt)} className="flex-1 bg-slate-100 text-slate-600 dark:text-slate-300 py-2 rounded text-xs font-bold uppercase hover:bg-slate-200 transition-colors">
                  แก้ไขราคา
                </button>
                <button onClick={() => handleDelete(rt.id, rt.name)} className="bg-red-50 text-red-500 px-4 py-2 rounded text-xs font-bold uppercase hover:bg-red-100 transition-colors">
                  ลบทิ้ง
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {isModalOpen && createPortal(
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4 z-[9999] animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-xl w-full max-w-sm overflow-hidden border border-slate-200 dark:border-slate-700/50">
            <div className="bg-slate-50 dark:bg-slate-700/50 px-6 py-4 border-b border-slate-200 dark:border-slate-700/50 flex justify-between items-center">
              <h3 className="font-bold text-slate-800 dark:text-slate-100 tracking-wide uppercase">{isEdit ? 'แก้ไขราคาห้องพัก' : 'เพิ่มประเภทห้องใหม่'}</h3>
              <button onClick={() => setIsModalOpen(false)} className="text-slate-400 dark:text-slate-300 hover:text-slate-700 dark:text-slate-200 font-bold text-xl">&times;</button>
            </div>
            <form onSubmit={handleSubmit} className="p-8 space-y-6">
              <div>
                <label className="block text-xs font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-2 uppercase">ชื่อประเภทห้อง</label>
                <input required className="w-full bg-white dark:bg-slate-800 border border-slate-300 p-3 text-sm font-bold text-slate-800 dark:text-slate-100 focus:ring-2 focus:ring-blue-500 outline-none rounded-md transition-all" value={currentType.name} onChange={e => setCurrentType({...currentType, name: e.target.value})} placeholder="เช่น ห้องสวีท" />
              </div>
              <div>
                <label className="block text-xs font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-2 uppercase">ราคาค่าเช่ามาตรฐาน (บาท)</label>
                <input type="number" required className="w-full bg-white dark:bg-slate-800 border border-slate-300 p-3 text-2xl font-black font-mono text-emerald-600 focus:ring-2 focus:ring-blue-500 outline-none rounded-md transition-all" value={currentType.price} onChange={e => setCurrentType({...currentType, price: e.target.value})} placeholder="0" />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1.5 uppercase">ค่าน้ำมาตรฐาน</label>
                  <input type="number" className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 p-2.5 text-sm font-mono text-slate-700 dark:text-slate-200 focus:ring-2 focus:ring-blue-500 outline-none rounded-md transition-all" value={currentType.water_fee} onChange={e => setCurrentType({...currentType, water_fee: e.target.value})} placeholder="0" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1.5 uppercase">ค่าไฟมาตรฐาน</label>
                  <input type="number" className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 p-2.5 text-sm font-mono text-slate-700 dark:text-slate-200 focus:ring-2 focus:ring-blue-500 outline-none rounded-md transition-all" value={currentType.electric_fee} onChange={e => setCurrentType({...currentType, electric_fee: e.target.value})} placeholder="0" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1.5 uppercase">ค่าส่วนกลางมาตรฐาน</label>
                  <input type="number" className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 p-2.5 text-sm font-mono text-slate-700 dark:text-slate-200 focus:ring-2 focus:ring-blue-500 outline-none rounded-md transition-all" value={currentType.common_fee} onChange={e => setCurrentType({...currentType, common_fee: e.target.value})} placeholder="0" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1.5 uppercase">ค่าปรับล่าช้ามาตรฐาน</label>
                  <input type="number" className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 p-2.5 text-sm font-mono text-slate-700 dark:text-slate-200 focus:ring-2 focus:ring-blue-500 outline-none rounded-md transition-all" value={currentType.late_fee} onChange={e => setCurrentType({...currentType, late_fee: e.target.value})} placeholder="0" />
                </div>
              </div>
              <div className="flex gap-3 pt-2">
                <button type="button" disabled={isSubmitting} onClick={() => setIsModalOpen(false)} className="flex-1 bg-slate-100 text-slate-500 dark:text-slate-400 dark:text-slate-300 py-3 rounded-lg text-xs font-bold uppercase transition-all hover:bg-slate-200 disabled:opacity-50">ยกเลิก</button>
                <button type="submit" disabled={isSubmitting} className={`flex-1 text-white py-3 rounded-lg text-xs font-bold uppercase tracking-widest shadow-md transition-all ${isSubmitting ? 'bg-slate-400 cursor-not-allowed' : 'bg-blue-600 hover:bg-blue-700'}`}>
                  {isSubmitting ? 'รอสักครู่...' : 'บันทึกข้อมูล'}
                </button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}

      <ConfirmModal
        isOpen={confirmConfig.isOpen}
        title="ยืนยันการลบประเภทห้องพัก"
        message={`คุณยืนยันการลบประเภทห้อง [${confirmConfig.name}] ออกจากระบบใช่หรือไม่?`}
        onConfirm={executeDelete}
        onCancel={() => setConfirmConfig({ ...confirmConfig, isOpen: false })}
      />
    </>
  );
}