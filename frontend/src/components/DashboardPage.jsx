import { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { API_URL } from '../config';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip as RechartsTooltip, ResponsiveContainer, BarChart, Bar, PieChart, Pie, Cell } from 'recharts';

export default function DashboardPage() {
  const [stats, setStats] = useState({
    total_residents: 0,
    empty_rooms: 0,
    income_this_month: 0,
    pending_bills: 0,
    deposit_this_month: 0,
    advance_rent_this_month: 0
  });
  
  const [recentLogs, setRecentLogs] = useState([]);
  const [pendingUsers, setPendingUsers] = useState([]); 
  const [expiringContracts, setExpiringContracts] = useState([]); 
  const [moveInStats, setMoveInStats] = useState([]);
  const [financialStats, setFinancialStats] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  // First-time backup restore states
  const [showFirstTimeBackup, setShowFirstTimeBackup] = useState(false);
  const [backupFile, setBackupFile] = useState(null);
  const [isRestoring, setIsRestoring] = useState(false);
  const [restoreError, setRestoreError] = useState('');

  useEffect(() => {
    // Check if we just completed a forced password change
    if (sessionStorage.getItem('showFirstTimeBackup') === 'true') {
      setShowFirstTimeBackup(true);
      sessionStorage.removeItem('showFirstTimeBackup');
    }

    Promise.all([
      fetch(`${API_URL}/dashboard-stats`).then(res => res.json()).catch(err => ({ error: err.message })),
      fetch(`${API_URL}/logs`).then(res => res.json()).catch(err => ({ error: err.message })),
      fetch(`${API_URL}/users`).then(res => res.json()).catch(err => ({ error: err.message })),
      fetch(`${API_URL}/payments`).then(res => res.json()).catch(err => ({ error: err.message })),
      fetch(`${API_URL}/rooms`).then(res => res.json()).catch(err => ({ error: err.message })),
      fetch(`${API_URL}/room-types`).then(res => res.json()).catch(err => ({ error: err.message })),
      fetch(`${API_URL}/maintenances`, { headers: { 'Authorization': 'Bearer ' + localStorage.getItem('dorminet_token') } }).then(res => res.json()).catch(err => ({ error: err.message }))
    ])
    .then(([statsData, logsData, usersData, paymentsData, roomsData, roomTypesData, maintenancesData]) => {
      // Safe extraction
      const safeLogs = Array.isArray(logsData) ? logsData : [];
      setRecentLogs(safeLogs.slice(0, 10)); 
      
      const currentMonthString = `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, '0')}`;
      const safeUsers = Array.isArray(usersData) ? usersData : [];
      const activeUsers = safeUsers.filter(u => u.status === 'กำลังพักอาศัย');
      const payments = Array.isArray(paymentsData) ? paymentsData : [];
      
      const unpaid = activeUsers.filter(u => !payments.find(p => p.user_id === u.id && p.month === currentMonthString && p.payment_status === 'paid'));
      unpaid.sort((a, b) => String(a.room_number || "").localeCompare(String(b.room_number || "")));
      setPendingUsers(unpaid);

      const upcoming = [...activeUsers]
        .filter(u => u.contract_end_date)
        .sort((a, b) => new Date(a.contract_end_date) - new Date(b.contract_end_date))
        .slice(0, 5); 
      setExpiringContracts(upcoming);
      
      const rooms = Array.isArray(roomsData) ? roomsData : [];
      const roomTypes = Array.isArray(roomTypesData) ? roomTypesData : [];
      
      // Calculate Monthly Move-ins & Expected Revenue
      const monthlyStats = {};
      const currentMonthStats = { deposit: 0, advanceRent: 0 };
      
      safeUsers.forEach(u => {
        if (!u.move_in_date || u.status === 'ยกเลิก' || u.status === 'ย้ายออกแล้ว') return;
        const monthKey = String(u.move_in_date).substring(0, 7); 
        if (!monthlyStats[monthKey]) {
          monthlyStats[monthKey] = { month: monthKey, newResidents: 0, deposit: 0, advanceRent: 0 };
        }
        monthlyStats[monthKey].newResidents += 1;
        monthlyStats[monthKey].deposit += Number(u.deposit) || 0;
        
        let basePrice = 0;
        const userRoom = rooms.find(r => r.room_number === u.room_number);
        if (userRoom) {
          const rType = roomTypes.find(rt => rt.name === userRoom.room_type);
          if (rType) basePrice = Number(rType.price) || 0;
        }
        monthlyStats[monthKey].advanceRent += basePrice;
      });
      
      // Sort and Format for Charts
      const sortedMonths = Object.values(monthlyStats)
        .sort((a, b) => String(a.month || "").localeCompare(String(b.month || "")))
        .slice(-6); // Last 6 active months
        
      // Map for Display
      const formattedMoveInStats = sortedMonths.map(m => {
        let name = m.month;
        try {
          const d = new Date(m.month + '-01');
          if (!isNaN(d)) {
            name = d.toLocaleDateString('th-TH', { month: 'short', year: '2-digit' });
          }
        } catch (e) {
          console.error("Date parse error", e);
        }
        return {
          name,
          'จำนวนผู้เช่าใหม่': m.newResidents,
        };
      });
      
      // Compile Financial Trend from Payments
      const payStats = {};
      
      // Pre-fill last 6 months to ensure chart draws lines instead of a single dot
      const d = new Date();
      for (let i = 5; i >= 0; i--) {
        const pastDate = new Date(d.getFullYear(), d.getMonth() - i, 1);
        const mKey = `${pastDate.getFullYear()}-${String(pastDate.getMonth() + 1).padStart(2, '0')}`;
        payStats[mKey] = { month: mKey, 'รายรับ': 0, 'ค้างชำระ (ประมาณการ)': 0 };
      }
      
      const initMonth = (mKey) => {
        if (!payStats[mKey]) {
           payStats[mKey] = { month: mKey, 'รายรับ': 0, 'ค้างชำระ (ประมาณการ)': 0 };
        }
      };

      payments.forEach(p => {
        if (Number(p.amount) > 0) {
          if (p.payment_status === 'paid') {
            // [Fix Dashboard Inconsistency] Use payment_date (yyyy-mm) for income (Cash-basis)
            const dateKey = p.payment_date && p.payment_date.length >= 7 ? p.payment_date.substring(0, 7) : String(p.month || "Unknown");
            initMonth(dateKey);
            payStats[dateKey]['รายรับ'] += Number(p.amount) || 0;
          } else {
            // Pending bills use the billing cycle month (Accrual-basis)
            const mKey = String(p.month || "Unknown");
            initMonth(mKey);
            payStats[mKey]['ค้างชำระ (ประมาณการ)'] += Number(p.amount) || 0;
          }
        }
      });
      
      // Sort Payment Months
      const sortedPayStats = Object.values(payStats)
        .sort((a, b) => String(a.month || "").localeCompare(String(b.month || "")))
        .slice(-6);
        
      setMoveInStats(formattedMoveInStats);
      setFinancialStats(sortedPayStats);
      
      // Calculate Maintenance Stats
      const maintenances = Array.isArray(maintenancesData) ? maintenancesData : [];
      const pendingMaints = maintenances.filter(m => m.status === 'รอดำเนินการ').length;
      const inProgressMaints = maintenances.filter(m => m.status === 'กำลังซ่อม' || m.status === 'กำลังติดต่อช่าง').length;
      const completedMaints = maintenances.filter(m => m.status === 'เสร็จสิ้น' || m.status === 'รอตรวจสอบชำระเงิน').length;
      
      
      setStats({
        total_residents: statsData?.total_residents || 0,
        empty_rooms: statsData?.empty_rooms || 0,
        income_this_month: statsData?.income_this_month || 0,
        billing_cycle_income: statsData?.billing_cycle_income || 0,
        pending_bills: statsData?.pending_bills || 0,
        deposit_this_month: currentMonthStats.deposit,
        advance_rent_this_month: currentMonthStats.advanceRent,
        pending_maints: pendingMaints,
        in_progress_maints: inProgressMaints,
        completed_maints: completedMaints
      });
      
      setTimeout(() => setIsLoading(false), 800);
    })
    .catch(err => {
      console.error("Error fetching dashboard data:", err);
      setTimeout(() => setIsLoading(false), 800);
    });
  }, []);

  const totalRooms = stats.total_residents + stats.empty_rooms;
  const occupancyRate = totalRooms > 0 ? Math.round((stats.total_residents / totalRooms) * 100) : 0;

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <span className="ml-3 text-slate-500 dark:text-slate-400 dark:text-slate-300 font-bold uppercase tracking-widest text-xs">กำลังโหลดและวิเคราะห์ข้อมูล...</span>
      </div>
    );
  }

  const handleBackupFileChange = (e) => {
    if (e.target.files && e.target.files.length > 0) {
      const file = e.target.files[0];
      if (!file.name.endsWith('.zip')) {
        setRestoreError('กรุณาอัปโหลดไฟล์นามสกุล .zip เท่านั้น');
        e.target.value = '';
        return;
      }
      setBackupFile(file);
      setRestoreError('');
    } else {
      setBackupFile(null);
    }
  };

  const handleRestoreSubmit = async () => {
    if (!backupFile) {
      setRestoreError('กรุณาเลือกไฟล์ Backup (.zip)');
      return;
    }

    setIsRestoring(true);
    setRestoreError('');
    try {
      const uploadData = new FormData();
      uploadData.append('backup_file', backupFile);

      const res = await fetch(`${API_URL}/system/backups/restore`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('dorminet_token')}`
        },
        body: uploadData
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || 'เกิดข้อผิดพลาดในการกู้คืนระบบ');
      }

      setShowFirstTimeBackup(false);
      window.location.reload(); // Reload to fetch restored data
    } catch (err) {
      setRestoreError(err.message);
      setIsRestoring(false);
    }
  };

  const handleSkipBackup = () => {
    setShowFirstTimeBackup(false);
  };

  return (
    <div className="animate-fade-in pb-12 font-sans text-slate-800 dark:text-slate-100">

      {/* ---------------- First-Time Backup Modal ---------------- */}
      {showFirstTimeBackup && createPortal(
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-[2rem] shadow-2xl max-w-md w-full overflow-hidden border border-slate-100 dark:border-slate-700/50 transform transition-all relative">
            <div className="p-8 text-center relative">
              
              <div className="relative z-10">
                <div className="w-20 h-20 mx-auto bg-blue-50 rounded-full flex items-center justify-center mb-6">
                  <svg className="w-10 h-10 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                  </svg>
                </div>
                <h3 className="text-2xl font-black text-slate-800 dark:text-slate-100 tracking-tight mb-2">ยินดีต้อนรับสู่ระบบ</h3>
                <p className="text-sm font-medium text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-6">
                  คุณต้องการนำเข้าข้อมูลหอพักจากไฟล์สำรองที่มีอยู่ หรือเริ่มต้นใช้งานด้วยระบบที่ว่างเปล่า?
                </p>

                {restoreError && (
                  <div className="mb-4 bg-red-50 text-red-600 text-xs px-4 py-3 rounded-xl font-bold text-left flex items-center gap-2">
                    <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                    <span>{restoreError}</span>
                  </div>
                )}

                <div className="mb-6 p-4 border-2 border-slate-200 dark:border-slate-700/50 border-dashed rounded-xl hover:border-blue-400 hover:bg-slate-50 dark:bg-slate-700/50 transition-colors">
                  <label htmlFor="modal-file-upload" className="cursor-pointer flex flex-col items-center justify-center">
                    <span className="text-sm font-bold text-blue-600 mb-1">เลือกไฟล์ Backup</span>
                    <span className="text-xs text-slate-500 dark:text-slate-400 dark:text-slate-300">{backupFile ? backupFile.name : 'ยังไม่ได้เลือกไฟล์'}</span>
                    <input id="modal-file-upload" type="file" accept=".zip" className="hidden" onChange={handleBackupFileChange} />
                  </label>
                </div>

                <div className="space-y-3">
                  <button
                    onClick={handleRestoreSubmit}
                    disabled={isRestoring || !backupFile}
                    className={`w-full flex items-center justify-center py-3.5 px-4 rounded-xl text-sm font-bold text-white transition-all shadow-md ${
                      !backupFile 
                        ? 'bg-slate-300 cursor-not-allowed shadow-none' 
                        : isRestoring 
                          ? 'bg-blue-400 cursor-not-allowed opacity-80' 
                          : 'bg-gradient-to-r from-blue-600 to-cyan-500 hover:from-blue-700 hover:to-cyan-600 hover:-translate-y-0.5'
                    }`}
                  >
                    {isRestoring ? (
                      <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                    ) : (
                      'นำเข้าไฟล์ระบบ'
                    )}
                  </button>
                  <button
                    onClick={handleSkipBackup}
                    disabled={isRestoring}
                    className="w-full flex items-center justify-center py-3.5 px-4 rounded-xl text-sm font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 bg-white dark:bg-slate-800 border-2 border-slate-100 dark:border-slate-700/50 hover:bg-slate-50 dark:bg-slate-700/50 hover:text-slate-700 dark:text-slate-200 transition-colors"
                  >
                    ข้ามไปก่อน
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>,
        document.body
      )}
      
      {/* ---------------- HEADER ---------------- */}
      <div className="mb-8 flex justify-between items-end border-b border-slate-200/60 dark:border-slate-700/50 pb-5">
        <div>
          <h2 className="text-2xl font-black text-slate-900 dark:text-slate-100 tracking-tight flex items-center gap-3">
            <span className="bg-gradient-to-br from-slate-800 to-slate-900 text-white p-2 rounded-lg shadow-md">
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M13 10V3L4 14h7v7l9-11h-7z" /></svg>
            </span>
            ภาพรวมระบบ
          </h2>
          <p className="text-sm font-semibold text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-2">
            ข้อมูลเชิงลึกและสถานะการดำเนินงานของระบบ
          </p>
        </div>
        <div className="hidden md:flex items-center gap-2 bg-white dark:bg-slate-800 px-4 py-2 rounded-full border border-slate-200 dark:border-slate-700/50 shadow-sm">
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
          <span className="text-[10px] font-black uppercase tracking-widest text-slate-600 dark:text-slate-300">ระบบออนไลน์ • {new Date().toLocaleDateString('th-TH', { day:'numeric', month: 'short', year: 'numeric' })}</span>
        </div>
      </div>

      {/* ---------------- KPIs (Executive Summary) ---------------- */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4 mb-8">
        
        {/* KPI 1: Occupancy Rate */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-[0_4px_20px_rgb(0,0,0,0.03)] relative overflow-hidden group">
          <div className="absolute top-0 right-0 w-24 h-24 bg-blue-500/5 rounded-bl-[100px] -z-10 group-hover:scale-110 transition-transform"></div>
          <div className="flex justify-between items-start mb-4">
            <div className="text-[10px] font-black text-slate-400 dark:text-slate-300 uppercase tracking-widest">อัตราการเข้าพัก</div>
            <div className="w-8 h-8 rounded-full bg-blue-50 text-blue-600 flex items-center justify-center">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <h3 className="text-3xl font-black font-mono text-slate-800 dark:text-slate-100">{occupancyRate}%</h3>
          </div>
          <div className="w-full bg-slate-100 rounded-full h-1 mt-4 overflow-hidden">
            <div className="bg-blue-500 h-full rounded-full" style={{ width: `${occupancyRate}%` }}></div>
          </div>
          <div className="flex justify-between mt-2 text-[10px] font-bold text-slate-400 dark:text-slate-300">
            <span>ผู้เช่าหลัก: {stats.total_residents} คน</span>
            <span>อัตราส่วนเข้าพัก</span>
          </div>
        </div>

        {/* Room Status KPI Card */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-[0_4px_20px_rgb(0,0,0,0.03)] relative overflow-hidden group">
          <div className="absolute top-0 right-0 w-24 h-24 bg-indigo-500/5 rounded-bl-[100px] -z-10 group-hover:scale-110 transition-transform"></div>
          <div className="flex justify-between items-start mb-3">
            <div className="text-[10px] font-black text-slate-400 dark:text-slate-300 uppercase tracking-widest">สถานะห้องพัก</div>
            <div className="w-8 h-8 rounded-full bg-indigo-50 text-indigo-600 flex items-center justify-center">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" /></svg>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-2 border-t border-slate-100 dark:border-slate-700/50 pt-3 mt-1">
            <div>
              <p className="text-[9px] font-black text-slate-400 dark:text-slate-300 uppercase tracking-widest">ห้องเต็ม (มีผู้เช่า)</p>
              <h4 className="text-xl font-black font-mono text-slate-800 dark:text-slate-100 mt-0.5">{stats.total_residents} <span className="text-[10px] font-bold text-slate-400 dark:text-slate-300">ห้อง</span></h4>
            </div>
            <div className="border-l border-slate-100 dark:border-slate-700/50 pl-3">
              <p className="text-[9px] font-black text-slate-400 dark:text-slate-300 uppercase tracking-widest">ห้องว่าง (พร้อมอยู่)</p>
              <h4 className="text-xl font-black font-mono text-emerald-600 mt-0.5">{stats.empty_rooms} <span className="text-[10px] font-bold text-slate-400 dark:text-slate-300">ห้อง</span></h4>
            </div>
          </div>
          <p className="mt-3 text-[10px] font-bold text-slate-400 dark:text-slate-300">
            จำนวนห้องทั้งหมด: <span className="text-slate-700 dark:text-slate-200 font-black">{totalRooms}</span> ห้อง
          </p>
        </div>

        {/* KPI 3 */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-[0_4px_20px_rgb(0,0,0,0.03)] relative overflow-hidden group">
          <div className="absolute top-0 right-0 w-24 h-24 bg-emerald-500/5 rounded-bl-[100px] -z-10 group-hover:scale-110 transition-transform"></div>
          <div className="flex justify-between items-start mb-4">
            <div className="text-[10px] font-black text-slate-400 dark:text-slate-300 uppercase tracking-widest">เงินสดรับเดือนนี้</div>
            <div className="w-8 h-8 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <h3 className="text-3xl font-black font-mono text-emerald-600">฿{(Number(stats.income_this_month)/1000 || 0).toFixed(1)}k</h3>
          </div>
          <p className="mt-2 text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 flex items-center gap-1">
            <span className="text-emerald-500 bg-emerald-50 px-1 rounded">อัปเดตล่าสุด</span> เงินเข้าบัญชีจริง
          </p>
        </div>

        {/* KPI 4 (New) */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-[0_4px_20px_rgb(0,0,0,0.03)] relative overflow-hidden group">
          <div className="absolute top-0 right-0 w-24 h-24 bg-cyan-500/5 rounded-bl-[100px] -z-10 group-hover:scale-110 transition-transform"></div>
          <div className="flex justify-between items-start mb-4">
            <div className="text-[10px] font-black text-slate-400 dark:text-slate-300 uppercase tracking-widest">ยอดเก็บรอบบิลนี้</div>
            <div className="w-8 h-8 rounded-full bg-cyan-50 text-cyan-600 flex items-center justify-center">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <h3 className="text-3xl font-black font-mono text-cyan-600">฿{(Number(stats.billing_cycle_income)/1000 || 0).toFixed(1)}k</h3>
          </div>
          <p className="mt-2 text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 flex items-center gap-1">
            <span className="text-cyan-500 bg-cyan-50 px-1 rounded">ตามรอบบิล</span> ยอดที่เก็บได้แล้ว
          </p>
        </div>

        {/* KPI 3 */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-[0_4px_20px_rgb(0,0,0,0.03)] relative overflow-hidden group">
          <div className="absolute top-0 right-0 w-24 h-24 bg-amber-500/5 rounded-bl-[100px] -z-10 group-hover:scale-110 transition-transform"></div>
          <div className="flex justify-between items-start mb-4">
            <div className="text-[10px] font-black text-slate-400 dark:text-slate-300 uppercase tracking-widest">มัดจำแรกเข้า</div>
            <div className="w-8 h-8 rounded-full bg-amber-50 text-amber-600 flex items-center justify-center">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" /></svg>
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <h3 className="text-3xl font-black font-mono text-slate-800 dark:text-slate-100">฿{(Number(stats.deposit_this_month)/1000 || 0).toFixed(1)}k</h3>
          </div>
          <p className="mt-2 text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 flex items-center gap-1">
            ผู้เช่าใหม่เดือนนี้
          </p>
        </div>

        {/* KPI 4 */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-[0_4px_20px_rgb(0,0,0,0.03)] relative overflow-hidden group">
          <div className={`absolute top-0 right-0 w-24 h-24 ${stats.pending_bills > 0 ? 'bg-red-500/5' : 'bg-slate-50 dark:bg-slate-700/500/5'} rounded-bl-[100px] -z-10 group-hover:scale-110 transition-transform`}></div>
          <div className="flex justify-between items-start mb-4">
            <div className="text-[10px] font-black text-slate-400 dark:text-slate-300 uppercase tracking-widest">บิลค้างชำระ</div>
            <div className={`w-8 h-8 rounded-full flex items-center justify-center ${stats.pending_bills > 0 ? 'bg-red-50 text-red-600' : 'bg-slate-50 dark:bg-slate-700/50 text-slate-400 dark:text-slate-300'}`}>
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <h3 className={`text-3xl font-black font-mono ${stats.pending_bills > 0 ? 'text-red-500' : 'text-slate-800 dark:text-slate-100'}`}>{stats.pending_bills} <span className="text-sm font-bold text-slate-400 dark:text-slate-300">ห้อง</span></h3>
          </div>
          <p className="mt-2 text-[10px] font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 flex items-center gap-1">
            ต้องติดตามทวงถาม
          </p>
        </div>

      </div>

      {/* ---------------- CHARTS SECTION ---------------- */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        
        {/* Chart 1: Revenue Trends (Native SVG Area Chart) */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-[0_4px_20px_rgb(0,0,0,0.02)]">
          <h3 className="text-sm font-bold text-slate-800 dark:text-slate-100 mb-6 flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-emerald-500"></div>
            แนวโน้มรายรับทางการเงิน (Financial Trends)
          </h3>
          <div className="h-64 w-full">
            {financialStats.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={financialStats} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorRevenueNative" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#10b981" stopOpacity={0.8}/>
                      <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <XAxis dataKey="month" stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} />
                  <YAxis stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} tickFormatter={(value) => `฿${value.toLocaleString()}`} />
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                  <RechartsTooltip formatter={(value) => [`฿${value.toLocaleString()}`, 'รายรับ']} />
                  <Area type="monotone" dataKey="รายรับ" stroke="#10b981" fillOpacity={1} fill="url(#colorRevenueNative)" />
                </AreaChart>
              </ResponsiveContainer>
            ) : (
              <div className="w-full h-full flex flex-col items-center justify-center text-slate-400 dark:text-slate-300">
                <svg className="w-10 h-10 mb-2 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" /></svg>
                <span className="text-xs font-bold uppercase tracking-widest">ยังไม่มีข้อมูลเพียงพอ</span>
              </div>
            )}
          </div>
        </div>

        {/* Chart 2: Move In Stats (Native CSS Bar Chart) */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-[0_4px_20px_rgb(0,0,0,0.02)]">
          <h3 className="text-sm font-bold text-slate-800 dark:text-slate-100 mb-6 flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-blue-500"></div>
            สถิติผู้เช่าใหม่รายเดือน (New Residents)
          </h3>
          <div className="h-64 w-full">
            {moveInStats.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={moveInStats} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
                  <XAxis dataKey="name" stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} />
                  <YAxis stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} />
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                  <RechartsTooltip formatter={(value) => [value, 'จำนวนผู้เช่าใหม่']} cursor={{fill: '#f1f5f9'}} />
                  <Bar dataKey="จำนวนผู้เช่าใหม่" fill="#3b82f6" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="w-full h-full flex flex-col items-center justify-center text-slate-400 dark:text-slate-300">
                <svg className="w-10 h-10 mb-2 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" /></svg>
                <span className="text-xs font-bold uppercase tracking-widest">ยังไม่มีข้อมูลผู้เข้าพัก</span>
              </div>
            )}
          </div>
        </div>

      </div>

      {/* ---------------- ADDITIONAL CHARTS SECTION ---------------- */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        
        {/* Chart 3: Occupancy Status (Pie Chart) */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-[0_4px_20px_rgb(0,0,0,0.02)]">
          <h3 className="text-sm font-bold text-slate-800 dark:text-slate-100 mb-6 flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-indigo-500"></div>
            สัดส่วนห้องพัก (Occupancy Breakdown)
          </h3>
          <div className="h-64 w-full flex flex-col items-center justify-center">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={[
                    { name: 'มีผู้เช่า', value: stats.total_residents, color: '#6366f1' },
                    { name: 'ห้องว่าง', value: stats.empty_rooms, color: '#10b981' }
                  ]}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={80}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {
                    [
                      { name: 'มีผู้เช่า', value: stats.total_residents, color: '#6366f1' },
                      { name: 'ห้องว่าง', value: stats.empty_rooms, color: '#10b981' }
                    ].map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))
                  }
                </Pie>
                <RechartsTooltip formatter={(value) => [value, 'ห้อง']} />
              </PieChart>
            </ResponsiveContainer>
            <div className="flex justify-center gap-4 mt-2">
              <div className="flex items-center gap-1 text-[11px] font-bold text-slate-600 dark:text-slate-300"><span className="w-3 h-3 rounded-full bg-[#6366f1]"></span> มีผู้เช่า ({stats.total_residents})</div>
              <div className="flex items-center gap-1 text-[11px] font-bold text-slate-600 dark:text-slate-300"><span className="w-3 h-3 rounded-full bg-[#10b981]"></span> ห้องว่าง ({stats.empty_rooms})</div>
            </div>
          </div>
        </div>

        {/* Chart 4: Maintenance Overview */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-[0_4px_20px_rgb(0,0,0,0.02)]">
          <h3 className="text-sm font-bold text-slate-800 dark:text-slate-100 mb-6 flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-purple-500"></div>
            สถานะการแจ้งซ่อม (Maintenance Status)
          </h3>
          <div className="h-64 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={[
                { name: 'รอดำเนินการ', value: stats.pending_maints || 0 },
                { name: 'กำลังซ่อม', value: stats.in_progress_maints || 0 },
                { name: 'เสร็จสิ้น', value: stats.completed_maints || 0 }
              ]} margin={{ top: 10, right: 30, left: 0, bottom: 0 }} layout="vertical">
                <CartesianGrid strokeDasharray="3 3" horizontal={true} vertical={false} stroke="#e2e8f0" />
                <XAxis type="number" stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} allowDecimals={false} />
                <YAxis dataKey="name" type="category" stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} width={80} />
                <RechartsTooltip formatter={(value) => [value, 'รายการ']} cursor={{fill: '#f1f5f9'}} />
                <Bar dataKey="value" radius={[0, 4, 4, 0]}>
                  {
                    [
                      { name: 'รอดำเนินการ', value: stats.pending_maints || 0, color: '#ef4444' },
                      { name: 'กำลังซ่อม', value: stats.in_progress_maints || 0, color: '#eab308' },
                      { name: 'เสร็จสิ้น', value: stats.completed_maints || 0, color: '#22c55e' }
                    ].map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))
                  }
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

      </div>

      {/* ---------------- OPERATIONAL SECTION ---------------- */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-stretch">
        
        {/* Column 1: Pending Bills */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-[0_4px_20px_rgb(0,0,0,0.02)] flex flex-col h-96">
          <div className="flex justify-between items-center border-b border-slate-100 dark:border-slate-700/50 pb-4 mb-4 flex-shrink-0">
            <h3 className="text-sm font-bold text-slate-800 dark:text-slate-100 flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-red-500 animate-pulse"></span>
              รอชำระเงิน
            </h3>
            <span className="text-[10px] font-black text-red-600 bg-red-50 px-2 py-0.5 rounded-full border border-red-100">{pendingUsers.length} ห้อง</span>
          </div>

          <div className="flex-1 overflow-y-auto pr-2 space-y-3 custom-scrollbar">
            {pendingUsers.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-full text-center opacity-60">
                <div className="w-12 h-12 rounded-full bg-slate-50 dark:bg-slate-700/50 flex items-center justify-center mb-3">
                  <svg className="w-5 h-5 text-slate-400 dark:text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" /></svg>
                </div>
                <p className="text-xs font-bold text-slate-600 dark:text-slate-300 tracking-wide uppercase">ไม่มีรายการค้างชำระ</p>
              </div>
            ) : (
              pendingUsers.map(user => {
                const dueDay = new Date(user.move_in_date).getDate();
                const today = new Date().getDate();
                const isOverdue = today > dueDay; 

                return (
                  <div key={user.id} className="group flex items-center justify-between p-3 rounded-xl border border-slate-100 dark:border-slate-700/50 bg-slate-50/50 hover:bg-white dark:bg-slate-800 hover:border-slate-200 dark:border-slate-700/50 hover:shadow-sm transition-all">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-mono font-black text-slate-800 dark:text-slate-100 text-base">{user.room_number}</span>
                        {isOverdue && <span className="text-[8px] font-black text-red-500 bg-red-50 border border-red-100 px-1.5 py-0.5 rounded tracking-widest uppercase">เกินกำหนด</span>}
                      </div>
                      <p className="text-[11px] text-slate-500 dark:text-slate-400 dark:text-slate-300 font-medium mt-0.5 truncate max-w-[120px]">{user.first_name} {user.last_name}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-[9px] font-bold text-slate-400 dark:text-slate-300 uppercase tracking-widest">กำหนดชำระ</p>
                      <p className={`font-mono font-bold text-xs mt-0.5 ${isOverdue ? 'text-red-600' : 'text-slate-700 dark:text-slate-200'}`}>วันที่ {dueDay}</p>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Column 2: Expiring Contracts */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-[0_4px_20px_rgb(0,0,0,0.02)] flex flex-col h-96">
          <div className="flex justify-between items-center border-b border-slate-100 dark:border-slate-700/50 pb-4 mb-4 flex-shrink-0">
            <h3 className="text-sm font-bold text-slate-800 dark:text-slate-100 flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-amber-500"></span>
              สัญญาใกล้หมดอายุ
            </h3>
          </div>
          
          <div className="flex-1 overflow-y-auto pr-2 space-y-3 custom-scrollbar">
            {expiringContracts.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-full text-center opacity-60">
                <div className="w-12 h-12 rounded-full bg-slate-50 dark:bg-slate-700/50 flex items-center justify-center mb-3">
                  <svg className="w-5 h-5 text-slate-400 dark:text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                </div>
                <p className="text-xs font-bold text-slate-600 dark:text-slate-300 tracking-wide uppercase">สัญญาปกติทุกห้อง</p>
              </div>
            ) : (
              expiringContracts.map(user => {
                const daysLeft = Math.ceil((new Date(user.contract_end_date) - new Date()) / (1000 * 60 * 60 * 24));
                const isExpired = daysLeft < 0;
                return (
                  <div key={user.id} className="flex items-center justify-between p-3 rounded-xl border border-slate-100 dark:border-slate-700/50 bg-slate-50/50 hover:bg-white dark:bg-slate-800 hover:border-slate-200 dark:border-slate-700/50 hover:shadow-sm transition-all">
                    <div>
                      <span className="font-mono font-black text-slate-800 dark:text-slate-100 text-base">{user.room_number}</span>
                      <p className="text-[11px] text-slate-500 dark:text-slate-400 dark:text-slate-300 font-medium mt-0.5 truncate max-w-[100px]">{user.first_name}</p>
                    </div>
                    <div className="text-right">
                      <p className="font-mono text-[11px] font-bold text-slate-700 dark:text-slate-200">{user.contract_end_date}</p>
                      <span className={`inline-block mt-1 text-[9px] font-black px-1.5 py-0.5 rounded border ${isExpired ? 'bg-red-50 text-red-600 border-red-100' : 'bg-amber-50 text-amber-600 border-amber-100'}`}>
                        {isExpired ? `เลยกำหนด ${Math.abs(daysLeft)} วัน` : `เหลือ ${daysLeft} วัน`}
                      </span>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Column 3: System Logs */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-[0_4px_20px_rgb(0,0,0,0.02)] flex flex-col h-96">
          <div className="flex justify-between items-center border-b border-slate-100 dark:border-slate-700/50 pb-4 mb-4 flex-shrink-0">
            <h3 className="text-sm font-bold text-slate-800 dark:text-slate-100 flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-slate-800"></span>
              ประวัติการทำรายการล่าสุด
            </h3>
            <span className="text-[9px] font-black text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest">System Logs</span>
          </div>

          <div className="flex-1 overflow-y-auto pr-2 space-y-4 custom-scrollbar relative before:absolute before:inset-y-0 before:left-[17px] before:w-[2px] before:bg-slate-100">
            {recentLogs.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-full text-center opacity-60">
                <p className="text-xs font-bold text-slate-600 dark:text-slate-300 tracking-wide uppercase">ยังไม่มีประวัติ</p>
              </div>
            ) : (
              recentLogs.map((log) => {
                let iconColor = "bg-white dark:bg-slate-800 text-slate-500 dark:text-slate-400 dark:text-slate-300 border-slate-200 dark:border-slate-700/50";
                if (log.action_type === "Create" || log.action_type === "Payment") iconColor = "bg-white dark:bg-slate-800 text-emerald-500 border-emerald-200";
                else if (log.action_type === "Update") iconColor = "bg-white dark:bg-slate-800 text-blue-500 border-blue-200";
                else if (log.action_type === "Delete" || log.action_type === "Move-out") iconColor = "bg-white dark:bg-slate-800 text-red-500 border-red-200";

                return (
                  <div key={log.id} className="relative flex items-start gap-4 group">
                    <div className={`mt-0.5 w-9 h-9 rounded-full border-2 flex items-center justify-center flex-shrink-0 font-bold text-[9px] uppercase tracking-tighter z-10 ${iconColor}`}>
                      {log.action_type.substring(0, 3)}
                    </div>
                    <div className="flex-1 min-w-0 bg-slate-50 dark:bg-slate-700/50 border border-slate-100 dark:border-slate-700/50 rounded-xl p-3 group-hover:bg-white dark:bg-slate-800 group-hover:border-slate-200 dark:border-slate-700/50 group-hover:shadow-sm transition-all">
                      <div className="flex justify-between items-start mb-1">
                        <p className="text-xs font-black text-slate-700 dark:text-slate-200">{log.action_type}</p>
                        <div className="text-[9px] text-slate-400 dark:text-slate-300 font-mono text-right">
                          {log.timestamp.split(' ')[1].substring(0,5)}
                        </div>
                      </div>
                      <p className="text-[11px] text-slate-500 dark:text-slate-400 dark:text-slate-300 leading-relaxed truncate" title={log.details}>{log.details}</p>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

      </div>
      
      {/* CSS for custom scrollbar within components */}
      <style>{`
        .custom-scrollbar::-webkit-scrollbar {
          width: 4px;
        }
        .custom-scrollbar::-webkit-scrollbar-track {
          background: transparent;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb {
          background: #cbd5e1;
          border-radius: 4px;
        }
        .custom-scrollbar:hover::-webkit-scrollbar-thumb {
          background: #94a3b8;
        }
      `}</style>

    </div>
  );
}