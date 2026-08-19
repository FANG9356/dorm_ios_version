import React, { useRef, useState } from 'react';
import { API_URL } from '../config';
import QRCodeDisplayModal from './QRCodeDisplayModal';
import InviteQRModal from './InviteQRModal';

export default function Sidebar({ isMobileMenuOpen, setIsMobileMenuOpen, userId, setProfileImage, activeMenu, setActiveMenu, sidebarPos, setSidebarPos, osMode, setOsMode, username, profileImage, userRole, handleLogout, showToast, theme, setTheme }) {
    
  const fileInputRef = useRef(null);
  const [isUploading, setIsUploading] = useState(false);
  const [isQRModalOpen, setIsQRModalOpen] = useState(false);
  const [isInviteModalOpen, setIsInviteModalOpen] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);

  const toggleFullscreen = () => {
    if (window.runtime) {
      if (isFullscreen) {
        window.runtime.WindowUnfullscreen();
        setIsFullscreen(false);
      } else {
        window.runtime.WindowFullscreen();
        setIsFullscreen(true);
      }
    }
  };

  const handleImageUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    
    let currentUserId = userId;
    const token = localStorage.getItem('dorminet_token');
    
    if (!currentUserId && token) {
      try {
        const payload = JSON.parse(atob(token.split('.')[1]));
        if (payload && (payload.id || payload.admin_id)) {
          currentUserId = payload.id || payload.admin_id;
          localStorage.setItem('user_id', payload.id || payload.admin_id);
        }
      } catch (e) {
        console.error('Cannot decode token', e);
      }
    }
    
    if (!currentUserId) {
      showToast('ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบใหม่', 'error');
      return;
    }
    
    const formData = new FormData();
    formData.append('profile_image', file);
    try {
      setIsUploading(true);
      showToast('กำลังอัปโหลดรูปภาพ...', 'success');
      const token = localStorage.getItem('dorminet_token');
      const res = await fetch(`${API_URL}/admins/profile-image?id=${currentUserId}`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        body: formData
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'อัปโหลดไม่สำเร็จ');
      
      setProfileImage(data.profile_image);
      localStorage.setItem('profile_image', data.profile_image);
      showToast('อัปโหลดรูปโปรไฟล์สำเร็จ', 'success');
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setIsUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };
    
  const togglePosition = () => setSidebarPos(sidebarPos === 'left' ? 'right' : 'left');

  const dormMenuItems = [
    {
      id: 'dashboard',
      label: 'ภาพรวมระบบ',
      icon: (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
        </svg>
      )
    },
    {
      id: 'residents',
      label: 'จัดการลูกบ้าน',
      icon: (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
        </svg>
      )
    },
    {
      id: 'finance',
      label: 'การเงินและชำระเงิน',
      icon: (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
        </svg>
      )
    },
    {
      id: 'entry_exit',
      label: 'บิลค่าใช้จ่าย (เข้า-ออก)',
      icon: (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
      )
    },
    {
      id: 'rooms',
      label: 'จัดการห้องพัก',
      icon: (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
        </svg>
      )
    },
    {
      id: 'prices',
      label: 'ตั้งค่าราคา',
      icon: (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
        </svg>
      )
    },
    {
      id: 'evidence',
      label: 'หลักฐานการโอน',
      icon: (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
        </svg>
      )
    },
    {
      id: 'maintenance',
      label: 'แจ้งซ่อม',
      icon: (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
        </svg>
      )
    }
  ];

  const adminMenuItems = [
    {
      id: 'admin_management',
      label: 'จัดการผู้ใช้งาน',
      icon: (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
        </svg>
      )
    },
    {
      id: 'backup',
      label: 'สำรองข้อมูลระบบ',
      icon: (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
        </svg>
      )
    },
    {
      id: 'logs',
      label: 'ประวัติการใช้งาน',
      icon: (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      )
    }
  ];

  const menuItems = osMode === 'admin' ? adminMenuItems : dormMenuItems;

  return (
    <>
      {/* Mobile Backdrop */}
      {isMobileMenuOpen && (
        <div 
          className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-40 lg:hidden transition-opacity"
          onClick={() => setIsMobileMenuOpen(false)}
        />
      )}
      
      <aside className={`
        fixed lg:static inset-y-0 left-0 z-50
        w-64 bg-[#f6f6f6]/95 dark:bg-slate-900/95 backdrop-blur-md text-slate-700 dark:text-slate-200 
        flex flex-col h-full border-r border-slate-200/80 dark:border-slate-800
        transition-transform duration-300 ease-in-out
        ${isMobileMenuOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}
      `}>
        <div draggable onDragEnd={togglePosition} onClick={togglePosition} className="absolute top-0 left-0 w-full h-1.5 bg-slate-200/50 dark:bg-slate-800/50 cursor-grab active:cursor-grabbing hover:bg-[#007aff] transition-colors opacity-0 group-hover:opacity-100 flex items-center justify-center"></div>
        <div className="px-6 pb-5 pt-[max(env(safe-area-inset-top),1.25rem)] border-b border-slate-200/50 dark:border-slate-800 flex items-center gap-3">
          <div className="w-6 h-6 bg-[#007aff] rounded-lg flex items-center justify-center font-bold text-white text-[10px] shadow-sm">S</div>
          <h1 className="text-sm font-extrabold tracking-widest text-slate-900 dark:text-slate-100 uppercase font-sans">
            {osMode === 'admin' ? 'DormiNet ADMIN' : 'DormiNet DORM'}
          </h1>
        </div>
        
        <div className="flex-1 overflow-y-auto overscroll-contain pb-8 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
          <div className="px-5 py-4 text-[10px] font-black text-slate-400 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest mt-1">Menu</div>
          <nav className="px-3.5 space-y-1">
            {menuItems.map(item => {
              const isActive = activeMenu === item.id;
              let activeBg = 'bg-[#007aff] text-white shadow-sm shadow-blue-500/20';
              if (osMode === 'admin') activeBg = 'bg-indigo-600 text-white shadow-sm shadow-indigo-500/20';
              return (
                <button
                  key={item.id}
                  onClick={() => { setActiveMenu(item.id); setIsMobileMenuOpen(false); }}
                  className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg text-xs font-semibold transition-all duration-150 ${isActive ? activeBg : 'text-slate-600 dark:text-slate-400 dark:text-slate-300 hover:bg-slate-200/60 dark:hover:bg-slate-800/60 hover:text-slate-900 dark:hover:text-slate-200'}`}
                >
                  <span className={isActive ? 'text-white' : 'text-slate-400 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300'}>
                    {item.icon}
                  </span>
                  {item.label}
                </button>
              );
            })}
          </nav>
        </div>

        <div className="border-t border-slate-200/50 dark:border-slate-800 bg-[#f6f6f6] dark:bg-slate-900 px-4 py-3 shrink-0 flex flex-col gap-3">
          


          <button 
            onClick={() => setIsQRModalOpen(true)}
            className="flex items-center justify-between px-3 py-2 bg-blue-500/10 hover:bg-blue-500/20 text-blue-600 dark:text-blue-400 rounded-lg transition-colors w-full mb-1"
          >
            <span className="text-xs font-bold flex items-center gap-2">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm14 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z" />
              </svg>
              แสดง QR เครื่องแม่ข่าย
            </span>
          </button>

          <button 
            onClick={toggleFullscreen}
            className="flex items-center justify-between px-3 py-2 bg-slate-200/50 dark:bg-slate-800/50 hover:bg-slate-200 dark:hover:bg-slate-800 rounded-lg transition-colors w-full mb-1"
          >
            <span className="text-xs font-bold text-slate-600 dark:text-slate-400 dark:text-slate-300 flex items-center gap-2">
              {isFullscreen ? (
                <>
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" /></svg>
                  ย่อหน้าจอ
                </>
              ) : (
                <>
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" /></svg>
                  ขยายเต็มจอ
                </>
              )}
            </span>
          </button>

          <button 
            onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}
            className="flex items-center justify-between px-3 py-2 bg-slate-200/50 dark:bg-slate-800/50 hover:bg-slate-200 dark:hover:bg-slate-800 rounded-lg transition-colors w-full"
          >
            <span className="text-xs font-bold text-slate-600 dark:text-slate-400 dark:text-slate-300">
              {theme === 'light' ? 'Dark Mode' : 'Light Mode'}
            </span>
            {theme === 'light' ? (
              <svg className="w-4 h-4 text-slate-600 dark:text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" /></svg>
            ) : (
              <svg className="w-4 h-4 text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" /></svg>
            )}
          </button>

          <div className="flex items-center justify-between pt-2 border-t border-slate-200/50 dark:border-slate-800">
            <input 
              type="file" 
              ref={fileInputRef} 
              className="hidden" 
              accept="image/*" 
              onChange={handleImageUpload} 
            />
            <button 
              onClick={() => {
                if (userRole === 'admin') {
                  fileInputRef.current?.click();
                  return;
                }
                const newMode = osMode === 'admin' ? 'dorm' : 'admin';
                setOsMode(newMode);
                setActiveMenu(newMode === 'admin' ? 'admin_management' : 'dashboard');
              }}
              className={`flex items-center gap-2 hover:bg-slate-200/50 dark:hover:bg-slate-800/50 p-1.5 -ml-1.5 rounded-xl transition-all cursor-pointer ${osMode === 'admin' ? 'bg-slate-200/50 dark:bg-slate-800/50' : ''}`}
            >
              <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-blue-500 to-purple-500 flex items-center justify-center text-white font-bold text-xs shadow-sm overflow-hidden">
                {profileImage ? (
                  <img src={`${API_URL.replace('/api', '')}${profileImage}`} alt="Profile" className="w-full h-full object-cover" />
                ) : (
                  username ? username.charAt(0).toUpperCase() : 'A'
                )}
              </div>
              <div className="flex flex-col text-left">
                <span className="text-xs font-bold text-slate-700 dark:text-slate-300">{username || 'Admin'}</span>
                <span className="text-[9px] text-slate-400 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300 font-medium">Administrator</span>
              </div>
            </button>
            <button
              onClick={handleLogout}
              className="p-1.5 text-slate-400 dark:text-slate-500 dark:text-slate-400 dark:text-slate-300 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-500/10 rounded-lg transition-colors"
              title="ออกจากระบบ"
            >
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" /></svg>
            </button>
          </div>
        </div>
      </aside>
      
      <QRCodeDisplayModal 
        isOpen={isQRModalOpen} 
        onClose={() => setIsQRModalOpen(false)} 
      />

      <InviteQRModal 
        isOpen={isInviteModalOpen}
        onClose={() => setIsInviteModalOpen(false)}
      />
    </>
  );
}