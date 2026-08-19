import { useEffect } from 'react';
import { API_URL } from '../../config';

export default function LogPage({ logs, fetchLogs }) {
  // ดึงข้อมูลใหม่ทุกครั้งที่กดเข้ามาหน้านี้
  useEffect(() => {
    fetchLogs();
  }, []);

  const handleExportCSV = () => {
    if (!logs || logs.length === 0) {
      alert("ไม่มีประวัติการใช้งานระบบสำหรับดาวน์โหลด");
      return;
    }
    
    // CSV headers: Time, Action, Details
    const headers = ["วันที่-เวลา", "ประเภทการกระทำ", "รายละเอียด"];
    
    // Map log entries into CSV rows
    const rows = logs.map(log => [
      log.timestamp,
      log.action_type,
      log.details.replace(/"/g, '""') // Escape double quotes
    ]);
    
    // Combine headers and rows (Add UTF-8 BOM for Excel Thai language support)
    const csvContent = "\uFEFF" + [ 
      headers.join(","),
      ...rows.map(e => e.map(val => `"${val}"`).join(","))
    ].join("\n");
    
    // Create download link
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `system_audit_logs_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="animate-fade-in flex flex-col h-[82vh] font-sans text-slate-800 dark:text-slate-100">
      
      {/* Header section */}
      <div className="flex justify-between items-center mb-6">
        <div>
          <h3 className="text-sm font-extrabold text-slate-800 dark:text-slate-100 uppercase tracking-wider">
            System Audit Logs
          </h3>
          <p className="text-xs text-slate-500 dark:text-slate-400 dark:text-slate-300 mt-1">ประวัติการใช้งานระบบและบันทึกกิจกรรมย้อนหลัง</p>
        </div>
        <div className="flex gap-2">
          <button 
            type="button"
            onClick={handleExportCSV} 
            className="bg-white dark:bg-slate-800 border border-slate-200/80 text-blue-600 px-4 py-2 rounded-lg text-xs font-bold uppercase tracking-wider shadow-sm hover:bg-blue-50/50 hover:border-blue-200 transition-all flex items-center gap-1.5"
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5"><path strokeLinecap="round" strokeLinejoin="round" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
            Export Excel / CSV
          </button>
          <button 
            type="button"
            onClick={fetchLogs} 
            className="bg-white dark:bg-slate-800 border border-slate-200/80 text-slate-600 dark:text-slate-300 px-4 py-2 rounded-lg text-xs font-bold uppercase tracking-wider shadow-sm hover:bg-slate-50 dark:bg-slate-700/50 hover:text-slate-900 dark:text-slate-100 transition-all flex items-center gap-1.5"
          >
            <span className="w-1.5 h-1.5 bg-emerald-500 rounded-full animate-pulse"></span>
            Refresh Logs
          </button>
        </div>
      </div>
      
      {/* Logs Card Container */}
      <div className="bg-white dark:bg-slate-800 border border-slate-200/60 dark:border-slate-700/50 rounded-2xl shadow-[0_8px_30px_rgb(0,0,0,0.02)] overflow-hidden flex-1 flex flex-col">
        <div className="px-6 py-4 border-b border-slate-100 dark:border-slate-700/50 bg-slate-50/50 flex items-center justify-between">
          <span className="text-[10px] font-black text-slate-400 dark:text-slate-300 tracking-widest uppercase">รายการกิจกรรมในระบบ</span>
          <span className="text-[10px] font-bold text-slate-400 dark:text-slate-300 font-mono">บันทึกทั้งหมด {logs.length} รายการ</span>
        </div>
        
        <div className="p-4 overflow-y-auto flex-1 divide-y divide-slate-100">
          {logs.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 text-slate-400 dark:text-slate-300 opacity-60">
              <svg className="w-12 h-12 mb-3 text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5">
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              <p className="font-bold uppercase tracking-widest text-xs">ไม่มีบันทึกประวัติกิจกรรมในระบบ</p>
            </div>
          ) : (
            logs.map((log) => {
              // Action badges
              let badgeColor = 'bg-slate-50 dark:bg-slate-700/50 text-slate-600 dark:text-slate-300 border-slate-200/80';
              if (log.action_type.includes('Delete') || log.action_type.includes('Remove')) {
                badgeColor = 'bg-red-50 text-red-600 border-red-100';
              } else if (log.action_type.includes('Add') || log.action_type.includes('Payment') || log.action_type.includes('Create') || log.action_type.includes('Backup')) {
                badgeColor = 'bg-emerald-50 text-emerald-600 border-emerald-100';
              } else if (log.action_type.includes('Edit') || log.action_type.includes('Update')) {
                badgeColor = 'bg-amber-50 text-amber-600 border-amber-100';
              }

              return (
                <div key={log.id} className="flex items-center gap-4 py-3 px-3 hover:bg-slate-50/50 transition-colors">
                  <span className="text-[10px] font-mono font-bold text-slate-400 dark:text-slate-300 bg-slate-50 dark:bg-slate-700/50 px-2 py-0.5 rounded border border-slate-100 dark:border-slate-700/50/60 shrink-0">
                    {log.timestamp}
                  </span>
                  <span className={`inline-flex items-center text-[9px] font-black px-2 py-0.5 rounded border uppercase tracking-wider shrink-0 ${badgeColor}`}>
                    {log.action_type}
                  </span>
                  <span className="text-xs font-semibold text-slate-600 dark:text-slate-300 break-words flex-1">
                    {log.details}
                  </span>
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}