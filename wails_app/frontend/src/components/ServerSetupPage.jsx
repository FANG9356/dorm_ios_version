import { useState, useEffect } from 'react';
import QRScannerModal from './QRScannerModal';
import { autoDiscoverServer } from '../utils/networkScanner';

import { StartLocalServer } from '../../wailsjs/go/main/App';

export default function ServerSetupPage({ onComplete }) {
  const [mode, setMode] = useState(''); // 'main' or 'client'
  
  const defaultIp = (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1' && window.location.hostname !== 'wails' && window.location.hostname !== 'wails.localhost') ? window.location.hostname : '';
  const [ipAddress, setIpAddress] = useState(defaultIp);
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isScannerOpen, setIsScannerOpen] = useState(false);
  const [discoveryStatus, setDiscoveryStatus] = useState('กำลังแสกนหาเครื่องแม่ข่ายในเครือข่าย...'); // null when done
  const [existingServerIp, setExistingServerIp] = useState(null);

  useEffect(() => {
    let isMounted = true;

    // ถ้าเข้าจาก IP อื่น (ไม่ใช่ localhost หรือ wails.localhost ของแอป) ให้เชื่อมต่อเป็นเครื่องลูกข่ายอัตโนมัติ
    const hostname = window.location.hostname;
    if (hostname !== 'localhost' && hostname !== '127.0.0.1' && hostname !== 'wails.localhost' && hostname !== 'wails') {
      const serverIp = hostname;
      // Use origin to preserve https/http and port (e.g., https://IP:5174/api) to avoid Mixed Content errors
      const testUrl = window.location.origin + '/api';
      setDiscoveryStatus(`พบเครื่องแม่ข่ายที่ ${serverIp} กำลังเชื่อมต่อ...`);
      
      setTimeout(() => {
        localStorage.setItem('dorminet_server_mode', 'client');
        localStorage.setItem('dorminet_server_url', testUrl);
        window.location.reload();
      }, 1500);
      return;
    }

    const performDiscovery = async () => {
      try {
        const foundIp = await autoDiscoverServer();
        if (isMounted && foundIp) {
          setExistingServerIp(foundIp);
          setDiscoveryStatus(`พบเครื่องแม่ข่ายที่ ${foundIp} กำลังเชื่อมต่อ...`);
          
          // Auto connect after 1 second delay for UX
          setTimeout(() => {
            const testUrl = `http://${foundIp}:4282/api`;
            localStorage.setItem('dorminet_server_mode', 'client');
            localStorage.setItem('dorminet_server_url', testUrl);
            window.location.reload();
          }, 1000);
        } else if (isMounted) {
          setDiscoveryStatus(null); // No server found, show buttons
        }
      } catch (err) {
        if (isMounted) setDiscoveryStatus(null);
      }
    };

    performDiscovery();

    return () => { isMounted = false; };
  }, []);

  const handleMainServer = async () => {
    setIsLoading(true);
    // Start local server using Wails bindings directly
    try {
      await StartLocalServer();
    } catch (err) {
      console.error("Failed to start local server via Wails:", err);
    }
    
    // Give it a second to boot
    setTimeout(() => {
      localStorage.setItem('dorminet_server_mode', 'main');
      localStorage.setItem('dorminet_server_url', 'http://localhost:4282/api');
      window.location.reload();
    }, 1500);
  };

  const handleClientSubmit = async (e) => {
    e.preventDefault();
    if (!ipAddress) return setError('กรุณาระบุ IP Address ของเครื่องแม่ข่าย');
    
    setIsLoading(true);
    setError('');
    const testUrl = `http://${ipAddress}:4282/api`;
    
    try {
      const res = await fetch(`${testUrl}/system/ping`);
      if (!res.ok) throw new Error('ไม่สามารถเชื่อมต่อได้');
      
      localStorage.setItem('dorminet_server_mode', 'client');
      localStorage.setItem('dorminet_server_url', testUrl);
      window.location.reload();
    } catch (err) {
      setError('ไม่พบเครื่องแม่ข่ายที่ IP นี้ หรือเครื่องแม่ข่ายออฟไลน์อยู่');
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 dark:bg-slate-900 flex flex-col justify-center py-12 sm:px-6 lg:px-8 relative overflow-hidden transition-colors">
      
      {/* Decorative Background Blobs */}
      <div className="absolute top-[-10%] left-[-10%] w-96 h-96 bg-blue-500/20 dark:bg-blue-600/20 rounded-full mix-blend-multiply dark:mix-blend-screen filter blur-3xl opacity-70 animate-blob pointer-events-none"></div>
      <div className="absolute top-[20%] right-[-10%] w-96 h-96 bg-indigo-500/20 dark:bg-indigo-600/20 rounded-full mix-blend-multiply dark:mix-blend-screen filter blur-3xl opacity-70 animate-blob animation-delay-2000 pointer-events-none"></div>
      <div className="absolute bottom-[-20%] left-[20%] w-96 h-96 bg-cyan-500/20 dark:bg-cyan-600/20 rounded-full mix-blend-multiply dark:mix-blend-screen filter blur-3xl opacity-70 animate-blob animation-delay-4000 pointer-events-none"></div>

      <div className="sm:mx-auto sm:w-full sm:max-w-md relative z-10 text-center px-4 animate-fade-in-up">
        <div className="w-20 h-20 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-3xl mx-auto flex items-center justify-center shadow-lg shadow-blue-500/30 mb-8 transform hover:scale-105 transition-transform">
          <svg className="w-10 h-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />
          </svg>
        </div>
        <h2 className="text-3xl sm:text-4xl font-extrabold text-slate-900 dark:text-white tracking-tight">
          ตั้งค่าการเชื่อมต่อ <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-cyan-500 dark:from-blue-400 dark:to-cyan-300">DormiNet</span>
        </h2>
        <p className="mt-3 text-sm sm:text-base text-slate-600 dark:text-slate-400 font-medium max-w-xs mx-auto">
          กรุณาเลือกรูปแบบการทำงานของอุปกรณ์นี้ หรือสแกนเพื่อเข้าสู่ระบบ
        </p>
      </div>

      <div className="mt-10 sm:mx-auto sm:w-full sm:max-w-md relative z-10 px-4 animate-fade-in-up" style={{ animationDelay: '0.1s' }}>
        <div className="bg-white/80 dark:bg-slate-800/80 backdrop-blur-xl py-10 px-6 sm:px-10 shadow-2xl shadow-blue-900/5 rounded-3xl border border-white/50 dark:border-slate-700/50 mx-4 sm:mx-0">
          
          {discoveryStatus && (
            <div className="py-8 text-center space-y-4">
              <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-blue-100 text-blue-600 mb-2">
                <svg className="w-6 h-6 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
              </div>
              <p className="text-sm font-bold text-slate-700 animate-pulse">
                {discoveryStatus}
              </p>
            </div>
          )}

          {!discoveryStatus && !mode && (
            <div className="space-y-4">
              <button
                onClick={handleMainServer}
                disabled={isLoading}
                className="w-full flex items-center justify-center gap-3 py-4 px-4 border border-transparent rounded-2xl shadow-md shadow-blue-600/20 text-sm font-bold text-white bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 transition-all hover:shadow-lg hover:shadow-blue-600/30 active:scale-[0.98]"
              >
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" /></svg>
                {isLoading ? 'กำลังเปิดใช้งาน...' : 'ใช้งานเป็น "เครื่องแม่ข่าย" (Main)'}
              </button>
              <button
                onClick={() => setMode('client')}
                disabled={isLoading}
                className="w-full flex items-center justify-center gap-3 py-4 px-4 border-2 border-blue-100 dark:border-slate-700 rounded-2xl shadow-sm text-sm font-bold text-blue-700 dark:text-blue-400 bg-blue-50/50 dark:bg-slate-800/50 hover:bg-blue-100 dark:hover:bg-slate-700 transition-all active:scale-[0.98]"
              >
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>
                ใช้งานเป็น "เครื่องลูกข่าย" (Client)
              </button>
            </div>
          )}

          {mode === 'client' && (
            <form className="space-y-6" onSubmit={handleClientSubmit}>
              {error && <div className="text-sm text-red-600 font-bold bg-red-50 p-3 rounded-lg">{error}</div>}
              <div className="animate-fade-in-up">
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-widest mb-2 flex justify-between items-end">
                  <span>IP เครื่องแม่ข่าย</span>
                  <button
                    type="button"
                    onClick={() => setIsScannerOpen(true)}
                    className="text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300 flex items-center gap-1.5 bg-blue-50 dark:bg-blue-900/30 hover:bg-blue-100 dark:hover:bg-blue-900/50 px-3 py-1.5 rounded-lg transition-colors"
                  >
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm14 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z" />
                    </svg>
                    สแกน QR
                  </button>
                </label>
                <input
                  type="text"
                  value={ipAddress}
                  onChange={e => setIpAddress(e.target.value)}
                  className="appearance-none block w-full px-5 py-4 border-2 border-slate-200 dark:border-slate-700 bg-white/50 dark:bg-slate-900/50 rounded-2xl shadow-sm placeholder-slate-400 dark:text-white focus:outline-none focus:border-blue-500 focus:ring-4 focus:ring-blue-500/20 transition-all font-mono text-lg text-center"
                  placeholder="192.168.1.X"
                />
              </div>
              <div className="flex gap-3 animate-fade-in-up" style={{ animationDelay: '0.1s' }}>
                <button
                  type="button"
                  onClick={() => setMode('')}
                  className="w-1/3 py-4 border-2 border-slate-200 dark:border-slate-700 rounded-2xl text-sm font-bold text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 transition-all active:scale-[0.98]"
                >
                  กลับ
                </button>
                <button
                  type="submit"
                  disabled={isLoading}
                  className="w-2/3 py-4 border border-transparent rounded-2xl text-sm font-bold text-white bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 shadow-md shadow-blue-600/20 hover:shadow-lg hover:shadow-blue-600/30 transition-all active:scale-[0.98]"
                >
                  {isLoading ? 'กำลังเชื่อมต่อ...' : 'ยืนยันการเชื่อมต่อ'}
                </button>
              </div>
            </form>
          )}
        </div>
      </div>
      
      <QRScannerModal 
        isOpen={isScannerOpen} 
        onClose={() => setIsScannerOpen(false)} 
        onScan={(ip) => {
          setIpAddress(ip);
        }} 
      />
    </div>
  );
}
