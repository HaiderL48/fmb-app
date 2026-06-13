// Mock data store for the application
export interface User {
  id: string;
  itsNumber: string;
  password: string;
  name: string;
  address: string;
  contact: string;
  email: string;
  thaliNumber?: string;
  sabilNumber?: string;
  packageId?: string;
  isFirstLogin: boolean;
}

export interface Package {
  id: string;
  name: string;
  type: 'Basic' | 'Premium' | 'Family';
  price: number;
  features: string[];
  validity: string;
  installmentOptions: number[];
}

export interface Zabihat {
  id: string;
  name: string;
  maxUnits: number;
  availableUnits: number;
  pricePerUnit: number;
  description: string;
  enabled: boolean;
}

export interface Payment {
  id: string;
  userId: string;
  amount: number;
  method: 'K-Net' | 'Cash' | 'Payment Link';
  date: string;
  status: 'Completed' | 'Pending' | 'Failed';
  receiptId?: string;
  packageId?: string;
  zabihatId?: string;
}

export interface MenuItem {
  id: string;
  day: string;
  items: string[];
  date: string;
}

export interface MenuFeedback {
  id: string;
  userId: string;
  menuId: string;
  rating: number;
  comment: string;
  date: string;
}

// Mock users
export const mockUsers: User[] = [
  {
    id: '1',
    itsNumber: '12345678',
    password: '12345678',
    name: 'Ahmed Al-Mansoor',
    address: 'Salmiya, Kuwait',
    contact: '+965 9999 8888',
    email: 'ahmed@example.com',
    thaliNumber: 'TH-2024-001',
    sabilNumber: 'SB-54321',
    packageId: '1',
    isFirstLogin: false,
  },
];

// Mock packages
export const mockPackages: Package[] = [
  {
    id: '1',
    name: 'Basic Package',
    type: 'Basic',
    price: 300,
    features: [
      'Daily meals (Lunch)',
      'Standard menu',
      'Email support',
      'Monthly reports',
    ],
    validity: '12 months',
    installmentOptions: [50, 100, 150],
  },
  {
    id: '2',
    name: 'Premium Package',
    type: 'Premium',
    price: 500,
    features: [
      'Daily meals (Lunch & Dinner)',
      'Premium menu with variety',
      'Priority support',
      'Weekly menu customization',
      'Nutritional reports',
    ],
    validity: '12 months',
    installmentOptions: [100, 150, 250],
  },
  {
    id: '3',
    name: 'Family Package',
    type: 'Family',
    price: 800,
    features: [
      'Daily meals for 4 people',
      'Premium menu with variety',
      'Dedicated support line',
      'Custom dietary requirements',
      'Weekly menu customization',
      'Free delivery upgrades',
    ],
    validity: '12 months',
    installmentOptions: [150, 200, 400],
  },
];

// Mock Zabihat
export const mockZabihat: Zabihat[] = [
  {
    id: '1',
    name: 'Goat Zabihat',
    maxUnits: 50,
    availableUnits: 35,
    pricePerUnit: 45,
    description: 'Fresh halal goat meat prepared according to Islamic guidelines',
    enabled: true,
  },
  {
    id: '2',
    name: 'Cow Zabihat',
    maxUnits: 20,
    availableUnits: 12,
    pricePerUnit: 180,
    description: 'Premium halal cow meat with complete processing',
    enabled: true,
  },
  {
    id: '3',
    name: 'Sheep Zabihat',
    maxUnits: 40,
    availableUnits: 28,
    pricePerUnit: 65,
    description: 'High-quality halal sheep meat',
    enabled: true,
  },
];

// Mock payments
export const mockPayments: Payment[] = [
  {
    id: 'PAY001',
    userId: '1',
    amount: 150,
    method: 'K-Net',
    date: '2026-02-15',
    status: 'Completed',
    receiptId: 'RCP001',
    packageId: '1',
  },
  {
    id: 'PAY002',
    userId: '1',
    amount: 100,
    method: 'Cash',
    date: '2026-01-20',
    status: 'Completed',
    receiptId: 'RCP002',
    packageId: '1',
  },
];

// Mock weekly menu
export const mockWeeklyMenu: MenuItem[] = [
  {
    id: '1',
    day: 'Sunday',
    items: ['Chicken Biryani', 'Vegetable Curry', 'Raita', 'Naan Bread'],
    date: '2026-03-14',
  },
  {
    id: '2',
    day: 'Monday',
    items: ['Lamb Mandi', 'Green Salad', 'Hummus', 'Arabic Bread'],
    date: '2026-03-15',
  },
  {
    id: '3',
    day: 'Tuesday',
    items: ['Grilled Fish', 'Rice Pilaf', 'Mixed Vegetables', 'Tahini'],
    date: '2026-03-16',
  },
  {
    id: '4',
    day: 'Wednesday',
    items: ['Chicken Shawarma', 'Fattoush Salad', 'Garlic Sauce', 'Pita Bread'],
    date: '2026-03-17',
  },
  {
    id: '5',
    day: 'Thursday',
    items: ['Beef Kabsa', 'Lentil Soup', 'Yogurt', 'Arabic Bread'],
    date: '2026-03-18',
  },
];

// Mock feedback
export const mockFeedback: MenuFeedback[] = [
  {
    id: '1',
    userId: '1',
    menuId: '1',
    rating: 5,
    comment: 'Excellent taste and quality! The Chicken Biryani was perfectly cooked.',
    date: '2026-03-14',
  },
  {
    id: '2',
    userId: '1',
    menuId: '2',
    rating: 4,
    comment: 'Very good Lamb Mandi. Would love more vegetables next time.',
    date: '2026-03-15',
  },
  {
    id: '3',
    userId: '1',
    menuId: '3',
    rating: 5,
    comment: 'The grilled fish was amazing! Fresh and delicious.',
    date: '2026-03-16',
  },
  {
    id: '4',
    userId: '1',
    menuId: '4',
    rating: 3,
    comment: 'Chicken Shawarma was okay. Could use more seasoning.',
    date: '2026-03-17',
  },
  {
    id: '5',
    userId: '1',
    menuId: '5',
    rating: 5,
    comment: 'Best Beef Kabsa I have had! The lentil soup was perfect too.',
    date: '2026-03-18',
  },
];

// Application Settings
export const appSettings = {
  minimumInstallment: 50,
};

// Admin credentials
export const adminCredentials = {
  username: 'admin',
  password: 'admin123',
};