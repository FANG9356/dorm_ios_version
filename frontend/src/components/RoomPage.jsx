import { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { API_URL } from '../config';
import ConfirmModal from './ConfirmModal';
export default function RoomPage({ addLog, showToast }) { 
  const [allRooms, setAllRooms] = useState([]);
  const [orderedRooms, setOrderedRooms] = useState([]);
  const [draggedRoom, setDraggedRoom] = useState(null);

  const [users, setUsers] = useState([]);
  const [roomTypes, setRoomTypes] = useState([]);
  
  const [isRoomModalOpen, setIsRoomModalOpen] = useState(false);
  const [isEditRoom, setIsEditRoom] = useState(false);
  const [currentRoom, setCurrentRoom] = useState({ id: null, room_number: '', room_type: '' });
  const [isSubmitting, setIsSubmitting] = useState(false); 
  const [isLoading, setIsLoading] = useState(true);

  const [showDeleteBtnId, setShowDeleteBtnId] = useState(null);
  const [confirmConfig, setConfirmConfig] = useState({ isOpen: false, id: null, roomNumber: '' });

  useEffect(() => {
    const handleEsc = (e) => {
      if (e.key === 'Escape') {
        setIsRoomModalOpen(false);
        setConfirmConfig(prev => ({ ...prev, isOpen: false }));
      }
    };
    window.addEventListener('keydown', handleEsc, { capture: true });
    return () => window.removeEventListener('keydown', handleEsc, { capture: true });
  }, []);

  const fetchData = () => {
    return Promise.all([
      fetch(`${API_URL}/rooms`).then(res => res.json()).then(data => {
        const fetchedRooms = data || [];
        setAllRooms(fetchedRooms);
        
        const savedOrder = localStorage.getItem('dorminet_room_order');
        if (savedOrder && fetchedRooms.length > 0) {
          const idOrder = JSON.parse(savedOrder);
          fetchedRooms.sort((a, b) => {
            let indexA = idOrder.indexOf(a.id);
            let indexB = idOrder.indexOf(b.id);
            if (indexA === -1) indexA = 999;
            if (indexB === -1) indexB = 999;
            return indexA - indexB;
          });
        }
        setOrderedRooms(fetchedRooms);
      }),
      fetch(`${API_URL}/users`).then(res => res.json()).then(data => setUsers(data || [])),
      fetch(`${API_URL}/room-types`).then(res => res.json()).then(data => setRoomTypes(data || []))
    ]);
  };

  useEffect(() => { 
    setIsLoading(true);
    fetchData().finally(() => setTimeout(() => setIsLoading(false), 800));
  }, []);

  const handleDragStart = (e, index) => {
    setDraggedRoom(index);
    e.dataTransfer.effectAllowed = "move";
  };
  const handleDragEnter = (e, index) => {
    if (draggedRoom === null || draggedRoom === index) return;
    const newOrder = [...orderedRooms];
    const draggedItem = newOrder[draggedRoom];
    newOrder.splice(draggedRoom, 1);
    newOrder.splice(index, 0, draggedItem);
    setDraggedRoom(index);
    setOrderedRooms(newOrder);
  };
  const handleDragEnd = () => {
    setDraggedRoom(null);
    const ids = orderedRooms.map(r => r.id);
    localStorage.setItem('dorminet_room_order', JSON.stringify(ids));
  };

  const openAddRoom = () => {
    setIsEditRoom(false);
    setCurrentRoom({ id: null, room_number: '', room_type: '' }); 
    setIsRoomModalOpen(true);
  };
  
  const openEditRoom = (room) => {
    setIsEditRoom(true);
    setCurrentRoom(room);
    setIsRoomModalOpen(true);
  };

  const handleRoomSubmit = (e) => {
    e.preventDefault();
    setIsSubmitting(true); // [ล็อกปุ่ม]
    
    fetch(`${API_URL}/rooms`, { // [เปลี่ยนเป็น API_URL]
      method: isEditRoom ? 'PUT' : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(currentRoom),
    }).then(async (res) => {
      if(!res.ok) {
          showToast('เกิดข้อผิดพลาดในการบันทึก (หมายเลขห้องอาจซ้ำกัน)', 'error'); 
      }
      else { 
        addLog(isEditRoom ? 'Update' : 'Create', `${isEditRoom ? 'แก้ไขตั้งค่า' : 'เพิ่ม'}ห้องพัก [${currentRoom.room_number}]`);
        fetchData(); 
        setIsRoomModalOpen(false); 
        showToast('บันทึกข้อมูลห้องพักเรียบร้อย', 'success'); 
      }
    }).finally(() => {
      setIsSubmitting(false); // [ปลดล็อกปุ่ม]
    });
  };

  const executeDeleteRoom = () => {
    const { id, roomNumber } = confirmConfig;
    setConfirmConfig({ ...confirmConfig, isOpen: false });
    fetch(`${API_URL}/rooms?id=${id}`, { method: 'DELETE' }).then(async (res) => {
      if (!res.ok) {
        const text = await res.text();
        showToast(text || 'ลบไม่สำเร็จ', 'error');
        return;
      }
      addLog('Delete', `ลบห้องพัก [${roomNumber}] ออกจากระบบ`);
      setShowDeleteBtnId(null);
      fetchData();
      showToast('ลบห้องพักออกจากระบบสำเร็จ', 'success'); 
    });
  };

  const handleDeleteRoom = (id, roomNumber) => {
    setConfirmConfig({ isOpen: true, id, roomNumber });
  };

  const getRoomOccupancy = (roomNum) => users.find(u => u.room_number === roomNum && u.status === 'กำลังพักอาศัย') || null;

  return (
    <>
      <div className="animate-fade-in">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-6 gap-4">
          <p className="text-xs font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest">ระบบจัดการห้องพัก — {allRooms.length} ห้อง</p>
          <button onClick={openAddRoom} className="self-end sm:self-auto w-[140px] h-[38px] shrink-0 bg-slate-900 text-white rounded-lg text-xs font-bold tracking-widest hover:bg-slate-800 transition-all shadow-md hover:shadow-lg hover:-translate-y-0.5 flex items-center justify-center">
            เพิ่มห้องพัก
          </button>
        </div>
        
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
          {isLoading ? (
            Array.from({ length: 10 }).map((_, i) => (
              <div key={`skeleton-${i}`} className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-lg p-5">
                <div className="flex justify-between items-start mb-3">
                  <div className="h-8 bg-slate-200 rounded w-16 animate-pulse"></div>
                  <div className="h-5 bg-slate-200 rounded w-16 animate-pulse"></div>
                </div>
                <div className="h-4 bg-slate-200 rounded w-20 mb-2 animate-pulse"></div>
                <div className="h-3 bg-slate-200 rounded w-24 mt-3 animate-pulse"></div>
              </div>
            ))
          ) : orderedRooms.length === 0 ? (
            <div className="col-span-full py-20 flex flex-col items-center justify-center text-slate-400 dark:text-slate-300">
              <svg className="w-12 h-12 text-slate-300 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
              </svg>
              <span className="font-bold text-sm">ยังไม่มีข้อมูลห้องพักในระบบ</span>
            </div>
          ) : (
            orderedRooms.map((room, index) => {
            const occupant = getRoomOccupancy(room.room_number);
            return (
              <div 
                key={room.id} 
                draggable
                onDragStart={(e) => handleDragStart(e, index)}
                onDragEnter={(e) => handleDragEnter(e, index)}
                onDragEnd={handleDragEnd}
                onDragOver={(e) => e.preventDefault()}
                onClick={() => {
                  if (showDeleteBtnId === room.id) {
                    setShowDeleteBtnId(null);
                  } else {
                    openEditRoom(room);
                  }
                }}
                onContextMenu={(e) => {
                  e.preventDefault();
                  if (!occupant) setShowDeleteBtnId(room.id);
                }}
                onMouseLeave={() => setShowDeleteBtnId(null)}
                className={`bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-lg p-5 relative transition-all cursor-pointer hover:border-slate-300 hover:shadow-sm ${draggedRoom === index ? 'opacity-50 border-dashed border-blue-400' : ''}`}
              >
                <div className="flex justify-between items-start mb-3">
                  <div className="font-mono text-2xl font-black text-slate-800 dark:text-slate-100">{room.room_number}</div>
                  {!occupant && showDeleteBtnId === room.id ? (
                    <button 
                      onClick={(e) => { e.stopPropagation(); handleDeleteRoom(room.id, room.room_number); }} 
                      className="text-white bg-red-500 hover:bg-red-600 rounded px-2 py-1 text-[10px] font-bold shadow-sm transition-all animate-fade-in flex items-center gap-1" 
                    >
                      <svg className="w-3 h-3" fill="none" stroke="currentColor" strokeWidth="3" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
                      ลบห้อง
                    </button>
                  ) : (
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded border uppercase tracking-wider ${occupant ? 'text-slate-500 dark:text-slate-400 dark:text-slate-300 bg-slate-50 dark:bg-slate-700/50 border-slate-200 dark:border-slate-700/50' : 'text-emerald-600 bg-emerald-50 border-emerald-200'}`}>
                      {occupant ? 'มีผู้เช่า' : 'ห้องว่าง'}
                    </span>
                  )}
                </div>
                <div className="text-xs font-bold text-blue-600 mb-2 uppercase tracking-wide">{room.room_type}</div>
                <div className="text-xs text-slate-500 dark:text-slate-400 dark:text-slate-300 border-t border-slate-100 dark:border-slate-700/50 pt-2 mt-1">{occupant ? `${occupant.first_name} ${occupant.last_name || ''}` : 'พร้อมใช้งาน'}</div>
              </div>
            );
            })
          )}
        </div>
      </div>

      {isRoomModalOpen && createPortal(
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4 z-[9999] animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-lg shadow-xl w-full max-w-sm overflow-hidden border border-slate-200 dark:border-slate-700/50">
            <div className="bg-slate-50 dark:bg-slate-700/50 px-6 py-4 border-b border-slate-200 dark:border-slate-700/50 flex justify-between items-center">
              <h3 className="text-sm font-bold text-slate-800 dark:text-slate-100 uppercase tracking-widest">{isEditRoom ? 'แก้ไขห้องพัก' : 'เพิ่มห้องพักใหม่'}</h3>
              <button onClick={() => setIsRoomModalOpen(false)} className="text-slate-400 dark:text-slate-300 hover:text-slate-600 dark:text-slate-300 text-xl transition-colors">&times;</button>
            </div>
            <form onSubmit={handleRoomSubmit} className="p-6">
              <div className="mb-5">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1.5 uppercase tracking-widest">หมายเลขห้อง</label>
                <input required className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-lg font-mono font-black text-slate-800 dark:text-slate-100 focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none rounded transition-all" value={currentRoom.room_number} onChange={e => setCurrentRoom({...currentRoom, room_number: e.target.value})} placeholder="เช่น 101" />
              </div>
              <div className="mb-6">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1.5 uppercase tracking-widest">ประเภทห้อง</label>
                <select required className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm font-bold text-slate-700 dark:text-slate-200 focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none rounded transition-all" value={currentRoom.room_type} onChange={e => setCurrentRoom({...currentRoom, room_type: e.target.value})}>
                  <option value="" disabled>-- เลือกประเภท --</option>
                  {roomTypes.map(rt => (<option key={rt.id} value={rt.name}>{rt.name}</option>))}
                </select>
              </div>
              <div className="flex gap-3">
                <button type="button" disabled={isSubmitting} onClick={() => setIsRoomModalOpen(false)} className="flex-1 bg-slate-100 text-slate-600 dark:text-slate-300 py-2.5 rounded text-xs font-bold uppercase tracking-widest transition-colors hover:bg-slate-200 disabled:opacity-50">ยกเลิก</button>
                <button type="submit" disabled={isSubmitting} className={`flex-1 text-white py-2.5 rounded text-xs font-bold uppercase tracking-widest transition-colors ${isSubmitting ? 'bg-slate-400 cursor-not-allowed' : 'bg-slate-900 hover:bg-slate-800'}`}>
                  {isSubmitting ? 'กำลังบันทึก...' : 'บันทึกข้อมูล'}
                </button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}

      <ConfirmModal
        isOpen={confirmConfig.isOpen}
        title="ยืนยันการลบห้องพัก"
        message={
          <div className="space-y-2">
            <p>คุณยืนยันที่จะลบห้อง <span className="font-bold text-slate-800 dark:text-slate-100">[{confirmConfig.roomNumber}]</span> ออกจากระบบใช่หรือไม่?</p>
            <p className="text-red-600 font-medium">การกระทำนี้ไม่สามารถย้อนกลับได้</p>
          </div>
        }
        confirmText="ยืนยันการลบ"
        onConfirm={executeDeleteRoom}
        onCancel={() => setConfirmConfig({ ...confirmConfig, isOpen: false })}
        isDanger={true}
      />
    </>
  );
}