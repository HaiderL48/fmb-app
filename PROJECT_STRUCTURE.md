# My Taste — Project Structure & Coding Style Guide

## Overview

**My Taste** is a Flutter-based food ordering app that connects users with home chefs/kitchens. It uses Firebase for auth and notifications, a custom REST API (Firebase Cloud Functions) for data, and the Provider pattern for state management.

---

## Folder Structure

```
my_taste/
├── lib/                        # All application source code
│   ├── apis/                   # HTTP API layer
│   ├── components/             # Reusable UI building blocks
│   ├── constants/              # App-wide constants (colors, styles, strings)
│   ├── models/                 # Data models (JSON serialization)
│   ├── providers/              # State management (Provider pattern)
│   ├── screens/                # Full-page UI screens
│   ├── services/               # Firebase integrations
│   ├── utils/                  # Helper utilities
│   ├── widgets/                # Larger reusable widget compositions
│   ├── config.dart             # Central barrel export file
│   ├── firebase_options.dart   # Firebase platform config (auto-generated)
│   └── main.dart               # App entry point
│
├── assets/
│   ├── images/                 # PNG/JPG images (logos, food photos)
│   ├── svg/                    # SVG icons and illustrations
│   └── fonts/font/             # Gotham font family (.otf files)
│
├── android/                    # Android platform-specific code
├── ios/                        # iOS platform-specific code
├── pubspec.yaml                # Dependencies and asset declarations
└── README.md
```

---

## lib/ — Detailed Breakdown

### `apis/`
Single file that handles all HTTP communication with the backend.

| File | Purpose |
|------|---------|
| `api_manager.dart` | Static class with all API methods. Uses a shared `safeRequest<T>()` wrapper that handles 401/403 by redirecting to login. Base URL points to Firebase Cloud Functions. |

### `components/`
Small, focused UI pieces that are composed into screens. Each component receives data via constructor parameters — they do **not** call providers directly (except for actions like wishlist toggling).

| File | Purpose |
|------|---------|
| `bottom_bar.dart` | Custom bottom navigation bar |
| `floating_button.dart` | Floating cart/action button on home |
| `food_card.dart` | Vertical dish card with image, tags, price |
| `food_card_horizontal.dart` | Horizontal dish card layout |
| `cart_item_component.dart` | Individual item row inside the cart |
| `cart_bottom_bar.dart` | Sticky bottom bar on cart screen (total + checkout) |
| `category_card.dart` | Cuisine/category chip card |
| `dish_detail.dart` | Dish info section (name, chef, description) |
| `extra_toppings.dart` | Add-on/topping selector for a dish |
| `nutrition_details.dart` | Nutritional info accordion |
| `ingrediant_details.dart` | Ingredients list section |
| `order_card.dart` | Order summary card in history |
| `offer_component.dart` | Offer/coupon display row |
| `Offer_card.dart` | Offer card in bottom sheet |
| `product_card.dart` | Generic product display card |
| `profile_info.dart` | User profile header info |
| `profile_function.dart` | Profile menu action rows |
| `video_player.dart` | Wrapped video player widget |
| `accordion.dart` | Expandable accordion section |
| `text_field.dart` | Styled text input wrapper |
| `my_buttons.dart` | Primary action button component |
| `my_categories.dart` | Horizontal category list |
| `my_gridview.dart` | Grid layout for dishes |

### `constants/`
Pure Dart files with no widgets — only values and style definitions.

| File | Purpose |
|------|---------|
| `colors.dart` | `MyColors` class with all color constants. Also contains `StyleText` with static `TextStyle` objects. |
| `styles.dart` | `MyTextStyle` class (context-aware text styles), `MyButtonStyle`, and `Buttons` static widget builders |
| `theme_data.dart` | Global `ThemeData` (`themeData`) used in `MaterialApp` |
| `images.dart` | `MyImages` class — string constants for asset image paths |
| `svg.dart` | `MySvg` class — string constants for SVG asset paths |
| `string.dart` | App-wide string constants |
| `intent_utils.dart` | `IntentUtils` — navigation helper with `fireIntent`, `fireIntentwithoutFinish`, `fireIntentwithAnimations` |
| `dishes.dart` | Static dish data (used for local/mock data) |
| `video.dart` | `Video` class — video asset path constants |

