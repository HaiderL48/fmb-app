# Flutter HTTP API Integration Guide

This guide shows how to call all available APIs from your Flutter app using the `http` package.

Base URL (examples):

- Local API: `http://localhost:4000/api/v1`
- Live API: `https://api.tmkfmb.com/api/v1`

Health checks:

- `GET /health`
- `GET /api/v1/health`

## 1) Add dependencies

In `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.2.1
```

Then run:

```bash
flutter pub get
```

## 2) Create reusable API client

Create `lib/core/api_client.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;

  ApiException(this.statusCode, this.message, {this.body});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.accessToken,
  }) : _client = client ?? http.Client();

  final String baseUrl; // Example: http://localhost:3000/api/v1
  final http.Client _client;
  String? accessToken;

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (accessToken != null && accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async {
    final res = await _client.get(_uri(path, query), headers: _headers(json: false));
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    final res = await _client.post(
      _uri(path),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> patch(String path, {Object? body}) async {
    final res = await _client.patch(
      _uri(path),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<void> delete(String path) async {
    final res = await _client.delete(_uri(path), headers: _headers(json: false));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _buildException(res);
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required List<File> files,
    String fileField = 'attachments',
  }) async {
    final req = http.MultipartRequest('POST', _uri(path));
    req.headers.addAll(_headers(json: false));
    req.fields.addAll(fields);
    for (final f in files) {
      req.files.add(await http.MultipartFile.fromPath(fileField, f.path));
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final hasBody = res.body.trim().isNotEmpty;
    final data = hasBody ? jsonDecode(res.body) as Map<String, dynamic> : <String, dynamic>{};
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        res.statusCode,
        (data['error']?['message'] ?? 'Request failed').toString(),
        body: data,
      );
    }
    return data;
  }

  ApiException _buildException(http.Response res) {
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return ApiException(
        res.statusCode,
        (data['error']?['message'] ?? 'Request failed').toString(),
        body: data,
      );
    } catch (_) {
      return ApiException(res.statusCode, 'Request failed');
    }
  }

  void close() => _client.close();
}
```

## 3) Login and token handling

Login endpoint:

- `POST /auth/login`

Request body:

```json
{
  "itsNumber": "12345678",
  "password": "your_password",
  "client": "mobile",
  "fcmToken": "fcm_device_token_here",
  "platform": "android",
  "appVersion": "1.0.0+12"
}
```

`client` values:

- `mobile` (for Flutter app)
- `admin_web` (admin portal only)

Example method:

```dart
Future<void> login(
  ApiClient api,
  String itsNumber,
  String password, {
  String? fcmToken,
  String? platform, // android | ios | web
  String? appVersion,
}) async {
  final res = await api.post('/auth/login', body: {
    'itsNumber': itsNumber,
    'password': password,
    'client': 'mobile',
    if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
    if (platform != null && platform.isNotEmpty) 'platform': platform,
    if (appVersion != null && appVersion.isNotEmpty) 'appVersion': appVersion,
  });

  final token = res['accessToken'] as String;
  api.accessToken = token;
}
```

## 4) Common response shapes

Most successful responses:

- `{ "data": ... }`
- `{ "meta": ..., "data": ... }`
- for some actions: `{ "ok": true }`

Error response:

```json
{
  "error": {
    "code": "SOME_CODE",
    "message": "Human readable message"
  }
}
```

## 5) Endpoint list with Flutter usage

All routes below are under `/api/v1`.

### A) Auth

- `POST /auth/login`

### B) Users

- `GET /users?page=1&limit=20`
- `POST /users`
- `POST /users/import`
- `GET /users/:id`
- `PATCH /users/:id`

Examples:

```dart
final users = await api.get('/users', query: {'page': '1', 'limit': '20'});

await api.post('/users', body: {
  'userType': 'APP_USER',
  'itsNumber': '12345678',
  'email': 'user@example.com',
  'password': 'strongPass123',
  'fullName': 'Demo User'
});

await api.patch('/users/<id>', body: {
  'fullName': 'Updated Name',
  'isActive': true
});
```

