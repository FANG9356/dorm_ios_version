import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import './App.css'
import App from './App.jsx'

import { API_URL } from './config'

const originalFetch = window.fetch;
window.fetch = async (url, options = {}) => {
  if (typeof url === 'string' && url.startsWith(API_URL) && !url.includes('/login') && !url.includes('/change-password')) {
    const token = localStorage.getItem('dorminet_token');
    if (token) {
      if (!options.headers) options.headers = {};
      if (options.headers instanceof Headers) {
        if (!options.headers.has('Authorization')) options.headers.set('Authorization', `Bearer ${token}`);
      } else if (Array.isArray(options.headers)) {
        if (!options.headers.find(h => h[0].toLowerCase() === 'authorization')) {
          options.headers.push(['Authorization', `Bearer ${token}`]);
        }
      } else {
        const hasAuth = Object.keys(options.headers).find(k => k.toLowerCase() === 'authorization');
        if (!hasAuth) options.headers['Authorization'] = `Bearer ${token}`;
      }
    }
  }
  const response = await originalFetch(url, options);
  if (response.status === 401 && typeof url === 'string' && !url.includes('/login')) {
    window.dispatchEvent(new Event('auth_error'));
  }
  return response;
};

if (localStorage.getItem('dorminet_force_reset_v5') !== 'true') {
  localStorage.clear();
  localStorage.setItem('dorminet_force_reset_v5', 'true');
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
