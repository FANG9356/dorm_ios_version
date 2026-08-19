import { createPortal } from 'react-dom';

export default function ConfirmModal({ isOpen, title, message, onConfirm, onCancel, confirmText = 'ยืนยัน', cancelText = 'ยกเลิก', isDanger = true, isAlert = false }) {
  if (!isOpen) return null;

  return createPortal(
    <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center p-4 z-[9999] animate-fade-in">
      <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-xl w-full max-w-sm overflow-hidden border border-slate-200 dark:border-slate-700/50 animate-scale-in">
        <div className="bg-slate-50 dark:bg-slate-700/50 px-6 py-4 border-b border-slate-200 dark:border-slate-700/50 flex justify-between items-center">
          <h3 className="font-bold text-slate-800 dark:text-slate-100 tracking-wide uppercase flex items-center gap-2">
            {isDanger && <span className="w-2 h-2 rounded-full bg-red-500 animate-pulse"></span>}
            {title || 'ยืนยันการดำเนินการ'}
          </h3>
          <button onClick={onCancel} className="text-slate-400 dark:text-slate-300 hover:text-slate-700 dark:text-slate-200 font-bold text-xl transition-colors">&times;</button>
        </div>
        <div className="p-6">
          <div className="text-sm font-medium text-slate-600 dark:text-slate-300 leading-relaxed">
            {message}
          </div>
        </div>
        <div className="bg-slate-50 dark:bg-slate-700/50 px-6 py-4 border-t border-slate-100 dark:border-slate-700/50 flex gap-3">
          {!isAlert && (
            <button 
              onClick={onCancel} 
              className="flex-1 bg-white dark:bg-slate-800 border border-slate-300 text-slate-600 dark:text-slate-300 py-2.5 rounded-lg text-xs font-bold uppercase transition-all hover:bg-slate-100 focus:ring-2 focus:ring-slate-200"
            >
              {cancelText}
            </button>
          )}
          <button 
            onClick={onConfirm} 
            className={`flex-1 text-white py-2.5 rounded-lg text-xs font-bold uppercase tracking-widest shadow-md transition-all focus:ring-2 ${isDanger ? 'bg-red-600 hover:bg-red-700 focus:ring-red-200 shadow-red-500/20' : 'bg-blue-600 hover:bg-blue-700 focus:ring-blue-200 shadow-blue-500/20'}`}
          >
            {confirmText}
          </button>
        </div>
      </div>
    </div>,
    document.body
  );
}