### C) Takhmin

- `GET /takhmin/me?misriYear=1447`
- `GET /takhmin/me/history`
- `GET /takhmin/app-users?misriYear=1447&page=1&limit=50`
- `GET /takhmin/app-users/:userId/history`
- `PATCH /takhmin/app-users/:id`
- `PATCH /takhmin/app-users/:id/completion`

Examples:

```dart
final myTakhmin = await api.get('/takhmin/me', query: {'misriYear': '1447'});
final myHistory = await api.get('/takhmin/me/history');

await api.patch('/takhmin/app-users/<id>', body: {
  'takhminAmountKd': 150.0,
  'misriYear': 1447
});

await api.patch('/takhmin/app-users/<id>/completion', body: {
  'misriYear': 1447,
  'completed': true
});
```

### D) Payments

- `GET /payments/eligible-users?misriYear=1447`
- `GET /payments/summary?misriYear=1447`
- `GET /payments/receipts?page=1&limit=50&misriYear=1447`
- `POST /payments/receipts`
- `POST /payments/upayments/initiate`
- `GET /payments/upayments/verify/:orderId`
- `GET /payments/upayments/orders/:orderId`

Example:

```dart
final summary = await api.get('/payments/summary', query: {'misriYear': '1447'});

await api.post('/payments/receipts', body: {
  'userId': '<user-uuid>',
  'misriYear': 1447,
  'amountKd': 25.0,
  'notes': 'Cash collected'
});

// UPayments KNET flow (mobile):
final init = await api.post('/payments/upayments/initiate', body: {
  'amountKd': 5.000,
  'productName': 'Subscription payment',
});
final orderId = init['data']['orderId'] as String;
final paymentUrl = init['data']['paymentUrl'] as String;
// Open paymentUrl in Flutter WebView, then verify:
final verify = await api.get('/payments/upayments/verify/$orderId');
final status = verify['data']['status']; // CAPTURED | DECLINED | PENDING | ...
```

### E) Packages

- `GET /packages?activeOnly=true`
- `GET /packages/:id`
- `POST /packages`
- `PATCH /packages/:id`
- `DELETE /packages/:id`

Example:

```dart
await api.post('/packages', body: {
  'title': 'Standard Plan',
  'tier': 'STANDARD',
  'priceKd': 10.0,
  'features': ['Feature A', 'Feature B'],
  'installmentsKd': [5.0, 5.0],
  'isActive': true
});
```

### F) Zabihat

- `GET /zabihat?enabledOnly=true`
- `GET /zabihat/:id`
- `POST /zabihat`
- `PATCH /zabihat/:id`
- `DELETE /zabihat/:id`

Example:

```dart
await api.post('/zabihat', body: {
  'title': 'Sheep Qurbani',
  'priceKd': 75.0,
  'capacity': 100,
  'unitsSold': 0,
  'isEnabled': true
});
```

### G) Menus

- `GET /menus?from=2026-01-01&to=2026-01-31`
- `GET /menus/:id`
- `POST /menus`
- `PATCH /menus/:id`
- `DELETE /menus/:id`

Example:

```dart
await api.post('/menus', body: {
  'menuDate': '2026-04-26',
  'title': 'Lunch Menu',
  'items': ['Rice', 'Dal', 'Salad'],
  'notes': 'Mild spice',
  'isPublished': true
});
```

### H) Notifications

- `GET /notifications?limit=20&offset=0`
- `GET /notifications/files/:storedName` (public file access URL)
- `POST /notifications` (multipart/form-data with attachments)
- `POST /notifications/test-push` (admin-only, single ITS test)
- `POST /notifications/push-topic` (admin-only, topic broadcast; default `all_users`)
- `POST /notifications/push-selected` (admin-only, selected ITS list)

Create notification with attachments:

```dart
final files = <File>[
  File('/path/to/file1.pdf'),
  File('/path/to/image1.jpg'),
];

await api.postMultipart(
  '/notifications',
  fields: {
    'title': 'Important Update',
    'body': 'Please read the attached circular.',
    'audienceMode': 'ALL', // or SELECTED
    // for SELECTED, send comma-separated ITS values:
    // 'selectedItsNumbers': '12345678,87654321',
  },
  files: files,
);
```

