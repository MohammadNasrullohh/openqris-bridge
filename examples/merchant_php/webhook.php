<?php
/**
 * Contoh Webhook Receiver PHP untuk OpenQris Bridge
 * Kompatibel dengan WordPress / WooCommerce / Native PHP
 */

// Secret Key harus SAMA dengan yang ada di aplikasi OpenQris Bridge HP
$bridgeSecretKey = getenv('BRIDGE_SECRET') ?: 'secret_qris_bridge_2026';

// Ambil raw input body
$rawPayload = file_get_contents('php://input');
$headers = getallheaders();

// Normalisasi header (case-insensitive)
$signature = $headers['X-Signature'] ?? $headers['x-signature'] ?? null;
$event = $headers['X-Event'] ?? $headers['x-event'] ?? null;
$timestamp = $headers['X-Timestamp'] ?? $headers['x-timestamp'] ?? null;

if (!$signature) {
    http_response_code(401);
    echo json_encode(['error' => 'Missing X-Signature header']);
    exit;
}

// Verifikasi HMAC-SHA256 signature
$expectedSignature = hash_hmac('sha256', $rawPayload, $bridgeSecretKey);

if (!hash_equals(strtolower($expectedSignature), strtolower($signature))) {
    http_response_code(403);
    echo json_encode(['error' => 'Invalid signature']);
    exit;
}

$data = json_decode($rawPayload, true);

if ($event === 'invoice.paid') {
    $invoice = $data['invoice'];
    $orderRef = $invoice['reference_id'];
    $totalAmount = $invoice['total_amount'];
    $mutation = $data['mutation'] ?? null;
    $provider = $mutation ? $mutation['provider'] : 'QRIS';

    // Lakukan update database toko Anda di sini:
    // UPDATE orders SET status = 'PAID', paid_at = NOW(), provider = '$provider' WHERE order_id = '$orderRef';

    error_log("Order $orderRef LUNAS sebesar Rp $totalAmount via $provider!");

    http_response_code(200);
    echo json_encode(['status' => 'success', 'message' => 'Order marked as paid']);
    exit;
}

http_response_code(200);
echo json_encode(['status' => 'ignored']);
