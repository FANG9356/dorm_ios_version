// Utility to quickly scan the local subnet for the DormiNet Main Server

export const scanSubnetForServer = async (subnet) => {
  const promises = [];
  // Scan IP range 1 to 254
  for (let i = 1; i <= 254; i++) {
    const ip = `${subnet}.${i}`;
    const testUrl = `http://${ip}:4282/api/system/ping`;
    
    // We use a short timeout because local network responses are typically <50ms.
    // Connection refused or timeouts will just reject and be caught.
    const p = new Promise((resolve) => {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => {
        controller.abort();
        resolve(null);
      }, 1500); // 1.5 second timeout

      fetch(testUrl, { 
        method: 'GET', 
        signal: controller.signal 
      })
      .then(res => {
        clearTimeout(timeoutId);
        // We expect either 200 OK or 401 Unauthorized (because of AuthMiddleware)
        if (res.ok || res.status === 401) {
          resolve(ip);
        } else {
          resolve(null);
        }
      })
      .catch(() => {
        clearTimeout(timeoutId);
        resolve(null);
      });
    });

    promises.push(p);
  }

  // Wait for all fetches to settle
  const results = await Promise.all(promises);
  // Find the first IP that returned successfully
  return results.find(ip => ip !== null);
};

export const autoDiscoverServer = async () => {
  let subnetsToScan = [];

  // If running inside Wails (Desktop), ask Go for the exact subnet
  if (window.go && window.go.main && window.go.main.App && window.go.main.App.GetLocalSubnet) {
    try {
      const exactSubnet = await window.go.main.App.GetLocalSubnet();
      if (exactSubnet) {
        subnetsToScan.push(exactSubnet);
      }
    } catch (err) {
      console.error("Failed to get subnet from Go:", err);
    }
  }

  // If we are in browser/mobile and accessed via IP (not localhost), use that IP's subnet
  const hostname = window.location.hostname;
  if (hostname !== 'localhost' && hostname !== '127.0.0.1') {
    const parts = hostname.split('.');
    if (parts.length === 4) {
      const browserSubnet = `${parts[0]}.${parts[1]}.${parts[2]}`;
      if (!subnetsToScan.includes(browserSubnet)) {
        subnetsToScan.push(browserSubnet);
      }
    }
  }

  // Fallback to most common local subnets if we don't have any exact matches
  if (subnetsToScan.length === 0) {
    subnetsToScan = ['192.168.1', '192.168.0', '10.0.0'];
  }

  // Scan subnets sequentially to avoid browser connection limits (usually max 6-10 parallel per origin, 
  // but here each IP is a different origin so browsers allow a lot of parallel fetches)
  for (const subnet of subnetsToScan) {
    console.log(`Scanning subnet ${subnet}.* for DormiNet Server...`);
    const foundIp = await scanSubnetForServer(subnet);
    if (foundIp) {
      console.log(`Server found at: ${foundIp}`);
      return foundIp;
    }
  }

  return null;
};
