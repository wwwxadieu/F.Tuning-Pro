// ── server.js ── F.Tune Pro License Server (PayOS + SQLite) ───────────────
'use strict';

// ── Load .env nếu có ──
try {
  const fs = require('fs');
  const envPath = require('path').join(__dirname, '.env');
  if (fs.existsSync(envPath)) {
    for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx < 1) continue;
      const key = trimmed.slice(0, eqIdx).trim();
      const val = trimmed.slice(eqIdx + 1).trim();
      if (!process.env[key]) process.env[key] = val;
    }
  }
} catch (_) {}

const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const db = require('./db');

const app = express();
const PORT = parseInt(process.env.PORT || '3000', 10);
const SERVER_URL = process.env.SERVER_URL || `http://localhost:${PORT}`;

// ── PayOS config ──────────────────────────────────────────────────────────
const PAYOS_CLIENT_ID = process.env.PAYOS_CLIENT_ID;
const PAYOS_API_KEY = process.env.PAYOS_API_KEY;
const PAYOS_CHECKSUM_KEY = process.env.PAYOS_CHECKSUM_KEY;
const PAYOS_API_URL = 'https://api-merchant.payos.vn';
const PRICE_AMOUNT = 99000; // 99.000 VNĐ

// ── Resend (email) config ─────────────────────────────────────────────────
const RESEND_API_KEY = process.env.RESEND_API_KEY;
const RESEND_FROM = process.env.RESEND_FROM || 'F.Tune Pro <noreply@ftune.app>';

// ── CORS ──────────────────────────────────────────────────────────────────
app.use(cors());

// ── PayOS Webhook (phải trước express.json!) ──────────────────────────────
app.post(
  '/webhook',
  express.raw({ type: 'application/json' }),
  (req, res) => {
    try {
      const body = JSON.parse(req.body.toString());
      const { code, data, signature } = body;

      if (!data || !signature) {
        return res.status(400).json({ error: 'Missing data or signature' });
      }

      // Verify signature: HMAC_SHA256 of sorted data fields
      const verifyData = sortObjToSignatureStr(data);
      const expectedSig = crypto
        .createHmac('sha256', PAYOS_CHECKSUM_KEY)
        .update(verifyData)
        .digest('hex');

      if (signature !== expectedSig) {
        console.error('[Webhook] Signature mismatch');
        return res.status(400).json({ error: 'Invalid signature' });
      }

      if (code === '00' && data.orderCode) {
        console.log('[Webhook] Payment success, orderCode:', data.orderCode);

        const licenseKey = db.createLicense({
          orderCode: String(data.orderCode),
          email: null,
        });
        console.log('[Webhook] License created:', licenseKey);
      }

      res.json({ received: true });
    } catch (err) {
      console.error('[Webhook] Error:', err.message);
      res.status(400).json({ error: err.message });
    }
  }
);

// ── JSON body parser (cho các route còn lại) ──────────────────────────────
app.use(express.json());

