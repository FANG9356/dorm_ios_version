// ศูนย์กลางตั้งค่า API — production ใช้ /api, dev ใช้ proxy ผ่าน /api
export const API_URL = import.meta.env.VITE_API_URL || '/api';

export const uploadsUrl = (filename) => {
  if (!filename) return '';
  const token = localStorage.getItem('dorminet_token');
  const baseUrl = `${API_URL.replace('/api', '')}/uploads/${filename}`;
  return token ? `${baseUrl}?token=${token}` : baseUrl;
};

// Global Fetch Interceptor for JWT
const originalFetch = window.fetch;
window.fetch = async (...args) => {
  let [resource, config] = args;
  
  if (typeof resource === 'string' && resource.startsWith(API_URL)) {
    const token = localStorage.getItem('dorminet_token');
    if (token) {
      config = config || {};
      config.headers = {
        ...config.headers,
        'Authorization': `Bearer ${token}`
      };
    }
  } else if (resource instanceof Request && resource.url.startsWith(API_URL)) {
    const token = localStorage.getItem('dorminet_token');
    if (token) {
      resource.headers.set('Authorization', `Bearer ${token}`);
    }
  }
  
  const response = await originalFetch(resource, config);
  
  const urlString = typeof resource === 'string' ? resource : resource.url;
  if (response.status === 401 && !urlString.includes('/api/login')) {
    localStorage.removeItem('dorminet_token');
    window.dispatchEvent(new Event('auth_error'));
  }
  
  return response;
};
