const QRCode = require('qrcode');
const os = require('os');
const path = require('path');

function lanIP() {
  const ifs = os.networkInterfaces();
  const list = [];
  for (const name of Object.keys(ifs)) {
    for (const a of ifs[name]) {
      if (a.family === 'IPv4' && !a.internal) list.push({ name, ip: a.address });
    }
  }
  const isWifi = n => /wi-?fi|wlan|无线/i.test(n);
  const isVirtual = n => /vmware|virtual|vbox|hyper-v|loopback|bluetooth|docker|vethernet/i.test(n);
  const wifi = list.find(c => isWifi(c.name));
  if (wifi) return wifi.ip;
  const real = list.find(c => !isVirtual(c.name));
  return real ? real.ip : (list[0] ? list[0].ip : '127.0.0.1');
}

const ip = lanIP();
const url = process.argv[2] || `http://${ip}:8000/`;
const file = path.join(__dirname, '二维码.png');

QRCode.toFile(file, url, { width: 640, margin: 2, errorCorrectionLevel: 'M' })
  .then(() => QRCode.toString(url, { type: 'terminal', small: true }))
  .then(t => {
    console.log(t);
    console.log('二维码内容:', url);
    console.log('二维码图片已保存:', file);
  })
  .catch(e => { console.error('生成失败:', e.message); process.exit(1); });
