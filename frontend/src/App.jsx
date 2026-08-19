import { useState, useEffect } from 'react';
import { API_URL } from './config';
import Sidebar from './components/Sidebar';
import DashboardPage from './components/DashboardPage';
import ResidentPage from './components/ResidentPage';
import FinancePage from './components/FinancePage';
import RoomPage from './components/RoomPage';
import PriceSettingsPage from './components/PriceSettingsPage';
import EntryExitBillingPage from './components/EntryExitBillingPage';
import EvidencePage from './components/EvidencePage';
import MaintenancePage from './components/MaintenancePage';
import LoginPage from './components/LoginPage';
import SetupPage from './components/SetupPage';
import LiffLinkAccount from './pages/LiffLinkAccount';

// Import Admin Components
import AdminManagementPage from './components/admin/AdminManagementPage';
import LogPage from './components/admin/LogPage';
import BackupPage from './components/admin/BackupPage';



function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(!!localStorage.getItem('dorminet_token'));
  const [needsSetup, setNeedsSetup] = useState(null);
  const [userId, setUserId] = useState(localStorage.getItem('user_id') || '');
  const [username, setUsername] = useState(localStorage.getItem('username') || 'admin');
  const [profileImage, setProfileImage] = useState(localStorage.getItem('profile_image') || '');
  const [userRole, setUserRole] = useState(localStorage.getItem('user_role') || 'services');
  const [activeMenu, setActiveMenu] = useState('dashboard');
  const [osMode, setOsMode] = useState('dorm'); // 'dorm' | 'network' | 'admin'

  useEffect(() => {
    const checkSetup = async () => {
      try {
        const res = await fetch(`${API_URL}/setup/status`);
        if (res.ok) {
          const data = await res.json();
          setNeedsSetup(data.needsSetup);
        } else {
          setNeedsSetup(false);
        }
      } catch (err) {
        console.error("Setup check failed", err);
        setNeedsSetup(false);
      }
    };
    checkSetup();
  }, []);

  useEffect(() => {
    if (userRole === 'admin' && osMode !== 'dorm') {
      setOsMode('dorm');
      setActiveMenu('dashboard');
    }
  }, [userRole, osMode]);
  const [theme, setTheme] = useState(localStorage.getItem('theme') || 'light');

  useEffect(() => {
    if (theme === 'dark') {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
    localStorage.setItem('theme', theme);
  }, [theme]);

  const [logs, setLogs] = useState([]);
  const [sidebarPos, setSidebarPos] = useState('left');
  const [toast, setToast] = useState({ visible: false, message: '', type: 'success' });
  const [showBackupPrompt, setShowBackupPrompt] = useState(false);
  const [isBackupLoading, setIsBackupLoading] = useState(false);

  const showToast = (message, type = 'success') => {
    setToast({ visible: true, message, type });
    setTimeout(() => { setToast({ visible: false, message: '', type: 'success' }); }, 3000);
  };

  const fetchLogs = async () => {
    try {
      const token = localStorage.getItem('dorminet_token');
      const res = await fetch(`${API_URL}/logs`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setLogs(data || []);
      }
    } catch (err) {
      console.error('Failed to fetch logs', err);
    }
  };

  const addLog = (action, details) => {
    fetch(`${API_URL}/logs`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action_type: action, details: details })
    }).then(res => { if (res.ok) fetchLogs(); }).catch(() => {});
  };

  useEffect(() => {
    if (isAuthenticated) {
      fetchLogs();
      
      // Ping server every 2 seconds to update online status
      const pingInterval = setInterval(async () => {
        try {
          const token = localStorage.getItem('dorminet_token');
          await fetch(`${API_URL}/admins/ping`, {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${token}` }
          });
        } catch (err) {
          console.error('Ping failed', err);
        }
      }, 2000);
      
      // Initial ping
      const initialPing = async () => {
        try {
          const token = localStorage.getItem('dorminet_token');
          await fetch(`${API_URL}/admins/ping`, {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${token}` }
          });
        } catch (err) {}
      };
      initialPing();

      const hasAsked = sessionStorage.getItem('hasAskedBackup');
      if (!hasAsked) {
        setShowBackupPrompt(true);
      }

      return () => clearInterval(pingInterval);
    }
    
    const handleAuthError = () => {
      setIsAuthenticated(false);
      showToast('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่', 'error');
    };
    window.addEventListener('auth_error', handleAuthError);
    
    return () => {
      window.removeEventListener('auth_error', handleAuthError);
    };
  }, [isAuthenticated]);

  // [เพิ่มใหม่] รับ Event เปลี่ยนหน้าข้าม Component แยกออกมาเพื่อไม่ให้ติดเงื่อนไข auth
  useEffect(() => {
    const handleMenuChange = (e) => setActiveMenu(e.detail);
    window.addEventListener('change_menu', handleMenuChange);
    return () => window.removeEventListener('change_menu', handleMenuChange);
  }, []);

  const handleBackupNow = async () => {
    setIsBackupLoading(true);
    try {
      const res = await fetch(`${API_URL}/system/backup/auto`, { method: 'POST' });
      if (res.ok) {
        showToast('กำลังสั่งสำรองข้อมูลอยู่เบื้องหลังเรียบร้อยแล้ว', 'success');
        addLog('Backup', 'ระบบสั่งสำรองข้อมูลอัตโนมัติ (Manual Prompt)');
      }
    } catch (err) {
      console.error(err);
      showToast('เกิดข้อผิดพลาดในการสั่งสำรองข้อมูล', 'error');
    }
    sessionStorage.setItem('hasAskedBackup', 'true');
    setIsBackupLoading(false);
    setShowBackupPrompt(false);
  };

  const handleSkipBackup = () => {
    sessionStorage.setItem('hasAskedBackup', 'true');
    setShowBackupPrompt(false);
  };

  const handleLogout = async () => {
    try {
      const token = localStorage.getItem('dorminet_token');
      if (token) {
        await fetch(`${API_URL}/logout`, {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${token}` }
        });
      }
    } catch (err) {
      console.error('Logout error', err);
    }
    
    localStorage.removeItem('dorminet_token');
    localStorage.removeItem('username');
    localStorage.removeItem('user_role');
    localStorage.removeItem('profile_image');
    setIsAuthenticated(false);
    setUsername('');
    setProfileImage('');
    setUserRole('services');
    setOsMode('dorm');
    setActiveMenu('dashboard');
  };

  const isLiff = window.location.pathname.includes('/liff') || 
                 window.location.search.includes('liff') || 
                 navigator.userAgent.includes('Line');
  
  if (isLiff) {
    return <LiffLinkAccount />;
  }

  if (needsSetup === null) {
    return (
      <div className="h-screen bg-slate-50 flex flex-col items-center justify-center">
        <div className="w-12 h-12 border-4 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
        <p className="mt-4 text-slate-500 dark:text-slate-400 dark:text-slate-300 font-bold tracking-widest text-sm animate-pulse">กำลังตรวจสอบระบบ...</p>
      </div>
    );
  }

  if (needsSetup) {
    return <SetupPage onSetupComplete={() => setNeedsSetup(false)} />;
  }

  if (!isAuthenticated) {
    return <LoginPage onLogin={() => {
      setIsAuthenticated(true);
      setUserId(localStorage.getItem('user_id') || '');
      setUsername(localStorage.getItem('username') || 'admin');
      setProfileImage(localStorage.getItem('profile_image') || '');
      const role = localStorage.getItem('user_role') || 'services';
      setUserRole(role);
      setOsMode('dorm');
      setActiveMenu('dashboard');
    }} />;
  }

  return (
    <div className="flex h-screen bg-[#f5f5f7] dark:bg-[#111827] text-slate-800 dark:text-slate-200 font-sans antialiased overflow-hidden selection:bg-indigo-500/30">
      <Sidebar 
        userId={userId}
        setProfileImage={setProfileImage}
        activeMenu={activeMenu} 
        setActiveMenu={setActiveMenu} 
        sidebarPos={sidebarPos} 
        setSidebarPos={setSidebarPos}
        osMode={osMode}
        setOsMode={setOsMode}
        username={username}
        profileImage={profileImage}
        userRole={userRole}
        handleLogout={handleLogout}
        showToast={showToast}
        theme={theme}
        setTheme={setTheme}
      />
      <div className="flex-1 flex flex-col h-screen overflow-hidden relative">
        <header className="bg-[#f5f5f7]/80 dark:bg-slate-900/80 backdrop-blur-md border-b border-slate-200/50 dark:border-slate-800 px-8 py-3.5 flex items-center justify-between z-10">
          <h2 className="text-sm font-extrabold text-slate-800 dark:text-slate-200 uppercase tracking-wider">
            {activeMenu === 'dashboard' && 'ภาพรวมระบบ (Dormitory)'}
            {activeMenu === 'admin_management' && 'จัดการผู้ใช้งาน'}
            {activeMenu === 'residents' && 'จัดการลูกบ้าน'}
            {activeMenu === 'finance' && 'การเงินและชำระเงิน'}
            {activeMenu === 'entry_exit' && 'บิลค่าใช้จ่าย (เข้า-ออก)'}
            {activeMenu === 'rooms' && 'จัดการห้องพัก'}
            {activeMenu === 'prices' && 'ตั้งค่าราคา'}
            {activeMenu === 'backup' && 'สำรองข้อมูล'}
            {activeMenu === 'maintenance' && 'แจ้งซ่อม'}
            {activeMenu === 'evidence' && 'หลักฐานการโอน'}
            {activeMenu === 'logs' && 'ประวัติการใช้งาน'}

          </h2>
          <div className="flex items-center gap-4">
            <span className="text-xs font-black tracking-widest text-slate-400 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase bg-slate-100/50 dark:bg-slate-800/50 px-3 py-1.5 rounded-lg border border-slate-200/50 dark:border-slate-700">
              STATUS: <span className="text-emerald-500 ml-1">• ONLINE</span>
            </span>
          </div>
        </header>
        <main className="flex-1 p-8 overflow-y-auto">
          {/* Admin OS Pages */}
          {osMode === 'admin' && activeMenu === 'admin_management' && <AdminManagementPage currentUsername={username} showToast={showToast} profileImage={profileImage} setProfileImage={setProfileImage} />}
          {osMode === 'admin' && activeMenu === 'logs' && <LogPage logs={logs} fetchLogs={fetchLogs} />}
          {osMode === 'admin' && activeMenu === 'backup' && <BackupPage addLog={addLog} showToast={showToast} />}

          {/* Dormitory Pages */}
          {osMode === 'dorm' && activeMenu === 'dashboard' && <DashboardPage addLog={addLog} />}
          {osMode === 'dorm' && activeMenu === 'residents' && <ResidentPage addLog={addLog} showToast={showToast} />}
          {osMode === 'dorm' && activeMenu === 'finance' && <FinancePage addLog={addLog} showToast={showToast} />}
          {osMode === 'dorm' && activeMenu === 'entry_exit' && <EntryExitBillingPage addLog={addLog} showToast={showToast} />}
          {osMode === 'dorm' && activeMenu === 'rooms' && <RoomPage addLog={addLog} showToast={showToast} />}
          {osMode === 'dorm' && activeMenu === 'prices' && <PriceSettingsPage addLog={addLog} showToast={showToast} />}
          {osMode === 'dorm' && activeMenu === 'evidence' && <EvidencePage addLog={addLog} showToast={showToast} />}
          {osMode === 'dorm' && activeMenu === 'maintenance' && <MaintenancePage addLog={addLog} showToast={showToast} />}

        </main>
        {toast.visible && (
          <div className="absolute top-6 right-6 bg-white/90 dark:bg-slate-800/90 backdrop-blur-md text-slate-800 dark:text-slate-200 border border-slate-200/60 dark:border-slate-700 rounded-xl px-5 py-3.5 shadow-[0_10px_35px_rgba(0,0,0,0.06)] dark:shadow-none flex items-center gap-3 transform transition-all duration-300 z-[9999] animate-fade-in">
            {toast.type === 'success' ? (
              <div className="w-5 h-5 rounded-full bg-emerald-500 text-white flex items-center justify-center shadow-sm shadow-emerald-500/20">
                <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="3"><path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" /></svg>
              </div>
            ) : (
              <div className="w-5 h-5 rounded-full bg-red-500 text-white flex items-center justify-center shadow-sm shadow-red-500/20">
                <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="3"><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
              </div>
            )}
            <div className="flex flex-col">
              <span className="text-[10px] font-black text-slate-400 dark:text-slate-300 uppercase tracking-widest">{toast.type === 'success' ? 'Notification' : 'Error Alert'}</span>
              <span className="text-xs font-semibold text-slate-700 dark:text-slate-200 mt-0.5">{toast.message}</span>
            </div>
          </div>
        )}
      </div>

      {showBackupPrompt && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 z-[9999] animate-fade-in font-sans">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden border border-slate-200">
            <div className="p-8">
              <div className="flex items-center justify-center mb-6">
                <div className="w-16 h-16 bg-blue-50 text-blue-600 rounded-full flex items-center justify-center shadow-inner">
                  <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M8 7v8a2 2 0 002 2h6M8 7V5a2 2 0 012-2h4.586a1 1 0 01.707.293l4.414 4.414a1 1 0 01.293.707V15a2 2 0 01-2 2h-2M8 7H6a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2v-2" /></svg>
                </div>
              </div>
              <h3 className="text-xl font-black text-slate-800 dark:text-slate-100 text-center mb-3">ต้องการสำรองข้อมูลหรือไม่?</h3>
              <p className="text-sm text-slate-500 dark:text-slate-400 dark:text-slate-300 text-center mb-8 leading-relaxed font-medium">
                พบการเริ่มต้นใช้งานระบบใหม่ เพื่อความปลอดภัยของข้อมูล คุณต้องการให้ระบบสำรองข้อมูล (Backup) ตอนนี้เลยหรือไม่?
              </p>
              <div className="flex flex-col gap-3">
                <button 
                  onClick={handleBackupNow}
                  disabled={isBackupLoading}
                  className="w-full bg-blue-600 hover:bg-blue-700 text-white py-3.5 rounded-xl text-sm font-black uppercase tracking-widest shadow-lg shadow-blue-500/30 transition-all flex justify-center items-center gap-2"
                >
                  {isBackupLoading ? (
                    <><svg className="animate-spin h-5 w-5" viewBox="0 0 24 24" fill="none"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg> กำลังส่งคำสั่ง...</>
                  ) : 'สำรองข้อมูลเดี๋ยวนี้'}
                </button>
                <button 
                  onClick={handleSkipBackup}
                  disabled={isBackupLoading}
                  className="w-full bg-slate-50 hover:bg-slate-100 text-slate-600 dark:text-slate-300 border border-slate-200 py-3.5 rounded-xl text-sm font-black uppercase tracking-widest transition-all"
                >
                  ข้ามไปก่อน
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;