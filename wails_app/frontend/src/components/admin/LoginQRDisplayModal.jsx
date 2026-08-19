import React, { useState, useEffect } from 'react';
import QRCode from 'react-qr-code';
import { API_URL } from '../../config';

export default function LoginQRDisplayModal({ isOpen, onClose, targetUsername }) {
  const [loginToken, setLoginToken] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [timeLeft, setTimeLeft] = useState(0);

  useEffect(() => {
    if (isOpen && targetUsername) {
      generateToken();
    } else {
      setLoginToken('');
      setTimeLeft(0);
    }
  }, [isOpen, targetUsername]);

  useEffect(() => {
    let timer;
    if (timeLeft > 0 && loginToken) {
      timer = setInterval(() => {
        setTimeLeft((prev) => prev - 1);
      }, 1000);
    } else if (timeLeft === 0 && loginToken) {
      setLoginToken('');
      setError('QR Code หมดอายุแล้ว กรุณาสร้างใหม่');
    }
    return () => clearInterval(timer);
  }, [timeLeft, loginToken]);

  const generateToken = async () => {
    setLoading(true);
    setError('');
    try {
      const res = await fetch(`${API_URL}/admins/login-qr/generate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('dorminet_token')}`
        },
        body: JSON.stringify({ target_username: targetUsername })
      });
      const data = await res.json();
      if (res.ok) {
        setLoginToken(data.login_token);
        setTimeLeft(parseInt(data.expires_in, 10));
      } else {
        setError(data.error || 'ไม่สามารถสร้าง QR Code ได้');
      }
    } catch (err) {
      setError('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    } finally {
      setLoading(false);
    }
  };

  if (!isOpen) return null;

  const formatTime = (seconds) => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  const qrValue = `login_token:${loginToken}`;

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in p-4">
      <div className="bg-white dark:bg-slate-800 rounded-3xl p-8 max-w-sm w-full shadow-2xl animate-scale-up text-center border border-slate-100 dark:border-slate-700/50">
        <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100 mb-2">QR เข้าสู่ระบบ</h2>
        <p className="text-slate-500 dark:text-slate-400 text-sm mb-6">
          ให้ <strong>{targetUsername}</strong> สแกนเพื่อเข้าสู่ระบบ
        </p>
        
        {loading ? (
          <div className="flex flex-col items-center justify-center py-10">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mb-4"></div>
            <p className="text-slate-500 dark:text-slate-400 font-medium text-sm">กำลังสร้าง QR Code...</p>
          </div>
        ) : error && !loginToken ? (
          <div className="bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 p-4 rounded-xl text-sm font-medium mb-6">
            {error}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center mb-6">
            <div className="bg-white p-4 rounded-2xl shadow-inner border border-slate-100 inline-block">
              {loginToken && (
                <QRCode value={qrValue} size={200} />
              )}
            </div>
            
            {timeLeft > 0 && (
              <div className="mt-6 flex items-center gap-2 text-amber-600 dark:text-amber-500 bg-amber-50 dark:bg-amber-500/10 px-4 py-2 rounded-full font-bold text-sm">
                <svg className="w-4 h-4 animate-pulse" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span>หมดเวลาใน {formatTime(timeLeft)}</span>
              </div>
            )}
          </div>
        )}
        
        <div className="flex gap-3">
          {(!loading && (!loginToken || timeLeft === 0)) && (
            <button
              onClick={generateToken}
              className="flex-1 bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 px-4 rounded-xl transition-all"
            >
              สร้างใหม่
            </button>
          )}
          <button
            onClick={onClose}
            className="flex-1 bg-slate-100 hover:bg-slate-200 dark:bg-slate-700 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-200 font-bold py-3 px-4 rounded-xl transition-all"
          >
            ปิดหน้าต่าง
          </button>
        </div>
      </div>
    </div>
  );
}
