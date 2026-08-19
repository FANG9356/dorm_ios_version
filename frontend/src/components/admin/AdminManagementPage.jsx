import React, { useState, useEffect, useRef } from 'react';
import { API_URL } from '../../config';

export default function AdminManagementPage({ currentUsername, showToast, profileImage, setProfileImage }) {
  const [admins, setAdmins] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  const [showAddModal, setShowAddModal] = useState(false);
  const [newUsername, setNewUsername] = useState('');
  const [newEmail, setNewEmail] = useState('');
  const [newRole, setNewRole] = useState('services');
  const [addLoading, setAddLoading] = useState(false);

  const [editModal, setEditModal] = useState({ show: false, type: '', id: null, username: '', newPassword: '', role: 'services', email: '' });
  const [editLoading, setEditLoading] = useState(false);

  const [deleteTarget, setDeleteTarget] = useState(null);

  const [openDropdown, setOpenDropdown] = useState(null);
  const dropdownRef = useRef(null);

  useEffect(() => {
    fetchAdmins();
    const interval = setInterval(fetchAdmins, 2000); // refresh every 2s for real-time online status
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setOpenDropdown(null);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [dropdownRef]);

  useEffect(() => {
    const handleEsc = (e) => {
      if (e.key === 'Escape') {
        setShowAddModal(false);
        setEditModal({ show: false, type: '', id: null, username: '', newPassword: '', role: 'services', email: '' });
        setDeleteTarget(null);
        setOpenDropdown(null);
      }
    };
    window.addEventListener('keydown', handleEsc);
    return () => window.removeEventListener('keydown', handleEsc);
  }, []);

  const fetchAdmins = async () => {
    try {
      const token = localStorage.getItem('dorminet_token');
      const res = await fetch(`${API_URL}/admins`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (!res.ok) throw new Error('ไม่สามารถดึงข้อมูลแอดมินได้');
      const data = await res.json();
      setAdmins(data || []);
      setError(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleAddAdmin = async (e) => {
    e.preventDefault();
    if (!newUsername.trim() || newUsername.toLowerCase() === 'admin') {
      showToast('ชื่อผู้ใช้ไม่ถูกต้อง หรือซ้ำกับคำว่า admin', 'error');
      return;
    }

    setAddLoading(true);
    try {
      const token = localStorage.getItem('dorminet_token');
      const res = await fetch(`${API_URL}/admins`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}` 
        },
        body: JSON.stringify({ username: newUsername, role: newRole, email: newEmail })
      });
      
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'ไม่สามารถสร้างผู้ใช้ได้');
      
      showToast(`สร้างผู้ใช้ ${newUsername} สำเร็จ! รหัสผ่านเริ่มต้นคือ admin`, 'success');
      setShowAddModal(false);
      setNewUsername('');
      setNewEmail('');
      setNewRole('services');
      fetchAdmins();
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setAddLoading(false);
    }
  };

  const fileInputRefs = useRef({});

  const handleImageUpload = async (adminId, file) => {
    if (!file) return;
    const formData = new FormData();
    formData.append('profile_image', file);
    try {
      showToast('กำลังอัปโหลดรูปภาพ...', 'success');
      const token = localStorage.getItem('dorminet_token');
      const res = await fetch(`${API_URL}/admins/profile-image?id=${adminId}`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        body: formData
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'อัปโหลดไม่สำเร็จ');
      showToast('อัปโหลดรูปโปรไฟล์สำเร็จ', 'success');
      
      const admin = admins.find(a => a.id === adminId);
      if (admin && admin.username === currentUsername) {
        setProfileImage(data.profile_image);
        localStorage.setItem('profile_image', data.profile_image);
      }
      fetchAdmins();
    } catch (err) {
      showToast(err.message, 'error');
    }
  };

  const handleEditSubmit = async (e) => {
    e.preventDefault();
    if (editModal.type === 'rename' && (!editModal.username.trim() || editModal.username.toLowerCase() === 'admin')) {
      showToast('ชื่อผู้ใช้ไม่ถูกต้อง', 'error');
      return;
    }
    
    // Add password validation here
    if (editModal.type === 'password') {
      const pw = editModal.newPassword;
      if (pw.length < 8 || !/[a-zA-Z]/.test(pw) || !/[0-9]/.test(pw)) {
        showToast('รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร และประกอบด้วยตัวอักษรและตัวเลข', 'error');
        return;
      }
    }

    setEditLoading(true);
    try {
      const token = localStorage.getItem('dorminet_token');
      const body = editModal.type === 'rename' 
        ? { username: editModal.username, email: editModal.email }
        : editModal.type === 'password'
        ? { new_password: editModal.newPassword }
        : { role: editModal.role };

      const res = await fetch(`${API_URL}/admins/${editModal.id}`, {
        method: 'PUT',
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}` 
        },
        body: JSON.stringify(body)
      });
      
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'ไม่สามารถอัปเดตข้อมูลได้');
      
      const targetAdmin = admins.find(a => a.id === editModal.id);
      const isSelf = targetAdmin && targetAdmin.username === currentUsername;

      if (isSelf) {
        showToast('อัปเดตข้อมูลสำเร็จ ระบบกำลังบังคับออกจากระบบเพื่อเข้าสู่ระบบใหม่...', 'success');
        setEditModal({ show: false, type: '', id: null, username: '', newPassword: '', role: 'services', email: '' });
        setTimeout(() => {
          localStorage.removeItem('dorminet_token');
          localStorage.removeItem('dorm_os_mode');
          window.location.reload();
        }, 2000);
      } else {
        showToast('อัปเดตข้อมูลสำเร็จ', 'success');
        setEditModal({ show: false, type: '', id: null, username: '', newPassword: '', role: 'services', email: '' });
        fetchAdmins();
      }
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setEditLoading(false);
    }
  };

  const handleDeleteAdmin = (id, username) => {
    if (id === 1) {
      showToast('ไม่สามารถลบบัญชีหลักได้', 'error');
      return;
    }
    if (username === currentUsername) {
      showToast('ไม่สามารถลบบัญชีที่กำลังใช้งานอยู่ได้', 'error');
      return;
    }
    setDeleteTarget({ id, username });
  };

  const confirmDeleteAdmin = async () => {
    if (!deleteTarget) return;
    const { id } = deleteTarget;

    try {
      const token = localStorage.getItem('dorminet_token');
      const res = await fetch(`${API_URL}/admins/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || 'ไม่สามารถลบข้อมูลได้');
      }
      
      showToast('ลบผู้ใช้สำเร็จ', 'success');
      setDeleteTarget(null);
      fetchAdmins();
    } catch (err) {
      showToast(err.message, 'error');
      setDeleteTarget(null);
    }
  };

  const isOnline = (lastActiveStr) => {
    if (!lastActiveStr) return false;
    
    // The API already returns proper ISO 8601 format (e.g., 2026-06-26T03:14:22Z)
    // So we can parse it directly using new Date() which works in all browsers including Safari
    const lastActive = new Date(lastActiveStr);
    
    const now = new Date();
    const diff = now - lastActive;
    return diff < 10000 && !isNaN(diff); // 10 seconds threshold for real-time
  };

  return (
    <>
      <div className="animate-fade-in relative min-h-full font-sans pb-10 text-slate-800 dark:text-slate-100">
        <div className="mb-10 flex flex-col lg:flex-row justify-between items-start lg:items-end gap-4 border-b border-slate-200/60 dark:border-slate-700/50 pb-6">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <div className="bg-slate-900 text-white p-2 rounded-xl shadow-md">
              <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
            </div>
            <h2 className="text-2xl font-black text-slate-900 dark:text-slate-100 tracking-tight uppercase">User Management</h2>
          </div>
          <div className="flex items-center gap-3">
            <p className="text-sm font-medium text-slate-500 dark:text-slate-400 dark:text-slate-300">จัดการบัญชีผู้ดูแลระบบ และกำหนดสิทธิ์การใช้งาน</p>
            <span className="px-2 py-0.5 rounded-md text-[10px] font-bold bg-emerald-100 text-emerald-700 tracking-wider">ACTIVE</span>
          </div>
        </div>
        <button
          onClick={() => setShowAddModal(true)}
          className="flex items-center gap-2 bg-[#007aff] hover:bg-blue-600 text-white px-4 py-2 rounded-xl text-sm font-bold shadow-lg shadow-blue-500/20 transition-all active:scale-95"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M12 4v16m8-8H4" /></svg>
          เพิ่ม Admin
        </button>
      </div>

      {loading && admins.length === 0 ? (
        <div className="flex justify-center items-center py-20">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#007aff]"></div>
        </div>
      ) : error ? (
        <div className="bg-red-50 text-red-600 p-4 rounded-xl border border-red-100 flex items-center gap-3">
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          <span className="font-bold">{error}</span>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {admins.map((admin) => {
            const online = admin.username === currentUsername || isOnline(admin.last_active);
            
            return (
              <div key={admin.id} className="bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200/60 dark:border-slate-700/50 shadow-sm hover:shadow-md transition-all relative group">
                <div className="flex justify-between items-start mb-4">
                  <div className="flex items-center gap-4">
                    <div className="relative group/avatar cursor-pointer" onClick={() => fileInputRefs.current[admin.id]?.click()}>
                      <input 
                        type="file" 
                        ref={el => fileInputRefs.current[admin.id] = el}
                        className="hidden" 
                        accept="image/*"
                        onChange={(e) => handleImageUpload(admin.id, e.target.files[0])}
                      />
                      <div className="w-12 h-12 rounded-2xl bg-gradient-to-tr from-[#007aff] to-purple-500 flex items-center justify-center text-white font-bold text-xl shadow-inner overflow-hidden relative">
                        {admin.profile_image ? (
                          <img src={`${API_URL.replace('/api', '')}${admin.profile_image}`} alt="Profile" className="w-full h-full object-cover" />
                        ) : (
                          admin.username.charAt(0).toUpperCase()
                        )}
                        <div className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 group-hover/avatar:opacity-100 transition-opacity">
                          <svg className="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                        </div>
                      </div>
                      <div className={`absolute -bottom-1 -right-1 w-4 h-4 border-2 border-white rounded-full ${online ? 'bg-emerald-500' : 'bg-slate-300'}`}></div>
                    </div>
                    <div>
                      <h3 className="text-lg font-bold text-slate-800 dark:text-slate-100 flex items-center gap-2">
                        {admin.username}
                        {admin.username === currentUsername && (
                          <span className="px-2 py-0.5 rounded text-[10px] font-black bg-[#007aff]/10 text-[#007aff] tracking-wider uppercase">YOU</span>
                        )}
                      </h3>
                      <p className="text-xs font-medium text-slate-400 dark:text-slate-300 mt-0.5 flex items-center gap-1.5">
                        {online ? (
                          <><span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span> Online Now</>
                        ) : (
                          <><span className="w-1.5 h-1.5 rounded-full bg-slate-300"></span> Offline</>
                        )}
                        <span className="mx-1">•</span>
                        <span className={`px-2 py-0.5 rounded uppercase text-[9px] font-black tracking-wider ${admin.role === 'services' ? 'bg-purple-100 text-purple-700' : 'bg-slate-100 text-slate-600 dark:text-slate-300'}`}>
                          {admin.role === 'services' ? 'SERVICES' : 'ADMIN'}
                        </span>
                      </p>
                      {admin.email && (
                        <p className="text-xs font-medium text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-1 flex items-center gap-1.5">
                          <svg className="w-3 h-3 text-slate-400 dark:text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>
                          {admin.email}
                        </p>
                      )}
                    </div>
                  </div>
                  
                  <div className="relative">
                    <button 
                      onClick={() => setOpenDropdown(openDropdown === admin.id ? null : admin.id)}
                      className="p-2 text-slate-400 dark:text-slate-300 hover:text-slate-800 dark:text-slate-100 hover:bg-slate-100 rounded-lg transition-colors"
                    >
                      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z" /></svg>
                    </button>

                    {openDropdown === admin.id && (
                      <div ref={dropdownRef} className="absolute right-0 mt-1 w-48 bg-white dark:bg-slate-800 rounded-xl shadow-xl border border-slate-100 dark:border-slate-700/50 py-2 z-20 animate-fade-in">
                        <button 
                          onClick={() => {
                            setEditModal({ show: true, type: 'rename', id: admin.id, username: admin.username, newPassword: '', role: admin.role || 'services', email: admin.email || '' });
                            setOpenDropdown(null);
                          }}
                          className="w-full text-left px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:bg-slate-700/50 flex items-center gap-2"
                        >
                          <svg className="w-4 h-4 text-slate-400 dark:text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
                          แก้ไขข้อมูลผู้ใช้
                        </button>
                        <button 
                          onClick={() => {
                            setEditModal({ show: true, type: 'password', id: admin.id, username: admin.username, newPassword: '', role: admin.role || 'services' });
                            setOpenDropdown(null);
                          }}
                          className="w-full text-left px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:bg-slate-700/50 flex items-center gap-2"
                        >
                          <svg className="w-4 h-4 text-slate-400 dark:text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" /></svg>
                          เปลี่ยนรหัสผ่าน
                        </button>
                        
                        {(admin.id !== 1 && admin.username !== currentUsername) && (
                          <>
                            <button 
                              onClick={() => {
                                setEditModal({ show: true, type: 'role', id: admin.id, username: admin.username, newPassword: '', role: admin.role || 'services' });
                                setOpenDropdown(null);
                              }}
                              className="w-full text-left px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:bg-slate-700/50 flex items-center gap-2"
                            >
                              <svg className="w-4 h-4 text-slate-400 dark:text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" /></svg>
                              เปลี่ยนสิทธิ์การเข้าถึง
                            </button>
                            <div className="h-px bg-slate-100 my-1 mx-2"></div>
                            <button 
                              onClick={() => {
                                handleDeleteAdmin(admin.id, admin.username);
                                setOpenDropdown(null);
                              }}
                              className="w-full text-left px-4 py-2 text-sm font-bold text-red-600 hover:bg-red-50 flex items-center gap-2"
                            >
                              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                              ลบบัญชี
                            </button>
                          </>
                        )}
                      </div>
                    )}
                  </div>
                </div>

                <div className="bg-slate-50 dark:bg-slate-700/50 rounded-xl p-3 flex items-center justify-between text-xs font-mono text-slate-500 dark:text-slate-400 dark:text-slate-300">
                  <span>ID: #{admin.id}</span>
                  {admin.id === 1 && <span className="bg-amber-100 text-amber-700 px-2 py-0.5 rounded font-bold">Main Admin</span>}
                </div>
              </div>
            );
          })}
        </div>
      )}
      </div>

      {/* Add Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-start justify-end p-8 bg-slate-900/20 backdrop-blur-[2px] animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-3xl shadow-2xl p-6 max-w-sm w-full mt-16 border border-slate-100 dark:border-slate-700/50 animate-slide-in-right">
            <div className="flex justify-between items-center mb-5">
              <h3 className="text-lg font-bold text-slate-900 dark:text-slate-100">เพิ่มผู้ใช้ใหม่</h3>
              <button onClick={() => setShowAddModal(false)} className="text-slate-400 dark:text-slate-300 hover:bg-slate-100 p-1.5 rounded-xl transition-colors">
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
            
            <form onSubmit={handleAddAdmin}>
              <div className="mb-5">
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-200 mb-2">ชื่อผู้ใช้งาน (Username)</label>
                <input
                  type="text"
                  value={newUsername}
                  onChange={(e) => setNewUsername(e.target.value)}
                  className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#007aff] focus:ring-4 focus:ring-[#007aff]/10 transition-all font-medium placeholder:text-slate-400 dark:text-slate-300"
                  placeholder="เช่น manager1"
                  autoFocus
                  required
                />
              </div>

              <div className="mb-5">
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-200 mb-2">อีเมล (Email) - เพื่อใช้กู้รหัสผ่าน</label>
                <input
                  type="email"
                  value={newEmail}
                  onChange={(e) => setNewEmail(e.target.value)}
                  className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#007aff] focus:ring-4 focus:ring-[#007aff]/10 transition-all font-medium placeholder:text-slate-400 dark:text-slate-300"
                  placeholder="manager@example.com"
                />
              </div>

              <div className="mb-5">
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-200 mb-2">สิทธิ์การเข้าถึง (Role)</label>
                <select
                  value={newRole}
                  onChange={(e) => setNewRole(e.target.value)}
                  className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#007aff] focus:ring-4 focus:ring-[#007aff]/10 transition-all font-medium"
                >
                  <option value="services">Services</option>
                  <option value="admin">Admin</option>
                </select>
              </div>

              <div className="bg-blue-50 text-blue-800 p-3 rounded-xl border border-blue-100 mb-5 flex gap-2.5 text-[11px] leading-relaxed">
                <svg className="w-4 h-4 shrink-0 text-[#007aff] mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                <p>รหัสผ่านเริ่มต้นคือ <strong className="font-bold">admin</strong> ระบบจะบังคับให้เปลี่ยนรหัสเมื่อเข้าสู่ระบบครั้งแรก</p>
              </div>

              <div className="flex justify-end gap-2">
                <button type="button" onClick={() => setShowAddModal(false)} className="px-4 py-2 rounded-xl text-sm font-bold text-slate-600 dark:text-slate-300 hover:bg-slate-100 transition-colors">ยกเลิก</button>
                <button type="submit" disabled={addLoading} className="px-4 py-2 bg-[#007aff] hover:bg-blue-600 text-white text-sm rounded-xl font-bold shadow-lg shadow-blue-500/20 disabled:opacity-50 transition-all active:scale-95 flex items-center gap-2">
                  {addLoading ? 'กำลังสร้าง...' : 'สร้างผู้ใช้'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Modal (Rename / Password) */}
      {editModal.show && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-sm animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-3xl shadow-2xl p-8 max-w-md w-full mx-4 border border-white/20">
            <div className="flex justify-between items-center mb-6">
              <h3 className="text-xl font-bold text-slate-900 dark:text-slate-100">
                {editModal.type === 'rename' ? 'แก้ไขข้อมูลผู้ใช้' : editModal.type === 'password' ? 'เปลี่ยนรหัสผ่าน' : 'เปลี่ยนสิทธิ์การเข้าถึง'}
              </h3>
              <button onClick={() => setEditModal({ show: false, type: '', id: null, username: '', newPassword: '', role: 'services', email: '' })} className="text-slate-400 dark:text-slate-300 hover:bg-slate-100 p-2 rounded-xl transition-colors">
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
            
            <form onSubmit={handleEditSubmit}>
              {editModal.type === 'rename' ? (
                <>
                  <div className="mb-6">
                    <label className="block text-sm font-bold text-slate-700 dark:text-slate-200 mb-2">ชื่อผู้ใช้งาน (Username) ใหม่</label>
                    <input
                      type="text"
                      value={editModal.username}
                      onChange={(e) => setEditModal({...editModal, username: e.target.value})}
                      className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-xl px-4 py-3 focus:outline-none focus:border-[#007aff] focus:ring-4 focus:ring-[#007aff]/10 transition-all font-medium"
                      autoFocus
                      required
                    />
                  </div>
                  <div className="mb-6">
                    <label className="block text-sm font-bold text-slate-700 dark:text-slate-200 mb-2">อีเมล (Email)</label>
                    <input
                      type="email"
                      value={editModal.email}
                      onChange={(e) => setEditModal({...editModal, email: e.target.value})}
                      className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-xl px-4 py-3 focus:outline-none focus:border-[#007aff] focus:ring-4 focus:ring-[#007aff]/10 transition-all font-medium"
                      placeholder="manager@example.com"
                    />
                  </div>
                </>
              ) : editModal.type === 'password' ? (
                <div className="mb-6">
                  <label className="block text-sm font-bold text-slate-700 dark:text-slate-200 mb-2">รหัสผ่านใหม่ สำหรับ {editModal.username}</label>
                  <input
                    type="password"
                    value={editModal.newPassword}
                    onChange={(e) => setEditModal({...editModal, newPassword: e.target.value})}
                    className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-xl px-4 py-3 focus:outline-none focus:border-[#007aff] focus:ring-4 focus:ring-[#007aff]/10 transition-all font-medium"
                    placeholder="ใส่รหัสผ่านใหม่ที่ต้องการตั้ง..."
                    autoFocus
                    required
                  />
                  <p className="text-xs text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-2">เมื่อเปลี่ยนรหัสผ่านแล้ว ผู้ใช้จะต้องใช้รหัสผ่านใหม่นี้ในการเข้าสู่ระบบครั้งถัดไป</p>
                </div>
              ) : (
                <div className="mb-6">
                  <label className="block text-sm font-bold text-slate-700 dark:text-slate-200 mb-2">เปลี่ยนสิทธิ์การเข้าถึง สำหรับ {editModal.username}</label>
                  <select
                    value={editModal.role}
                    onChange={(e) => setEditModal({...editModal, role: e.target.value})}
                    className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-xl px-4 py-3 focus:outline-none focus:border-[#007aff] focus:ring-4 focus:ring-[#007aff]/10 transition-all font-medium"
                  >
                    <option value="services">Services</option>
                    <option value="admin">Admin</option>
                  </select>
                </div>
              )}

              <div className="flex justify-end gap-3">
                <button type="button" onClick={() => setEditModal({ show: false, type: '', id: null, username: '', newPassword: '', role: 'services', email: '' })} className="px-5 py-2.5 rounded-xl font-bold text-slate-600 dark:text-slate-300 hover:bg-slate-100 transition-colors">ยกเลิก</button>
                <button type="submit" disabled={editLoading} className="px-5 py-2.5 bg-[#007aff] hover:bg-blue-600 text-white rounded-xl font-bold shadow-lg shadow-blue-500/20 disabled:opacity-50 transition-all active:scale-95 flex items-center gap-2">
                  {editLoading ? 'กำลังบันทึก...' : 'บันทึกข้อมูล'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {deleteTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden transform transition-all border border-slate-100 dark:border-slate-700/50">
            <div className="p-6 border-b border-slate-100 dark:border-slate-700/50 flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-red-100 text-red-600 flex items-center justify-center">
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1-1v3M4 7h16" />
                </svg>
              </div>
              <div>
                <h3 className="text-lg font-black text-slate-800 dark:text-slate-100">ลบบัญชีผู้ใช้</h3>
                <p className="text-xs font-semibold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest mt-0.5">Permanent Action</p>
              </div>
            </div>
            <div className="p-6 text-sm text-slate-600 dark:text-slate-300 font-medium">
              คุณแน่ใจหรือไม่ว่าต้องการลบบัญชีผู้ใช้งาน <strong className="text-slate-800 dark:text-slate-100 bg-slate-100 px-2 py-1 rounded font-mono text-xs mt-1 inline-block border border-slate-200 dark:border-slate-700/50">{deleteTarget.username}</strong> ?
            </div>
            <div className="p-6 bg-slate-50 dark:bg-slate-700/50 flex justify-end gap-3 border-t border-slate-100 dark:border-slate-700/50">
              <button 
                onClick={() => setDeleteTarget(null)}
                className="px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-wider text-slate-600 dark:text-slate-300 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 hover:bg-slate-50 dark:bg-slate-700/50 transition-all shadow-sm"
              >
                ยกเลิก
              </button>
              <button 
                onClick={confirmDeleteAdmin}
                className="px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-wider text-white bg-red-600 hover:bg-red-700 shadow-lg shadow-red-500/30 transition-all"
              >
                ยืนยันการลบ
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
