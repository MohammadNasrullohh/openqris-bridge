# OpenQris Bridge 🇮🇩 (Panduan Bahasa Indonesia)

> **Solusi Payment Gateway Open Source berbasis Flutter (Android & iOS) untuk QRIS Statis & E-Wallet Indonesia.**  
> Ubah HP Android atau iOS Anda menjadi jembatan payment gateway otomatis tanpa biaya MDR bulanan atau legalitas PT/CV. Cukup gunakan QRIS Statis yang sudah Anda miliki (DANA Bisnis, ShopeePay Merchant, BCA, GoPay, Mandiri, BRI)!

---

## 💡 Latar Belakang & Solusi

Untuk menerima pembayaran otomatis di website/aplikasi di Indonesia, biasanya kita harus mendaftar ke payment gateway komersial (seperti Midtrans, Xendit, Doku). Namun, pendaftarannya memerlukan syarat legalitas usaha (PT/CV), verifikasi berkas, potongan biaya admin per transaksi, dan penahanan dana (hold settlement).

Di sisi lain, hampir setiap pemilik usaha/developer sudah memiliki **QRIS Statis** dari:
- **DANA Bisnis**
- **ShopeePay Merchant**
- **GoPay / GoBiz**
- **BCA Merchant / myBCA**
- **Livin' Mandiri / BRImo**

Uang dari QRIS statis ini langsung masuk ke rekening pribadi/e-wallet Anda seketika. Sayangnya, QRIS statis tidak punya API atau Webhook otomatis untuk memberitahu server toko saat pembeli telah mentransfer.

**OpenQris Bridge menyelesaikan masalah ini dengan mekanisme:**
1. **Konversi QRIS Statis ke Dinamis**: Mengubah string QRIS statis Anda menjadi QRIS dinamis ber-nominal otomatis (injeksi Tag 54 nominal transaksi dan rekalkulasi CRC16).
2. **Kode Unik Otomatis**: Jika ada transaksi Rp 25.000, sistem memberikan kode unik (misal +142 sehingga total menjadi Rp 25.142) dengan batas kadaluarsa 15 menit.
3. **Penyadap Notifikasi (Notification Listener)**: HP Android Anda yang terpasang aplikasi ini akan menangkap notifikasi pop-up pembayaran masuk dari DANA/Shopee/BCA/GoPay.
4. **Pencocokan Nominal & Webhook**: Aplikasi membaca pesan *"Berhasil menerima saldo sebesar Rp 25.142 dari BUDI"*, mencocokkan nominal dengan invoice yang pending, menandai invoice sebagai **LUNAS**, dan langsung mengirimkan **Webhook bertanda tangan HMAC-SHA256** ke website toko Anda!
5. **Embedded Server Lokal**: Aplikasi Flutter ini juga menjalankan server HTTP & WebSocket internal di HP Anda (`http://ip-hp:8080`), sehingga komputer kasir (POS), bot Telegram, atau website lokal dapat langsung membuat invoice dan memantau status secara realtime.

---

## 🚀 Fitur Utama

- **Generator QRIS Dinamis Otomatis (Standar ASPI / Bank Indonesia)**
  - Masukkan string QRIS statis toko Anda sekali saja di Pengaturan.
  - Setiap ada transaksi (misal Rp 25.000), sistem otomatis menyuntikkan nominal ke QRIS sehingga pembeli saat scan **tidak perlu mengetikkan nominal manual lagi**!
- **Parser Notifikasi E-Wallet & Bank Lengkap**
  - DANA (`id.dana`)
  - ShopeePay / Shopee Merchant (`com.shopee.id`)
  - GoPay / GoBiz (`com.gojek.app`)
  - OVO (`ovo.id`)
  - BCA Mobile / myBCA / SMS Banking (`com.bca`)
  - Livin' by Mandiri (`id.co.bankmandiri.livin`)
  - BRImo (`id.co.bri.brimo`)
  - SeaBank (`com.seabank.id`)
  - Aturan Kustom Regex: Tambahkan pola regex sendiri untuk bank daerah atau SMS banking.
- **Alokasi Kode Unik Anti-Tabrakan (Collision-Free)**
  - Pilihan strategi: Acak (+1 s/d 999), Berurutan (+1, +2...), Diskon (-1 s/d -999), atau Tanpa Kode Unik.
  - Mencegah dua transaksi pending memiliki nominal rupiah yang sama.
- **Kasir QRIS Cepat (POS Mode)**
  - Tombol cepat Rp 10k, 25k, 50k, 100k, 250k.
  - Tampilan QRIS besar untuk ditunjukkan langsung ke pelanggan di kasir dengan deteksi pembayaran otomatis secara live.
- **Simulator Pengujian Bawaan**
  - Uji alur notifikasi DANA, ShopeePay, BCA tanpa perlu transfer uang sungguhan!
- **Keamanan Webhook HMAC-SHA256**
  - Setiap webhook yang dikirim dari HP ke server toko Anda ditandatangani menggunakan Secret Key rahasia untuk mencegah pemalsuan pembayaran.

---

## 🛠️ Cara Menjalankan

### Persyaratan
- Flutter SDK 3.24+
- Android Studio / Android SDK 34+
- HP Android (versi Android 8.0 Oreo ke atas direkomendasikan)

### Langkah Pemasangan
```bash
git clone https://github.com/your-username/openqris-bridge.git
cd openqris-bridge
flutter pub get
flutter run
```

### Konfigurasi Awal di Aplikasi
1. Buka tab **Pengaturan**.
2. Tempel string QRIS statis toko Anda (dapat diambil dengan men-scan gambar QRIS Anda menggunakan aplikasi pembaca QR biasa).
3. Masukkan URL Webhook website Anda (misal `https://tokosaya.com/api/webhook/qris`).
4. Buat Secret Key rahasia (misal `kunci_rahasia_toko_123`).
5. Pada HP Android, izinkan **Akses Notifikasi** saat diminta agar aplikasi bisa membaca notifikasi transfer e-wallet yang masuk.

---

## 💻 Contoh Integrasi Backend Toko

### 1. Node.js / Express
Lihat folder [examples/merchant_nodejs/](examples/merchant_nodejs/):
```javascript
// Buat tagihan Rp 25.000 ke HP
const res = await fetch('http://192.168.1.50:8080/api/v1/invoices', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ amount: 25000, reference_id: 'ORDER-123' })
});
const data = await res.json();
console.log('Total yang harus dibayar:', data.data.total_amount); // Contoh: 25142
```

### 2. PHP / WooCommerce
Lihat file [examples/merchant_php/webhook.php](examples/merchant_php/webhook.php) untuk contoh verifikasi signature HMAC-SHA256 di server PHP.

---

## 🧪 Pengujian Unit Test

Proyek ini dilengkapi dengan 13 unit test lengkap yang mencakup:
- Validasi EMVCo TLV & kalkulasi checksum CRC-16/CCITT.
- Injeksi Tag 54 nominal transaksi.
- Regex parser untuk DANA, Shopee, BCA, GoPay, OVO, Mandiri, BRI, SeaBank.
- Alokasi kode unik dan pencocokan mutasi.
- Endpoint REST API server internal.

Jalankan test dengan perintah:
```bash
flutter test
```

---

## 📄 Lisensi

Proyek ini dilisensikan di bawah lisensi terbuka [MIT License](LICENSE). Bebas digunakan, dimodifikasi, dan didistribusikan untuk keperluan personal maupun komersial.
