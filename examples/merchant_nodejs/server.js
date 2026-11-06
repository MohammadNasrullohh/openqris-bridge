/**
 * Contoh Merchant Backend (Node.js & Express)
 * Terhubung ke OpenQris Bridge yang berjalan di HP Android/iOS Anda.
 */

const express = require('express');
const crypto = require('crypto');

const app = express();
const PORT = 3000;

// Secret Key harus SAMA dengan yang diatur di aplikasi OpenQris Bridge
const BRIDGE_SECRET_KEY = process.env.BRIDGE_SECRET || 'secret_qris_bridge_2026';
const PHONE_BRIDGE_URL = process.env.BRIDGE_URL || 'http://192.168.1.50:8080';

// Perlu raw body untuk verifikasi HMAC signature yang presisi
app.use(express.json({
  verify: (req, res, buf) => {
    req.rawBody = buf.toString('utf8');
  }
}));

// Mock database order toko
const ordersDb = new Map();

/**
 * 1. Endpoint Buat Order Baru (contoh 25k)
 * Frontend toko panggil ini saat checkout.
 */
app.post('/api/checkout', async (req, res) => {
  try {
    const orderId = `ORDER-${Date.now()}`;
    const baseAmount = req.body.amount || 25000;

    // Panggil HP Android yang menjalankan OpenQris Bridge
    const bridgeResponse = await fetch(`${PHONE_BRIDGE_URL}/api/v1/invoices`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount: baseAmount,
        reference_id: orderId,
        expiry_minutes: 15,
        metadata: { customer_name: req.body.customer_name || 'Budi' }
      })
    });

    const bridgeData = await bridgeResponse.json();

    if (!bridgeData.success) {
      return res.status(500).json({ success: false, error: bridgeData.error });
    }

    const invoice = bridgeData.data;

    // Simpan order di database toko dengan status PENDING
    ordersDb.set(orderId, {
      orderId,
      invoiceId: invoice.id,
      baseAmount: invoice.base_amount,
      uniqueCode: invoice.unique_code,
      totalAmount: invoice.total_amount,
      status: 'PENDING',
      qrisString: invoice.qris_raw,
      createdAt: new Date()
    });

    console.log(`[Order Created] ${orderId}: Base Rp ${baseAmount} + Kode Unik ${invoice.unique_code} = Total Rp ${invoice.total_amount}`);

    // Kembalikan data QRIS dinamis ke frontend
    return res.status(201).json({
      success: true,
      order_id: orderId,
      invoice_id: invoice.id,
      base_amount: invoice.base_amount,
      unique_code: invoice.unique_code,
      total_amount: invoice.total_amount,
      qris_string: invoice.qris_raw,
      expires_at: invoice.expires_at
    });
  } catch (err) {
    console.error('Gagal menghubungi OpenQris Bridge di HP:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * 2. Webhook Listener dari OpenQris Bridge
 * Dipanggil otomatis oleh HP ketika ada notifikasi DANA/Shopee/BCA masuk!
 */
app.post('/api/webhook/qris', (req, res) => {
  const signature = req.headers['x-signature'];
  const event = req.headers['x-event'];
  const timestamp = req.headers['x-timestamp'];

  if (!signature) {
    return res.status(401).json({ error: 'Missing X-Signature header' });
  }

  // Verifikasi HMAC-SHA256
  const hmac = crypto.createHmac('sha256', BRIDGE_SECRET_KEY);
  const calculatedSignature = hmac.update(req.rawBody).digest('hex');

  if (calculatedSignature.toLowerCase() !== signature.toLowerCase()) {
    console.warn('[Webhook] Signature tidak valid! Ditolak.');
    return res.status(403).json({ error: 'Invalid HMAC signature' });
  }

  const payload = req.body;
  console.log(`[Webhook Diterima] Event: ${event} pada ${timestamp}`);

  if (event === 'invoice.paid') {
    const inv = payload.invoice;
    const refId = inv.reference_id;
    const mutation = payload.mutation;

    console.log(`✅ [LUNAS] Order ${refId} (${inv.id}) lunas sebesar Rp ${inv.total_amount}`);
    if (mutation) {
      console.log(`   Diterima via: ${mutation.provider} dari ${mutation.sender_name || 'Customer'}`);
    }

    // Update status order di DB toko menjadi PAID
    if (ordersDb.has(refId)) {
      const order = ordersDb.get(refId);
      order.status = 'PAID';
      order.paidAt = new Date();
      order.provider = mutation ? mutation.provider : 'QRIS';
    }

    // Respon HTTP 200 OK ke OpenQris Bridge
    return res.json({ status: 'ok', message: 'Invoice confirmed' });
  }

  return res.json({ status: 'ignored' });
});

/**
 * 3. Cek Status Order (Polling frontend)
 */
app.get('/api/orders/:orderId', (req, res) => {
  const order = ordersDb.get(req.params.orderId);
  if (!order) return res.status(404).json({ error: 'Order not found' });
  return res.json({ success: true, order });
});

app.listen(PORT, () => {
  console.log(`=======================================================`);
  console.log(`  Contoh Merchant Store aktif di http://localhost:${PORT}`);
  console.log(`  Bridge HP Target : ${PHONE_BRIDGE_URL}`);
  console.log(`  Webhook Endpoint : http://localhost:${PORT}/api/webhook/qris`);
  console.log(`=======================================================`);
});