// ── Tạo PayOS Payment Link ───────────────────────────────────────────────
app.post('/create-checkout-session', async (req, res) => {
  try {
    if (!PAYOS_CLIENT_ID || !PAYOS_API_KEY || !PAYOS_CHECKSUM_KEY) {
      return res.status(500).json({ error: 'PayOS chưa cấu hình.' });
    }

    const email = (req.body?.email || '').trim();
    const orderCode = Date.now() % 2147483647; // Int32 unique
    const description = 'FTune Pro';
    const returnUrl = `${SERVER_URL}/payment/success?orderCode=${orderCode}`;
    const cancelUrl = `${SERVER_URL}/payment/cancel`;

    // Lưu pending order + email vào DB
    if (email) {
      db.savePendingOrder({ orderCode: String(orderCode), email });
    }

    // Tạo signature: HMAC_SHA256 of sorted fields
    const signData = `amount=${PRICE_AMOUNT}&cancelUrl=${cancelUrl}&description=${description}&orderCode=${orderCode}&returnUrl=${returnUrl}`;
    const signature = crypto
      .createHmac('sha256', PAYOS_CHECKSUM_KEY)
      .update(signData)
      .digest('hex');

    const payload = {
      orderCode,
      amount: PRICE_AMOUNT,
      description,
      buyerEmail: email || undefined,
      cancelUrl,
      returnUrl,
      signature,
      items: [
        {
          name: 'F.Tune Pro - Lifetime License',
          quantity: 1,
          price: PRICE_AMOUNT,
        },
      ],
    };

    const response = await fetch(`${PAYOS_API_URL}/v2/payment-requests`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-client-id': PAYOS_CLIENT_ID,
        'x-api-key': PAYOS_API_KEY,
      },
      body: JSON.stringify(payload),
    });

    const result = await response.json();

    if (result.code !== '00' || !result.data?.checkoutUrl) {
      console.error('[PayOS] Error:', result);
      return res.status(500).json({
        error: result.desc || 'Không thể tạo link thanh toán.',
      });
    }

    res.json({
      checkoutUrl: result.data.checkoutUrl,
      orderCode: String(orderCode),
    });
  } catch (err) {
    console.error('[Checkout] Error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── Trang thanh toán thành công (redirect từ PayOS) ───────────────────────
app.get('/payment/success', async (req, res) => {
  const orderCode = req.query.orderCode;
  if (!orderCode) {
    return res.status(400).send('Missing orderCode');
  }

  // Chủ động verify payment qua PayOS API
  let license = db.getLicenseByOrderCode(orderCode);
  if (!license) {
    try {
      const payosRes = await fetch(
        `${PAYOS_API_URL}/v2/payment-requests/${orderCode}`,
        {
          headers: {
            'x-client-id': PAYOS_CLIENT_ID,
            'x-api-key': PAYOS_API_KEY,
          },
        }
      );
      const payosData = await payosRes.json();
      if (payosData.code === '00' && payosData.data?.status === 'PAID') {
        const key = db.createLicense({ orderCode: String(orderCode), email: null });
        license = { license_key: key };
        // Gửi email backup license key
        const fullLicense = db.getLicenseByOrderCode(orderCode);
        if (fullLicense?.email) {
          sendLicenseEmail(fullLicense.email, key).catch(() => {});
        }
      }
    } catch (_) {}
  }

  res.send(`<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>F.Tune Pro - Thanh toán thành công</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: 'Segoe UI', system-ui, sans-serif;
    background: #0d1117; color: #e6edf3;
    display: flex; align-items: center; justify-content: center;
    min-height: 100vh; padding: 24px;
  }
  .card {
    background: #161b22; border: 1px solid #30363d;
    border-radius: 16px; padding: 40px; max-width: 480px;
    text-align: center;
  }
  .icon { font-size: 64px; margin-bottom: 16px; }
  h1 { font-size: 24px; margin-bottom: 8px; color: #58a6ff; }
  p { color: #8b949e; line-height: 1.6; margin-bottom: 20px; }
  .key {
    background: #0d1117; border: 1px solid #30363d;
    border-radius: 8px; padding: 14px 20px;
    font-family: 'Cascadia Code', monospace;
    font-size: 18px; letter-spacing: 2px;
    color: #7ee787; word-break: break-all;
    user-select: all;
  }
  .note { font-size: 12px; color: #6e7681; margin-top: 16px; }
</style>
</head><body>
<div class="card">
  <div class="icon">🎉</div>
  <h1>Thanh toán thành công!</h1>
  <p>Cảm ơn bạn đã mua F.Tune Pro.<br>Mã kích hoạt của bạn:</p>
  ${license ? `<div class="key">${license.license_key}</div>` : '<p style="color:#f85149">Đang xử lý... vui lòng chờ vài giây.</p>'}
  <p class="note">App sẽ tự động kích hoạt cho bạn.</p>
</div>
</body></html>`);
});

// ── Trang hủy thanh toán ──────────────────────────────────────────────────
app.get('/payment/cancel', (_req, res) => {
  res.send(`<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<title>F.Tune Pro - Đã hủy</title>
<style>
  body {
    font-family: 'Segoe UI', system-ui, sans-serif;
    background: #0d1117; color: #e6edf3;
    display: flex; align-items: center; justify-content: center;
    min-height: 100vh;
  }
  .card {
    background: #161b22; border: 1px solid #30363d;
    border-radius: 16px; padding: 40px; text-align: center;
  }
  h1 { color: #f85149; }
  p { color: #8b949e; margin-top: 8px; }
</style>
</head><body>
<div class="card">
  <h1>Đã hủy thanh toán</h1>
  <p>Bạn có thể đóng cửa sổ này và thử lại.</p>
</div>
</body></html>`);
});

// ── Lấy license key theo orderCode (app gọi sau khi detect success) ──────
// Chủ động gọi PayOS API để verify payment thay vì chờ webhook
// (webhook không thể gửi đến localhost khi chạy desktop app)
app.get('/license/:orderCode', async (req, res) => {
  const orderCode = req.params.orderCode;

  // 1. Kiểm tra DB trước — nếu đã có license thì trả luôn
  const existing = db.getLicenseByOrderCode(orderCode);
  if (existing) {
    return res.json({ licenseKey: existing.license_key });
  }

  // 2. Gọi PayOS API để kiểm tra trạng thái thanh toán
  try {
    const payosRes = await fetch(
      `${PAYOS_API_URL}/v2/payment-requests/${orderCode}`,
      {
        headers: {
          'x-client-id': PAYOS_CLIENT_ID,
          'x-api-key': PAYOS_API_KEY,
        },
      }
    );
    const payosData = await payosRes.json();

    if (payosData.code !== '00' || !payosData.data) {
      return res.status(404).json({
        error: 'Không tìm thấy đơn hàng trên PayOS.',
      });
    }

    const status = payosData.data.status;

    if (status === 'PAID') {
      // Thanh toán thành công → tạo license key
      const licenseKey = db.createLicense({
        orderCode: String(orderCode),
        email: null,
      });
      console.log('[Verify] Payment PAID, license created:', licenseKey);

      // Gửi email backup license key (fire-and-forget)
      const license = db.getLicenseByOrderCode(orderCode);
      if (license?.email) {
        sendLicenseEmail(license.email, licenseKey).catch(() => {});
      }

      return res.json({ licenseKey });
    }

    if (status === 'PENDING') {
      return res.status(202).json({
        error: 'Đang chờ thanh toán. Thử lại sau.',
        status: 'PENDING',
      });
    }

    // CANCELLED, EXPIRED, etc.
    return res.status(400).json({
      error: `Đơn hàng ${status}. Vui lòng thử lại.`,
      status,
    });
  } catch (err) {
    console.error('[Verify] Error:', err.message);
    return res.status(500).json({ error: 'Lỗi khi xác minh thanh toán.' });
  }
});

// ── Validate license key (app gọi khi user nhập key) ─────────────────────
app.post('/validate', (req, res) => {
  const { licenseKey } = req.body || {};
  if (!licenseKey || typeof licenseKey !== 'string') {
    return res.status(400).json({ valid: false, message: 'Thiếu licenseKey.' });
  }
  const result = db.validateLicense(licenseKey.trim());
  res.json(result);
});

// ── Health check ──────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── Helper: sort object keys → key=value string for signature ─────────────
function sortObjToSignatureStr(obj) {
  return Object.keys(obj)
    .sort()
    .map((k) => `${k}=${obj[k]}`)
    .join('&');
}

// ── Helper: gửi license key qua email (Resend) ───────────────────────────
async function sendLicenseEmail(toEmail, licenseKey) {
  if (!RESEND_API_KEY || !toEmail) return;

  const html = `
<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:#0d1117;color:#e6edf3;font-family:'Segoe UI',system-ui,sans-serif;">
<div style="max-width:520px;margin:40px auto;background:#161b22;border:1px solid #30363d;border-radius:16px;padding:40px;text-align:center;">
  <div style="font-size:48px;margin-bottom:12px;">🎉</div>
  <h1 style="font-size:22px;color:#58a6ff;margin:0 0 8px;">Cảm ơn bạn đã mua F.Tune Pro!</h1>
  <p style="color:#8b949e;line-height:1.6;margin-bottom:24px;">
    Đây là mã kích hoạt của bạn. Hãy lưu lại email này để dùng khi cài lại app.
  </p>
  <div style="background:#0d1117;border:1px solid #30363d;border-radius:8px;padding:16px 24px;font-family:'Cascadia Code',monospace;font-size:20px;letter-spacing:2px;color:#7ee787;word-break:break-all;">
    ${licenseKey}
  </div>
  <p style="font-size:12px;color:#6e7681;margin-top:20px;">
    Để kích hoạt: Mở F.Tune Pro → Settings → Nhập mã → Dán mã trên → Kích hoạt.
  </p>
  <hr style="border:none;border-top:1px solid #30363d;margin:24px 0;">
  <p style="font-size:11px;color:#484f58;">F.Tune Pro — Forza Horizon Tuning Assistant</p>
</div>
</body></html>`;

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: RESEND_FROM,
        to: [toEmail],
        subject: 'F.Tune Pro — Mã kích hoạt của bạn',
        html,
      }),
    });
    const data = await res.json();
    console.log('[Email] Sent license to', toEmail, '→', data.id || data);
  } catch (err) {
    console.error('[Email] Failed to send:', err.message);
  }
}

// ── Start ─────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`[F.Tune License Server] Running on ${SERVER_URL}`);
  console.log(`[PayOS] Client ID: ${PAYOS_CLIENT_ID ? '✓' : '(NOT SET)'}`);
});
