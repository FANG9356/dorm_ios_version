import { useState, useEffect, useRef } from 'react';
import { API_URL } from '../../config';

export default function BackupPage({ addLog, showToast }) {
  const [file, setFile] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isResetModalOpen, setIsResetModalOpen] = useState(false);
  const [resetConfirmText, setResetConfirmText] = useState('');
  const [isDragging, setIsDragging] = useState(false);
  const [backups, setBackups] = useState([]);
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [restoreTarget, setRestoreTarget] = useState(null);
  const [fileToRestore, setFileToRestore] = useState(null);
  const [isDeleteAllModalOpen, setIsDeleteAllModalOpen] = useState(false);
  const fileInputRef = useRef(null);

  const fetchBackups = async () => {
    try {
      const res = await fetch(`${API_URL}/system/backups`);
      if (res.ok) {
        const data = await res.json();
        setBackups(data || []);
      }
    } catch (error) {
      console.error("Failed to fetch backups", error);
    }
  };

  useEffect(() => {
    fetchBackups();
  }, []);

  useEffect(() => {
    const handleEsc = (e) => {
      if (e.key === 'Escape' && isResetModalOpen) {
        setIsResetModalOpen(false);
      }
    };
    window.addEventListener('keydown', handleEsc);
    return () => window.removeEventListener('keydown', handleEsc);
  }, [isResetModalOpen]);

  const confirmDelete = async () => {
    if (!deleteTarget) return;
    const { name } = deleteTarget;
    setDeleteTarget(null);
    try {
      const res = await fetch(`${API_URL}/system/backups?name=${encodeURIComponent(name)}`, {
        method: 'DELETE'
      });
      if (res.ok) {
        showToast('ลบข้อมูลสำรองสำเร็จแล้ว', 'success');
        addLog('Backup Delete', `ลบไฟล์สำรองข้อมูล (zip) ${name}`);
        fetchBackups();
      } else {
        showToast('ลบข้อมูลสำรองล้มเหลว', 'error');
      }
    } catch (error) {
      console.error(error);
      showToast('เกิดข้อผิดพลาดในการลบข้อมูลสำรอง', 'error');
    }
  };

  const confirmDeleteAll = async () => {
    setIsDeleteAllModalOpen(false);
    setIsLoading(true);
    try {
      const res = await fetch(`${API_URL}/system/backups/all`, { method: 'DELETE' });
      if (res.ok) {
        showToast('ลบข้อมูลสำรองทั้งหมดสำเร็จแล้ว', 'success');
        addLog('Backup Delete All', 'ลบไฟล์สำรองข้อมูลทั้งหมดในระบบ');
        fetchBackups();
      } else {
        showToast('ลบข้อมูลสำรองล้มเหลว', 'error');
      }
    } catch (error) {
      console.error(error);
      showToast('เกิดข้อผิดพลาดในการลบข้อมูลสำรองทั้งหมด', 'error');
    }
    setTimeout(() => setIsLoading(false), 800);
  };

  // Export (Create backup on server)
  const handleExport = async () => {
    setIsLoading(true);
    try {
      const response = await fetch(`${API_URL}/system/backup/zip`);
      if (!response.ok) throw new Error("การสร้างไฟล์แบ็กอัพล้มเหลว");
      
      addLog('Backup', 'สร้างไฟล์สำรองข้อมูลระบบทั้งหมดและไฟล์รูปภาพ (ZIP) ลงเซิร์ฟเวอร์');
      showToast('สร้างไฟล์สำรองข้อมูลสำเร็จแล้ว กรุณาตรวจสอบในตารางด้านล่าง', 'success');
      fetchBackups();
    } catch (error) {
      console.error(error);
      showToast('เกิดข้อผิดพลาดในการสำรองข้อมูล', 'error');
    }
    setTimeout(() => setIsLoading(false), 800);
  };

  const handleDownload = async (name) => {
    try {
      const response = await fetch(`${API_URL}/system/backups/download?name=${encodeURIComponent(name)}`);
      if (!response.ok) throw new Error("การดาวน์โหลดล้มเหลว");
      
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const dlAnchorElem = document.createElement('a');
      dlAnchorElem.href = url;
      dlAnchorElem.download = name; 
      document.body.appendChild(dlAnchorElem);
      dlAnchorElem.click();
      document.body.removeChild(dlAnchorElem);
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error(err);
      showToast(err.message || 'เกิดข้อผิดพลาดในการดาวน์โหลดแบ็กอัพ', 'error');
    }
  };

  const showFilePath = async (name) => {
    try {
      const response = await fetch(`${API_URL}/system/backups/open-folder`);
      if (response.ok) {
        const data = await response.json();
        showToast(`เปิดโฟลเดอร์ที่เก็บไฟล์สำเร็จ`, 'success');
        
        // คัดลอก Path เต็มไปที่ Clipboard ด้วยเผื่อจำเป็น
        navigator.clipboard.writeText(data.path).catch(() => {});
      } else {
        throw new Error("Cannot open folder");
      }
    } catch (err) {
      // Fallback
      const path = `backend-dorm/backups_zip/${name}`;
      navigator.clipboard.writeText(path).then(() => {
        showToast(`คัดลอกที่เก็บไฟล์แล้ว: ${path}`, 'success');
      }).catch(() => {
        showToast(`ที่เก็บไฟล์: ${path}`, 'success');
      });
    }
  };

  // Import
  const handleImport = (e) => {
    e.preventDefault();
    if (!file) return showToast('กรุณาเลือกไฟล์ Backup (.zip)', 'error');
    setFileToRestore(file);
  };

  const confirmRestore = () => {
    if (!fileToRestore) return;
    setFileToRestore(null);

    setIsLoading(true);
    const formData = new FormData();
    formData.append('backup_file', file);

    fetch(`${API_URL}/system/restore/zip`, {
      method: 'POST',
      body: formData 
    })
    .then(async res => {
      if (res.ok) {
        addLog('Restore', 'กู้คืนข้อมูลระบบและรูปภาพสำเร็จ (ZIP)');
        showToast('กู้คืนข้อมูลและรูปภาพสำเร็จ! ระบบจะรีเฟรชสักครู่...', 'success');
        setFile(null);
        if (fileInputRef.current) fileInputRef.current.value = "";
        setTimeout(() => window.location.reload(), 2000);
      } else {
        const text = await res.text();
        console.error("Restore upload failed with:", text);
        showToast(`เกิดข้อผิดพลาด: ${text}`, 'error');
      }
    })
    .catch((err) => {
      console.error(err);
      showToast('เกิดข้อผิดพลาดในการติดต่อเซิร์ฟเวอร์', 'error');
    })
    .finally(() => setTimeout(() => setIsLoading(false), 800));
  };

  const confirmServerRestore = () => {
    if (!restoreTarget) return;
    const { name } = restoreTarget;
    setRestoreTarget(null);

    setIsLoading(true);
    fetch(`${API_URL}/system/backups/restore?name=${encodeURIComponent(name)}`, {
      method: 'POST'
    })
    .then(async res => {
      if (res.ok) {
        addLog('Restore', `กู้คืนข้อมูลระบบและรูปภาพจากไฟล์สำรอง: ${name}`);
        showToast('กู้คืนข้อมูลและรูปภาพสำเร็จ! ระบบจะรีเฟรชสักครู่...', 'success');
        setTimeout(() => window.location.reload(), 2000);
      } else {
        const text = await res.text();
        console.error("Restore failed with:", text);
        showToast(`เกิดข้อผิดพลาด: ${text}`, 'error');
      }
    })
    .catch((err) => {
      console.error(err);
      showToast('เกิดข้อผิดพลาดในการติดต่อเซิร์ฟเวอร์', 'error');
    })
    .finally(() => setTimeout(() => setIsLoading(false), 800));
  };

  // Reset
  const executeReset = () => {
    setIsLoading(true);
    fetch(`${API_URL}/system/reset`, { method: 'POST' })
    .then(res => {
      if (res.ok) {
        showToast('ล้างข้อมูลระบบและรูปภาพทั้งหมดเรียบร้อยแล้ว', 'success');
        setIsResetModalOpen(false);
        setTimeout(() => window.location.reload(), 1500);
      }
    }).finally(() => setTimeout(() => setIsLoading(false), 800));
  };

  // Drag & Drop Handlers
  const handleDragOver = (e) => {
    e.preventDefault();
    setIsDragging(true);
  };
  const handleDragLeave = (e) => {
    e.preventDefault();
    setIsDragging(false);
  };
  const handleDrop = (e) => {
    e.preventDefault();
    setIsDragging(false);
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      const droppedFile = e.dataTransfer.files[0];
      if (droppedFile.name.endsWith('.zip')) {
        setFile(droppedFile);
      } else {
        showToast('กรุณาอัปโหลดเฉพาะไฟล์ .zip เท่านั้น', 'error');
      }
    }
  };

  return (
    <>
      {/* Delete Confirmation Modal */}
      {deleteTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-md overflow-hidden transform transition-all">
            <div className="p-6 border-b border-slate-100 dark:border-slate-700/50 flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-red-100 text-red-600 flex items-center justify-center">
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1-1v3M4 7h16" />
                </svg>
              </div>
              <div>
                <h3 className="text-lg font-black text-slate-800 dark:text-slate-100">Delete Backup</h3>
                <p className="text-xs font-semibold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest mt-0.5">Permanent Action</p>
              </div>
            </div>
            <div className="p-6 text-sm text-slate-600 dark:text-slate-300 font-medium">
              คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลสำรองนี้ <br/>
              <strong className="text-slate-800 dark:text-slate-100 bg-slate-100 px-2 py-1 rounded font-mono text-xs mt-2 inline-block border border-slate-200 dark:border-slate-700/50">
                {deleteTarget.name}
              </strong> ?
            </div>
            <div className="p-6 bg-slate-50 dark:bg-slate-700/50 flex justify-end gap-3 border-t border-slate-100 dark:border-slate-700/50">
              <button 
                onClick={() => setDeleteTarget(null)}
                className="px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-wider text-slate-600 dark:text-slate-300 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 hover:bg-slate-50 dark:bg-slate-700/50 transition-all shadow-sm"
              >
                ยกเลิก
              </button>
              <button 
                onClick={confirmDelete}
                className="px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-wider text-white bg-red-600 hover:bg-red-700 shadow-lg shadow-red-500/30 transition-all"
              >
                ยืนยันการลบ
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Restore Confirmation Modal */}
      {fileToRestore && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-md overflow-hidden transform transition-all">
            <div className="p-6 border-b border-slate-100 dark:border-slate-700/50 flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-orange-100 text-orange-600 flex items-center justify-center">
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
              </div>
              <div>
                <h3 className="text-lg font-black text-slate-800 dark:text-slate-100">Confirm Restore</h3>
                <p className="text-xs font-semibold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest mt-0.5">Critical Action</p>
              </div>
            </div>
            <div className="p-6 text-sm text-slate-600 dark:text-slate-300 font-medium">
              คุณแน่ใจหรือไม่ว่าต้องการกู้คืนข้อมูลระบบด้วยไฟล์นี้? <br/><br/>
              <strong className="text-red-500">คำเตือน:</strong> ข้อมูลเดิมและรูปภาพในระบบปัจจุบันจะถูก <strong className="text-slate-800 dark:text-slate-100">ลบทิ้งทั้งหมด</strong> และแทนที่ด้วยข้อมูลจากไฟล์ Backup นึ้
            </div>
            <div className="p-6 bg-slate-50 dark:bg-slate-700/50 flex justify-end gap-3 border-t border-slate-100 dark:border-slate-700/50">
              <button 
                onClick={() => setFileToRestore(null)}
                className="px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-wider text-slate-600 dark:text-slate-300 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 hover:bg-slate-50 dark:bg-slate-700/50 transition-all shadow-sm"
              >
                ยกเลิก
              </button>
              <button 
                onClick={confirmRestore}
                className="px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-wider text-white bg-orange-500 hover:bg-orange-600 shadow-lg shadow-orange-500/30 transition-all"
              >
                ยืนยันการกู้คืน
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete All Confirmation Modal */}
      {isDeleteAllModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm animate-fade-in">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-md overflow-hidden transform transition-all">
            <div className="p-6 border-b border-slate-100 dark:border-slate-700/50 flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-red-100 text-red-600 flex items-center justify-center">
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1-1v3M4 7h16" />
                </svg>
              </div>
              <div>
                <h3 className="text-lg font-black text-slate-800 dark:text-slate-100">Delete All Backups</h3>
                <p className="text-xs font-semibold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest mt-0.5">Permanent Action</p>
              </div>
            </div>
            <div className="p-6 text-sm text-slate-600 dark:text-slate-300 font-medium">
              คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลสำรอง <strong className="text-red-600">ทั้งหมด</strong> ที่อยู่บนเซิร์ฟเวอร์? <br/><br/>
              การกระทำนี้จะไม่สามารถย้อนกลับได้
            </div>
            <div className="p-6 bg-slate-50 dark:bg-slate-700/50 flex justify-end gap-3 border-t border-slate-100 dark:border-slate-700/50">
              <button 
                onClick={() => setIsDeleteAllModalOpen(false)}
                className="px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-wider text-slate-600 dark:text-slate-300 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 hover:bg-slate-50 dark:bg-slate-700/50 transition-all shadow-sm"
              >
                ยกเลิก
              </button>
              <button 
                onClick={confirmDeleteAll}
                className="px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-wider text-white bg-red-600 hover:bg-red-700 shadow-lg shadow-red-500/30 transition-all"
              >
                ยืนยันการลบทั้งหมด
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="animate-fade-in relative min-h-full font-sans pb-10 text-slate-800 dark:text-slate-100">
      
      <div className="mb-10 flex flex-col xl:flex-row justify-between items-start xl:items-end gap-4 border-b border-slate-200/60 dark:border-slate-700/50 pb-6">
        <div>
          <h2 className="text-2xl font-black text-slate-900 dark:text-slate-100 tracking-tight flex items-center gap-3">
            <span className="bg-slate-900 text-white p-2 rounded-lg shadow-md">
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" /></svg>
            </span>
            DATA CENTER
          </h2>
          <p className="text-sm font-semibold text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-2 flex items-center gap-2">
            ศูนย์การสำรองข้อมูลและกู้คืนระบบ 
            <span className="px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700 text-[10px] font-black tracking-widest border border-emerald-200 shadow-sm uppercase">Active</span>
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        
        {/* Export Card */}
        <div className="group relative bg-white dark:bg-slate-800 border border-slate-200/70 rounded-2xl p-8 shadow-[0_8px_30px_rgb(0,0,0,0.04)] hover:shadow-[0_8px_30px_rgb(0,0,0,0.08)] transition-all duration-300 flex flex-col overflow-hidden">
          <div className="absolute top-0 right-0 w-32 h-32 bg-blue-500/5 rounded-bl-full -z-10 group-hover:scale-110 transition-transform duration-500"></div>
          
          <div className="flex items-start justify-between mb-6">
            <div className="w-14 h-14 bg-gradient-to-br from-blue-500 to-indigo-600 text-white rounded-xl flex items-center justify-center shadow-lg shadow-blue-500/30">
              <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" /></svg>
            </div>
            <span className="text-[10px] font-black tracking-widest text-blue-600 bg-blue-50 px-3 py-1 rounded-full uppercase border border-blue-100">Export Module</span>
          </div>
          
          <h3 className="text-xl font-extrabold text-slate-800 dark:text-slate-100 mb-2">สร้างไฟล์สำรองระบบ</h3>
          <p className="text-sm text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-8 leading-relaxed font-medium">
            สร้างไฟล์บีบอัด <b className="text-slate-700 dark:text-slate-200">.zip</b> ที่ครอบคลุมฐานข้อมูล สลิปการโอนเงิน และรูปภาพหลักฐานทั้งหมดของระบบ เพื่อความปลอดภัย
          </p>
          
          <button 
            onClick={handleExport} 
            disabled={isLoading} 
            className="mt-auto w-full group/btn relative overflow-hidden bg-slate-900 text-white py-4 rounded-xl text-xs font-black uppercase tracking-widest shadow-lg hover:shadow-xl transition-all disabled:opacity-70 disabled:cursor-not-allowed"
          >
            <div className="absolute inset-0 w-full h-full bg-gradient-to-r from-blue-600 to-indigo-600 opacity-0 group-hover/btn:opacity-100 transition-opacity duration-300"></div>
            <span className="relative flex items-center justify-center gap-2">
              {isLoading ? (
                <><svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg> กำลังสร้างไฟล์สำรอง...</>
              ) : 'เริ่มดำเนินการดาวน์โหลด'}
            </span>
          </button>
        </div>

        {/* Import Card */}
        <div className="group relative bg-white dark:bg-slate-800 border border-slate-200/70 rounded-2xl p-8 shadow-[0_8px_30px_rgb(0,0,0,0.04)] hover:shadow-[0_8px_30px_rgb(0,0,0,0.08)] transition-all duration-300 flex flex-col overflow-hidden">
          <div className="absolute top-0 right-0 w-32 h-32 bg-emerald-500/5 rounded-bl-full -z-10 group-hover:scale-110 transition-transform duration-500"></div>
          
          <div className="flex items-start justify-between mb-6">
            <div className="w-14 h-14 bg-gradient-to-br from-emerald-400 to-teal-500 text-white rounded-xl flex items-center justify-center shadow-lg shadow-emerald-500/30">
              <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" /></svg>
            </div>
            <span className="text-[10px] font-black tracking-widest text-emerald-600 bg-emerald-50 px-3 py-1 rounded-full uppercase border border-emerald-100">Restore Module</span>
          </div>
          
          <h3 className="text-xl font-extrabold text-slate-800 dark:text-slate-100 mb-2">กู้คืนระบบจากไฟล์</h3>
          <p className="text-sm text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-6 leading-relaxed font-medium">
            อัปโหลดไฟล์ <b className="text-slate-700 dark:text-slate-200">.zip</b> ที่ได้จากการสำรองข้อมูลเพื่อกู้คืน <span className="text-amber-600 font-bold">คำเตือน: ข้อมูลในระบบปัจจุบันจะถูกเขียนทับทั้งหมด</span>
          </p>
          
          <form onSubmit={handleImport} className="w-full flex flex-col gap-4 mt-auto">
            {/* Drag & Drop Zone */}
            <div 
              onDragOver={handleDragOver}
              onDragLeave={handleDragLeave}
              onDrop={handleDrop}
              onClick={() => fileInputRef.current?.click()}
              className={`relative border-2 border-dashed rounded-xl p-6 text-center cursor-pointer transition-all duration-300 flex flex-col items-center justify-center ${isDragging ? 'border-emerald-500 bg-emerald-50/50' : file ? 'border-slate-300 bg-slate-50 dark:bg-slate-700/50 hover:bg-slate-100 hover:border-slate-400' : 'border-slate-200 dark:border-slate-700/50 bg-slate-50/50 hover:bg-slate-50 dark:bg-slate-700/50 hover:border-emerald-300'}`}
            >
              <input 
                ref={fileInputRef}
                type="file" 
                accept=".zip"
                className="hidden"
                onChange={(e) => setFile(e.target.files[0])}
              />
              {file ? (
                <div className="flex flex-col items-center">
                  <div className="w-10 h-10 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mb-2">
                    <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M5 13l4 4L19 7" /></svg>
                  </div>
                  <span className="text-sm font-bold text-slate-700 dark:text-slate-200">{file.name}</span>
                  <span className="text-[10px] font-bold text-slate-400 dark:text-slate-300 mt-1 uppercase tracking-widest">{(file.size / (1024*1024)).toFixed(2)} MB</span>
                </div>
              ) : (
                <>
                  <div className="w-10 h-10 rounded-full bg-slate-100 text-slate-400 dark:text-slate-300 flex items-center justify-center mb-3">
                    <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" /></svg>
                  </div>
                  <span className="text-xs font-bold text-slate-600 dark:text-slate-300">ลากและวางไฟล์ .zip ที่นี่</span>
                  <span className="text-[10px] font-semibold text-slate-400 dark:text-slate-300 mt-1 uppercase tracking-widest">หรือคลิกเพื่อเลือกไฟล์</span>
                </>
              )}
            </div>

            <button type="submit" disabled={isLoading || !file} className="w-full bg-white dark:bg-slate-800 border border-slate-300 text-slate-800 dark:text-slate-100 py-3.5 rounded-xl text-xs font-black uppercase tracking-widest shadow-sm hover:border-slate-400 hover:bg-slate-50 dark:bg-slate-700/50 transition-all disabled:opacity-50 disabled:cursor-not-allowed">
              {isLoading ? 'กำลังประมวลผลการกู้คืน...' : 'เริ่มการกู้คืนระบบ'}
            </button>
          </form>
        </div>
      </div>

      {/* ---------------- Backup List Section ---------------- */}
      <div className="mt-12 bg-white dark:bg-slate-800 border border-slate-200/70 rounded-2xl p-8 shadow-[0_8px_30px_rgb(0,0,0,0.04)]">
        <div className="flex justify-between items-center border-b border-slate-100 dark:border-slate-700/50 pb-4 mb-6">
          <div>
            <h3 className="text-lg font-extrabold text-slate-800 dark:text-slate-100">ประวัติการสำรองข้อมูลบนเซิร์ฟเวอร์</h3>
            <p className="text-xs text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-1">รายการสำรองข้อมูลทั้งแบบ ZIP และแบบโฟลเดอร์สำหรับตรวจสอบและกู้คืน</p>
          </div>
          <div className="flex items-center gap-2">
            <button 
              type="button"
              onClick={fetchBackups} 
              className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-slate-600 dark:text-slate-300 bg-slate-100 hover:bg-slate-200 rounded-lg transition-all"
            >
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99" /></svg>
              รีเฟรช
            </button>
            <button 
              type="button"
              onClick={() => setIsDeleteAllModalOpen(true)}
              disabled={backups.length === 0}
              className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-red-600 bg-red-50 hover:bg-red-100 border border-red-100 rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1-1v3M4 7h16" /></svg>
              ลบทิ้งทั้งหมด
            </button>
          </div>
        </div>

        {backups.length === 0 ? (
          <div className="text-center py-10 border border-dashed border-slate-200 dark:border-slate-700/50 rounded-xl bg-slate-50/50">
            <svg className="w-10 h-10 text-slate-300 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" /></svg>
            <p className="text-xs font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-wider">ไม่มีไฟล์สำรองข้อมูลบนเซิร์ฟเวอร์</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-slate-100 dark:border-slate-700/50 text-[10px] font-black text-slate-400 dark:text-slate-300 uppercase tracking-widest text-slate-400 dark:text-slate-300">
                  <th className="pb-3 font-black text-slate-400 dark:text-slate-300">ชื่อข้อมูลสำรอง</th>
                  <th className="pb-3 font-black text-slate-400 dark:text-slate-300">ขนาดไฟล์</th>
                  <th className="pb-3 font-black text-slate-400 dark:text-slate-300">เวลาสำรองข้อมูล</th>
                  <th className="pb-3 font-black text-right text-slate-400 dark:text-slate-300">การจัดการ</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {backups.map((item, idx) => {
                  const dateObj = new Date(item.created_at);
                  const formattedDate = dateObj.toLocaleDateString('th-TH', {
                    day: 'numeric',
                    month: 'short',
                    year: 'numeric',
                  }) + ' • ' + dateObj.toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit' }) + ' น.';

                  const displaySize = item.size 
                    ? (item.size / (1024 * 1024)).toFixed(2) + ' MB' 
                    : 'N/A';

                  return (
                    <tr 
                      key={idx} 
                      className="group hover:bg-slate-50/50 transition-colors cursor-pointer"
                      onDoubleClick={() => showFilePath(item.name)}
                      title="ดับเบิ้ลคลิกเพื่อดูและคัดลอกที่เก็บไฟล์"
                    >
                      <td className="py-4 font-mono text-xs font-bold text-slate-700 dark:text-slate-200 max-w-xs truncate" title={item.name}>
                        {item.name}
                      </td>
                      <td className="py-4 text-xs font-bold text-slate-500 dark:text-slate-400 dark:text-slate-300">
                        {displaySize}
                      </td>
                      <td className="py-4 text-xs font-semibold text-slate-500 dark:text-slate-400 dark:text-slate-300">
                        {formattedDate}
                      </td>
                      <td className="py-4 text-right">
                        <div className="flex justify-end gap-2">
                          <button
                            type="button"
                            onClick={() => handleDownload(item.name)}
                            className="p-1.5 rounded-lg border border-slate-200 dark:border-slate-700/50 text-slate-500 dark:text-slate-400 dark:text-slate-300 hover:text-blue-600 hover:border-blue-200 hover:bg-blue-50 transition-all flex items-center justify-center"
                            title="ดาวน์โหลดไฟล์สำรองข้อมูล"
                          >
                            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" /></svg>
                          </button>
                          <button
                            type="button"
                            onClick={() => setRestoreTarget({ name: item.name })}
                            className="p-1.5 rounded-lg border border-slate-200 dark:border-slate-700/50 text-slate-400 dark:text-slate-300 hover:text-emerald-600 hover:border-emerald-200 hover:bg-emerald-50 transition-all flex items-center justify-center"
                            title="ย้อนคืนข้อมูล (Restore)"
                          >
                            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6" /></svg>
                          </button>
                          <button
                            type="button"
                            onClick={() => setDeleteTarget({ name: item.name })}
                            className="p-1.5 rounded-lg border border-slate-200 dark:border-slate-700/50 text-slate-400 dark:text-slate-300 hover:text-red-600 hover:border-red-200 hover:bg-red-50 transition-all flex items-center justify-center"
                            title="ลบไฟล์สำรองข้อมูล"
                          >
                            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1-1v3M4 7h16" /></svg>
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Danger Zone: Factory Reset (Light Themed) */}
      <div className="mt-12 bg-white dark:bg-slate-800 rounded-2xl p-6 border border-red-200/60 shadow-sm relative overflow-hidden">
        <div className="relative flex flex-col md:flex-row items-center justify-between gap-6">
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 bg-red-50 text-red-600 rounded-xl flex items-center justify-center border border-red-100 shrink-0">
              <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
            </div>
            <div>
              <h3 className="text-lg font-black text-red-600 tracking-wide">รีเซ็ตระบบกลับเป็นค่าเริ่มต้น (FACTORY RESET)</h3>
              <p className="text-xs text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-1 font-medium leading-relaxed max-w-xl">
                การดำเนินการนี้จะลบข้อมูลลูกบ้าน, ประวัติการเงิน, ประวัติการใช้งาน และไฟล์รูปภาพทั้งหมดออกอย่างถาวร <strong className="text-red-600">การกระทำนี้ไม่สามารถย้อนกลับได้</strong>
              </p>
            </div>
          </div>
          <button 
            onClick={() => { setIsResetModalOpen(true); setResetConfirmText(''); }} 
            disabled={isLoading} 
            className="w-full md:w-auto shrink-0 bg-transparent border-2 border-red-200 text-red-600 px-8 py-3.5 rounded-xl text-xs font-black uppercase tracking-widest hover:bg-red-50 hover:border-red-300 transition-all focus:outline-none disabled:opacity-50"
          >
            ดำเนินการรีเซ็ต
          </button>
        </div>
      </div>
    </div>

      {/* Reset Confirmation Modal (Light Themed) */}
      {isResetModalOpen && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4 z-[100] animate-fade-in font-sans">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-lg overflow-hidden border border-slate-200 dark:border-slate-700/50 relative">
            {/* Top red accent line */}
            <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-red-500 to-red-600"></div>
            
            <div className="p-8">
              <div className="flex items-center gap-3 mb-6">
                <div className="w-10 h-10 rounded-full bg-red-50 flex items-center justify-center text-red-600 border border-red-100">
                  <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
                </div>
                <h3 className="font-black text-lg text-slate-800 dark:text-slate-100 tracking-wide uppercase">ยืนยันการทำลายข้อมูล</h3>
              </div>
              
              <div className="bg-red-50 p-5 rounded-xl border border-red-100 mb-6">
                <p className="text-xs text-red-700 font-bold mb-3 uppercase tracking-widest">ข้อมูลเป้าหมายที่จะถูกลบทิ้งทั้งหมด:</p>
                <ul className="text-xs text-slate-600 dark:text-slate-300 list-none space-y-2 font-medium">
                  <li className="flex items-center gap-2"><div className="w-1 h-1 rounded-full bg-red-500"></div> ประวัติลูกบ้านและสัญญาเช่าทั้งหมด</li>
                  <li className="flex items-center gap-2"><div className="w-1 h-1 rounded-full bg-red-500"></div> ประวัติการชำระเงินและบิลค่าใช้จ่าย</li>
                  <li className="flex items-center gap-2"><div className="w-1 h-1 rounded-full bg-red-500"></div> ประวัติการกระทำในระบบทั้งหมด</li>
                  <li className="flex items-center gap-2"><div className="w-1 h-1 rounded-full bg-red-500"></div> <b className="text-red-700">ล้างไฟล์รูปภาพและสลิปการโอนเงินทั้งหมดเกลี้ยงระบบ (.jpg, .png)</b></li>
                </ul>
              </div>
 
              <div className="mb-8">
                <label className="block text-[10px] font-black text-slate-500 dark:text-slate-400 dark:text-slate-300 uppercase tracking-widest mb-3">
                  พิมพ์คำว่า <span className="text-red-600 bg-red-50 px-2 py-0.5 rounded border border-red-100 mx-1">RESET</span> เพื่อปลดล็อคความปลอดภัย
                </label>
                <input 
                  type="text" 
                  autoComplete="off"
                  className="w-full bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 p-4 text-sm font-mono rounded-xl outline-none focus:border-red-600 focus:ring-1 focus:ring-red-600 uppercase text-center font-bold text-slate-800 dark:text-slate-100 placeholder-slate-300 transition-all"
                  value={resetConfirmText}
                  onChange={(e) => setResetConfirmText(e.target.value.toUpperCase())}
                  placeholder="รอการยืนยัน..."
                />
              </div>
 
              <div className="flex gap-4">
                <button type="button" onClick={() => setIsResetModalOpen(false)} className="flex-1 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 text-slate-600 dark:text-slate-300 py-3.5 rounded-xl text-xs font-black uppercase tracking-widest hover:bg-slate-50 dark:bg-slate-700/50 hover:text-slate-800 dark:text-slate-100 transition-all">ยกเลิก</button>
                <button 
                  type="button" 
                  onClick={executeReset}
                  disabled={resetConfirmText !== 'RESET' || isLoading}
                  className={`flex-1 py-3.5 rounded-xl text-xs font-black uppercase tracking-widest shadow-md transition-all ${resetConfirmText === 'RESET' && !isLoading ? 'bg-red-600 text-white hover:bg-red-700' : 'bg-slate-100 text-slate-400 dark:text-slate-300 cursor-not-allowed'}`}
                >
                  {isLoading ? 'กำลังลบข้อมูล...' : 'ยืนยันการลบ'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Restore Server File Confirm Modal */}
      {restoreTarget && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-xl w-full max-w-md overflow-hidden animate-fade-in-up border border-slate-200 dark:border-slate-700/50">
            <div className="p-6">
              <div className="w-12 h-12 bg-emerald-100 text-emerald-600 rounded-full flex items-center justify-center mb-4 mx-auto border border-emerald-200">
                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6" /></svg>
              </div>
              <h3 className="text-lg font-black text-slate-800 dark:text-slate-100 text-center mb-2">ยืนยันการย้อนคืนระบบ?</h3>
              <p className="text-sm text-slate-500 dark:text-slate-400 dark:text-slate-300 text-center mb-2 leading-relaxed">
                คุณแน่ใจหรือไม่ที่จะใช้ไฟล์สำรองข้อมูล <strong className="text-emerald-600">{restoreTarget.name}</strong> ในการย้อนคืนระบบ?
              </p>
              <p className="text-xs text-amber-600 text-center mb-6 font-bold bg-amber-50 p-2 rounded-lg border border-amber-100">
                คำเตือน: ข้อมูลในระบบปัจจุบันจะถูกลบและเขียนทับทั้งหมด
              </p>
              <div className="flex gap-3">
                <button 
                  onClick={() => setRestoreTarget(null)}
                  disabled={isLoading}
                  className="flex-1 py-2.5 bg-slate-100 text-slate-700 dark:text-slate-200 font-bold rounded-xl text-sm hover:bg-slate-200 disabled:opacity-50 transition-colors"
                >
                  ยกเลิก
                </button>
                <button 
                  onClick={confirmServerRestore}
                  disabled={isLoading}
                  className="flex-1 py-2.5 bg-emerald-600 text-white font-bold rounded-xl text-sm hover:bg-emerald-700 disabled:opacity-50 transition-colors flex justify-center items-center gap-2 shadow-md"
                >
                  {isLoading ? (
                    <><svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg> กำลังกู้คืน...</>
                  ) : 'ย้อนคืนระบบ'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

    </>
  );
}