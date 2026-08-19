import React, { useEffect, useRef, useState } from 'react';
import { Html5Qrcode } from 'html5-qrcode';

export default function QRScannerModal({ isOpen, onClose, onScan }) {
  const [error, setError] = useState('');
  const scannerRef = useRef(null);

  useEffect(() => {
    if (!isOpen) return;

    let html5QrCode;

    const startScanner = async () => {
      try {
        html5QrCode = new Html5Qrcode("qr-reader");
        await html5QrCode.start(
          { facingMode: "environment" },
          {
            fps: 10,
            aspectRatio: window.innerHeight > window.innerWidth ? window.innerHeight / window.innerWidth : window.innerWidth / window.innerHeight
          },
          (decodedText) => {
            // Validate if it looks like an IP or URL
            html5QrCode.stop().then(() => {
              onScan(decodedText);
              onClose();
            }).catch(err => console.error("Failed to stop scanner", err));
          },
          (errorMessage) => {
            // Ignore scan failures (happens every frame it doesn't see a QR)
          }
        );
      } catch (err) {
        setError('ไม่สามารถเปิดกล้องได้ กรุณาตรวจสอบสิทธิ์การเข้าถึงกล้อง');
        console.error(err);
      }
    };

    startScanner();

    return () => {
      if (html5QrCode && html5QrCode.isScanning) {
        html5QrCode.stop().catch(console.error);
      }
    };
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black flex items-center justify-center z-[100] animate-fade-in">
      {/* Close button */}
      <button 
        onClick={onClose}
        className="absolute top-6 right-6 w-12 h-12 bg-black/40 hover:bg-black/60 text-white rounded-full flex items-center justify-center z-[110] transition-colors backdrop-blur-md"
      >
        <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>

      {error ? (
        <div className="text-center p-6 z-[105]">
          <div className="w-16 h-16 bg-red-500/20 text-red-500 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
            </svg>
          </div>
          <p className="text-white font-medium">{error}</p>
        </div>
      ) : (
        <div className="relative w-full h-full flex items-center justify-center overflow-hidden bg-black">
          {/* The actual scanner */}
          <div id="qr-reader" className="w-full h-full absolute inset-0 flex flex-col items-center justify-center"></div>
          
          {/* Overlay with clear center square */}
          <div className="absolute inset-0 pointer-events-none flex items-center justify-center z-[105] overflow-hidden">
            <div className="w-72 h-72 rounded-3xl shadow-[0_0_0_9999px_rgba(0,0,0,0.75)] border-2 border-white/40 relative flex items-center justify-center">
              {/* Corner brackets */}
              <div className="absolute -top-1 -left-1 w-10 h-10 border-t-4 border-l-4 border-white rounded-tl-3xl"></div>
              <div className="absolute -top-1 -right-1 w-10 h-10 border-t-4 border-r-4 border-white rounded-tr-3xl"></div>
              <div className="absolute -bottom-1 -left-1 w-10 h-10 border-b-4 border-l-4 border-white rounded-bl-3xl"></div>
              <div className="absolute -bottom-1 -right-1 w-10 h-10 border-b-4 border-r-4 border-white rounded-br-3xl"></div>
              
              {/* Optional scanning laser (if you want it minimalist, you can remove this, but a simple line looks good) */}
              <div className="w-full h-0.5 bg-white/50 shadow-[0_0_8px_rgba(255,255,255,0.8)] absolute top-0 left-0 animate-scan pointer-events-none"></div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
