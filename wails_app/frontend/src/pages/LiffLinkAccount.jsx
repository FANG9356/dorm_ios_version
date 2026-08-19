import React, { useState, useEffect } from 'react';

const LiffLinkAccount = () => {
  const [rooms, setRooms] = useState([]);
  const [selectedRoom, setSelectedRoom] = useState('');
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [lineProfile, setLineProfile] = useState(null);
  const [status, setStatus] = useState({ type: '', message: '' });
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [phoneNumber, setPhoneNumber] = useState('');
  const [isVerified, setIsVerified] = useState(false);
  const [tenantName, setTenantName] = useState('');
  const [verifying, setVerifying] = useState(false);

  // เปลี่ยนเป็น LIFF ID ของคุณ
  const liffId = "2010525486-cUOKPsCJ"; 

  useEffect(() => {
    document.body.style.backgroundColor = '#f3f4f6';
    
    // Fetch available rooms
    const fetchRooms = async () => {
      try {
        const res = await fetch('/api/liff/rooms');
        if (res.ok) {
          const data = await res.json();
          setRooms(data || []);
        }
      } catch (err) {
        console.error('Failed to fetch rooms', err);
      }
    };
    
    fetchRooms();

    if (!window.liff) {
      setStatus({ type: 'error', message: 'LIFF SDK is not loaded' });
      setLoading(false);
      return;
    }

    const initLiff = async () => {
      try {
        await window.liff.init({ liffId: liffId });
        if (window.liff.isLoggedIn()) {
          const profile = await window.liff.getProfile();
          profile.idToken = window.liff.getIDToken();
          setLineProfile(profile);
        } else {
          window.liff.login();
        }
      } catch (err) {
        console.error('LIFF Init Error', err);
        setStatus({ type: 'error', message: 'กรุณาเปิดลิงก์นี้ผ่านแอป LINE บนมือถือ' });
      } finally {
        setLoading(false);
      }
    };

    initLiff();
    
    return () => {
        document.body.style.backgroundColor = '';
    };
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    setStatus({ type: '', message: '' });

    if (!selectedRoom) {
      setStatus({ type: 'error', message: 'กรุณาเลือกห้องพัก' });
      setSubmitting(false);
      return;
    }
    if (!lineProfile || !lineProfile.userId) {
      setStatus({ type: 'error', message: 'ไม่พบข้อมูล LINE ID กรุณาเปิดผ่านแอป LINE' });
      setSubmitting(false);
      return;
    }

    try {
      const response = await fetch('/api/liff/link', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          access_token: window.liff.getAccessToken(),
          room_number: selectedRoom,
          phone: phoneNumber
        })
      });

      const data = await response.json();
      if (response.ok) {
        setStatus({ type: 'success', message: 'ผูกบัญชีสำเร็จ! ปิดหน้านี้ได้เลยค่ะ' });
        setTimeout(() => {
          if (window.liff) window.liff.closeWindow();
        }, 3000);
      } else {
        setStatus({ type: 'error', message: data.error || 'เกิดข้อผิดพลาด' });
      }
    } catch (err) {
      setStatus({ type: 'error', message: 'เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์' });
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-screen bg-slate-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  const handleVerifyPhone = async () => {
    if (!phoneNumber) {
      setStatus({ type: 'error', message: 'กรุณากรอกเบอร์โทรศัพท์' });
      return;
    }
    setVerifying(true);
    setStatus({ type: '', message: '' });
    
    try {
      const response = await fetch('/api/liff/verify-tenant', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          room_number: selectedRoom,
          phone: phoneNumber
        })
      });

      const data = await response.json();
      if (response.ok) {
        setIsVerified(true);
        setTenantName(data.masked_name);
        setStatus({ type: 'success', message: 'ตรวจสอบข้อมูลถูกต้อง' });
      } else {
        setIsVerified(false);
        setTenantName('');
        setStatus({ type: 'error', message: data.error || 'เบอร์โทรศัพท์ไม่ถูกต้อง' });
      }
    } catch (err) {
      setStatus({ type: 'error', message: 'เกิดข้อผิดพลาดในการเชื่อมต่อ' });
    } finally {
      setVerifying(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#F8F9FA] flex flex-col items-center pt-10 px-6 font-sans relative overflow-hidden">
      
      {/* Background Decor */}
      <div className="absolute top-0 left-0 w-full h-64 bg-gradient-to-b from-slate-200/50 to-transparent -z-10"></div>
      <div className="absolute top-[-50px] right-[-50px] w-40 h-40 bg-indigo-500/5 rounded-full blur-3xl -z-10"></div>
      <div className="absolute top-[20%] left-[-50px] w-48 h-48 bg-blue-500/5 rounded-full blur-3xl -z-10"></div>
      
      {/* Header Section */}
      <div className="flex flex-col items-center mb-10 w-full max-w-sm mt-4">
        {lineProfile && lineProfile.pictureUrl ? (
          <div className="relative mb-5 p-1 bg-gradient-to-b from-slate-200 to-slate-50 rounded-full shadow-sm">
            <img 
              src={lineProfile.pictureUrl} 
              alt="Profile" 
              className="w-20 h-20 rounded-full border-4 border-white object-cover shadow-sm"
            />
          </div>
        ) : (
          <div className="w-20 h-20 rounded-full bg-slate-100 flex items-center justify-center shadow-inner mb-5 border-4 border-white">
            <svg className="w-8 h-8 text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>
          </div>
        )}
        <h2 className="text-2xl font-bold text-slate-900 tracking-tight">Resident Access</h2>
        <p className="text-slate-500 text-sm mt-1.5 font-medium">
          เชื่อมต่อบัญชีสำหรับ <span className="text-slate-800 font-bold">{lineProfile ? lineProfile.displayName : 'ลูกบ้าน'}</span>
        </p>
      </div>

      {/* Card Form */}
      <form onSubmit={handleSubmit} className="w-full max-w-sm flex flex-col items-center z-10 pb-32">
        <div className="bg-white/80 backdrop-blur-xl p-7 rounded-[2rem] shadow-[0_8px_30px_rgb(0,0,0,0.04)] border border-slate-100 w-full relative">
          
          {status.message && (
            <div className={`p-4 rounded-2xl mb-6 text-sm text-center font-medium animate-fade-in flex items-center justify-center gap-2 ${
              status.type === 'error' ? 'bg-red-50 text-red-600' : 'bg-emerald-50 text-emerald-700'
            }`}>
              {status.type === 'error' ? (
                <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
              ) : (
                <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
              )}
              {status.message}
            </div>
          )}

          <div className="space-y-5">
            <div>
              <label className="block text-slate-500 text-xs font-bold mb-2 uppercase tracking-widest pl-1">หมายเลขห้องพัก</label>
              <div className="relative">
                {/* Premium Dropdown Trigger */}
                <div 
                  onClick={() => setIsDropdownOpen(!isDropdownOpen)}
                  className={`w-full px-4 py-3.5 rounded-2xl border transition-all cursor-pointer flex items-center justify-between ${isDropdownOpen ? 'border-slate-400 bg-white shadow-sm ring-4 ring-slate-100' : 'border-transparent bg-slate-100/80 hover:bg-slate-200/50'}`}
                >
                  <span className={selectedRoom ? 'text-slate-900 font-bold' : 'text-slate-400 font-medium'}>
                    {selectedRoom ? `ห้อง ${selectedRoom}` : 'เลือกหมายเลขห้อง'}
                  </span>
                  <div className={`text-slate-400 transition-transform duration-300 ${isDropdownOpen ? 'rotate-180' : ''}`}>
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7"></path></svg>
                  </div>
                </div>

                {/* Premium Dropdown Menu */}
                {isDropdownOpen && (
                  <div className="absolute z-50 w-full mt-2 bg-white/90 backdrop-blur-xl border border-slate-100 rounded-2xl shadow-[0_10px_40px_rgb(0,0,0,0.08)] max-h-60 overflow-auto animate-fade-in origin-top">
                    {rooms.length === 0 ? (
                      <div className="p-5 text-center text-slate-400 text-sm font-medium">ไม่พบห้องว่าง</div>
                    ) : (
                      <ul className="py-2">
                        {rooms.map((room) => (
                          <li 
                            key={room.room_number} 
                            onClick={() => {
                              setSelectedRoom(room.room_number);
                              setIsDropdownOpen(false);
                              setIsVerified(false);
                              setTenantName('');
                              setPhoneNumber('');
                              setStatus({ type: '', message: '' });
                            }}
                            className={`px-5 py-3 cursor-pointer transition-colors flex justify-between items-center ${selectedRoom === room.room_number ? 'bg-slate-900 text-white font-bold' : 'text-slate-600 font-medium hover:bg-slate-50'}`}
                          >
                            <span>ห้อง {room.room_number}</span>
                            {selectedRoom === room.room_number && (
                              <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M5 13l4 4L19 7" /></svg>
                            )}
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                )}
              </div>
            </div>

            {selectedRoom && !isVerified && (
              <div className="animate-fade-in space-y-2 pt-2">
                <label className="block text-slate-500 text-xs font-bold mb-2 uppercase tracking-widest pl-1">เบอร์โทรศัพท์ยืนยัน</label>
                <div className="flex gap-2">
                  <input
                    type="tel"
                    placeholder="08X-XXX-XXXX"
                    value={phoneNumber}
                    onChange={(e) => setPhoneNumber(e.target.value)}
                    className="flex-1 w-full px-4 py-3.5 rounded-2xl border border-transparent bg-slate-100/80 text-slate-900 font-medium focus:bg-white focus:border-slate-400 focus:ring-4 focus:ring-slate-100 outline-none transition-all placeholder:text-slate-400"
                  />
                  <button
                    type="button"
                    onClick={handleVerifyPhone}
                    disabled={verifying || !phoneNumber}
                    className="px-6 py-3.5 bg-slate-900 text-white text-sm font-bold rounded-2xl hover:bg-slate-800 transition-colors disabled:opacity-30 disabled:bg-slate-300"
                  >
                    {verifying ? (
                      <svg className="animate-spin h-5 w-5 text-white mx-auto" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                    ) : 'ยืนยัน'}
                  </button>
                </div>
              </div>
            )}

            {isVerified && tenantName && (
              <div className="pt-2 animate-fade-in">
                <div className="p-4 bg-emerald-50 rounded-2xl border border-emerald-100/50 flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center text-emerald-600">
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M5 13l4 4L19 7" /></svg>
                    </div>
                    <div>
                      <p className="text-[10px] font-bold text-emerald-600/80 uppercase tracking-widest">ข้อมูลผู้เช่าถูกต้อง</p>
                      <p className="text-sm font-bold text-emerald-900">{tenantName}</p>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Fixed Submit Button at Bottom */}
        <div className="fixed bottom-0 left-0 w-full p-6 pb-8 bg-gradient-to-t from-[#F8F9FA] via-[#F8F9FA]/90 to-transparent z-40 flex justify-center pointer-events-none">
          <div className="w-full max-w-sm pointer-events-auto">
            <button 
              type="submit" 
              disabled={submitting || !isVerified}
              className={`w-full py-4 rounded-2xl text-base font-bold text-white transition-all transform active:scale-95 shadow-lg ${
                (submitting || !isVerified) 
                  ? 'bg-slate-200 text-slate-400 shadow-none cursor-not-allowed' 
                  : 'bg-slate-900 hover:bg-slate-800 shadow-slate-900/20 cursor-pointer'
              }`}
            >
              {submitting ? (
                <div className="flex items-center justify-center space-x-2">
                  <svg className="animate-spin h-5 w-5 text-white/50" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  <span>กำลังดำเนินการ...</span>
                </div>
              ) : 'เสร็จสิ้นการเชื่อมต่อ'}
            </button>
          </div>
        </div>
      </form>
      
      <div className="fixed top-6 right-6 opacity-40">
         <svg className="w-6 h-6 text-slate-400" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/></svg>
      </div>
    </div>
  );
};

export default LiffLinkAccount;