### `models/`
Plain Dart classes for JSON deserialization. Each model follows the same pattern:
- Top-level `fromJson` function (e.g., `homeModalFromJson`)
- `factory Model.fromJson(Map<String, dynamic> json)` constructor
- `toJson()` method

| File | Purpose |
|------|---------|
| `home_modal.dart` | Home screen data: banners, cuisines, chefs list |
| `dish_model.dart` | Individual dish with chef info, cart state |
| `user_model.dart` | User profile data |
| `login_model.dart` | Auth response with user details |
| `order_model.dart` | Order summary |
| `order_dish_model.dart` | Dish within an order |
| `address_model.dart` | Delivery address |
| `add_addressmodal.dart` | Add address API response |
| `get_address_modal.dart` | Get addresses API response |
| `delete_address_modal.dart` | Delete address API response |
| `cart_list_model.dart` | Cart item structure |
| `offers_model.dart` | Coupon/offer data |
| `category_model.dart` | Food category |
| `cuisine_model.dart` | Cuisine type |
| `chef_model.dart` | Chef/kitchen profile |
| `chef_by_cuisine_modal.dart` | Chefs filtered by cuisine |
| `chef_wise_dish_modal.dart` | Dishes from a specific chef |
| `notification_model.dart` | Push notification data |
| `favourite_model.dart` | Wishlist/favourite item |
| `community_model.dart` | Community/regional tag |
| `regional_model.dart` | Regional food tag |
| `add_on_model.dart` | Dish add-on/topping |
| `lat_lng_bounds.dart` | Geographic bounding box for map queries |
| `usertokenmodal.dart` | FCM token update response |

### `providers/`
All state management using the `Provider` package with `ChangeNotifier`. Each provider owns a slice of app state.

| File | Purpose |
|------|---------|
| `auth/login_provider.dart` | Phone input, form validation, OTP trigger, Firebase token |
| `auth/user_data_provider.dart` | Logged-in user data (token, name, phone) persisted via SharedPreferences |
| `auth/my_information_provider.dart` | Profile edit state |
| `home_provider.dart` | Home screen data: banners, cuisines, chef list. Triggers location fetch first, then API call |
| `dish_provider.dart` | Dishes for a specific chef/kitchen |
| `add_to_cart_provider.dart` | Cart items list, total price, selected address |
| `orders_provider.dart` | Order placement, order history, offers |
| `address_provider.dart` | User's saved addresses |
| `add_address_provider.dart` | Add address flow + current GPS location |
| `wishlist_provider.dart` | Favourites/wishlist management |
| `category_provider.dart` | Category list state |
| `chef_by_cuisine_provider.dart` | Chefs filtered by selected cuisine |
| `notification_provider.dart` | In-app notification list |
| `video_provider.dart` | Video playback state |
| `otp_provider.dart` | OTP verification flow |

### `screens/`
Full-page views. Each screen is a `StatefulWidget` that reads from providers via `Consumer` or `Provider.of`.

```
screens/
├── auth/
│   ├── login_screen.dart         # Phone number entry
│   ├── otp_screen.dart           # OTP verification
│   └── editprofile_screen.dart   # Edit user profile
│
├── bottom/                       # Main tab screens
│   ├── home_page.dart            # Tab container (bottom nav host)
│   ├── home_widget → widgets/    # Home content (see widgets/)
│   ├── cart_screen.dart          # Cart + address + checkout
│   ├── order_history_screen.dart # Past orders
│   ├── profile_screen.dart       # User profile
│   └── setyourtaste_screen.dart  # Taste preference setup
│
├── walkthrough/
│   ├── splash_screen.dart        # Initial splash + auth check
│   ├── splash_screen_1/2/3.dart  # Onboarding slides
│
├── category_screen.dart          # Chefs filtered by cuisine
├── dish_screen.dart              # Dish listing for a kitchen
├── singledish_screen.dart        # Single dish detail + video
├── single_kitchen_screen.dart    # Kitchen profile + menu
├── payment_options.dart          # Payment method selection
├── myaddress_scree.dart          # Address list + selection
├── add_address_screen.dart       # Add new address with map
├── location_picker.dart          # Google Maps location picker
├── myfavorites_screen.dart       # Wishlist screen
├── orders_screen.dart            # Active orders
├── notification_screen.dart      # Push notification list
├── myinformation_screen.dart     # User info display
├── coupens_screen.dart           # Coupons/offers list
├── forgot_password_screen.dart   # Password reset
├── edit_screen.dart              # Generic edit screen
├── privacypolicy_screen.dart     # Privacy policy
└── support_screen.dart           # Support/help screen
```

