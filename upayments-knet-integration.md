# UPayments — KNET Only Integration Guide
> Stack: Node.js (Express) backend · Flutter frontend  
> Payment method: **KNET (Debit) only**  
> UPayments API version: v2

---

## Table of Contents
1. [How it works — overview](#1-how-it-works--overview)
2. [Dashboard setup](#2-dashboard-setup)
3. [Backend guide — Node.js](#3-backend-guide--nodejs)
4. [Flutter guide](#4-flutter-guide)
5. [Testing with KNET sandbox](#5-testing-with-knet-sandbox)
6. [Error handling reference](#6-error-handling-reference)
7. [Go-live checklist](#7-go-live-checklist)

---

## 1. How it works — overview

```
Flutter App
    │
    │  POST /api/payment/initiate   (sends order details)
    ▼
Node.js Backend
    │
    │  POST https://sandboxapi.upayments.com/api/v1/charge
    │  body: { payment_gateway: "knet", ... }
    ▼
UPayments API
    │
    │  returns { paymentURL }
    ▼
Node.js  ──── paymentURL ────▶  Flutter
                                    │
                                    │  Opens WebView with paymentURL
                                    ▼
                              UPayments KNET Page
                              (user enters debit card)
                                    │
                         ┌──────────┴──────────┐
                    success                  failure
                         │                       │
                  redirect to              redirect to
                  /payment/success         /payment/error
                         │                       │
                    Flutter intercepts URL — pops WebView
                         │
                    POST /api/payment/verify/:orderId
                         │
                    Node.js checks status with UPayments
                         │
                    Returns { status: "CAPTURED" / "DECLINED" }
                         │
                    Flutter shows result screen

PARALLEL (server-to-server):
UPayments  ──POST──▶  Node.js /webhook/upayments
                          │
                      Updates DB (order marked paid)
```

**Rule:** Never trust only the redirect. Always verify server-side AND handle the webhook.

---

## 2. Dashboard Setup

1. Log in to [UPayments Merchant Dashboard](https://merchant.upayments.com)
2. Go to **Settings → API Credentials** and copy:
   - `Merchant ID`
   - `Username`
   - `Password`
   - `API Key`
3. Go to **Settings → Payment Methods** and enable **KNET only** — disable all others (Credit Card, Samsung Pay, Google Pay, Apple Pay). This makes `payment_gateway: "knet"` the only active method.
4. Set these redirect URLs (point them at your Node.js server):
   - **Success URL:** `https://yourdomain.com/payment/success`
   - **Error URL:** `https://yourdomain.com/payment/error`
   - **Notify URL (Webhook):** `https://yourdomain.com/webhook/upayments`
5. Keep **Test Mode ON** until you go live.

---

## 3. Backend Guide — Node.js

### 3.1 Folder structure

```
backend/
├── .env
├── app.js
├── routes/
│   └── payment.js
└── webhooks/
    └── upayments.js
```

### 3.2 Install dependencies

```bash
npm install express axios dotenv
```

### 3.3 Environment variables — `.env`

```env
# UPayments credentials
UPAYMENTS_MERCHANT_ID=your_merchant_id
UPAYMENTS_USERNAME=your_username
UPAYMENTS_PASSWORD=your_password
UPAYMENTS_API_KEY=your_api_key

# Sandbox base URL — swap for production when going live
UPAYMENTS_BASE_URL=https://sandboxapi.upayments.com/api/v1
# Production: https://api.upayments.com/api/v1

# Your server's public URL (used for redirect + notify URLs)
BASE_URL=https://yourdomain.com

NODE_ENV=development
```

> **Never commit `.env` to git.** Add it to `.gitignore`.

### 3.4 Main app — `app.js`

```js
require('dotenv').config();
const express = require('express');
const app = express();

app.use(express.json());

// Payment routes
app.use('/api/payment', require('./routes/payment'));

// Webhook route (separate — UPayments POSTs here)
app.use('/webhook', require('./webhooks/upayments'));

app.listen(3000, () => console.log('Server running on port 3000'));
```

### 3.5 Payment routes — `routes/payment.js`

```js
const express = require('express');
const axios = require('axios');
const router = express.Router();

// Helper: shared UPayments credentials object
const upayCredentials = () => ({
  merchant_id: process.env.UPAYMENTS_MERCHANT_ID,
  username:    process.env.UPAYMENTS_USERNAME,
  password:    process.env.UPAYMENTS_PASSWORD,
  api_key:     process.env.UPAYMENTS_API_KEY,
});

// ─────────────────────────────────────────────
// ROUTE 1: Initiate KNET payment
// Called by Flutter when user taps "Pay"
// POST /api/payment/initiate
// ─────────────────────────────────────────────
router.post('/initiate', async (req, res) => {
  const {
    orderId,          // unique string, min 30 chars recommended
    amount,           // string, e.g. "5.000" (max 3 decimal places)
    customerName,
    customerEmail,
    customerMobile,
    products,         // array: [{ name, price, qty }]
  } = req.body;

  // Basic validation
  if (!orderId || !amount || !customerEmail) {
    return res.status(400).json({ success: false, error: 'Missing required fields' });
  }

  const payload = {
    ...upayCredentials(),

    order_id:        orderId,
    total_price:     amount,
    currency_code:   'KWD',        // KNET is Kuwait-specific (KWD)

    customer_fname:  customerName,
    customer_email:  customerEmail,
    customer_mobile: customerMobile,

    // KNET only — hardcoded
    payment_gateway: 'knet',
    whitelabled:     'false',

    // Redirect URLs (must match what you set in dashboard)
    success_url: `${process.env.BASE_URL}/payment/success`,
    error_url:   `${process.env.BASE_URL}/payment/error`,
    notify_url:  `${process.env.BASE_URL}/webhook/upayments`,

    // 1 = sandbox, 0 = production
    test_mode: process.env.NODE_ENV === 'production' ? '0' : '1',

    // Products
    product_name:  products.map(p => p.name),
    product_price: products.map(p => p.price),
    product_qty:   products.map(p => p.qty),
  };

  try {
    const response = await axios.post(
      `${process.env.UPAYMENTS_BASE_URL}/charge`,
      payload,
      { headers: { 'Content-Type': 'application/json' } }
    );

    const paymentURL = response.data?.data?.link;

    if (!paymentURL) {
      console.error('No payment URL in response:', response.data);
      return res.status(502).json({ success: false, error: 'UPayments did not return a payment URL' });
    }

    // TODO: Save order to your database here
    // await db.orders.create({ orderId, amount, status: 'pending', createdAt: new Date() });

    return res.json({ success: true, paymentURL, orderId });

  } catch (err) {
    console.error('UPayments /charge error:', err.response?.data || err.message);
    return res.status(500).json({ success: false, error: 'Failed to initiate payment' });
  }
});

// ─────────────────────────────────────────────
// ROUTE 2: Verify payment status
// Called by Flutter after WebView redirects
// GET /api/payment/verify/:orderId
// ─────────────────────────────────────────────
router.get('/verify/:orderId', async (req, res) => {
  const { orderId } = req.params;

  try {
    const response = await axios.post(
      `${process.env.UPAYMENTS_BASE_URL}/check-payment-status`,
      {
        ...upayCredentials(),
        order_id: orderId,
      },
      { headers: { 'Content-Type': 'application/json' } }
    );

    const status = response.data?.data?.status; // "CAPTURED", "DECLINED", "PENDING"

    // TODO: Update your DB order status here if CAPTURED
    // if (status === 'CAPTURED') {
    //   await db.orders.update({ status: 'paid' }, { where: { orderId } });
    // }

    return res.json({ success: true, status, raw: response.data });

  } catch (err) {
    console.error('UPayments /check-payment-status error:', err.response?.data || err.message);
    return res.status(500).json({ success: false, error: 'Verification failed' });
  }
});

module.exports = router;
```

### 3.6 Webhook handler — `webhooks/upayments.js`

```js
const express = require('express');
const router = express.Router();

// ─────────────────────────────────────────────
// WEBHOOK: UPayments POSTs here after payment
// POST /webhook/upayments
// This is the authoritative server-to-server confirmation.
// ─────────────────────────────────────────────
router.post('/upayments', async (req, res) => {
  const data = req.body;

  console.log('UPayments webhook received:', JSON.stringify(data, null, 2));

  const orderId      = data?.order_id;
  const result       = data?.result;         // "CAPTURED", "DECLINED"
  const trackId      = data?.trackid;        // KNET tracking ID
  const paymentId    = data?.paymentid;      // KNET payment ID
  const referenceId  = data?.ref;            // KNET reference number

  if (!orderId) {
    return res.sendStatus(400);
  }

  if (result === 'CAPTURED') {
    // TODO: Mark order as paid in your database
    // await db.orders.update(
    //   { status: 'paid', trackId, paymentId, referenceId },
    //   { where: { orderId } }
    // );
    console.log(`✅ Order ${orderId} paid. TrackID: ${trackId}`);
  } else {
    // TODO: Mark order as failed/declined
    // await db.orders.update({ status: 'failed' }, { where: { orderId } });
    console.log(`❌ Order ${orderId} not captured. Result: ${result}`);
  }

  // Always return 200 — if you return anything else,
  // UPayments will retry the webhook multiple times
  return res.sendStatus(200);
});

module.exports = router;
```

### 3.7 Redirect pages (simple)

UPayments redirects the browser to these URLs after payment. You can return JSON or HTML — Flutter will intercept the URL before the page even loads.

```js
// Add to app.js or a separate routes file

app.get('/payment/success', (req, res) => {
  // Flutter intercepts this URL — this page is a fallback only
  res.json({ status: 'success' });
});

app.get('/payment/error', (req, res) => {
  res.json({ status: 'error' });
});
```

### 3.8 Backend API summary

| Method | Endpoint | Called by | Purpose |
|--------|----------|-----------|---------|
| POST | `/api/payment/initiate` | Flutter | Create KNET charge, get paymentURL |
| GET | `/api/payment/verify/:orderId` | Flutter | Check payment status after redirect |
| POST | `/webhook/upayments` | UPayments | Server-to-server payment confirmation |
| GET | `/payment/success` | UPayments redirect | Success landing (Flutter intercepts) |
| GET | `/payment/error` | UPayments redirect | Error landing (Flutter intercepts) |

---

## 4. Flutter Guide

### 4.1 Folder structure

```
lib/
├── services/
│   └── payment_service.dart       # API calls to your Node.js backend
├── screens/
│   └── payment_webview_screen.dart  # WebView that loads KNET page
└── models/
    └── payment_result.dart        # Result model
```

### 4.2 Add dependencies — `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  webview_flutter: ^4.8.0    # WebView to open KNET payment page
  http: ^1.2.0               # HTTP calls to your Node.js backend
  uuid: ^4.3.3               # Generate unique order IDs
```

Run:
```bash
flutter pub get
```

### 4.3 Android setup

In `android/app/src/main/AndroidManifest.xml`, add internet permission inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### 4.4 iOS setup

In `ios/Runner/Info.plist`, add:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### 4.5 Payment result model — `lib/models/payment_result.dart`

```dart
enum PaymentStatus { captured, declined, cancelled, failed }

class PaymentResult {
  final PaymentStatus status;
  final String orderId;
  final String? message;

  const PaymentResult({
    required this.status,
    required this.orderId,
    this.message,
  });

  bool get isSuccess => status == PaymentStatus.captured;
}
```

### 4.6 Payment service — `lib/services/payment_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/payment_result.dart';

class PaymentService {
  // Replace with your actual Node.js backend URL
  static const String _baseUrl = 'https://yourdomain.com/api/payment';

  // ─────────────────────────────────────────
  // Step 1: Initiate — call your backend
  // Returns { paymentURL, orderId }
  // ─────────────────────────────────────────
  static Future<Map<String, dynamic>> initiateKnetPayment({
    required String orderId,
    required String amount,        // e.g. "5.000"
    required String customerName,
    required String customerEmail,
    required String customerMobile,
    required List<Map<String, dynamic>> products,
    // products format: [{ 'name': 'Item', 'price': '5.000', 'qty': '1' }]
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/initiate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'orderId':         orderId,
        'amount':          amount,
        'customerName':    customerName,
        'customerEmail':   customerEmail,
        'customerMobile':  customerMobile,
        'products':        products,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Backend error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Payment initiation failed');
    }

    return data; // { success, paymentURL, orderId }
  }

  // ─────────────────────────────────────────
  // Step 2: Verify — after WebView redirects
  // Returns PaymentStatus
  // ─────────────────────────────────────────
  static Future<PaymentStatus> verifyPayment(String orderId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/verify/$orderId'),
    );

    if (response.statusCode != 200) {
      return PaymentStatus.failed;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String? ?? '';

    switch (status.toUpperCase()) {
      case 'CAPTURED':
        return PaymentStatus.captured;
      case 'DECLINED':
        return PaymentStatus.declined;
      default:
        return PaymentStatus.failed;
    }
  }
}
```

### 4.7 WebView screen — `lib/screens/payment_webview_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/payment_result.dart';
import '../services/payment_service.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String orderId;

  // These must match what your Node.js backend sends to UPayments
  static const String successUrl = 'https://yourdomain.com/payment/success';
  static const String errorUrl   = 'https://yourdomain.com/payment/error';

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.orderId,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _resultHandled = false; // prevent double-pop

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() => _isLoading = true);
          _checkForRedirect(url);   // check on navigation start too
        },
        onPageFinished: (url) {
          setState(() => _isLoading = false);
        },
        onNavigationRequest: (request) {
          _checkForRedirect(request.url);
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          debugPrint('WebView error: ${error.description}');
        },
      ))
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  // Intercept UPayments redirect URLs
  void _checkForRedirect(String url) {
    if (_resultHandled) return;

    if (url.startsWith(PaymentWebViewScreen.successUrl)) {
      _handlePaymentResult(success: true);
    } else if (url.startsWith(PaymentWebViewScreen.errorUrl)) {
      _handlePaymentResult(success: false);
    }
  }

  Future<void> _handlePaymentResult({required bool success}) async {
    if (_resultHandled) return;
    _resultHandled = true;

    PaymentStatus status;

    if (success) {
      // Verify with your backend — don't trust redirect alone
      status = await PaymentService.verifyPayment(widget.orderId);
    } else {
      status = PaymentStatus.declined;
    }

    if (mounted) {
      Navigator.of(context).pop(
        PaymentResult(status: status, orderId: widget.orderId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay with KNET'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel payment',
          onPressed: () {
            if (!_resultHandled) {
              _resultHandled = true;
              Navigator.of(context).pop(
                PaymentResult(
                  status: PaymentStatus.cancelled,
                  orderId: widget.orderId,
                ),
              );
            }
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
```

### 4.8 Triggering payment — example usage in any screen

```dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/payment_service.dart';
import '../screens/payment_webview_screen.dart';
import '../models/payment_result.dart';

// Call this from your checkout button's onPressed
Future<void> handleCheckout(BuildContext context) async {
  // Generate a unique order ID
  // Using UUID is safe — strip dashes for cleaner ID
  final orderId = const Uuid().v4().replaceAll('-', '');

  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // Step 1: Call your backend to initiate payment
    final result = await PaymentService.initiateKnetPayment(
      orderId:        orderId,
      amount:         '5.000',           // KWD, max 3 decimal places
      customerName:   'Ahmed Al-Rashid',
      customerEmail:  'ahmed@example.com',
      customerMobile: '96512345678',
      products: [
        {'name': 'Monthly Plan', 'price': '5.000', 'qty': '1'},
      ],
    );

    // Dismiss loading
    if (context.mounted) Navigator.of(context).pop();

    // Step 2: Open KNET payment page in WebView
    final paymentResult = await Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute(
        builder: (_) => PaymentWebViewScreen(
          paymentUrl: result['paymentURL'] as String,
          orderId:    orderId,
        ),
      ),
    );

    // Step 3: Handle result
    if (paymentResult == null) return; // user dismissed somehow

    if (paymentResult.isSuccess) {
      // Navigate to success screen or show success dialog
      _showResult(context, success: true, orderId: orderId);
    } else if (paymentResult.status == PaymentStatus.cancelled) {
      // User closed the WebView
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment cancelled')),
      );
    } else {
      // DECLINED or FAILED
      _showResult(context, success: false, orderId: orderId);
    }

  } catch (e) {
    // Dismiss loading if still showing
    if (context.mounted) Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}

void _showResult(BuildContext context, {required bool success, required String orderId}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(success ? '✅ Payment Successful' : '❌ Payment Failed'),
      content: Text(
        success
          ? 'Your order has been placed.\nOrder ID: $orderId'
          : 'Your payment was not completed.\nPlease try again.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

---

## 5. Testing with KNET Sandbox

### Sandbox credentials (for your Node.js .env)
```
UPAYMENTS_USERNAME=test
UPAYMENTS_PASSWORD=test
UPAYMENTS_API_KEY=jtest123
UPAYMENTS_BASE_URL=https://sandboxapi.upayments.com/api/v1
```

Set `test_mode: '1'` in your backend payload (the code above already does this when `NODE_ENV !== 'production'`).

### KNET test card details
When the KNET sandbox page opens in your Flutter WebView, use these:

| Field | Value |
|-------|-------|
| Card Number | `0000000001` |
| PIN | `1234` |
| Result to simulate | Choose from the test portal UI |

The KNET sandbox portal lets you choose to simulate a success or failure — use both to test your redirect handling.

### Testing webhooks locally
UPayments cannot reach `localhost`. Use **ngrok** to expose your local backend:

```bash
# Install ngrok, then:
ngrok http 3000
```

Copy the HTTPS URL ngrok gives you (e.g. `https://abc123.ngrok.io`) and set:
- `BASE_URL=https://abc123.ngrok.io` in your `.env`
- Update `UPAYMENTS_BASE_URL` redirect URLs accordingly in the dashboard

Now UPayments can POST to your local `/webhook/upayments`.

### Manual test sequence
1. Flutter calls `POST /api/payment/initiate` → get back `paymentURL`
2. WebView opens — use KNET test card
3. Choose "Success" in KNET sandbox portal
4. WebView intercepts redirect to `/payment/success`
5. Flutter calls `GET /api/payment/verify/:orderId` → expect `{ status: "CAPTURED" }`
6. Check your Node.js terminal — webhook POST should arrive at `/webhook/upayments`
7. Repeat steps 1–6 but choose "Failure" in KNET portal — expect `DECLINED`

---

## 6. Error Handling Reference

### UPayments API errors (backend)

| HTTP Status | Meaning | Fix |
|-------------|---------|-----|
| 401 | Wrong credentials | Check merchant ID, username, password, API key |
| 422 | Invalid payload | Check `order_id` uniqueness, `total_price` format (3 decimal), `currency_code` |
| 200 but no `link` | Missing payment URL | Check `payment_gateway: 'knet'` is set; enable KNET in dashboard |
| 500 | UPayments server error | Retry with exponential backoff |

### Webhook result values

| `result` value | Meaning |
|---------------|---------|
| `CAPTURED` | Payment successful — mark order as paid |
| `DECLINED` | Card declined — notify user |
| `ABANDONED` | User closed KNET page — order stays pending |
| `ERROR` | Technical error on KNET side |

### Flutter WebView edge cases

| Scenario | How to handle |
|----------|--------------|
| User presses back/close | Pop with `PaymentStatus.cancelled` |
| No internet | Show error before opening WebView |
| WebView load fails | `onWebResourceError` callback — show retry |
| Redirect URL intercepted twice | `_resultHandled` flag prevents double-pop |

---

## 7. Go-Live Checklist

### Backend
- [ ] Change `UPAYMENTS_BASE_URL` to `https://api.upayments.com/api/v1`
- [ ] Set `NODE_ENV=production` (sets `test_mode: '0'` automatically)
- [ ] Replace sandbox credentials with live merchant credentials
- [ ] Set `BASE_URL` to your production domain (HTTPS required)
- [ ] Update success/error/notify URLs in UPayments dashboard to production URLs
- [ ] Add your DB update logic in `/initiate` (save pending order) and `/webhook` (mark paid)
- [ ] Add request authentication to `/api/payment/initiate` (JWT or API key from Flutter)
- [ ] Set up logging and alerting on webhook failures

### Flutter
- [ ] Change `_baseUrl` in `PaymentService` to your production backend URL
- [ ] Change `successUrl` and `errorUrl` constants in `PaymentWebViewScreen` to production URLs
- [ ] Test on a real Android and iOS device (not just simulator)
- [ ] Test with a real KNET debit card on production before launch

### UPayments Dashboard
- [ ] Disable test mode
- [ ] Verify only KNET is enabled
- [ ] Confirm notify URL is your production webhook endpoint

---

## Quick Reference — KNET-specific values

```
payment_gateway : "knet"
currency_code   : "KWD"      ← KNET is Kuwait-specific
test_mode       : "1"        ← sandbox | "0" for production
whitelabled     : "false"    ← keep false unless UPayments enables it for you
```

The `payment_gateway: "knet"` field in the payload is what locks the checkout to KNET only — the user will not see any other payment option.

---

## Project Implementation Status (FMB Kuwait API)

The backend now includes a Flutter-ready UPayments test flow.

### Implemented endpoints

- `POST /api/v1/payments/upayments/initiate` (auth required)
  - Creates a pending local order and calls UPayments `/charge`.
  - Returns `orderId` + `paymentUrl` for Flutter WebView launch.
- `GET /api/v1/payments/upayments/verify/:orderId` (auth required)
  - Calls UPayments `/check-payment-status`.
  - Updates local order status (`CAPTURED`, `DECLINED`, etc).
- `GET /api/v1/payments/upayments/orders/:orderId` (auth required)
  - Returns current local order status/details.
- `POST /webhook/upayments` (public webhook)
  - Accepts UPayments server callback and updates local order status.
- `GET /api/v1/payments/upayments/callback/success`
- `GET /api/v1/payments/upayments/callback/error`

### Implemented persistence

Prisma model/table: `upayment_orders`

- Stores `order_id`, `user_id`, amount, status, payment URL
- Stores provider IDs (`track_id`, `payment_id`, `reference_id`)
- Stores raw initiate/verify/webhook payload snapshots for debugging

### Environment keys used in this project

- `UPAYMENTS_BASE_URL` (sandbox default: `https://sandboxapi.upayments.com/api/v1`)
- `UPAYMENTS_BEARER_TOKEN`
- `UPAYMENTS_TEST_MODE` (`1` test, `0` production)
- `UPAYMENTS_PAYMENT_GATEWAY` (`knet`)
- `UPAYMENTS_WHITELABLED` (`false` unless enabled for your merchant)
- `PUBLIC_API_BASE_URL` (used to derive success/error/notify URLs)
- Optional overrides:
  - `UPAYMENTS_SUCCESS_URL`
  - `UPAYMENTS_ERROR_URL`
  - `UPAYMENTS_NOTIFY_URL`

### Current test key setup

- Non-whitelabeled test bearer token can be set as:
  - `UPAYMENTS_BEARER_TOKEN=jtest123`

When you get production credentials, replace only env values (no route changes needed).
