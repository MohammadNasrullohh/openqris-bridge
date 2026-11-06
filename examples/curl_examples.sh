#!/usr/bin/env bash
# ==============================================================================
# OpenQris Bridge - Quick Curl Testing Examples
# Ganti IP sesuai alamat IP HP Android / iOS Anda pada jaringan WiFi yang sama
# ==============================================================================

BRIDGE_IP="192.168.1.50:8080"

echo "=== 1. Health Check ==="
curl -s "http://${BRIDGE_IP}/health" | jq .

echo -e "\n=== 2. Buat Transaksi Baru Rp 25.000 ==="
curl -s -X POST "http://${BRIDGE_IP}/api/v1/invoices" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 25000,
    "reference_id": "ORDER-DEMO-25K",
    "expiry_minutes": 15
  }' | jq .

echo -e "\n=== 3. Cek Daftar Invoice Aktif ==="
curl -s "http://${BRIDGE_IP}/api/v1/invoices?status=PENDING" | jq .

echo -e "\n=== 4. Simulasikan Notifikasi DANA Masuk (Rp 25.142) ==="
curl -s -X POST "http://${BRIDGE_IP}/api/v1/mutations/simulate" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 25142,
    "provider": "DANA",
    "sender_name": "BUDI SANTOSO",
    "title": "DANA Bisnis",
    "message": "Berhasil menerima saldo sebesar Rp 25.142 dari BUDI SANTOSO"
  }' | jq .

echo -e "\n=== 5. Cek Riwayat Mutasi ==="
curl -s "http://${BRIDGE_IP}/api/v1/mutations" | jq .