### `services/`
Firebase-specific service classes.

| File | Purpose |
|------|---------|
| `firebase_auth.dart` | Firebase Auth wrapper (phone OTP sign-in) |
| `fireabase_services.dart` | FCM setup: local notifications init, foreground/background message handlers |

### `utils/`
Stateless helper classes and functions.

| File | Purpose |
|------|---------|
| `show_snackbar.dart` | `ShowSnackbar().showSnackBar(context, text)` — single method wrapper |
| `show_dialog.dart` | Dialog helper utilities |
| `bottom_sheet.dart` | `ShowBottomSheet()` — offer and payment bottom sheets |
| `loader.dart` | Loading overlay utility |
| `location_provider.dart` | GPS location fetch helper |
| `connectionUtils.dart` | `ConnectionUtils.checkConnection()` — returns `bool` for internet status |
| `showotp_dialogue.dart` | OTP dialog helper |
| `text_dialog.dart` | Text input dialog helper |
| `statefull_wrapper.dart` | Stateful widget wrapper utility |

### `widgets/`
Larger widget compositions used across multiple screens.

| File | Purpose |
|------|---------|
| `home_widget.dart` | Full home screen content: search bar, carousel banners, cuisine list, kitchen cards, offer grid |
| `custom_appbar.dart` | Reusable `PreferredSizeWidget` app bar |
| `common_textfield.dart` | Styled text field with validation |
| `common_mobile_textfield.dart` | Phone number input with country code |
| `custom_dropdown.dart` | Styled dropdown selector |
| `loading_widget.dart` | Centered loading spinner |
| `custom_dialogs.dart` | Reusable dialog templates |

---

## assets/ — Breakdown

```
assets/
├── images/          # Raster images (PNG/JPG)
│   ├── my-taste_logo.png
│   ├── logoLight-01.png
│   ├── carousal-1.jpg / carousal-2.jpg
│   ├── burger.png / dosa.png / sandwich.png
│   ├── specialoffer.png / top10.png
│   └── img.png → img_4.png      # Offer grid images
│
├── svg/             # Vector icons and illustrations
│   ├── logoLight.svg / fulllogodark.svg
│   ├── home_filled.svg / home_outlined.svg
│   ├── cart_filled.svg
│   ├── profile_filled.svg / profile_outlined.svg
│   ├── Document_outlined.svg / document_filled.svg
│   ├── veg.svg / non-veg.svg
│   ├── splashimg1/2/3.svg       # Onboarding illustrations
│   └── floating-button-01-01.svg
│
└── fonts/font/      # Gotham Rounded font family
    ├── GothamRounded-Light.otf   (weight 400)
    ├── GothamRounded-Book.otf    (weight 500)
    ├── GothamRounded-Medium.otf  (weight 600)
    └── GothamRounded-Bold.otf    (weight 800)
```

---

## Coding Style & Patterns

### 1. Central Barrel Export — `config.dart`

All imports across the app go through a single `config.dart` barrel file. Every screen and component imports only this one file:

```dart
import '../../config.dart';
```

`config.dart` re-exports Flutter, Firebase, all providers, models, screens, components, utils, and third-party packages. This keeps individual files clean but means `config.dart` must be updated whenever a new file is added.

---

### 2. Screen Structure

Every screen follows this consistent pattern:

