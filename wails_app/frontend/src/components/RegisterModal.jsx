import React, { useState } from 'react';
import { API_URL } from '../config';

export default function RegisterModal({ isOpen, onClose, inviteToken, onRegisterSuccess }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (password !== confirmPassword) {
      setError('รหัสผ่านไม่ตรงกัน');
      return;
    }
    if (password.length < 8 || !/[a-zA-Z]/.test(password) || !/[0-9]/.test(password)) {
      setError('รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร และประกอบด้วยตัวอักษรภาษาอังกฤษและตัวเลข');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const res = await fetch(`${API_URL}/admins/invite/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          invite_token: inviteToken.replace('invite_token:', ''),
          username,
          password
        })
      });

      const data = await res.json();
      if (res.ok) {
        onRegisterSuccess();
      } else {
        setError(data.error || 'เกิดข้อผิดพลาดในการสมัครสมาชิก');
      }
    } catch (err) {
      setError('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
    } finally {
      setLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in p-4">
      <div className="bg-white dark:bg-slate-800 rounded-3xl p-8 max-w-sm w-full shadow-2xl animate-scale-up border border-slate-100 dark:border-slate-700/50">
        <div className="text-center mb-6">
          <div className="w-16 h-16 bg-emerald-50 dark:bg-emerald-900/30 text-emerald-500 dark:text-emerald-400 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" /></svg>
          </div>
          <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100">สร้างบัญชีผู้ใช้ใหม่</h2>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-2">สำหรับพนักงานหอพัก หรือผู้ดูแลระบบ</p>
        </div>

        {error && (
          <div className="bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 p-4 rounded-xl text-sm font-medium mb-6 text-center">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <input
            type="text"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="w-full bg-slate-100/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-2xl px-5 py-4 focus:outline-none focus:bg-white dark:bg-slate-800 focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 transition-all font-medium text-sm placeholder:text-slate-400 dark:text-slate-300"
            placeholder="ชื่อผู้ใช้งาน (Username)"
            required
          />
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full bg-slate-100/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-2xl px-5 py-4 focus:outline-none focus:bg-white dark:bg-slate-800 focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 transition-all font-medium text-sm placeholder:text-slate-400 dark:text-slate-300"
            placeholder="รหัสผ่าน (อย่างน้อย 8 ตัวอักษร)"
            required
          />
          <input
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            className="w-full bg-slate-100/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-2xl px-5 py-4 focus:outline-none focus:bg-white dark:bg-slate-800 focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 transition-all font-medium text-sm placeholder:text-slate-400 dark:text-slate-300"
            placeholder="ยืนยันรหัสผ่าน (Confirm Password)"
            required
          />

          <div className="flex gap-3 pt-4">
            <button
              type="submit"
              disabled={loading}
              className="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white font-bold py-3 px-4 rounded-xl transition-all disabled:opacity-50"
            >
              {loading ? 'กำลังสร้างบัญชี...' : 'สมัครสมาชิก'}
            </button>
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="flex-1 bg-slate-100 hover:bg-slate-200 dark:bg-slate-700 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-200 font-bold py-3 px-4 rounded-xl transition-all disabled:opacity-50"
            >
              ยกเลิก
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
