const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PORT = 8000;
const ROOT = __dirname;
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon'
};

function lanIPs() {
  const ifs = os.networkInterfaces();
  const list = [];
  for (const name of Object.keys(ifs)) {
    for (const a of ifs[name]) {
      if (a.family === 'IPv4' && !a.internal) list.push({ name, ip: a.address });
    }
  }
  const isWifi = n => /wi-?fi|wlan|无线/i.test(n);
  const isVirtual = n => /vmware|virtual|vbox|hyper-v|loopback|bluetooth|docker|vethernet/i.test(n);
  list.sort((a, b) => {
    const score = c => (isWifi(c.name) ? 2 : isVirtual(c.name) ? 0 : 1);
    return score(b) - score(a);
  });
  return list;
}

http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p === '/') p = '/index.html';
  const file = path.join(ROOT, p);
  if (!file.startsWith(ROOT)) { res.writeHead(403); return res.end('403'); }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }); return res.end('404 Not Found'); }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(PORT, '0.0.0.0', () => {
  console.log('生日惊喜服务器已启动：');
  console.log(`  本机访问:  http://localhost:${PORT}/`);
  for (const c of lanIPs()) {
    console.log(`  [${c.name}]  http://${c.ip}:${PORT}/`);
  }
  console.log('提示：手机需与本机连接同一个 Wi-Fi，用对应网卡的地址访问。');
});