```dart
class MyScreen extends StatefulWidget {
  // Required data passed via constructor
  final SomeModel data;
  const MyScreen({super.key, required this.data});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {

  @override
  void initState() {
    super.initState();
    // Trigger data fetch via provider (listen: false)
    Provider.of<SomeProvider>(context, listen: false).fetchData(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SomeProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: CustomAppbar(title: 'Screen Title'),
          body: provider.isLoading
              ? const LoadingWidget()
              : _bodyWidget(provider),
        );
      },
    );
  }

  // Body extracted into a private method to keep build() clean
  Widget _bodyWidget(SomeProvider provider) {
    return Column(children: [...]);
  }
}
```

Key conventions:
- `initState` triggers data fetching with `listen: false`
- `Consumer` (or `Consumer2`, `Consumer3`) wraps the `Scaffold` for reactive rebuilds
- Loading state is handled with `provider.isLoading ? LoadingWidget() : content`
- Body UI is extracted into a `_bodyWidget()` private method

---

### 3. Provider Pattern

Each provider follows this structure:

```dart
class SomeProvider with ChangeNotifier {
  // Private state with public getter
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<SomeModel> _items = [];
  List<SomeModel> get items => _items;

  // Token/user data loaded before API calls
  String strToken = '';

  // Called from initState via WidgetsBinding to avoid context issues
  void onReady(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getDataAsync(context);
    });
  }

  Future<void> _getDataAsync(BuildContext context) async {
    // Load user token from UserDataProvider first
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    await userDataProvider.loadAsync();
    strToken = userDataProvider.usertoken;
    fetchData(context);
  }

  void fetchData(BuildContext context) async {
    updateLoader(true);
    try {
      bool hasInternet = await ConnectionUtils.checkConnection();
      if (hasInternet) {
        final ResultModal result = await ApiManager.someEndpoint(
          token: strToken,
          context: context,
        );
        if (result.error == false) {
          _items = result.data!;
          notifyListeners();
        } else {
          ShowSnackbar().showSnackBar(context, result.message!);
        }
      } else {
        ShowSnackbar().showSnackBar(context, "Check your internet connection");
      }
    } catch (e) {
      ShowSnackbar().showSnackBar(context, e.toString());
    } finally {
      updateLoader(false);
    }
  }

  void updateLoader(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
```

Key conventions:
- Always check internet with `ConnectionUtils.checkConnection()` before API calls
- Always wrap API calls in `try/catch/finally`
- `finally` block always calls `updateLoader(false)`
- Errors shown via `ShowSnackbar().showSnackBar()`
- `WidgetsBinding.instance.addPostFrameCallback` used in `onReady()` to safely access context after first frame

---

### 4. API Calling Pattern

All API calls go through `ApiManager` in `lib/apis/api_manager.dart`:

```dart
class ApiManager {
  static String BASEURL = "https://us-central1-mytaste-ea555.cloudfunctions.net/app/";

  // Shared wrapper handles 401/403 → redirects to login
  static Future<T> safeRequest<T>({
    required BuildContext context,
    required Future<http.Response> Function() request,
    required T Function(String) parser,
  }) async {
    final response = await request();
    if (response.statusCode == 401 || response.statusCode == 403) {
      IntentUtils.fireIntentwithAnimations(context, LoginScreen(), true);
      throw Exception("Unauthorized");
    }
    return parser(response.body);
  }

  // Each endpoint is a static method
  static Future<HomeModal> homeDetails({
    required BuildContext context,
    required String token,
    required String latitude,
    required String longitude,
  }) {
    return safeRequest(
      context: context,
      request: () => http.post(
        Uri.parse("${BASEURL}homeDetails"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"latitude": latitude, "longitude": longitude}),
      ),
      parser: homeModalFromJson,  // top-level fromJson function from model file
    );
  }
}
```

Key conventions:
- `safeRequest<T>` is the single entry point — handles auth errors globally
- Bearer token passed in `Authorization` header
- Response parsed by the model's top-level `fromJson` function
- Each API method is strongly typed with its return model

---

### 5. Navigation

Navigation uses `IntentUtils` — never raw `Navigator` calls in screens:

```dart
// Push new screen (keeps back stack)
IntentUtils.fireIntentwithoutFinish(context, SomeScreen());

// Push with animation, optionally clear back stack
IntentUtils.fireIntentwithAnimations(context, SomeScreen(), false); // keep stack
IntentUtils.fireIntentwithAnimations(context, SomeScreen(), true);  // clear stack

// Clear entire stack (used after login/logout)
IntentUtils.fireIntent(context, SomeScreen());
```

