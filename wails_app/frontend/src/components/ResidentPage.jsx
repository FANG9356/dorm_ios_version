import { useState, useEffect } from 'react';
import { API_URL } from '../config';
import ConfirmModal from './ConfirmModal';

export default function ResidentPage({ addLog, showToast }) {
  const [users, setUsers] = useState([]);
  const [availableRooms, setAvailableRooms] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [roomTypes, setRoomTypes] = useState([]);
  const [activeTab, setActiveTab] = useState('all'); // 'all', 'active', 'booking', 'inactive'
  const [isLoading, setIsLoading] = useState(true);

  const [isResidentModalOpen, setIsResidentModalOpen] = useState(false);
  const [isEdit, setIsEdit] = useState(false);
  const [originalStatus, setOriginalStatus] = useState('');
  const [originalRoomNumber, setOriginalRoomNumber] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isDeleteConfirmOpen, setIsDeleteConfirmOpen] = useState(false);
  const [userToDelete, setUserToDelete] = useState(null);
  


  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);

  const [isUnmaskModalOpen, setIsUnmaskModalOpen] = useState(false);
  const [unmaskPassword, setUnmaskPassword] = useState('');
  const [unmaskError, setUnmaskError] = useState('');
  const [unmaskingUserId, setUnmaskingUserId] = useState(null);

  const [currentUser, setCurrentUser] = useState({ prefix: 'นาย', first_name: '', last_name: '', room_number: '', status: 'กำลังพักอาศัย', national_id: '', phone: '', address: '', move_in_date: '', contract_end_date: '', deposit: '', booking_status: '', payment_method: 'full_payment', indefinite_contract: 0, slip_files: [] });

  const [isMoveOutModalOpen, setIsMoveOutModalOpen] = useState(false);
  const [moveOutData, setMoveOutData] = useState({ original_deposit: 0, cleaning: 0, damage: 0 });

  const [sysModal, setSysModal] = useState({ isOpen: false, title: '', message: '', isAlert: false, isDanger: false, onConfirm: null, onCancel: null });

  const [searchTerm, setSearchTerm] = useState('');
  const [sortBy, setSortBy] = useState('room_asc'); 

  useEffect(() => {
    const handleEsc = (e) => {
      if (e.key === 'Escape') {
        if (sysModal.isOpen) {
          setSysModal(prev => ({ ...prev, isOpen: false }));
        } else if (isDeleteModalOpen) {
          setIsDeleteModalOpen(false);
          setUserToDelete(null);
        } else if (isMoveOutModalOpen) {
          setIsMoveOutModalOpen(false);
        } else if (isResidentModalOpen) {
          setIsResidentModalOpen(false);
        }
      }
    };
    window.addEventListener('keydown', handleEsc, { capture: true });
    return () => window.removeEventListener('keydown', handleEsc, { capture: true });
  }, [sysModal.isOpen, isDeleteModalOpen, isMoveOutModalOpen, isResidentModalOpen]);

  const fetchUsers = () => fetch(`${API_URL}/users`).then(res => res.json()).then(data => setUsers(data || []));
  const fetchAvailableRooms = () => fetch(`${API_URL}/rooms/available`).then(res => res.json()).then(data => setAvailableRooms(data || []));
  const fetchRoomsAndTypes = () => {
    return Promise.all([
      fetch(`${API_URL}/rooms`).then(res => res.json()).then(data => setRooms(data || [])),
      fetch(`${API_URL}/room-types`).then(res => res.json()).then(data => setRoomTypes(data || []))
    ]);
  };

  useEffect(() => { 
    setIsLoading(true);
    Promise.all([
      fetchUsers(), 
      fetchRoomsAndTypes()
    ]).finally(() => {
      setTimeout(() => setIsLoading(false), 800);
    });
  }, []);

  const getRoomPrice = (roomNumber) => {
    const room = rooms.find(r => r.room_number === roomNumber);
    if (!room) return 2500;
    const rType = roomTypes.find(rt => rt.name === room.room_type);
    return rType ? rType.price : 2500;
  };

  const openAddResident = () => {
    fetchAvailableRooms();
    setIsEdit(false);
    setOriginalStatus('กำลังพักอาศัย');
    setOriginalRoomNumber('');
    setCurrentUser({ prefix: 'นาย', first_name: '', last_name: '', room_number: '', status: 'กำลังพักอาศัย', national_id: '', phone: '', address: '', move_in_date: new Date().toISOString().split('T')[0], contract_end_date: '', deposit: '', booking_status: '', payment_method: 'full_payment', indefinite_contract: 0, slip_files: [], additional_appliances: '', additional_appliance_fee: '', additional_details: '' });
    setIsResidentModalOpen(true);
  };

  const openEditResident = (user) => {
    fetchAvailableRooms();
    setIsEdit(true);
    setOriginalStatus(user.status);
    setOriginalRoomNumber(user.room_number);
    setCurrentUser({ ...user, slip_files: [] });
    setIsResidentModalOpen(true);
  };

  const openDeleteModal = (user) => {
    setUserToDelete(user);
    setIsDeleteModalOpen(true);
  };

  const confirmDelete = () => {
    setIsSubmitting(true);
    fetch(`${API_URL}/users?id=${userToDelete.id}`, {
      method: 'DELETE',
    }).then(async (res) => {
      if (!res.ok) throw new Error('Delete failed');
      addLog('Delete', `ลบลูกบ้านห้อง ${userToDelete.room_number} (${userToDelete.first_name} ${userToDelete.last_name})`);
      fetchUsers();
      setIsDeleteModalOpen(false);
      setUserToDelete(null);
      showToast('ลบลูกบ้านสำเร็จ', 'success');
    }).catch((err) => {
      console.error(err);
      showToast('ไม่สามารถลบลูกบ้าน: ' + err.message, 'error');
    }).finally(() => {
      setIsSubmitting(false);
    });
  };

  const handleResidentSubmit = (e) => {
    e.preventDefault();
    if (currentUser.status === 'ย้ายออกแล้ว' && originalStatus !== 'ย้ายออกแล้ว') {
        setMoveOutData({ original_deposit: currentUser.deposit || 0, cleaning: 0, damage: 0 });
        setIsMoveOutModalOpen(true);
    } else {
        saveResidentData();
    }
  };

  const handleUnmaskSubmit = async () => {
    try {
      const res = await fetch(`${API_URL}/users/unmask-id`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id: unmaskingUserId, password: unmaskPassword })
      });
      if (!res.ok) {
        setUnmaskError('รหัสผ่านไม่ถูกต้อง');
        return;
      }
      const data = await res.json();
      setCurrentUser(prev => ({ ...prev, national_id: data.national_id }));
      setIsUnmaskModalOpen(false);
      setUnmaskPassword('');
      setUnmaskError('');
      showToast('ปลดล็อคเลขบัตรประชาชนแล้ว', 'success');
    } catch (err) {
      setUnmaskError('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  };

  const saveResidentData = () => {
    setIsSubmitting(true); 
    
    const dataToSave = {
      ...currentUser,
      deposit: Number(currentUser.deposit) || 0,
      additional_appliance_fee: Number(currentUser.additional_appliance_fee) || 0
    };
    
    // คำนวณยอดเงินจองชั่วคราว
    let bookingAmount = 0;
    const rentVal = getRoomPrice(currentUser.room_number);
    if (currentUser.status === 'จอง') {
      if (currentUser.payment_method === 'full_booking' || currentUser.payment_method === 'full_payment') {
        bookingAmount = rentVal;
      } else if (currentUser.payment_method === 'installment_3') {
        bookingAmount = rentVal / 2;
      }
    }
    
    let fetchOptions = {};
    if (currentUser.slip_files && currentUser.slip_files.length > 0) {
      const userForm = new FormData();
      userForm.append('data', JSON.stringify(dataToSave));
      currentUser.slip_files.forEach(file => {
        userForm.append('slips', file);
      });
      fetchOptions = {
        method: isEdit ? 'PUT' : 'POST',
        body: userForm,
      };
    } else {
      fetchOptions = {
        method: isEdit ? 'PUT' : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(dataToSave),
      };
    }

    fetch(`${API_URL}/users`, fetchOptions).then(async (res) => { 
      if (!res.ok) {
        const errorText = await res.text();
        throw new Error(errorText);
      }
      
      let savedUserId = currentUser.id;
      if (!isEdit) {
         try {
           const resJson = await res.clone().json();
           savedUserId = resJson.id;
         } catch(e) {
           console.error("Failed to parse user ID response", e);
         }
      }
      
      // อัปโหลดรูปสลิปจอง/มัดจำถ้ามีการแนบภาพ
      if (currentUser.slip_files && currentUser.slip_files.length > 0 && savedUserId) {
         const payForm = new FormData();
         payForm.append('user_id', savedUserId);
         payForm.append('room_number', currentUser.room_number);
         payForm.append('rent_fee', bookingAmount);
         // ใช้ยอด deposit ถ้ายอดจองเป็น 0 (เช่น กรณีสถานะไม่ใช่ จอง แต่เป็น กำลังพักอาศัย)
         const paymentAmount = bookingAmount > 0 ? bookingAmount : (Number(currentUser.deposit) || 0);
         payForm.append('amount', paymentAmount);
         payForm.append('month', new Date().toISOString().slice(0, 7));
         payForm.append('date', new Date().toISOString().split('T')[0]);
         payForm.append('method', 'เงินโอน (Transfer)');
         payForm.append('payment_plan', currentUser.payment_method);
         payForm.append('installment_phase', currentUser.payment_method === 'installment_3' ? '1' : '0');
         payForm.append('payment_status', 'paid');
         currentUser.slip_files.forEach(file => {
            payForm.append('slips', file);
         });
         
         await fetch(`${API_URL}/payments`, {
            method: 'POST',
            body: payForm
         }).then(pres => {
            if (!pres.ok) console.error("Booking slip upload failed");
         }).catch(perr => {
            console.error("Booking slip upload failed", perr);
         });
      }

      let logMsg = '';
      if (isEdit) {
         if (originalRoomNumber !== currentUser.room_number) {
            logMsg = `ย้ายห้องพัก: ${currentUser.first_name} จากห้อง ${originalRoomNumber} ไปยังห้อง ${currentUser.room_number}`;
         } else {
            logMsg = `อัปเดตข้อมูลห้อง ${currentUser.room_number} (${currentUser.first_name})`;
         }
      } else {
         logMsg = `ลงทะเบียนเข้าพัก: ห้อง ${currentUser.room_number} วางมัดจำ ${dataToSave.deposit} บาท`;
      }

      addLog(isEdit ? 'Update' : 'Create', logMsg);
      fetchUsers(); 
      setIsResidentModalOpen(false);
      showToast('บันทึกข้อมูลสำเร็จ', 'success');

      // [เพิ่มใหม่] แจ้งเตือนถามว่าต้องการพิมพ์บิลแรกเข้าหรือไม่ ถ้าเพิ่งเพิ่มผู้เช่าใหม่
      if (!isEdit && savedUserId && currentUser.status !== 'ย้ายออกแล้ว') {
        setSysModal({
          isOpen: true,
          title: 'เพิ่มผู้เช่าสำเร็จ',
          message: `เพิ่มผู้เช่าห้อง ${currentUser.room_number} เรียบร้อยแล้ว ต้องการไปที่หน้า "บิลค่าใช้จ่าย (เข้า-ออก)" เพื่อออกบิลแรกเข้าหรือไม่?`,
          isAlert: false,
          isDanger: false,
          onConfirm: () => {
            setSysModal(prev => ({ ...prev, isOpen: false }));
            window.history.pushState({}, '', `/?action=move_in&user_id=${savedUserId}`);
            window.dispatchEvent(new CustomEvent('change_menu', { detail: 'entry_exit' }));
          },
          onCancel: () => setSysModal(prev => ({ ...prev, isOpen: false }))
        });
      }
    }).catch((err) => {
      console.error(err);
      showToast('เกิดข้อผิดพลาดในการบันทึกข้อมูล: ' + err.message, 'error');
    }).finally(() => {
      setIsSubmitting(false); 
    });
  };

  const confirmMoveOut = () => {
    setIsSubmitting(true);
    const net = Number(moveOutData.original_deposit) - Number(moveOutData.cleaning) - Number(moveOutData.damage);
    
    fetch(`${API_URL}/move-out`, { 
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            user_id: currentUser.id,
            room_number: currentUser.room_number,
            original_deposit: Number(moveOutData.original_deposit),
            cleaning_fee: Number(moveOutData.cleaning),
            damage_fee: Number(moveOutData.damage),
            net_refund: net
        }),
    }).then(async (res) => {
        if (!res.ok) throw new Error("Move-out Transaction Failed");
        addLog('Move-out', `ลูกบ้านห้อง ${currentUser.room_number} ย้ายออก คืนเงินประกันสุทธิ: ${net} บาท`);
        
        fetchUsers(); 
        setIsMoveOutModalOpen(false);
        setIsResidentModalOpen(false); 
        showToast('ดำเนินการย้ายออกเสร็จสิ้น', 'success');

        // [เพิ่มใหม่] แจ้งเตือนถามว่าต้องการพิมพ์บิลย้ายออกหรือไม่
        setSysModal({
          isOpen: true,
          title: 'ย้ายออกสำเร็จ',
          message: `ดำเนินการย้ายออกห้อง ${currentUser.room_number} สำเร็จ ต้องการไปที่หน้า "บิลค่าใช้จ่าย (เข้า-ออก)" เพื่อพิมพ์ใบคืนเงินย้ายออกหรือไม่?`,
          isAlert: false,
          isDanger: false,
          onConfirm: () => {
            setSysModal(prev => ({ ...prev, isOpen: false }));
            window.history.pushState({}, '', `/?action=move_out&user_id=${currentUser.id}`);
            window.dispatchEvent(new CustomEvent('change_menu', { detail: 'entry_exit' }));
          },
          onCancel: () => setSysModal(prev => ({ ...prev, isOpen: false }))
        });
    }).catch(() => showToast('เกิดข้อผิดพลาดระหว่างการทำรายการ', 'error'))
      .finally(() => setIsSubmitting(false));
  };

  const calculateDuration = (start, end, isIndefinite = false) => {
    if (!start) return '-';
    const startDate = new Date(start); 
    const endDate = isIndefinite ? new Date() : (end ? new Date(end) : null);
    
    if (!endDate) return '-';
    
    if (!isIndefinite && endDate < startDate) return 'ข้อมูลไม่ถูกต้อง';
    if (isIndefinite && endDate < startDate) return 'ยังไม่ถึงวันเข้าอยู่';
    
    let years = endDate.getFullYear() - startDate.getFullYear();
    let months = endDate.getMonth() - startDate.getMonth();
    
    if (months < 0) { years -= 1; months += 12; }
    
    if (endDate.getDate() < startDate.getDate()) {
        months -= 1;
        if (months < 0) {
            years -= 1;
            months += 12;
        }
    }
    
    let result = [];
    if (years > 0) result.push(`${years} ปี`);
    if (months > 0) result.push(`${months} เดือน`);
    
    if (result.length === 0) {
        return isIndefinite ? 'เข้าอยู่ไม่ถึง 1 เดือน' : 'หมดสัญญา';
    }
    
    return isIndefinite ? `พักอาศัยแล้ว ${result.join(' ')}` : result.join(' ');
  };

  const formatPhone = (phone) => {
    if (!phone || phone.length !== 10) return phone || '-';
    return `${phone.slice(0,3)}-${phone.slice(3,6)}-${phone.slice(6)}`;
  };

  const filteredUsers = users.filter(user => 
    (user.room_number || '').toLowerCase().includes((searchTerm || '').toLowerCase()) ||
    (user.first_name || '').toLowerCase().includes((searchTerm || '').toLowerCase()) ||
    (user.last_name || '').toLowerCase().includes((searchTerm || '').toLowerCase()) ||
    (user.phone && user.phone.includes(searchTerm))
  );

  let tabFilteredUsers = filteredUsers;
  if (activeTab === 'active') {
    tabFilteredUsers = filteredUsers.filter(u => u.status === 'กำลังพักอาศัย');
  } else if (activeTab === 'booking') {
    tabFilteredUsers = filteredUsers.filter(u => u.status === 'จอง');
  } else if (activeTab === 'inactive') {
    tabFilteredUsers = filteredUsers.filter(u => u.status === 'ย้ายออกแล้ว');
  }

  let displayUsers = [...tabFilteredUsers];
  if (sortBy === 'room_asc') {
      displayUsers.sort((a, b) => a.room_number.localeCompare(b.room_number, undefined, {numeric: true}));
  } else if (sortBy === 'room_desc') {
      displayUsers.sort((a, b) => b.room_number.localeCompare(a.room_number, undefined, {numeric: true}));
  } else if (sortBy === 'status_active') {
      displayUsers.sort((a, b) => {
          if (a.status === b.status) return a.room_number.localeCompare(b.room_number, undefined, {numeric: true});
          return a.status === 'กำลังพักอาศัย' ? -1 : 1;
      });
  } else if (sortBy === 'status_inactive') {
      displayUsers.sort((a, b) => {
          if (a.status === b.status) return a.room_number.localeCompare(b.room_number, undefined, {numeric: true});
          return a.status === 'ย้ายออกแล้ว' ? -1 : 1;
      });
  }

  return (
    <>
      <div className="animate-fade-in">
        <div className="flex flex-col xl:flex-row justify-between items-end xl:items-center mb-6 gap-4">
          <div className="flex-1 w-full flex flex-col sm:flex-row gap-3">
            <input type="text" placeholder="ค้นหาเลขห้อง ชื่อ หรือเบอร์โทรศัพท์..." value={searchTerm} onChange={e => setSearchTerm(e.target.value)} className="w-full sm:w-80 bg-white dark:bg-slate-800 border border-slate-300 p-2.5 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 transition-all shadow-sm" />
            
            <div className="relative w-full sm:w-auto">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <svg className="w-4 h-4 text-slate-400 dark:text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z"></path></svg>
              </div>
              <select 
                value={sortBy} 
                onChange={e => setSortBy(e.target.value)} 
                className="w-full sm:w-48 appearance-none bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 text-slate-700 dark:text-slate-200 text-sm font-bold rounded-lg pl-9 pr-8 py-2.5 outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 hover:bg-slate-100 transition-colors cursor-pointer shadow-sm"
              >
                <option value="room_asc">เลขห้อง 1 - 9</option>
                <option value="room_desc">เลขห้อง 9 - 1</option>
                <option value="status_active">กำลังพักอาศัย</option>
                <option value="status_inactive">ย้ายออกแล้ว</option>
              </select>
              <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
                <svg className="w-4 h-4 text-slate-400 dark:text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7"></path></svg>
              </div>
            </div>

          </div>
          <button onClick={openAddResident} className="w-[140px] h-[38px] shrink-0 bg-slate-900 text-white rounded-lg text-xs font-bold tracking-widest hover:bg-slate-800 transition-all shadow-md hover:shadow-lg hover:-translate-y-0.5 flex items-center justify-center">
            เพิ่มลูกบ้านใหม่
          </button>
        </div>

        {/* Tabs คัดกรองกลุ่มผู้เช่า */}
        <div className="flex border-b border-slate-200 dark:border-slate-700/50 mb-6 overflow-x-auto gap-2 scrollbar-none">
          <button 
            type="button"
            onClick={() => setActiveTab('all')} 
            className={`px-5 py-2.5 text-xs font-bold uppercase tracking-widest border-b-2 transition-all whitespace-nowrap ${activeTab === 'all' ? 'border-blue-600 text-blue-600' : 'border-transparent text-slate-500 dark:text-slate-400 dark:text-slate-300 hover:text-slate-800 dark:text-slate-100'}`}
          >
            ทั้งหมด ({users.length})
          </button>
          <button 
            type="button"
            onClick={() => setActiveTab('active')} 
            className={`px-5 py-2.5 text-xs font-bold uppercase tracking-widest border-b-2 transition-all whitespace-nowrap ${activeTab === 'active' ? 'border-emerald-600 text-emerald-600' : 'border-transparent text-slate-500 dark:text-slate-400 dark:text-slate-300 hover:text-slate-800 dark:text-slate-100'}`}
          >
            กำลังพักอาศัย ({users.filter(u => u.status === 'กำลังพักอาศัย').length})
          </button>
          <button 
            type="button"
            onClick={() => setActiveTab('booking')} 
            className={`px-5 py-2.5 text-xs font-bold uppercase tracking-widest border-b-2 transition-all whitespace-nowrap ${activeTab === 'booking' ? 'border-amber-500 text-amber-500' : 'border-transparent text-slate-500 dark:text-slate-400 dark:text-slate-300 hover:text-slate-800 dark:text-slate-100'}`}
          >
            จอง ({users.filter(u => u.status === 'จอง').length})
          </button>
          <button 
            type="button"
            onClick={() => setActiveTab('inactive')} 
            className={`px-5 py-2.5 text-xs font-bold uppercase tracking-widest border-b-2 transition-all whitespace-nowrap ${activeTab === 'inactive' ? 'border-orange-500 text-orange-500' : 'border-transparent text-slate-500 dark:text-slate-400 dark:text-slate-300 hover:text-slate-800 dark:text-slate-100'}`}
          >
            ย้ายออกแล้ว ({users.filter(u => u.status === 'ย้ายออกแล้ว').length})
          </button>
        </div>

        <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-xl shadow-sm overflow-hidden">
          {/* Desktop Table View */}
          <div className="hidden lg:block overflow-x-auto">
            <table className="w-full text-left border-collapse min-w-[1000px]">
            <thead>
              <tr className="bg-slate-50 dark:bg-slate-700/50 border-b border-slate-200 dark:border-slate-700/50 text-xs text-slate-500 dark:text-slate-400 dark:text-slate-300 font-bold uppercase tracking-wider">
                <th className="py-4 px-6 whitespace-nowrap">ห้องพัก</th><th className="py-4 px-6 whitespace-nowrap">ชื่อ - นามสกุล</th><th className="py-4 px-6 whitespace-nowrap">เบอร์โทรศัพท์</th><th className="py-4 px-6 whitespace-nowrap">ระยะเวลาสัญญา</th><th className="py-4 px-6 w-36 whitespace-nowrap">สถานะผู้เช่า</th><th className="py-4 px-6 text-right w-24">จัดการ</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-sm">
              {isLoading ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <tr key={`skeleton-${i}`}>
                    <td className="py-4 px-6"><div className="h-6 bg-slate-200 rounded w-16 animate-pulse"></div></td>
                    <td className="py-4 px-6"><div className="h-5 bg-slate-200 rounded w-32 animate-pulse"></div></td>
                    <td className="py-4 px-6"><div className="h-4 bg-slate-200 rounded w-24 animate-pulse"></div></td>
                    <td className="py-4 px-6"><div className="h-4 bg-slate-200 rounded w-36 animate-pulse"></div></td>
                    <td className="py-4 px-6"><div className="h-6 bg-slate-200 rounded w-20 animate-pulse"></div></td>
                    <td className="py-4 px-6 text-right"><div className="h-6 bg-slate-200 rounded w-16 ml-auto animate-pulse"></div></td>
                  </tr>
                ))
              ) : displayUsers.length === 0 ? (
                <tr><td colSpan="6" className="py-12 text-center text-slate-400 dark:text-slate-300">
                  <div className="flex flex-col items-center justify-center space-y-3">
                    <svg className="w-12 h-12 text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                    </svg>
                    <span className="font-bold text-sm">ไม่พบข้อมูลลูกบ้าน</span>
                  </div>
                </td></tr>
              ) : (
                displayUsers.map((user) => {
                  const isMovedOut = user.status === 'ย้ายออกแล้ว';
                  
                  return (
                    <tr key={user.id} className={`transition-all duration-200 group cursor-pointer ${isMovedOut ? 'bg-orange-50/50 hover:bg-orange-100/70' : 'hover:bg-blue-50/50 hover:shadow-sm'}`}>
                      <td className={`py-4 px-6 font-mono font-bold text-lg whitespace-nowrap transition-colors ${isMovedOut ? 'text-orange-700' : 'text-slate-800 dark:text-slate-100 group-hover:text-blue-600'}`}>{user.room_number}</td>
                      <td className={`py-4 px-6 font-semibold whitespace-nowrap ${isMovedOut ? 'text-slate-500 dark:text-slate-400 dark:text-slate-300' : 'text-slate-900 dark:text-slate-100'}`}>{user.prefix}{user.first_name} {user.last_name}</td>
                      <td className={`py-4 px-6 font-mono whitespace-nowrap ${isMovedOut ? 'text-slate-400 dark:text-slate-300' : 'text-slate-600 dark:text-slate-300'}`}>{formatPhone(user.phone)}</td>
                      <td className="py-4 px-6 whitespace-nowrap">
                        <div className={`font-mono text-xs ${isMovedOut ? 'text-slate-400 dark:text-slate-300' : 'text-slate-600 dark:text-slate-300'}`}>{user.move_in_date || '-'} <span className="text-slate-400 dark:text-slate-300 mx-1">ถึง</span> {user.indefinite_contract === 1 ? 'ไม่มีกำหนด' : (user.contract_end_date || '-')}</div>
                        <div className={`text-[10px] font-bold mt-1 inline-block px-2 py-0.5 rounded border tracking-wide ${isMovedOut ? 'text-orange-600 bg-orange-100/50 border-orange-200' : 'text-blue-600 bg-blue-50 border-blue-100'}`}>
                          {calculateDuration(user.move_in_date, user.contract_end_date, user.indefinite_contract === 1)}
                        </div>
                      </td>
                      <td className="py-4 px-6 whitespace-nowrap"><span className={`px-2.5 py-1 rounded text-xs font-bold border ${isMovedOut ? 'bg-slate-100 text-slate-500 dark:text-slate-400 dark:text-slate-300 border-slate-300' : 'bg-emerald-50 text-emerald-700 border-emerald-200'}`}>{user.status}</span></td>
                      <td className="py-4 px-6 text-right">
                        <div className="flex justify-end items-center gap-2">
                          <button onClick={() => openEditResident(user)} className="text-slate-600 dark:text-slate-300 font-bold text-xs hover:text-blue-600 transition-colors uppercase tracking-widest bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 px-3 py-1 rounded shadow-sm hover:bg-blue-50">แก้ไข</button>
                          {isMovedOut && (
                            <button onClick={() => openDeleteModal(user)} className="text-slate-400 dark:text-slate-300 hover:text-red-600 transition-colors w-7 h-7 flex items-center justify-center rounded-full hover:bg-red-50" title="ลบข้อมูล">
                              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" />
                              </svg>
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
          </div>

          {/* Mobile Card View */}
          <div className="lg:hidden flex flex-col divide-y divide-slate-100 dark:divide-slate-700/50">
            {isLoading ? (
              Array.from({ length: 5 }).map((_, i) => (
                <div key={`mob-skeleton-${i}`} className="p-4 flex flex-col gap-3">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 bg-slate-200 dark:bg-slate-700 rounded-xl animate-pulse"></div>
                    <div className="flex-1 space-y-2">
                      <div className="h-5 bg-slate-200 dark:bg-slate-700 rounded w-32 animate-pulse"></div>
                      <div className="h-4 bg-slate-200 dark:bg-slate-700 rounded w-24 animate-pulse"></div>
                    </div>
                  </div>
                </div>
              ))
            ) : displayUsers.length === 0 ? (
              <div className="py-12 text-center text-slate-400 dark:text-slate-300">
                <div className="flex flex-col items-center justify-center space-y-3">
                  <svg className="w-12 h-12 text-slate-300 dark:text-slate-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                  </svg>
                  <span className="font-bold text-sm">ไม่พบข้อมูลลูกบ้าน</span>
                </div>
              </div>
            ) : (
              displayUsers.map((user) => {
                const isMovedOut = user.status === 'ย้ายออกแล้ว';
                
                return (
                  <div 
                    key={user.id} 
                    onClick={() => openEditResident(user)} 
                    className={`p-4 flex flex-col gap-3 transition-all cursor-pointer ${isMovedOut ? 'bg-orange-50/30 dark:bg-orange-900/10' : 'hover:bg-blue-50/50 active:bg-blue-50 dark:hover:bg-blue-900/10 dark:active:bg-blue-900/20'}`}
                  >
                    <div className="flex justify-between items-start">
                      <div className="flex items-center gap-3">
                        <div className={`w-12 h-12 rounded-xl flex items-center justify-center font-mono font-bold text-lg shadow-sm border ${isMovedOut ? 'bg-orange-100 text-orange-700 border-orange-200 dark:bg-orange-900/30 dark:border-orange-800' : 'bg-blue-50 text-blue-700 border-blue-100 dark:bg-blue-900/30 dark:text-blue-400 dark:border-blue-800'}`}>
                          {user.room_number}
                        </div>
                        <div>
                          <h3 className={`font-bold text-sm sm:text-base ${isMovedOut ? 'text-slate-500 dark:text-slate-400' : 'text-slate-900 dark:text-slate-100'}`}>
                            {user.prefix}{user.first_name} {user.last_name}
                          </h3>
                          <p className="font-mono text-xs sm:text-sm text-slate-500 dark:text-slate-400">{formatPhone(user.phone)}</p>
                        </div>
                      </div>
                      <span className={`px-2 py-1 rounded text-[10px] sm:text-xs font-bold border ${isMovedOut ? 'bg-slate-100 text-slate-500 border-slate-300 dark:bg-slate-700 dark:border-slate-600' : 'bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-900/30 dark:text-emerald-400 dark:border-emerald-800'}`}>
                        {user.status}
                      </span>
                    </div>
                    
                    <div className="flex justify-between items-end mt-1">
                      <div className="flex flex-col gap-1">
                        <span className="text-[10px] text-slate-400 dark:text-slate-500 font-semibold uppercase tracking-wider">ระยะเวลาสัญญา</span>
                        <div className={`font-mono text-xs ${isMovedOut ? 'text-slate-400 dark:text-slate-500' : 'text-slate-600 dark:text-slate-300'}`}>
                          {user.move_in_date || '-'} <span className="mx-0.5 opacity-50">ถึง</span> {user.indefinite_contract === 1 ? 'ไม่มีกำหนด' : (user.contract_end_date || '-')}
                        </div>
                        <div className={`text-[10px] font-bold inline-block px-2 py-0.5 rounded border tracking-wide w-max ${isMovedOut ? 'text-orange-600 bg-orange-100/50 border-orange-200 dark:bg-orange-900/30 dark:border-orange-800' : 'text-blue-600 bg-blue-50 border-blue-100 dark:bg-blue-900/30 dark:text-blue-400 dark:border-blue-800'}`}>
                          {calculateDuration(user.move_in_date, user.contract_end_date, user.indefinite_contract === 1)}
                        </div>
                      </div>
                      
                      {isMovedOut && (
                        <button 
                          onClick={(e) => { e.stopPropagation(); openDeleteModal(user); }} 
                          className="text-slate-400 dark:text-slate-500 hover:text-red-600 dark:hover:text-red-400 w-8 h-8 flex items-center justify-center rounded-full bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600"
                        >
                          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
                        </button>
                      )}
                    </div>
                  </div>
                )
              })
            )}
          </div>
        </div>
      </div>

      {isResidentModalOpen && !isMoveOutModalOpen && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4 z-50 animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-lg shadow-xl w-full max-w-3xl overflow-hidden border border-slate-200 dark:border-slate-700/50 flex flex-col">
            <div className="bg-slate-50 dark:bg-slate-700/50 px-6 py-4 border-b border-slate-200 dark:border-slate-700/50 flex-shrink-0"><h3 className="font-bold text-slate-800 dark:text-slate-100 text-sm uppercase tracking-widest">{isEdit ? 'แก้ไขข้อมูลลูกบ้าน' : 'ลงทะเบียนลูกบ้านใหม่'}</h3></div>
            <form onSubmit={handleResidentSubmit} className="flex flex-col overflow-hidden max-h-[85vh]">
              <div className="p-4 md:p-6 grid grid-cols-1 md:grid-cols-6 gap-4 md:gap-5 overflow-y-auto overflow-x-hidden w-full">
                <div className="col-span-1 md:col-span-6 border-b border-slate-100 dark:border-slate-700/50 pb-2 mb-1"><h4 className="text-[11px] font-bold text-slate-800 dark:text-slate-100 uppercase tracking-widest">ข้อมูลส่วนตัว</h4></div>
              
              <div className="col-span-1 md:col-span-1">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1 uppercase tracking-wider">คำนำหน้า</label>
                <select className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm rounded outline-none focus:ring-2 focus:ring-blue-500 transition-all" value={currentUser.prefix} onChange={e => setCurrentUser({...currentUser, prefix: e.target.value})}><option>นาย</option><option>นาง</option><option>นางสาว</option></select>
              </div>
              <div className="col-span-1 md:col-span-2">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1 uppercase tracking-wider">ชื่อ</label>
                <input required className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm rounded outline-none focus:ring-2 focus:ring-blue-500 transition-all" value={currentUser.first_name} onChange={e => setCurrentUser({...currentUser, first_name: e.target.value.replace(/[0-9]/g, '')})} />
              </div>
              <div className="col-span-1 md:col-span-3">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1 uppercase tracking-wider">นามสกุล</label>
                <input required className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm rounded outline-none focus:ring-2 focus:ring-blue-500 transition-all" value={currentUser.last_name} onChange={e => setCurrentUser({...currentUser, last_name: e.target.value.replace(/[0-9]/g, '')})} />
              </div>
              
              <div className="col-span-1 md:col-span-3">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1 uppercase tracking-wider">เลขบัตรประชาชน</label>
                <div className="relative">
                  <input required maxLength="17" pattern="^([0-9]{13}|[xX\-0-9]{13,17})$" title="กรุณากรอกตัวเลข 13 หลัก หรือข้อมูลเดิม" className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm font-mono rounded outline-none focus:ring-2 focus:ring-blue-500 transition-all pr-10" value={currentUser.national_id} onChange={e => setCurrentUser({...currentUser, national_id: e.target.value.replace(/[^0-9xX\-]/g, '')})} />
                  {isEdit && currentUser.national_id && currentUser.national_id.includes('X') && (
                    <button type="button" onClick={() => { setUnmaskingUserId(currentUser.id); setIsUnmaskModalOpen(true); }} className="absolute inset-y-0 right-0 px-3 flex items-center text-slate-400 dark:text-slate-300 hover:text-blue-600 transition-colors" title="แสดงเลขบัตรประชาชน">
                      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                      </svg>
                    </button>
                  )}
                </div>
              </div>
              <div className="col-span-1 md:col-span-3">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1 uppercase tracking-wider">เบอร์โทรศัพท์</label>
                <input required maxLength="10" pattern="[0-9]{10}" title="กรุณากรอกตัวเลขเบอร์โทร 10 หลักเท่านั้น" className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm font-mono rounded outline-none focus:ring-2 focus:ring-blue-500 transition-all" value={currentUser.phone} onChange={e => setCurrentUser({...currentUser, phone: e.target.value.replace(/[^0-9]/g, '')})} />
              </div>
              
              <div className="col-span-1 md:col-span-6 border-b border-slate-100 dark:border-slate-700/50 pb-2 mt-4 mb-1"><h4 className="text-[11px] font-bold text-slate-800 dark:text-slate-100 uppercase tracking-widest">ข้อมูลสัญญาเช่า</h4></div>
              
              <div className="col-span-1 md:col-span-2">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1 uppercase tracking-wider">หมายเลขห้อง</label>
                <select required className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm font-mono font-bold text-slate-800 dark:text-slate-100 rounded outline-none focus:ring-2 focus:ring-blue-500 transition-all" value={currentUser.room_number} onChange={e => setCurrentUser({...currentUser, room_number: e.target.value})}>
                  <option value="" disabled>-- เลือกห้อง --</option>
                  {isEdit && <option value={originalRoomNumber}>{originalRoomNumber} (ห้องเดิม)</option>}
                  {availableRooms.map(room => (<option key={room.id} value={room.room_number}>{room.room_number} - {room.room_type}</option>))}
                </select>
              </div>
              <div className="col-span-1 md:col-span-2">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1 uppercase tracking-wider">วันที่ทำสัญญา</label>
                <input type="date" required className="w-full min-w-0 appearance-none block bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm font-mono rounded outline-none focus:ring-2 focus:ring-blue-500 transition-all" value={currentUser.move_in_date} onChange={e => setCurrentUser({...currentUser, move_in_date: e.target.value})} />
              </div>
              <div className="col-span-1 md:col-span-2">
                <div className="flex justify-between items-center mb-1">
                  <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-wider">วันสิ้นสุดสัญญา</label>
                  <label className="flex items-center gap-1.5 text-[9px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest cursor-pointer hover:text-slate-700 dark:text-slate-200">
                    <input type="checkbox" checked={currentUser.indefinite_contract === 1} onChange={e => setCurrentUser({...currentUser, indefinite_contract: e.target.checked ? 1 : 0, contract_end_date: e.target.checked ? '' : currentUser.contract_end_date})} className="w-3 h-3 rounded border-slate-300 text-blue-600 focus:ring-blue-500" />
                    ไม่ระบุ
                  </label>
                </div>
                {currentUser.indefinite_contract === 1 ? (
                  <div className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 px-3 py-2.5 text-sm rounded text-slate-400 dark:text-slate-300 font-mono text-center flex items-center justify-center">ไม่มีกำหนด</div>
                ) : (
                  <input type="date" required={currentUser.indefinite_contract === 0} className="w-full min-w-0 appearance-none block bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm font-mono rounded outline-none focus:ring-2 focus:ring-blue-500 transition-all" value={currentUser.contract_end_date} onChange={e => setCurrentUser({...currentUser, contract_end_date: e.target.value})} />
                )}
              </div>

              {currentUser.status === 'จอง' && (() => {
                const rRent = getRoomPrice(currentUser.room_number);
                const hRent = rRent / 2;
                const depVal = Number(currentUser.deposit) || rRent;
                
                return (
                  <div className="col-span-1 md:col-span-6 border border-amber-200 bg-amber-50 p-5 rounded space-y-4">
                    <h4 className="text-xs font-bold text-amber-900 uppercase tracking-widest">ตัวเลือกการชำระเงินและผ่อนชำระ (จองที่พัก)</h4>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <label className={`flex items-start gap-3 p-3 border rounded cursor-pointer bg-white dark:bg-slate-800 transition-all hover:bg-slate-50 dark:bg-slate-700/50 ${currentUser.payment_method === 'full_booking' || currentUser.payment_method === 'full_payment' ? 'border-amber-400 ring-1 ring-amber-400' : 'border-slate-200 dark:border-slate-700/50'}`}>
                        <input 
                          type="radio" 
                          name="payment_method" 
                          value="full_booking" 
                          checked={currentUser.payment_method === 'full_booking' || currentUser.payment_method === 'full_payment'} 
                          onChange={e => setCurrentUser({...currentUser, payment_method: e.target.value})} 
                          className="w-3.5 h-3.5 mt-1 text-amber-600 focus:ring-amber-500" 
                        />
                        <div className="flex-1">
                          <div className="font-bold text-slate-800 dark:text-slate-100 text-[11px] uppercase tracking-wider">แบบที่ 1: จองจ่ายเต็มจำนวน</div>
                          <div className="text-[10px] font-mono text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-1 space-y-0.5">
                            <div>• ตอนจองจ่ายมัดจำ/ประกัน: <strong className="text-slate-800 dark:text-slate-100">{depVal.toLocaleString()} บาท</strong></div>
                            <div>• วันเข้าอยู่จ่ายค่าห้องเต็ม: <strong className="text-slate-800 dark:text-slate-100">{rRent.toLocaleString()} บาท</strong></div>
                          </div>
                        </div>
                      </label>

                      <label className={`flex items-start gap-3 p-3 border rounded cursor-pointer bg-white dark:bg-slate-800 transition-all hover:bg-slate-50 dark:bg-slate-700/50 ${currentUser.payment_method === 'installment_3' ? 'border-amber-400 ring-1 ring-amber-400' : 'border-slate-200 dark:border-slate-700/50'}`}>
                        <input 
                          type="radio" 
                          name="payment_method" 
                          value="installment_3" 
                          checked={currentUser.payment_method === 'installment_3'} 
                          onChange={e => setCurrentUser({...currentUser, payment_method: e.target.value})} 
                          className="w-3.5 h-3.5 mt-1 text-amber-600 focus:ring-amber-500" 
                        />
                        <div className="flex-1">
                          <div className="font-bold text-slate-800 dark:text-slate-100 text-[11px] uppercase tracking-wider">แบบที่ 2: แบ่งชำระ 3 รอบ</div>
                          <div className="text-[10px] font-mono text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-1 space-y-0.5">
                            <div>• รอบ 1 (วันจอง): จ่ายค่าห้องครึ่งหนึ่ง <strong className="text-slate-800 dark:text-slate-100">{hRent.toLocaleString()} บาท</strong></div>
                            <div>• รอบ 2 (วันเข้าอยู่): จ่ายมัดจำ/ประกัน <strong className="text-slate-800 dark:text-slate-100">{depVal.toLocaleString()} บาท</strong></div>
                            <div>• รอบ 3 (ตามกำหนด): จ่ายค่าห้องส่วนที่เหลือ <strong className="text-slate-800 dark:text-slate-100">{hRent.toLocaleString()} บาท</strong></div>
                          </div>
                        </div>
                      </label>
                    </div>

                    {currentUser.payment_method === 'installment_3' && (
                      <div className="p-3 bg-amber-100/60 rounded border border-amber-200 animate-fade-in space-y-3">
                        <div className="text-[10px] font-bold text-amber-800 uppercase tracking-widest border-b border-amber-200/50 pb-2">
                          กำหนดวันชำระรอบที่ 3 (ค่าห้องส่วนที่เหลือ)
                        </div>
                        <label className="flex items-center gap-2 cursor-pointer text-slate-700 dark:text-slate-200 text-[10px] font-bold uppercase tracking-wider">
                          <input 
                            type="radio" 
                            name="installment_3_date_type"
                            checked={currentUser.booking_status !== 'negotiated'} 
                            onChange={() => setCurrentUser({...currentUser, booking_status: 'default'})} 
                            className="w-3.5 h-3.5 text-amber-600 focus:ring-amber-500" 
                          />
                          <span>ไม่เกินวันที่ 15 ของเดือน (ค่าเริ่มต้น)</span>
                        </label>
                        
                        <label className="flex items-center gap-2 cursor-pointer text-slate-700 dark:text-slate-200 text-[10px] font-bold uppercase tracking-wider">
                          <input 
                            type="radio" 
                            name="installment_3_date_type"
                            checked={currentUser.booking_status === 'negotiated'} 
                            onChange={() => setCurrentUser({...currentUser, booking_status: 'negotiated'})} 
                            className="w-3.5 h-3.5 text-amber-600 focus:ring-amber-500" 
                          />
                          <span>ต่อรองวันที่ชำระใหม่ (ระบุวันที่)</span>
                        </label>
                        
                        {currentUser.booking_status === 'negotiated' && (
                          <div className="pl-6 pt-1 animate-fade-in">
                            <input 
                              type="date" 
                              className="w-full min-w-0 appearance-none block bg-white dark:bg-slate-800 border border-amber-200 px-3 py-2 rounded-md font-mono text-xs focus:ring-2 focus:ring-amber-500 outline-none transition-all text-slate-700 dark:text-slate-200"
                              value={currentUser.installment_3_date || ''}
                              onChange={e => setCurrentUser({...currentUser, installment_3_date: e.target.value})}
                            />
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                );
              })()}

              <div className="col-span-1 md:col-span-6 border-b border-slate-100 dark:border-slate-700/50 pb-2 mt-4 mb-1"><h4 className="text-[11px] font-bold text-slate-800 dark:text-slate-100 uppercase tracking-widest">ข้อมูลเพิ่มเติม / บริการเสริม</h4></div>
              
              <div className="col-span-1 md:col-span-4">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1 uppercase tracking-wider">เครื่องใช้ไฟฟ้าเพิ่มเติม (เช่น ตู้เย็น, ทีวี)</label>
                <input className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm rounded outline-none focus:ring-2 focus:ring-blue-500 transition-all" value={currentUser.additional_appliances || ''} onChange={e => setCurrentUser({...currentUser, additional_appliances: e.target.value})} placeholder="ถ้าไม่มีให้เว้นว่างไว้" />
              </div>
              <div className="col-span-1 md:col-span-2">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1 uppercase tracking-wider">ค่าเครื่องใช้ไฟฟ้า/เดือน (บาท)</label>
                <input type="number" className="w-full min-w-0 appearance-none block bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm font-mono rounded outline-none focus:ring-2 focus:ring-blue-500 transition-all" value={currentUser.additional_appliance_fee || ''} onChange={e => setCurrentUser({...currentUser, additional_appliance_fee: e.target.value})} placeholder="0" />
              </div>
              
              <div className="col-span-1 md:col-span-6">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1 uppercase tracking-wider">รายละเอียดเพิ่มเติม (หมายเหตุ)</label>
                <input className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm rounded outline-none focus:ring-2 focus:ring-blue-500 transition-all" value={currentUser.additional_details || ''} onChange={e => setCurrentUser({...currentUser, additional_details: e.target.value})} placeholder="ข้อมูลอื่นๆ เช่น ทะเบียนรถ, ผู้ติดต่อฉุกเฉิน..." />
              </div>

              <div className="col-span-1 md:col-span-3 mt-2">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1 uppercase tracking-wider">เงินประกัน / ค่ามัดจำ (บาท)</label>
                <div className="flex gap-2">
                  <input type="number" required className="flex-1 min-w-0 appearance-none block bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm font-mono rounded outline-none focus:ring-2 focus:ring-blue-500 transition-all" value={currentUser.deposit} onChange={e => setCurrentUser({...currentUser, deposit: e.target.value})} placeholder="0" />
                  <label className="flex-shrink-0 cursor-pointer bg-slate-100 hover:bg-slate-200 border border-slate-300 text-slate-600 dark:text-slate-300 px-3 py-2.5 rounded text-[10px] font-bold uppercase tracking-widest transition-colors flex items-center justify-center gap-1">
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" /></svg>
                    แนบสลิป {currentUser.slip_files && currentUser.slip_files.length > 0 && `(${currentUser.slip_files.length})`}
                    <input type="file" multiple accept="image/*" className="hidden" onChange={e => setCurrentUser({...currentUser, slip_files: Array.from(e.target.files)})} />
                  </label>
                </div>
              </div>

              <div className="col-span-1 md:col-span-3">
                <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-1 uppercase tracking-wider">สถานะผู้เช่า</label>
                <select className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm font-bold rounded outline-none focus:ring-2 focus:ring-blue-500 transition-all" value={currentUser.status} onChange={e => setCurrentUser({...currentUser, status: e.target.value})}>
                  <option value="กำลังพักอาศัย">กำลังพักอาศัย</option>
                  <option value="จอง">จอง</option>
                  <option value="ย้ายออกแล้ว" className="text-red-600">ย้ายออกแล้ว</option>
                </select>
              </div>
              </div>
              <div className="flex-shrink-0 bg-slate-50 dark:bg-slate-800/80 px-6 py-4 flex gap-3 border-t border-slate-200 dark:border-slate-700/50">
                <button type="button" disabled={isSubmitting} onClick={() => setIsResidentModalOpen(false)} className="flex-1 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-200 py-2.5 rounded text-xs font-bold uppercase tracking-widest hover:bg-slate-50 dark:hover:bg-slate-600 transition-colors disabled:opacity-50 shadow-sm">ยกเลิก</button>
                <button type="submit" disabled={isSubmitting} className={`flex-1 text-white py-2.5 rounded text-xs font-bold uppercase tracking-widest transition-all shadow-sm ${isSubmitting ? 'bg-slate-400 cursor-not-allowed' : 'bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600'}`}>
                  {isSubmitting ? 'กำลังบันทึก...' : 'บันทึกข้อมูล'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {isMoveOutModalOpen && (
          <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4 z-[100] animate-fade-in">
              <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-md p-8 border border-slate-200 dark:border-slate-700/50">
                  <h3 className="font-bold text-slate-800 dark:text-slate-100 text-lg mb-6">คำนวณคืนเงินประกัน</h3>
                  <div className="space-y-5">
                      <div>
                        <label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">เงินประกันที่รับมาตอนแรก (บาท)</label>
                        <input type="number" className="w-full min-w-0 appearance-none block bg-slate-50 dark:bg-slate-700/50 border border-slate-300 p-3 rounded-md font-mono outline-none focus:ring-2 focus:ring-blue-500 text-lg" value={moveOutData.original_deposit} onChange={e => setMoveOutData({...moveOutData, original_deposit: e.target.value})} />
                      </div>

                      <div className="grid grid-cols-2 gap-4">
                          <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">หักค่าทำความสะอาด</label><input type="number" className="w-full min-w-0 appearance-none block bg-white dark:bg-slate-800 border border-red-300 p-2 rounded-md font-mono text-red-500 outline-none focus:ring-2 focus:ring-red-500" value={moveOutData.cleaning} onChange={e => setMoveOutData({...moveOutData, cleaning: e.target.value})} /></div>
                          <div><label className="block text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase mb-1">หักค่าเสียหาย</label><input type="number" className="w-full min-w-0 appearance-none block bg-white dark:bg-slate-800 border border-red-300 p-2 rounded-md font-mono text-red-500 outline-none focus:ring-2 focus:ring-red-500" value={moveOutData.damage} onChange={e => setMoveOutData({...moveOutData, damage: e.target.value})} /></div>
                      </div>
                      <div className="bg-emerald-50/50 p-4 rounded-lg border border-emerald-200 flex justify-between items-center mt-4">
                          <span className="text-xs font-bold text-emerald-700">ยอดเงินคืนสุทธิ:</span>
                          <span className="text-3xl font-black text-emerald-600 font-mono">{(Number(moveOutData.original_deposit) - Number(moveOutData.cleaning) - Number(moveOutData.damage)).toLocaleString()} ฿</span>
                      </div>
                      <div className="flex gap-3 mt-6 pt-4 border-t border-slate-100 dark:border-slate-700/50">
                          <button disabled={isSubmitting} onClick={() => { setIsMoveOutModalOpen(false); setCurrentUser({...currentUser, status: originalStatus}); }} className="flex-1 bg-white dark:bg-slate-800 border border-slate-300 text-slate-600 dark:text-slate-300 py-3 rounded-lg text-xs font-bold hover:bg-slate-50 dark:bg-slate-700/50 transition-colors disabled:opacity-50">ยกเลิก</button>
                          <button disabled={isSubmitting} onClick={confirmMoveOut} className={`flex-1 text-white py-3 rounded-lg text-xs font-bold shadow-lg transition-colors ${isSubmitting ? 'bg-slate-400 cursor-not-allowed' : 'bg-red-600 hover:bg-red-700 hover:shadow-red-500/30'}`}>
                            {isSubmitting ? 'กำลังดำเนินการ...' : 'ยืนยันการย้ายออก'}
                          </button>
                      </div>
                  </div>
              </div>
          </div>
      )}

      <ConfirmModal
        isOpen={isDeleteModalOpen}
        title="ยืนยันการลบลูกบ้าน"
        message={
          userToDelete ? (
            <div className="space-y-4 mb-2">
              <div className="bg-red-50 p-4 rounded-lg border border-red-200">
                <div className="text-sm text-slate-600 dark:text-slate-300 mb-2">ชื่อ:</div>
                <div className="text-lg font-bold text-slate-800 dark:text-slate-100">{userToDelete.prefix}{userToDelete.first_name} {userToDelete.last_name}</div>
              </div>
              <div className="bg-amber-50 p-4 rounded-lg border border-amber-200">
                <div className="text-sm text-slate-600 dark:text-slate-300 mb-2">ห้อง:</div>
                <div className="text-lg font-bold text-slate-800 dark:text-slate-100">{userToDelete.room_number}</div>
              </div>
              <div className="text-sm text-red-600 font-medium">คำเตือน: การลบนี้จะลบข้อมูลเกี่ยวกับลูกบ้านรายนี้ทั้งหมด รวมถึงประวัติการชำระเงิน</div>
            </div>
          ) : null
        }
        confirmText={isSubmitting ? 'กำลังลบ...' : 'ยืนยันการลบ'}
        onConfirm={confirmDelete}
        onCancel={() => { setIsDeleteModalOpen(false); setUserToDelete(null); }}
        isDanger={true}
      />
      <ConfirmModal {...sysModal} />

      {isUnmaskModalOpen && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 z-[60] animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-lg shadow-xl w-full max-w-sm overflow-hidden border border-slate-200 dark:border-slate-700/50">
            <div className="bg-slate-50 dark:bg-slate-700/50 px-6 py-4 border-b border-slate-200 dark:border-slate-700/50"><h3 className="font-bold text-slate-800 dark:text-slate-100 text-sm uppercase tracking-widest">ยืนยันตัวตน (Admin)</h3></div>
            <div className="p-6">
              <p className="text-xs text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-4">กรุณาใส่รหัสผ่านเพื่อดูเลขบัตรประชาชนแบบเต็ม เพื่อเหตุผลด้านความปลอดภัยและ PDPA</p>
              <input type="password" value={unmaskPassword} onChange={e => setUnmaskPassword(e.target.value)} placeholder="รหัสผ่าน Admin" className="w-full bg-white dark:bg-slate-800 border border-slate-300 px-3 py-2.5 text-sm rounded outline-none focus:ring-2 focus:ring-blue-500 mb-2" autoFocus />
              {unmaskError && <p className="text-xs text-red-500 mb-2">{unmaskError}</p>}
              <div className="flex gap-2 justify-end mt-4">
                <button type="button" onClick={() => { setIsUnmaskModalOpen(false); setUnmaskPassword(''); setUnmaskError(''); }} className="px-4 py-2 border border-slate-200 dark:border-slate-700/50 text-slate-600 dark:text-slate-300 rounded text-xs font-bold uppercase tracking-widest hover:bg-slate-50 dark:bg-slate-700/50">ยกเลิก</button>
                <button type="button" onClick={handleUnmaskSubmit} className="px-4 py-2 bg-blue-600 text-white rounded text-xs font-bold uppercase tracking-widest hover:bg-blue-700 disabled:opacity-50">ตรวจสอบ</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}