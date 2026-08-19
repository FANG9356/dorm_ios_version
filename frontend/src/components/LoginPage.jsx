import React, { useState, useRef } from 'react';
import { API_URL } from '../config';

export default function LoginPage({ onLogin }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [requirePasswordChange, setRequirePasswordChange] = useState(false);
  const [newUsername, setNewUsername] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  // Forgot password states
  const [forgotMode, setForgotMode] = useState(false); // false | 'request' | 'reset'
  const [forgotEmail, setForgotEmail] = useState('');
  const [forgotOtp, setForgotOtp] = useState(['', '', '', '', '', '']);
  const [forgotNewPassword, setForgotNewPassword] = useState('');
  
  const otpRefs = [
    useRef(null), useRef(null), useRef(null), 
    useRef(null), useRef(null), useRef(null)
  ];

  const handleOtpChange = (index, value) => {
    if (!/^[0-9]*$/.test(value)) return;
    
    const newOtp = [...forgotOtp];
    newOtp[index] = value.substring(value.length - 1);
    setForgotOtp(newOtp);

    // Auto focus next
    if (value && index < 5) {
      otpRefs[index + 1].current.focus();
    }
  };

  const handleOtpKeyDown = (index, e) => {
    if (e.key === 'Backspace' && !forgotOtp[index] && index > 0) {
      otpRefs[index - 1].current.focus();
    }
  };

  const handleOtpPaste = (e) => {
    e.preventDefault();
    const pastedData = e.clipboardData.getData('text').replace(/[^0-9]/g, '').slice(0, 6);
    if (pastedData) {
      const newOtp = [...forgotOtp];
      for (let i = 0; i < pastedData.length; i++) {
        newOtp[i] = pastedData[i];
      }
      setForgotOtp(newOtp);
      if (pastedData.length < 6) {
        otpRefs[pastedData.length].current.focus();
      } else {
        otpRefs[5].current.focus();
      }
    }
  };

  const handleForgotRequest = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const res = await fetch(`${API_URL}/forgot-password`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: forgotEmail })
      });
      const data = await res.json();
      if (res.ok) {
        setForgotMode('verify');
        setError(data.message || 'ส่งรหัส OTP สำเร็จ');
      } else {
        setError(data.error || 'เกิดข้อผิดพลาด');
      }
    } catch (err) {
      setError('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
    } finally {
      setLoading(false);
    }
  };

  const handleForgotVerify = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const otpString = forgotOtp.join('');
      if (otpString.length < 6) {
        setError('กรุณากรอกรหัส OTP ให้ครบ 6 หลัก');
        setLoading(false);
        return;
      }
      const res = await fetch(`${API_URL}/verify-otp`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: forgotEmail, otp: otpString })
      });
      const data = await res.json();
      if (res.ok) {
        setForgotMode('reset');
        setError('');
      } else {
        setError(data.error || 'เกิดข้อผิดพลาด');
      }
    } catch (err) {
      setError('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
    } finally {
      setLoading(false);
    }
  };

  const handleForgotReset = async (e) => {
    e.preventDefault();
    if (forgotNewPassword !== confirmPassword) {
      setError('รหัสผ่านใหม่ไม่ตรงกัน');
      return;
    }
    if (forgotNewPassword.length < 8 || !/[a-zA-Z]/.test(forgotNewPassword) || !/[0-9]/.test(forgotNewPassword)) {
      setError('รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร และประกอบด้วยตัวอักษรภาษาอังกฤษและตัวเลข');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const otpString = forgotOtp.join('');

      const res = await fetch(`${API_URL}/reset-password`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: forgotEmail, otp: otpString, new_password: forgotNewPassword })
      });
      const data = await res.json();
      if (res.ok) {
        setForgotMode(false);
        setForgotEmail('');
        setForgotOtp(['', '', '', '', '', '']);
        setForgotNewPassword('');
        setConfirmPassword('');
        setError('รีเซ็ตรหัสผ่านสำเร็จ! กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่');
      } else {
        setError(data.error || 'รหัส OTP ไม่ถูกต้อง');
      }
    } catch (err) {
      setError('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const res = await fetch(`${API_URL}/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password })
      });

      const data = await res.json();

      if (res.ok && data.token) {
        localStorage.setItem('dorminet_token', data.token);
        localStorage.setItem('user_id', data.id || '');
        localStorage.setItem('username', data.username || username);
        localStorage.setItem('user_role', data.role || 'admin');
        localStorage.setItem('profile_image', data.profile_image || '');
        onLogin();
      } else if (res.ok && data.require_password_change) {
        setRequirePasswordChange(true);
        setError('เพื่อความปลอดภัย กรุณาตั้งรหัสผ่านใหม่สำหรับการเข้าใช้งานครั้งแรก');
      } else {
        setError(data.error || 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง');
      }
    } catch (err) {
      setError('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
    } finally {
      setLoading(false);
    }
  };

  const handleChangePassword = async (e) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) {
      setError('รหัสผ่านใหม่ไม่ตรงกัน');
      return;
    }
    if (newPassword === 'admin' || newUsername === 'admin') {
      setError('ไม่สามารถใช้ชื่อผู้ใช้ หรือ รหัสผ่านนี้ได้ กรุณาตั้งเป็นคำอื่น');
      return;
    }
    if (!newUsername.trim()) {
      setError('กรุณาตั้งชื่อผู้ใช้ใหม่');
      return;
    }
    
    // Add password validation here
    if (newPassword.length < 8 || !/[a-zA-Z]/.test(newPassword) || !/[0-9]/.test(newPassword)) {
      setError('รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร และประกอบด้วยตัวอักษรภาษาอังกฤษและตัวเลข');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const res = await fetch(`${API_URL}/change-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, old_password: password, new_username: newUsername, new_password: newPassword })
      });
      
      if (res.ok) {
        setRequirePasswordChange(false);
        setPassword('');
        setNewPassword('');
        setConfirmPassword('');
        setNewUsername('');
        sessionStorage.setItem('showFirstTimeBackup', 'true');
        setError('เปลี่ยนชื่อผู้ใช้และรหัสผ่านสำเร็จ! กรุณาเข้าสู่ระบบด้วยข้อมูลใหม่');
      } else {
        const data = await res.json();
        setError(data.error || 'ไม่สามารถเปลี่ยนรหัสผ่านได้');
      }
    } catch (err) {
      setError('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-50 to-slate-200 p-4 sm:p-8">
      <div className={`w-full ${forgotMode ? 'max-w-[550px]' : 'max-w-[480px]'} bg-white dark:bg-slate-800/80 backdrop-blur-xl rounded-[2.5rem] shadow-2xl shadow-slate-200/60 border border-white p-10 sm:p-14 transition-all duration-500 ease-in-out`}>
        {!forgotMode && (
          <div className="text-center mb-10 animate-fade-in">
            <div className="w-16 h-16 bg-gradient-to-tr from-blue-600 to-indigo-500 text-white rounded-2xl flex items-center justify-center mx-auto mb-6 shadow-lg shadow-blue-500/30">
              <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
            </div>
            <h1 className="text-3xl font-black text-slate-800 dark:text-slate-100 tracking-tight">DormiNet</h1>
            <p className="text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-2 text-sm font-medium">จัดการหอพักอย่างมืออาชีพ</p>
          </div>
        )}
        
        {requirePasswordChange && (
          <form onSubmit={handleChangePassword} className="space-y-5">
            {error && (
              <div className="bg-amber-50 text-amber-600 text-xs px-4 py-3 rounded-xl font-bold text-center border border-amber-100 flex items-center justify-center gap-2 animate-fade-in">
                <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                <span>{error}</span>
              </div>
            )}
            
            <div className="space-y-4">
              <div>
                <input
                  type="text"
                  value={newUsername}
                  onChange={(e) => setNewUsername(e.target.value)}
                  className="w-full bg-slate-100/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-2xl px-5 py-4 focus:outline-none focus:bg-white dark:bg-slate-800 focus:border-purple-500 focus:ring-4 focus:ring-purple-500/10 transition-all font-medium text-sm placeholder:text-slate-400 dark:text-slate-300"
                  placeholder="ชื่อผู้ใช้ใหม่ (New Username)"
                  required
                />
              </div>
              <div>
                <input
                  type="password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  className="w-full bg-slate-100/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-2xl px-5 py-4 focus:outline-none focus:bg-white dark:bg-slate-800 focus:border-purple-500 focus:ring-4 focus:ring-purple-500/10 transition-all font-medium text-sm placeholder:text-slate-400 dark:text-slate-300"
                  placeholder="รหัสผ่านใหม่ (New Password)"
                  required
                />
              </div>
              <div>
                <input
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  className="w-full bg-slate-100/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-2xl px-5 py-4 focus:outline-none focus:bg-white dark:bg-slate-800 focus:border-purple-500 focus:ring-4 focus:ring-purple-500/10 transition-all font-medium text-sm placeholder:text-slate-400 dark:text-slate-300"
                  placeholder="ยืนยันรหัสผ่านใหม่ (Confirm Password)"
                  required
                />
              </div>
            </div>
            
            <button
              type="submit"
              disabled={loading}
              className="w-full mt-2 bg-purple-600 hover:bg-purple-700 text-white font-bold py-4 px-4 rounded-2xl transition-all shadow-xl shadow-purple-600/20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 group"
            >
              {loading ? 'กำลังบันทึก...' : 'บันทึกข้อมูลและเข้าสู่ระบบ'}
            </button>
          </form>
        )}
        {!requirePasswordChange && !forgotMode && (
          <form onSubmit={handleSubmit} className="space-y-5 animate-fade-in">
            {error && (
              <div className="bg-slate-50 dark:bg-slate-700/50 text-slate-700 dark:text-slate-200 border-slate-200 dark:border-slate-700/50 text-xs px-4 py-3 rounded-xl font-bold text-center border flex items-center justify-center gap-2 animate-fade-in">
                <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                <span>{error}</span>
              </div>
            )}
            
            <div className="space-y-4">
              <div>
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="w-full bg-slate-100/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-2xl px-5 py-4 focus:outline-none focus:bg-white dark:bg-slate-800 focus:border-blue-500 focus:ring-4 focus:ring-blue-500/10 transition-all font-medium text-sm placeholder:text-slate-400 dark:text-slate-300"
                  placeholder="ชื่อผู้ใช้งาน (Username)"
                  required
                  disabled={requirePasswordChange}
                />
              </div>
              <div>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full bg-slate-100/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-2xl px-5 py-4 focus:outline-none focus:bg-white dark:bg-slate-800 focus:border-blue-500 focus:ring-4 focus:ring-blue-500/10 transition-all font-medium text-sm placeholder:text-slate-400 dark:text-slate-300"
                  placeholder="รหัสผ่าน (Password)"
                  required
                  disabled={requirePasswordChange}
                />
              </div>
            </div>
            
            <button
              type="submit"
              disabled={loading}
              className="w-full mt-2 bg-slate-900 hover:bg-black text-white font-bold py-4 px-4 rounded-2xl transition-all shadow-xl shadow-slate-900/20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 group"
            >
              {loading ? 'กำลังเข้าสู่ระบบ...' : (
                <>
                  เข้าสู่ระบบ
                  <svg className="w-4 h-4 group-hover:translate-x-1 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M14 5l7 7m0 0l-7 7m7-7H3" /></svg>
                </>
              )}
            </button>
            <div className="text-center mt-4">
              <button 
                type="button" 
                onClick={() => { setForgotMode('request'); setError(''); }} 
                className="text-sm text-slate-500 dark:text-slate-400 dark:text-slate-300 hover:text-blue-600 font-medium transition-colors"
              >
                ลืมรหัสผ่าน? (Forgot Password)
              </button>
            </div>
          </form>
        )}
        
        {forgotMode === 'request' && !requirePasswordChange && (
          <form onSubmit={handleForgotRequest} className="space-y-6 animate-fade-in py-2">
            <div className="text-center mb-6">
              <div className="w-16 h-16 bg-indigo-50 text-indigo-500 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>
              </div>
              <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100">กู้คืนรหัสผ่าน</h2>
              <p className="text-sm text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-2">กรุณากรอกอีเมลที่เชื่อมโยงกับบัญชีของท่าน<br/>เพื่อรับรหัสยืนยัน (OTP)</p>
            </div>
            
            {error && (
              <div className="bg-slate-50 dark:bg-slate-700/50 text-slate-700 dark:text-slate-200 border-slate-200 dark:border-slate-700/50 text-xs px-4 py-3 rounded-xl font-bold text-center border flex items-center justify-center gap-2 animate-fade-in">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                <span>{error}</span>
              </div>
            )}
            
            <div>
              <input
                type="email"
                value={forgotEmail}
                onChange={(e) => setForgotEmail(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-xl px-5 py-4 focus:outline-none focus:bg-white dark:bg-slate-800 focus:border-indigo-500 focus:ring-4 focus:ring-indigo-500/10 transition-all font-medium text-sm placeholder:text-slate-400 dark:text-slate-300 text-center"
                placeholder="อีเมล (Email Address)"
                required
              />
            </div>
            
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-4 px-4 rounded-xl transition-all shadow-lg shadow-indigo-600/20 disabled:opacity-50 flex items-center justify-center"
            >
              {loading ? 'กำลังส่ง...' : 'ขอรับรหัสยืนยัน'}
            </button>
            
            <div className="text-center mt-2">
              <button 
                type="button" 
                onClick={() => { setForgotMode(false); setError(''); }} 
                className="text-sm text-slate-400 dark:text-slate-300 hover:text-slate-700 dark:text-slate-200 font-medium transition-colors"
              >
                ย้อนกลับไปหน้าเข้าสู่ระบบ
              </button>
            </div>
          </form>
        )}

        {forgotMode === 'verify' && !requirePasswordChange && (
          <form onSubmit={handleForgotVerify} className="space-y-6 animate-fade-in py-2">
            <div className="text-center mb-6">
              <div className="w-16 h-16 bg-indigo-50 text-indigo-500 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" /></svg>
              </div>
              <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100">ยืนยันรหัส OTP</h2>
              <p className="text-sm text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-2">กรุณากรอกรหัส 6 หลักที่เราส่งไปยัง<br/><span className="font-semibold text-slate-700 dark:text-slate-200">{forgotEmail}</span></p>
            </div>
            
            {error && (
              <div className="bg-slate-50 dark:bg-slate-700/50 text-slate-700 dark:text-slate-200 border-slate-200 dark:border-slate-700/50 text-xs px-4 py-3 rounded-xl font-bold text-center border flex items-center justify-center gap-2 animate-fade-in">
                <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                <span>{error}</span>
              </div>
            )}
            
            <div className="space-y-5">
              <div className="flex justify-center gap-2 mb-2">
                {[0, 1, 2, 3, 4, 5].map((index) => (
                  <input
                    key={index}
                    ref={otpRefs[index]}
                    type="text"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    maxLength={1}
                    value={forgotOtp[index]}
                    onChange={(e) => handleOtpChange(index, e.target.value)}
                    onKeyDown={(e) => handleOtpKeyDown(index, e)}
                    onPaste={handleOtpPaste}
                    className="w-11 h-12 text-center text-xl font-bold text-slate-800 dark:text-slate-100 bg-white dark:bg-slate-800 border border-slate-300 rounded-lg focus:bg-white dark:bg-slate-800 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 transition-all outline-none"
                    required
                  />
                ))}
              </div>
            </div>
            
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-4 px-4 rounded-xl transition-all shadow-lg shadow-indigo-600/20 disabled:opacity-50 flex items-center justify-center"
            >
              {loading ? 'กำลังตรวจสอบ...' : 'ถัดไป (Next)'}
            </button>
            
            <div className="text-center mt-2">
              <button 
                type="button" 
                onClick={() => { setForgotMode('request'); setError(''); setForgotOtp(['', '', '', '', '', '']); }} 
                className="text-sm text-slate-400 dark:text-slate-300 hover:text-slate-700 dark:text-slate-200 font-medium transition-colors"
              >
                ไม่ได้รับรหัสยืนยัน? ขอรับใหม่
              </button>
            </div>
          </form>
        )}

        {forgotMode === 'reset' && !requirePasswordChange && (
          <form onSubmit={handleForgotReset} className="space-y-6 animate-fade-in py-2">
            <div className="text-center mb-6">
              <div className="w-16 h-16 bg-indigo-50 text-indigo-500 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" /></svg>
              </div>
              <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100">ตั้งรหัสผ่านใหม่</h2>
              <p className="text-sm text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-2">รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร<br/>ประกอบด้วยภาษาอังกฤษและตัวเลข</p>
            </div>
            
            {error && (
              <div className="bg-slate-50 dark:bg-slate-700/50 text-slate-700 dark:text-slate-200 border-slate-200 dark:border-slate-700/50 text-xs px-4 py-3 rounded-xl font-bold text-center border flex items-center justify-center gap-2 animate-fade-in">
                <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                <span>{error}</span>
              </div>
            )}
            
            <div className="space-y-5">
              <input
                type="password"
                value={forgotNewPassword}
                onChange={(e) => setForgotNewPassword(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-xl px-5 py-4 focus:outline-none focus:bg-white dark:bg-slate-800 focus:border-indigo-500 focus:ring-4 focus:ring-indigo-500/10 transition-all font-medium text-sm placeholder:text-slate-400 dark:text-slate-300"
                placeholder="รหัสผ่านใหม่ (New Password)"
                required
              />
              <input
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-700/50 text-slate-800 dark:text-slate-100 rounded-xl px-5 py-4 focus:outline-none focus:bg-white dark:bg-slate-800 focus:border-indigo-500 focus:ring-4 focus:ring-indigo-500/10 transition-all font-medium text-sm placeholder:text-slate-400 dark:text-slate-300"
                placeholder="ยืนยันรหัสผ่านใหม่ (Confirm Password)"
                required
              />
            </div>
            
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-4 px-4 rounded-xl transition-all shadow-lg shadow-indigo-600/20 disabled:opacity-50 flex items-center justify-center"
            >
              {loading ? 'กำลังบันทึก...' : 'เปลี่ยนรหัสผ่านใหม่'}
            </button>
          </form>
        )}
        

      </div>
    </div>
  );
}
