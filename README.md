# OpenQris Bridge 🇮🇩

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.32+-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Desktop-green.svg)]()
[![Tests](https://img.shields.io/badge/Tests-13%20Passed-brightgreen.svg)]()

> **Open-source Payment Gateway Bridge for Indonesian QRIS & E-Wallets (Flutter for Android & iOS).**  
> Turn your smartphone with any static QRIS (DANA Bisnis, ShopeePay Merchant, BCA, GoPay, Mandiri, BRI) into an automated, zero-fee payment gateway with unique nominal matching and instant webhooks!

---

## 💡 The Problem This Solves

Commercial payment gateways (Midtrans, Xendit, Doku) often require business legalities (PT/CV), KYC verification, charge 0.7% MDR fees, and hold settlements for days.

Meanwhile, UMKM merchants and developers already have **free static QRIS** (from DANA Bisnis, ShopeePay Merchant, or BCA) that settles instantly into their personal account with 0.3% MDR. However, static QRIS has no developer API or webhook to automatically notify websites when a customer pays.

**OpenQris Bridge bridges this gap completely:**
1. **Converts Static QRIS to Dynamic QRIS** on the fly by injecting EMVCo Tag 54 with the exact nominal (e.g. Rp 25.142) and recomputing CRC16.
2. **Assigns Unique Codes** (e.g., Rp 25.000 + 142 = Rp 25.142) so payments are uniquely identifiable.
3. **Intercepts Push Notifications** on your phone (DANA, ShopeePay, GoPay, BCA, Mandiri, BRImo, SeaBank) via native Android `NotificationListenerService` and iOS bridge channels.
4. **Automatically Matches Invoices** and dispatches signed **HMAC-SHA256 Webhooks** to your website or e-commerce backend in real-time.
5. **Runs an Embedded HTTP/WebSocket Server** directly on your phone (`http://phone-ip:8080`) so local POS cashier terminals or servers on your network can query and create invoices directly!

---

## 🚀 Key Features

- **Dynamic QRIS Generator (EMVCo ASPI Standard)**
  - Converts any static QRIS string into dynamic QRIS with pre-filled amounts.
  - Automatic CRC-16/CCITT calculation.
  - Built-in QR viewer with one-tap copy and share.

- **Automated Multi-Provider Notification Parser**
  - **DANA** (`id.dana`)
  - **Shopee / ShopeePay** (`com.shopee.id`, `com.shopee.merchant`)
  - **GoPay / GoBiz** (`com.gojek.app`, `com.gobiz`)
  - **OVO** (`ovo.id`)
  - **BCA Mobile / myBCA / SMS Banking** (`com.bca`)
  - **Livin' by Mandiri** (`id.co.bankmandiri.livin`)
  - **BRImo** (`id.co.bri.brimo`)
  - **SeaBank** (`com.seabank.id`)
  - **Custom Regex Rules**: Add custom patterns for any regional bank or SMS banking!

- **Intelligent Unique Code Allocator**
  - Strategies: Random (+1..999), Sequential (+1, +2...), Discount (-1..-999), None (0).
  - Anti-collision engine: Guarantees no two active pending invoices share the same payable nominal.
  - Auto-expiration timer (default 15 minutes) to release reserved unique codes.

- **Embedded Local REST & WebSocket Server**
  - Runs directly inside the Flutter app on Android, iOS, and Windows.
  - `POST /api/v1/invoices` — Create order & get dynamic QRIS string.
  - `GET /api/v1/invoices/:id` — Poll invoice status.
  - `POST /api/v1/mutations/simulate` — Development test bench.
  - `WS /ws` — Real-time event stream.

- **Secure HMAC-SHA256 Webhook Dispatcher**
  - Sends signed HTTP POST requests to your merchant backend.
  - Automatic retries with exponential backoff on network failures.
  - In-app delivery log viewer with latency and response status.

- **Interactive Test Bench Simulator**
  - Simulate DANA, ShopeePay, or BCA notifications with any amount without spending real money.
  - Instant live feedback verifying regex parsing, matching, and webhook delivery.

---

## 📱 App Screenshots & Navigation

The application consists of 5 core screens:
1. **Beranda (Dashboard)**: Daily revenue, success rate, system status (Listener & Server), and recent transactions.
2. **Kasir (POS)**: Fast point-of-sale cashier keypad with preset amounts (10k, 25k, 50k, 100k) and live payment detection.
3. **Transaksi (Invoices)**: Filterable list of All, Pending, Paid, and Expired invoices.
4. **Simulator**: Developer test bench to simulate incoming wallet notifications.
5. **Mutasi (Log)**: Stream of raw intercepted notifications from financial apps.
6. **Pengaturan (Settings)**: Static QRIS configuration, unique code strategy, webhook URL & secret key, embedded server settings, and provider toggles.

---

## 🛠️ Quick Start

### Prerequisites
- Flutter SDK 3.24+ (Dart 3.5+)
- Android SDK 34+ (for Android APK)

### 1. Clone & Install Dependencies
```bash
git clone https://github.com/your-username/openqris-bridge.git
cd openqris-bridge
flutter pub get
```

### 2. Run the App
```bash
# Run on connected Android / iOS device or Windows desktop
flutter run
```

### 3. Running Unit Tests
```bash
flutter test
```
All 13 unit tests for EMVCo parsing, CRC16 calculation, notification regexes, unique code allocation, and embedded REST server endpoints will execute and pass!

---

## 🔌 API Reference (Embedded Phone Server)

When the embedded server is enabled, your phone exposes HTTP endpoints on `http://<phone-ip>:8080`:

### Create Invoice
```http
POST /api/v1/invoices
Content-Type: application/json

{
  "amount": 25000,
  "reference_id": "ORDER-9921",
  "expiry_minutes": 15
}
```

**Response (`201 Created`):**
```json
{
  "success": true,
  "data": {
    "id": "INV-20261106-A1B2C3",
    "reference_id": "ORDER-9921",
    "base_amount": 25000.0,
    "unique_code": 142,
    "total_amount": 25142.0,
    "formatted_total_amount": "Rp 25.142",
    "qris_raw": "00020101021226610016ID.CO.SHOPEE.WWW...540525142...6304ABCD",
    "status": "PENDING",
    "created_at": "2026-11-06T20:30:00.000Z",
    "expires_at": "2026-11-06T20:45:00.000Z"
  }
}
```

### Check Invoice Status
```http
GET /api/v1/invoices/INV-20261106-A1B2C3
```

---

## 🪝 Webhook Payload & Verification

When a payment is matched, OpenQris Bridge sends an HTTP POST request to your webhook endpoint:

### Headers
```http
Content-Type: application/json
User-Agent: OpenQrisBridge/1.0
X-Event: invoice.paid
X-Timestamp: 2026-11-06T20:35:10.000Z
X-Signature: <64-character hex HMAC-SHA256 signature>
```

### Payload
```json
{
  "event": "invoice.paid",
  "timestamp": "2026-11-06T20:35:10.000Z",
  "invoice": {
    "id": "INV-20261106-A1B2C3",
    "reference_id": "ORDER-9921",
    "base_amount": 25000.0,
    "unique_code": 142,
    "total_amount": 25142.0,
    "status": "PAID",
    "paid_at": "2026-11-06T20:35:10.000Z"
  },
  "mutation": {
    "id": "mut-uuid",
    "provider": "DANA",
    "amount": 25142.0,
    "sender_name": "BUDI SANTOSO",
    "raw_title": "DANA Bisnis",
    "received_at": "2026-11-06T20:35:08.000Z"
  }
}
```

### Verifying Signature in Node.js
```javascript
const crypto = require('crypto');

function verifyWebhook(rawBody, signatureHeader, secretKey) {
  const hmac = crypto.createHmac('sha256', secretKey);
  const calculated = hmac.update(rawBody).digest('hex');
  return calculated.toLowerCase() === signatureHeader.toLowerCase();
}
```

See [examples/merchant_nodejs/](examples/merchant_nodejs/) and [examples/merchant_php/](examples/merchant_php/) for ready-to-use sample backends.

---

## 📖 Documentation

- [System Architecture & Sequence Diagram](docs/ARCHITECTURE.md)
- [EMVCo QRIS Specification & Tag 54 Details](docs/EMVCO_SPEC.md)
- [Panduan Bahasa Indonesia](README.id.md)

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
