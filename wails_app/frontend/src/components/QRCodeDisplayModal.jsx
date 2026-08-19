import React, { useState, useEffect } from 'react';
import { QRCodeSVG } from 'qrcode.react';

export default function QRCodeDisplayModal({ isOpen, onClose }) {
  const [localIp, setLocalIp] = useState('127.0.0.1');

  useEffect(() => {
    if (isOpen && window.go && window.go.main && window.go.main.App && window.go.main.App.GetLocalIP) {
      window.go.main.App.GetLocalIP().then(ip => {
        setLocalIp(ip);
      }).catch(err => console.error("Failed to get local IP:", err));
    }
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center z-[100] p-4">
      <div className="bg-white dark:bg-slate-800 rounded-3xl shadow-2xl p-8 max-w-sm w-full relative border border-slate-200 dark:border-slate-700">
        <button 
          onClick={onClose}
          className="absolute top-4 right-4 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
        >
          <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>

        <div className="text-center">
          <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 mb-4">
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm14 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z" />
            </svg>
          </div>
          <h3 className="text-xl font-bold text-slate-800 dark:text-slate-100 mb-2">
            สแกนเพื่อเชื่อมต่อ
          </h3>
          <p className="text-sm text-slate-500 dark:text-slate-400 mb-6">
            เปิดแอพ DormiNet บนมือถือของคุณ และเลือกเมนู "สแกน QR Code"
          </p>

          <div className="bg-white p-4 rounded-2xl shadow-inner border border-slate-100 inline-block mb-6">
            <QRCodeSVG 
              value={localIp} 
              size={200}
              level="H"
              includeMargin={true}
              fgColor="#0f172a"
            />
          </div>

          <div className="bg-slate-50 dark:bg-slate-900/50 rounded-xl p-3 border border-slate-100 dark:border-slate-700/50">
            <p className="text-xs text-slate-500 dark:text-slate-400 uppercase font-semibold tracking-wider mb-1">
              IP ADDRESS เครื่องแม่ข่าย
            </p>
            <p className="text-lg font-mono font-bold text-slate-700 dark:text-slate-300">
              {localIp}
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
