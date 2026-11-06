# EMVCo QRIS Specification & Dynamic Conversion

OpenQris Bridge adheres to the Bank Indonesia (BI) and Asosiasi Sistem Pembayaran Indonesia (ASPI) QRIS specifications, based on the international EMVCo QR Code standard.

## EMVCo Tag-Length-Value (TLV) Structure

Every field in a QRIS code is encoded as:
- **Tag ID**: 2 numeric digits (`00` - `99`)
- **Length**: 2 numeric digits (`01` - `99`)
- **Value**: String of length specified by Length

| Tag | Name | Description | Example |
|---|---|---|---|
| `00` | Payload Format Indicator | Always `01` | `000201` |
| `01` | Point of Initiation Method | `11` = Static, `12` = Dynamic | `010212` |
| `26`-`51` | Merchant Account Info | Provider specific (Dana, Shopee, BCA, GoPay) | `26610016ID.CO.SHOPEE.WWW...` |
| `52` | Merchant Category Code (MCC) | 4-digit ISO 18245 code | `52045411` |
| `53` | Transaction Currency | Indonesian Rupiah (`360`) | `5303360` |
| `54` | Transaction Amount | Nominal amount (injected dynamically) | `540525142` |
| `58` | Country Code | Country (`ID`) | `5802ID` |
| `59` | Merchant Name | Name printed on merchant QR | `5914WARUNG DJ TEST` |
| `60` | Merchant City | City location | `6007JAKARTA` |
| `61` | Postal Code | Postal code | `610512345` |
| `62` | Additional Data Template | Bill Number / Invoice ID | `62120108INV-1001` |
| `63` | CRC16-CCITT | 4-character Hexadecimal CRC checksum | `6304ABCD` |

## Static to Dynamic Conversion Algorithm

1. Parse the merchant's static QRIS code into individual TLV tags.
2. Update **Tag 01** value from `11` (Static) to `12` (Dynamic).
3. Insert or update **Tag 54** with the exact total nominal (e.g. `25142`).
4. Inject the invoice identifier into **Tag 62** (Sub-tag `01` Bill Number).
5. Strip the existing **Tag 63** (CRC).
6. Reassemble all TLV tags in ascending numerical order.
7. Append `6304` to the string buffer.
8. Compute the 16-bit CRC checksum using `CRC-16/CCITT-FALSE` (Polynomial `0x1021`, Initial `0xFFFF`).
9. Append the resulting 4-character uppercase Hex string to form the final dynamic QRIS code.

When scanned by banking and e-wallet apps, the dynamic QRIS automatically populates the exact payment amount in the customer's payment screen without requiring manual amount input!