---

### 6. Styling

Text styles come from `MyTextStyle` in `constants/styles.dart`. They are context-aware static methods:

```dart
Text('Title', style: MyTextStyle.titleprimary(context))
Text('Description', style: MyTextStyle.textDes(context))
Text('Link', style: MyTextStyle.textLink(context, false))
Text('Error', style: MyTextStyle.textError(context))
```

Colors come from `MyColors` in `constants/colors.dart`:

```dart
color: MyColors.primary      // #335928 (dark green)
color: MyColors.secondary    // #03A63D
color: MyColors.gray
color: MyColors.white
color: MyColors.tagOrange    // tag background
```

Font family is `'Gotham'` (Gotham Rounded) used throughout via `fontFamily: 'Gotham'`.

---

### 7. Component Usage in Screens

Components receive data as constructor arguments and are composed inside screen `_bodyWidget()` methods:

```dart
// In cart_screen.dart _bodyWidget():
Column(
  children: [
    CartItemComponent(
      addTOCartProvider: addTOCartProvider,
      dishProvider: dishProvider,
    ),
    GestureDetector(
      onTap: () async {
        final chosen = await ShowBottomSheet().offerBottomSheet(context);
      },
      child: OfferComponent(),
    ),
    CartBottomBar(
      paymentTap: () { ... },
      onTap: () { ... },
    ),
  ],
)
```

Components that need to trigger state changes call providers directly:

```dart
// In food_card.dart
Provider.of<WishlistProvider>(context, listen: false).addToWishList(widget.dish);
```

---

### 8. Multi-Provider Consumption

When a screen needs data from multiple providers, `Consumer2`, `Consumer3`, or `Consumer4` is used:

```dart
// cart_screen.dart
Consumer3<DishProvider, AddToCartProvider, OrdersProvider>(
  builder: (context, dishProvider, addToCartProvider, ordersProvider, child) {
    return Scaffold(...);
  },
)

// home_widget.dart
Consumer4<AddToCartProvider, AddAddressProvider, HomeProvider, CategoryProvider>(
  builder: (context, cartProvider, addressProvider, homeProvider, categoryProvider, child) {
    return Scaffold(...);
  },
)
```

---

### 9. Loading State Pattern

Every screen that fetches data shows a loading indicator while waiting:

```dart
body: provider.isLoading
    ? const Center(child: LoadingWidget())
    : _bodyWidget(provider),
```

`LoadingWidget` is a reusable spinner in `lib/widgets/loading_widget.dart`.

---

### 10. Internet Check Before Every API Call

Every provider method that calls the API first checks connectivity:

```dart
bool hasInternet = await ConnectionUtils.checkConnection();
if (hasInternet) {
  // make API call
} else {
  ShowSnackbar().showSnackBar(context, "Check your internet connection");
}
```

---

## Key Dependencies

| Package | Usage |
|---------|-------|
| `provider` | State management |
| `firebase_auth` | Phone OTP authentication |
| `cloud_firestore` | Legacy direct Firestore access (being replaced by REST API) |
| `firebase_messaging` | Push notifications (FCM) |
| `flutter_local_notifications` | Local notification display |
| `firebase_storage` | Profile image upload |
| `http` | REST API calls to Cloud Functions |
| `google_maps_flutter` | Map for address picking |
| `geolocator` | GPS location |
| `geocoding` | Reverse geocoding (lat/lng → address) |
| `cached_network_image` | Network image caching |
| `flutter_carousel_widget` | Banner carousel |
| `carousel_slider` | Kitchen image slider |
| `smooth_page_indicator` | Carousel dot indicators |
| `flutter_svg` | SVG asset rendering |
| `google_fonts` | Google Fonts access |
| `shared_preferences` | Local persistence (user token, login state) |
| `pinput` | OTP input field |
| `flutter_screenutil` | Responsive sizing |
| `connectivity_plus` | Internet connectivity check |
| `image_picker` | Camera/gallery image selection |
| `flutter_typeahead` | Search autocomplete |