Broadcast to all users topic:

```dart
await api.post('/notifications/push-topic', body: {
  'topic': 'all_users', // optional, defaults to all_users
  'title': 'New Menu Available',
  'body': 'Today menu is now live.',
  'data': {
    'type': 'menu_new',
    'screen': 'menu',
  },
  'dryRun': false,
});
```

Send to selected ITS numbers:

```dart
await api.post('/notifications/push-selected', body: {
  'itsNumbers': ['50435536', '40405506'],
  'title': 'Takhmin Reminder',
  'body': 'Please complete your Takhmin for this year.',
  'data': {
    'type': 'takhmin_reminder',
    'screen': 'takhmin',
  },
  'dryRun': false,
});
```

Attachment limits:

- max `5` files
- max `10 MB` per file
- field name must be `attachments`

### I) Password update (currently available)

There is no separate `/change-password` route in the current backend.

Current available way:

- `PATCH /users/:id` with `password` field (requires authenticated API session)

Example:

```dart
await api.patch('/users/<user-id>', body: {
  'password': 'newStrongPassword123',
});
```

> Note: this is a user update endpoint, not a dedicated "current password + new password" self-service endpoint.

### J) Feedback API

Feedback is DB-backed (`menu_feedback` table) and supports:

- submit from mobile/admin session
- paginated list with filters
- aggregated summary
- admin review status update

Routes:

- `POST /feedback` (mobile/admin auth session)
- `GET /feedback?page=1&limit=50&rating=5&search=great&isReviewed=false`
- `GET /feedback/summary`
- `PATCH /feedback/:id` with `{ "isReviewed": true }` (admin only)

#### 1) Submit feedback

Request body supports either `menuId` or `menuDate` (`YYYY-MM-DD`), plus rating/comment.

```json
{
  "menuDate": "2026-05-01",
  "rating": 5,
  "comment": "Great meal quality and taste."
}
```

Flutter example:

```dart
final created = await api.post('/feedback', body: {
  'menuDate': '2026-05-01', // or use menuId
  'rating': 5,
  'comment': 'Great meal quality and taste.',
});
```

#### 2) List feedback

Use filters when needed (`rating`, `search`, `isReviewed`) with pagination:

```dart
final list = await api.get('/feedback', query: {
  'page': '1',
  'limit': '50',
  'rating': '5',         // optional
  'search': 'great',     // optional
  'isReviewed': 'false', // optional
});
```

#### 3) Feedback summary

```dart
final summary = await api.get('/feedback/summary');
```

Returns values like:

- `totalFeedback`
- `averageRating`
- `fiveStarReviews`
- `lowRatings`
- `reviewedCount`
- `unreviewedCount`
- `ratingBreakdown`

#### 4) Mark review status (admin only)

```dart
await api.patch('/feedback/<feedback-id>', body: {
  'isReviewed': true,
});
```

## 6) Minimal repository pattern (recommended)

Create feature repositories that call `ApiClient` and map JSON to models:

- `AuthRepository` -> login/token storage
- `UserRepository` -> list/create/update users
- `PaymentsRepository` -> summary/receipts
- etc.

This keeps UI code clean and testable.

## 7) Token persistence (recommended)

Store token in secure storage (for example `flutter_secure_storage`) and restore it when app starts.

Pseudo-flow:

1. App launch -> read token
2. If token exists -> set `api.accessToken`
3. Call a protected endpoint
4. If `401` -> clear token and redirect to login

## 8) Quick connectivity test

Use this to verify app can reach API:

```dart
Future<bool> ping(ApiClient api) async {
  final health = await api.get('/health');
  return health['ok'] == true;
}
```

If your server is running locally and your Flutter app runs on Android emulator, use:

- `http://10.0.2.2:4000/api/v1` (instead of localhost)

---

If you want, I can also generate ready-made Dart files (`auth_repository.dart`, `payments_repository.dart`, models, and error parser) directly in your Flutter project structure.
