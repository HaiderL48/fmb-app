import '../models/user_model.dart';
import '../models/package_model.dart';
import '../models/zabihat_model.dart';
import '../models/payment_model.dart';
import '../models/menu_model.dart';
import '../models/menu_feedback_model.dart';

// ─── App Settings ─────────────────────────────────────────────────────────────

const double kMinimumInstallment = 50.0;

// ─── Mock Users ───────────────────────────────────────────────────────────────

final List<UserModel> mockUsers = [
  UserModel(
    id: '1',
    itsNumber: '12345678',
    password: '12345678',
    fullName: 'Ahmed Al-Mansoor',
    address: 'Salmiya, Kuwait',
    contactPhone: '+965 9999 8888',
    email: 'ahmed@example.com',
    thaliNumber: 'TH-2024-001',
    sabilNumber: 'SB-54321',
    packageId: '1',
    isFirstLogin: false,
  ),
];

// ─── Mock Packages ────────────────────────────────────────────────────────────

final List<PackageModel> mockPackages = [
  PackageModel(
    id: '1',
    name: 'Basic Package',
    tier: PackageTier.basic,
    priceKd: 300,
    features: const [
      'Daily meals (Lunch)',
      'Standard menu',
      'Email support',
      'Monthly reports',
    ],
    validity: '12 months',
    installmentOptions: const [50, 100, 150],
  ),
  PackageModel(
    id: '2',
    name: 'Premium Package',
    tier: PackageTier.premium,
    priceKd: 500,
    features: const [
      'Daily meals (Lunch & Dinner)',
      'Premium menu with variety',
      'Priority support',
      'Weekly menu customization',
      'Nutritional reports',
    ],
    validity: '12 months',
    installmentOptions: const [100, 150, 250],
  ),
  PackageModel(
    id: '3',
    name: 'Family Package',
    tier: PackageTier.family,
    priceKd: 800,
    features: const [
      'Daily meals for 4 people',
      'Premium menu with variety',
      'Dedicated support line',
      'Custom dietary requirements',
      'Weekly menu customization',
      'Free delivery upgrades',
    ],
    validity: '12 months',
    installmentOptions: const [150, 200, 400],
  ),
];

// ─── Mock Zabihat ─────────────────────────────────────────────────────────────

final List<ZabihatModel> mockZabihat = [
  ZabihatModel(
    id: '1',
    title: 'Goat Zabihat',
    capacity: 50,
    unitsSold: 15, // 50 - 35 available
    priceKd: 45,
    description:
        'Fresh halal goat meat prepared according to Islamic guidelines',
    isEnabled: true,
  ),
  ZabihatModel(
    id: '2',
    title: 'Cow Zabihat',
    capacity: 20,
    unitsSold: 8, // 20 - 12 available
    priceKd: 180,
    description: 'Premium halal cow meat with complete processing',
    isEnabled: true,
  ),
  ZabihatModel(
    id: '3',
    title: 'Sheep Zabihat',
    capacity: 40,
    unitsSold: 12, // 40 - 28 available
    priceKd: 65,
    description: 'High-quality halal sheep meat',
    isEnabled: true,
  ),
];

// ─── Mock Payments ────────────────────────────────────────────────────────────

final List<PaymentModel> mockPayments = [
  PaymentModel(
    id: 'PAY001',
    userId: '1',
    amountKd: 150,
    method: PaymentMethod.knet,
    receivedAt: DateTime(2026, 2, 15),
    status: PaymentStatus.completed,
    receiptNumber: 'RCP001',
    packageId: '1',
  ),
  PaymentModel(
    id: 'PAY002',
    userId: '1',
    amountKd: 100,
    method: PaymentMethod.cash,
    receivedAt: DateTime(2026, 1, 20),
    status: PaymentStatus.completed,
    receiptNumber: 'RCP002',
    packageId: '1',
  ),
];

// ─── Mock Weekly Menu ─────────────────────────────────────────────────────────

final List<MenuModel> mockWeeklyMenu = [
  MenuModel(
    id: '1',
    menuDate: DateTime(2026, 3, 14),
    dayLabel: 'Sunday',
    items: const ['Chicken Biryani', 'Vegetable Curry', 'Raita', 'Naan Bread'],
  ),
  MenuModel(
    id: '2',
    menuDate: DateTime(2026, 3, 15),
    dayLabel: 'Monday',
    items: const ['Lamb Mandi', 'Green Salad', 'Hummus', 'Arabic Bread'],
  ),
  MenuModel(
    id: '3',
    menuDate: DateTime(2026, 3, 16),
    dayLabel: 'Tuesday',
    items: const ['Grilled Fish', 'Rice Pilaf', 'Mixed Vegetables', 'Tahini'],
  ),
  MenuModel(
    id: '4',
    menuDate: DateTime(2026, 3, 17),
    dayLabel: 'Wednesday',
    items: const [
      'Chicken Shawarma',
      'Fattoush Salad',
      'Garlic Sauce',
      'Pita Bread',
    ],
  ),
  MenuModel(
    id: '5',
    menuDate: DateTime(2026, 3, 18),
    dayLabel: 'Thursday',
    items: const ['Beef Kabsa', 'Lentil Soup', 'Yogurt', 'Arabic Bread'],
  ),
];

// ─── Mock Feedback ────────────────────────────────────────────────────────────

final List<MenuFeedbackModel> mockFeedback = [
  MenuFeedbackModel(
    id: '1',
    userId: '1',
    menuId: '1',
    rating: 5,
    comment:
        'Excellent taste and quality! The Chicken Biryani was perfectly cooked.',
    date: DateTime(2026, 3, 14),
  ),
  MenuFeedbackModel(
    id: '2',
    userId: '1',
    menuId: '2',
    rating: 4,
    comment: 'Very good Lamb Mandi. Would love more vegetables next time.',
    date: DateTime(2026, 3, 15),
  ),
  MenuFeedbackModel(
    id: '3',
    userId: '1',
    menuId: '3',
    rating: 5,
    comment: 'The grilled fish was amazing! Fresh and delicious.',
    date: DateTime(2026, 3, 16),
  ),
  MenuFeedbackModel(
    id: '4',
    userId: '1',
    menuId: '4',
    rating: 3,
    comment: 'Chicken Shawarma was okay. Could use more seasoning.',
    date: DateTime(2026, 3, 17),
  ),
  MenuFeedbackModel(
    id: '5',
    userId: '1',
    menuId: '5',
    rating: 5,
    comment: 'Best Beef Kabsa I have had! The lentil soup was perfect too.',
    date: DateTime(2026, 3, 18),
  ),
];
