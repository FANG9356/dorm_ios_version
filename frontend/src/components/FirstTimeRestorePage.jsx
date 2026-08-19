import { useState } from 'react';
import { API_URL } from '../config';

export default function FirstTimeRestorePage({ onComplete }) {
  const [backupFile, setBackupFile] = useState(null);
  const [isRestoring, setIsRestoring] = useState(false);
  const [restoreError, setRestoreError] = useState('');

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

      // Success
      onComplete();
    } catch (err) {
      setRestoreError(err.message);
      setIsRestoring(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 dark:bg-slate-700/50 flex flex-col items-center justify-center p-4">
      <div className="bg-white dark:bg-slate-800 rounded-3xl shadow-xl shadow-slate-200/50 max-w-lg w-full overflow-hidden border border-slate-100 dark:border-slate-700/50 p-10 animate-fade-in text-center relative">
        <div className="absolute top-[-20%] right-[-10%] w-32 h-32 bg-blue-100 rounded-full mix-blend-multiply blur-2xl opacity-70"></div>
        <div className="absolute bottom-[-10%] left-[-10%] w-32 h-32 bg-cyan-100 rounded-full mix-blend-multiply blur-2xl opacity-70"></div>
        
        <div className="relative z-10">
          <div className="w-24 h-24 mx-auto bg-blue-50 rounded-full flex items-center justify-center mb-8 border-[6px] border-white shadow-sm">
            <svg className="w-12 h-12 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
            </svg>
          </div>
          
          <h1 className="text-3xl font-black text-slate-800 dark:text-slate-100 tracking-tight mb-3">ตั้งค่าการทำงานครั้งแรก</h1>
          <p className="text-base text-slate-500 dark:text-slate-400 dark:text-slate-300 mb-8 leading-relaxed font-medium">
            คุณต้องการนำเข้าข้อมูลหอพักเดิมจากไฟล์สำรอง (.zip) <br/>หรือต้องการเริ่มต้นใช้งานระบบใหม่ที่ว่างเปล่า?
          </p>

          {restoreError && (
            <div className="mb-6 bg-red-50 text-red-600 text-sm px-5 py-4 rounded-xl font-bold text-left flex items-center gap-3">
              <svg className="w-5 h-5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
              <span>{restoreError}</span>
            </div>
          )}

          <div className="mb-8 p-6 border-2 border-slate-200 dark:border-slate-700/50 border-dashed rounded-2xl hover:border-blue-500 hover:bg-slate-50/50 transition-all cursor-pointer group">
            <label htmlFor="modal-file-upload" className="cursor-pointer flex flex-col items-center justify-center w-full h-full">
              <div className="w-12 h-12 bg-slate-100 text-slate-400 dark:text-slate-300 rounded-full flex items-center justify-center mb-3 group-hover:bg-blue-100 group-hover:text-blue-600 transition-colors">
                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" /></svg>
              </div>
              <span className="text-base font-bold text-slate-700 dark:text-slate-200 group-hover:text-blue-700 mb-1 transition-colors">เลือกไฟล์ Backup (.zip)</span>
              <span className="text-sm font-medium text-slate-500 dark:text-slate-400 dark:text-slate-300">{backupFile ? backupFile.name : 'ขนาดไม่เกิน 50MB'}</span>
              <input id="modal-file-upload" type="file" accept=".zip" className="hidden" onChange={handleBackupFileChange} />
            </label>
          </div>

          <div className="space-y-4">
            <button
              onClick={handleRestoreSubmit}
              disabled={isRestoring || !backupFile}
              className={`w-full flex items-center justify-center py-4 px-6 rounded-2xl text-base font-black text-white transition-all shadow-lg ${
                !backupFile 
                  ? 'bg-slate-200 text-slate-400 dark:text-slate-300 cursor-not-allowed shadow-none' 
                  : isRestoring 
                    ? 'bg-blue-400 cursor-not-allowed opacity-80 shadow-blue-500/30' 
                    : 'bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 hover:-translate-y-1 shadow-blue-500/40'
              }`}
            >
              {isRestoring ? (
                <div className="flex items-center gap-3">
                  <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                  กำลังนำเข้าข้อมูล...
                </div>
              ) : (
                'นำเข้าข้อมูลและเริ่มต้นใช้งาน'
              )}
            </button>
            <button
              onClick={onComplete}
              disabled={isRestoring}
              className="w-full flex items-center justify-center py-4 px-6 rounded-2xl text-sm font-black text-slate-500 dark:text-slate-400 dark:text-slate-300 bg-white dark:bg-slate-800 border-2 border-slate-200 dark:border-slate-700/50 hover:bg-slate-50 dark:bg-slate-700/50 hover:text-slate-700 dark:text-slate-200 hover:border-slate-300 transition-colors"
            >
              ข้ามไปก่อน (เริ่มต้นด้วยระบบว่างเปล่า)
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
