# FMB Kuwait API Reference

Base URL: `https://your-api-host/api/v1`

All responses are JSON. All authenticated endpoints require:
```
Authorization: Bearer <accessToken>
```

---

## Authentication

### User Types
| Type | Description |
|---|---|
| `ADMIN` | Can sign in on admin web and mobile app |
| `APP_USER` | Mobile app only |

### Client Channels
| Channel | Who uses it |
|---|---|
| `admin_web` | Admin panel (React) |
| `mobile` | Flutter mobile app |

---

## Endpoints

---

### POST `/auth/login`

Sign in and receive a JWT token.

**No auth required.**

**Request Body**
| Field | Type | Required | Description |
|---|---|---|---|
| `itsNumber` | `string` (max 32) | ✅ | User's ITS number |
| `password` | `string` | ✅ | User's password |
| `client` | `"admin_web"` \| `"mobile"` | ✅ | Which client is logging in |

```json
{
  "itsNumber": "12345678",
  "password": "MyPassword123",
  "client": "mobile"
}
```

**Success Response `200`**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiJ9...",
  "tokenType": "Bearer",
  "expiresInSeconds": 43200,
  "user": {
    "id": "uuid-string",
    "userType": "APP_USER",
    "itsNumber": "12345678",
    "email": "user@example.com",
    "fullName": "John Doe",
    "contactPhone": "+965 9999 9999",
    "address": "Block 5, Street 10, Kuwait City",
    "thaliNumber": "T-001",
    "sabilNumber": "S-001",
    "takhminAmountKd": 150.00,
    "isActive": true,
    "createdAt": "2026-01-01T00:00:00.000Z",
    "updatedAt": "2026-01-01T00:00:00.000Z"
  }
}
```

**Error Responses**
| Status | Code | Reason |
|---|---|---|
| `404` | `ITS_NOT_FOUND` | No account with this ITS number |
| `401` | `INVALID_PASSWORD` | Wrong password |
| `403` | `ACCOUNT_INACTIVE` | Account is disabled |
| `403` | `CHANNEL_NOT_ALLOWED` | User type not allowed on this channel |

---

## Users `/users`

> **Admin web token required for all endpoints.**

---

### GET `/users`

List all users with pagination.

**Query Parameters**
| Param | Type | Default | Description |
|---|---|---|---|
| `page` | `number` | `1` | Page number |
| `limit` | `number` | `20` | Items per page (max 500) |

**Success Response `200`**
```json
{
  "data": [
    {
      "id": "uuid",
      "userType": "APP_USER",
      "itsNumber": "12345678",
      "email": "user@example.com",
      "fullName": "John Doe",
      "contactPhone": "+965 9999 9999",
      "address": "Kuwait City",
      "thaliNumber": "T-001",
      "sabilNumber": "S-001",
      "takhminAmountKd": 150.00,
      "isActive": true,
      "createdAt": "2026-01-01T00:00:00.000Z",
      "updatedAt": "2026-01-01T00:00:00.000Z"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "activeTotal": 95,
    "inactiveTotal": 5
  }
}
```

---

### GET `/users/:id`

Get a single user by ID.

**Success Response `200`**
```json
{
  "data": { ...user object }
}
```

**Error `404`** — User not found.

---

### POST `/users`

Create a new user.

**Request Body**
| Field | Type | Required | Description |
|---|---|---|---|
| `userType` | `"ADMIN"` \| `"APP_USER"` | ✅ | User type |
| `itsNumber` | `string` (max 32) | ✅ | Unique ITS number |
| `email` | `string` (email) | ✅ | Unique email address |
| `password` | `string` (min 8) | ✅ | Plain text password (hashed server-side) |
| `fullName` | `string` (max 255) | ✅ | Full name |
| `contactPhone` | `string` (max 64) | ❌ | Phone number |
| `address` | `string` (max 2000) | ❌ | Address |
| `thaliNumber` | `string` (max 64) | ❌ | Thali number |
| `sabilNumber` | `string` (max 64) | ❌ | Sabil number |

**Success Response `201`**
```json
{
  "data": { ...user object }
}
```

**Error `409`** — Duplicate email or ITS number.

---

### POST `/users/import`

Bulk import users from an array.

**Request Body**
```json
{
  "users": [
    {
      "userType": "APP_USER",
      "itsNumber": "12345678",
      "email": "user@example.com",
      "password": "Password123",
      "fullName": "John Doe"
    }
  ]
}
```

**Success Response `200`**
```json
{
  "data": {
    "created": 10,
    "failures": [
      {
        "index": 2,
        "itsNumber": "99999999",
        "email": "dup@example.com",
        "message": "Duplicate email or ITS number"
      }
    ]
  }
}
```

---

### PATCH `/users/:id`

Update a user. Send only the fields you want to change.

**Request Body** (all optional, at least one required)
| Field | Type | Description |
|---|---|---|
| `email` | `string` | New email |
| `fullName` | `string` | New full name |
| `contactPhone` | `string` \| `null` | Phone (null to clear) |
| `address` | `string` \| `null` | Address (null to clear) |
| `thaliNumber` | `string` \| `null` | Thali number (null to clear) |
| `sabilNumber` | `string` \| `null` | Sabil number (null to clear) |
| `userType` | `"ADMIN"` \| `"APP_USER"` | Change user type |
| `isActive` | `boolean` | Enable/disable account |
| `password` | `string` (min 8) | New password |

**Success Response `200`**
```json
{
  "data": { ...updated user object }
}
```

---

## Takhmin `/takhmin`

> Takhmin = annual estimate amount (in KD) per Misri (Hijri) year.
> **Admin web token required for all endpoints.**

---

### GET `/takhmin/app-users?misriYear=1446`

List all active app users with their Takhmin for a Misri year.

**Query Parameters**
| Param | Type | Default | Description |
|---|---|---|---|
| `misriYear` | `number` | current year | Misri (Hijri) year e.g. `1446` |

**Success Response `200`**
```json
{
  "meta": { "misriYear": 1446 },
  "data": [
    {
      "id": "uuid",
      "itsNumber": "12345678",
      "fullName": "John Doe",
      "email": "user@example.com",
      "contactPhone": "+965 9999 9999",
      "misriYear": 1446,
      "takhminAmountKd": 150.00,
      "takhminCompletedAt": "2026-01-15T10:00:00.000Z",
      "updatedAt": "2026-01-15T10:00:00.000Z"
    }
  ]
}
```

---

### GET `/takhmin/app-users/:userId/history`

Get full Takhmin history for a user across all Misri years.

**Success Response `200`**
```json
{
  "data": [
    {
      "misriYear": 1446,
      "amountKd": 150.00,
      "updatedAt": "2026-01-15T10:00:00.000Z",
      "totalPaidKd": 100.00,
      "remainingKd": 50.00
    }
  ]
}
```

---

### PATCH `/takhmin/app-users/:id`

Set or clear Takhmin amount for a user for a Misri year.

**Request Body**
| Field | Type | Required | Description |
|---|---|---|---|
| `takhminAmountKd` | `number` \| `null` | ✅ | Amount in KD, or null to clear |
| `misriYear` | `number` (1300–1600) | ✅ | Misri year |

```json
{
  "takhminAmountKd": 150.00,
  "misriYear": 1446
}
```

**Success Response `200`**
```json
{
  "data": { ...user object }
}
```

---

### PATCH `/takhmin/app-users/:id/completion`

Mark Takhmin as complete or incomplete for a Misri year.

**Request Body**
| Field | Type | Required | Description |
|---|---|---|---|
| `misriYear` | `number` (1300–1600) | ✅ | Misri year |
| `completed` | `boolean` | ✅ | true = complete, false = incomplete |

```json
{
  "misriYear": 1446,
  "completed": true
}
```

**Success Response `200`**
```json
{ "ok": true }
```

**Error Codes**
| Code | Reason |
|---|---|
| `TAKHMIN_NOT_APPLICABLE` | User is not an active app user |
| `TAKHMIN_ROW_MISSING` | No Takhmin row exists — set amount first |

---

## Payments `/payments`

> **Admin web token required for all endpoints.**

---

### GET `/payments/eligible-users?misriYear=1446`

List users eligible to receive a cash payment (Takhmin must be marked complete).

**Query Parameters**
| Param | Type | Default | Description |
|---|---|---|---|
| `misriYear` | `number` | current year | Misri year |

**Success Response `200`**
```json
{
  "meta": { "misriYear": 1446 },
  "data": [
    {
      "id": "uuid",
      "itsNumber": "12345678",
      "fullName": "John Doe",
      "email": "user@example.com",
      "contactPhone": "+965 9999 9999",
      "misriYear": 1446,
      "takhminAmountKd": 150.00,
      "takhminCompletedAt": "2026-01-15T10:00:00.000Z",
      "totalPaidKd": 100.00,
      "remainingKd": 50.00
    }
  ]
}
```

---

### GET `/payments/summary?misriYear=1446`

Get total payment summary.

**Success Response `200`**
```json
{
  "meta": { "misriYear": 1446 },
  "data": {
    "receiptCount": 25,
    "totalAmountKd": 3750.00
  }
}
```

---

### GET `/payments/receipts`

List all payment receipts with pagination.

**Query Parameters**
| Param | Type | Default | Description |
|---|---|---|---|
| `page` | `number` | `1` | Page number |
| `limit` | `number` | `50` | Items per page (max 200) |
| `misriYear` | `number` | all years | Filter by Misri year |

**Success Response `200`**
```json
{
  "meta": {
    "page": 1,
    "limit": 50,
    "total": 100,
    "totalPages": 2
  },
  "data": [
    {
      "id": "uuid",
      "receiptNumber": "RCP-1446-ABC123DEF456",
      "userId": "uuid",
      "subscriberName": "John Doe",
      "itsNumber": "12345678",
      "misriYear": 1446,
      "amountKd": 50.00,
      "paymentMethod": "cash",
      "notes": "Partial payment",
      "receivedAt": "2026-01-20T10:00:00.000Z",
      "recordedByName": "Admin User",
      "createdAt": "2026-01-20T10:00:00.000Z"
    }
  ]
}
```

---

### POST `/payments/receipts`

Record a new cash payment receipt.

**Request Body**
| Field | Type | Required | Description |
|---|---|---|---|
| `userId` | `string` (uuid) | ✅ | User ID of the subscriber |
| `misriYear` | `number` (1300–1600) | ✅ | Misri year |
| `amountKd` | `number` (positive) | ✅ | Amount paid in KD |
| `notes` | `string` \| `null` (max 2000) | ❌ | Optional notes |

```json
{
  "userId": "uuid-of-subscriber",
  "misriYear": 1446,
  "amountKd": 50.00,
  "notes": "First installment"
}
```

**Success Response `201`**
```json
{
  "data": {
    "id": "uuid",
    "receiptNumber": "RCP-1446-ABC123DEF456",
    "takhminAmountKd": 150.00,
    "totalPaidKd": 150.00,
    "remainingKd": 0.00
  }
}
```

**Error Codes**
| Code | Reason |
|---|---|
| `PAYMENT_NOT_APPLICABLE` | User is not an active app user |
| `PAYMENT_PREREQUISITE` | Takhmin not marked complete for this year |

---

## Packages `/packages`

> Subscription pricing tiers (Basic, Premium, Family).
> **Admin web token required for all endpoints.**

---

### GET `/packages?activeOnly=true`

List all subscription packages.

**Query Parameters**
| Param | Type | Default | Description |
|---|---|---|---|
| `activeOnly` | `"true"` \| `"false"` | `false` | Only return active packages |

**Success Response `200`**
```json
{
  "data": [
    {
      "id": "uuid",
      "title": "Basic Package",
      "tier": "Basic",
      "priceKd": 120.00,
      "features": ["Daily lunch", "Weekly menu updates"],
      "installmentsKd": [40.00, 40.00, 40.00],
      "isActive": true,
      "sortOrder": 1,
      "createdAt": "2026-01-01T00:00:00.000Z",
      "updatedAt": "2026-01-01T00:00:00.000Z"
    }
  ]
}
```

**Package Tiers:** `Basic` | `Premium` | `Family`

---

### GET `/packages/:id`

Get a single package by ID.

---

### POST `/packages`

Create a new package.

**Request Body**
| Field | Type | Required | Description |
|---|---|---|---|
| `title` | `string` (max 255) | ✅ | Package name |
| `tier` | `"Basic"` \| `"Premium"` \| `"Family"` | ✅ | Tier |
| `priceKd` | `number` (≥0) | ✅ | Total price in KD |
| `features` | `string[]` (max 100 items) | ❌ | List of feature strings |
| `installmentsKd` | `number[]` (max 50 items) | ❌ | Installment amounts in KD |
| `isActive` | `boolean` | ❌ | Default `true` |
| `sortOrder` | `number` | ❌ | Display order, default `0` |

---

### PATCH `/packages/:id`

Update a package. All fields optional.

---

### DELETE `/packages/:id`

Delete a package. Returns `204 No Content`.

---

## Zabihat `/zabihat`

> Zabihat offerings with inventory tracking.
> **Admin web token required for all endpoints.**

---

### GET `/zabihat?enabledOnly=true`

List all Zabihat offerings.

**Success Response `200`**
```json
{
  "data": [
    {
      "id": "uuid",
      "code": "ZAB-001",
      "title": "Whole Sheep",
      "description": "Full Zabihat offering",
      "priceKd": 85.00,
      "capacity": 50,
      "unitsSold": 12,
      "available": 38,
      "isEnabled": true,
      "sortOrder": 1,
      "createdAt": "2026-01-01T00:00:00.000Z",
      "updatedAt": "2026-01-01T00:00:00.000Z"
    }
  ]
}
```

---

### GET `/zabihat/:id`

Get a single Zabihat offering.

---

### POST `/zabihat`

Create a new Zabihat offering.

**Request Body**
| Field | Type | Required | Description |
|---|---|---|---|
| `title` | `string` (max 255) | ✅ | Offering name |
| `priceKd` | `number` (≥0) | ✅ | Price in KD |
| `capacity` | `number` (int, min 1) | ✅ | Total units available |
| `code` | `string` (max 64) \| `null` | ❌ | Unique code |
| `description` | `string` (max 4000) \| `null` | ❌ | Description |
| `unitsSold` | `number` (int, ≥0) | ❌ | Units already sold, default `0` |
| `isEnabled` | `boolean` | ❌ | Default `true` |
| `sortOrder` | `number` | ❌ | Default `0` |

---

### PATCH `/zabihat/:id`

Update a Zabihat offering. All fields optional.

---

### DELETE `/zabihat/:id`

Delete a Zabihat offering. Returns `204 No Content`.

---

## Menus `/menus`

> Daily food menus.
> **Admin web token required for all endpoints.**

---

### GET `/menus?from=2026-01-01&to=2026-01-31`

List daily menus, optionally filtered by date range.

**Query Parameters**
| Param | Type | Description |
|---|---|---|
| `from` | `YYYY-MM-DD` | Start date (inclusive) |
| `to` | `YYYY-MM-DD` | End date (inclusive) |

**Success Response `200`**
```json
{
  "data": [
    {
      "id": "uuid",
      "menuDate": "2026-01-20",
      "dayLabel": "Tuesday",
      "title": "Special Menu",
      "items": ["Biryani", "Salad", "Dessert"],
      "notes": "Extra spicy today",
      "isPublished": true,
      "createdAt": "2026-01-01T00:00:00.000Z",
      "updatedAt": "2026-01-01T00:00:00.000Z"
    }
  ]
}
```

---

### GET `/menus/:id`

Get a single menu by ID.

---

### POST `/menus`

Create a daily menu.

**Request Body**
| Field | Type | Required | Description |
|---|---|---|---|
| `menuDate` | `YYYY-MM-DD` | ✅ | Date (must be unique) |
| `items` | `string[]` (1–40 items) | ✅ | Menu items list |
| `title` | `string` (max 255) \| `null` | ❌ | Menu title |
| `notes` | `string` (max 4000) \| `null` | ❌ | Notes |
| `isPublished` | `boolean` | ❌ | Default `true` |

**Error `409`** — `DUPLICATE_DATE` — A menu for this date already exists.

---

### PATCH `/menus/:id`

Update a menu. All fields optional.

---

### DELETE `/menus/:id`

Delete a menu. Returns `204 No Content`.

---

## Notifications `/notifications`

> Admin broadcast notifications with optional file attachments.
> **Admin web token required** (except file serving).

---

### GET `/notifications/files/:storedName`

**No auth required.** Serve an uploaded attachment file (image or PDF).

---

### GET `/notifications?limit=50&offset=0`

List notifications, newest first.

**Query Parameters**
| Param | Type | Default | Description |
|---|---|---|---|
| `limit` | `number` | `100` | Max items (max 200) |
| `offset` | `number` | `0` | Skip N items |

**Success Response `200`**
```json
{
  "data": [
    {
      "id": "uuid",
      "title": "Important Announcement",
      "body": "Please note the schedule change...",
      "audienceMode": "ALL",
      "audienceLabel": "All Subscribers",
      "selectedItsNumbers": [],
      "attachments": [
        {
          "kind": "image",
          "originalName": "schedule.jpg",
          "url": "/api/v1/notifications/files/abc123.jpg"
        }
      ],
      "sentAt": "2026-01-20T10:00:00.000Z",
      "sentByUserId": "uuid",
      "createdAt": "2026-01-20T10:00:00.000Z",
      "updatedAt": "2026-01-20T10:00:00.000Z"
    }
  ]
}
```

---

### POST `/notifications`

Send a new notification. Uses `multipart/form-data` (supports file uploads).

**Form Fields**
| Field | Type | Required | Description |
|---|---|---|---|
| `title` | `string` (max 255) | ✅ | Notification title |
| `body` | `string` (max 8000) | ✅ | Notification body text |
| `audienceMode` | `"ALL"` \| `"SELECTED"` | ✅ | Who receives it |
| `selectedItsNumbers` | `string` (comma-separated) | ❌ | Required when `audienceMode=SELECTED` e.g. `"12345678,87654321"` |
| `attachments` | file (max 5 files, 10MB each) | ❌ | Images or PDFs |

**Success Response `201`**
```json
{
  "data": { ...notification object }
}
```

**Error Codes**
| Code | Reason |
|---|---|
| `INVALID_AUDIENCE` | SELECTED mode with no ITS numbers, or ALL mode with ITS numbers |
| `FILE_TOO_LARGE` | Attachment exceeds 10 MB |
| `TOO_MANY_FILES` | More than 5 attachments |

---

## Database Tables

### `users`
| Column | Type | Description |
|---|---|---|
| `id` | `CHAR(36)` | UUID primary key |
| `user_type` | `ENUM(ADMIN, APP_USER)` | User role |
| `its_number` | `VARCHAR(32)` | Unique ITS number |
| `email` | `VARCHAR(255)` | Unique email |
| `password_hash` | `VARCHAR(255)` | bcrypt hash |
| `full_name` | `VARCHAR(255)` | Full name |
| `contact_phone` | `VARCHAR(64)` | Optional phone |
| `address` | `TEXT` | Optional address |
| `thali_number` | `VARCHAR(64)` | Optional thali number |
| `sabil_number` | `VARCHAR(64)` | Optional sabil number |
| `is_active` | `BOOLEAN` | Account enabled flag |
| `created_at` | `DATETIME` | Creation timestamp |
| `updated_at` | `DATETIME` | Last update timestamp |

### `user_takhmin`
| Column | Type | Description |
|---|---|---|
| `id` | `CHAR(36)` | UUID primary key |
| `user_id` | `CHAR(36)` | FK → users.id |
| `misri_year` | `SMALLINT` | Hijri year e.g. 1446 |
| `amount_kd` | `DECIMAL(10,2)` | Estimated amount in KD |
| `takhmin_completed_at` | `DATETIME(3)` | When marked complete (null = incomplete) |
| `created_at` | `DATETIME` | Creation timestamp |
| `updated_at` | `DATETIME` | Last update timestamp |

### `payment_receipts`
| Column | Type | Description |
|---|---|---|
| `id` | `CHAR(36)` | UUID primary key |
| `receipt_number` | `VARCHAR(40)` | Unique e.g. `RCP-1446-ABC123DEF456` |
| `user_id` | `CHAR(36)` | FK → users.id (subscriber) |
| `misri_year` | `SMALLINT` | Hijri year |
| `amount_kd` | `DECIMAL(10,2)` | Amount paid |
| `payment_method` | `VARCHAR(32)` | Always `"cash"` currently |
| `notes` | `TEXT` | Optional notes |
| `received_at` | `DATETIME(3)` | When payment was received |
| `recorded_by_user_id` | `CHAR(36)` | FK → users.id (admin who recorded) |
| `created_at` | `DATETIME` | Creation timestamp |
| `updated_at` | `DATETIME` | Last update timestamp |

### `subscription_packages`
| Column | Type | Description |
|---|---|---|
| `id` | `CHAR(36)` | UUID primary key |
| `title` | `VARCHAR(255)` | Package name |
| `tier` | `ENUM(Basic, Premium, Family)` | Tier level |
| `price_kd` | `DECIMAL(10,2)` | Total price in KD |
| `features` | `JSON` | Array of feature strings |
| `installments_kd` | `JSON` | Array of installment amounts |
| `is_active` | `BOOLEAN` | Visible/active flag |
| `sort_order` | `INT` | Display order |
| `created_at` | `DATETIME` | Creation timestamp |
| `updated_at` | `DATETIME` | Last update timestamp |

### `zabihat_offerings`
| Column | Type | Description |
|---|---|---|
| `id` | `CHAR(36)` | UUID primary key |
| `code` | `VARCHAR(64)` | Optional unique code |
| `title` | `VARCHAR(255)` | Offering name |
| `description` | `TEXT` | Optional description |
| `price_kd` | `DECIMAL(10,2)` | Price per unit in KD |
| `capacity` | `INT` | Total units available |
| `units_sold` | `INT` | Units sold so far |
| `is_enabled` | `BOOLEAN` | Visible/enabled flag |
| `sort_order` | `INT` | Display order |
| `created_at` | `DATETIME` | Creation timestamp |
| `updated_at` | `DATETIME` | Last update timestamp |

### `daily_menus`
| Column | Type | Description |
|---|---|---|
| `id` | `CHAR(36)` | UUID primary key |
| `menu_date` | `DATE` | Unique date for this menu |
| `title` | `VARCHAR(255)` | Optional menu title |
| `items` | `JSON` | Array of menu item strings |
| `notes` | `TEXT` | Optional notes |
| `is_published` | `BOOLEAN` | Published/visible flag |
| `created_at` | `DATETIME` | Creation timestamp |
| `updated_at` | `DATETIME` | Last update timestamp |

### `admin_notifications`
| Column | Type | Description |
|---|---|---|
| `id` | `CHAR(36)` | UUID primary key |
| `title` | `VARCHAR(255)` | Notification title |
| `body` | `TEXT` | Notification body |
| `audience_mode` | `ENUM(ALL, SELECTED)` | Who receives it |
| `audience_label` | `VARCHAR(255)` | Human-readable e.g. "All Subscribers" |
| `selected_its_numbers` | `JSON` | Array of ITS numbers (SELECTED mode only) |
| `attachments` | `JSON` | Array of `{kind, mimeType, originalName, storedName}` |
| `sent_at` | `DATETIME(3)` | When sent |
| `sent_by_user_id` | `CHAR(36)` | FK → users.id (admin who sent) |
| `created_at` | `DATETIME` | Creation timestamp |
| `updated_at` | `DATETIME` | Last update timestamp |

---

## Common Error Response Format

All errors follow this shape:
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message"
  }
}
```

## JWT Token Details

- Algorithm: `HS256`
- Expiry: `12 hours` (43200 seconds)
- Payload contains: `sub` (user ID), `typ` (user type), `aud` (client channel)
- Pass in header: `Authorization: Bearer <token>`