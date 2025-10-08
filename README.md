# Dee's Budget App - Mobile Budget & Expense Tracking Application

[![Flutter](https://img.shields.io/badge/Flutter-3.9.0-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Integrated-FFCA28?logo=firebase)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com)

## 📋 Project Information

**Title:** Design and Implementation of a Mobile Budget & Expense Tracking App

**Student:** Deborah Chibuzo Okere  
**Matric Number:** NOU213070643  
**Institution:** National Open University of Nigeria  
**Academic Session:** 2024/2025

---

## 🎯 Project Overview

Dee's Budget App is a mobile financial management application designed specifically for Nigerian users with diverse income structures. The application addresses the critical gap in existing Personal Finance Management (PFM) tools by providing **income-type personalized** budgeting experiences for:

- **Fixed Earners** - Salaried workers with stable monthly income
- **Variable Earners** - Gig workers, freelancers with irregular income
- **Hybrid Earners** - Users with both fixed salary and variable side income

### Key Innovation

Unlike conventional budgeting apps that assume stable income patterns, this application provides:

✅ **Income-type specific dashboards** tailored to each user's earning pattern  
✅ **Rule-based automation** for intelligent fund allocation  
✅ **Cash-first design** accommodating Nigeria's cash-dominant economy  
✅ **Offline-capable** functionality for areas with limited connectivity  
✅ **Context-aware** features aligned with Nigerian financial behaviors

---

## 🚀 Features

### Core Functionality

#### 1. Authentication & User Management
- Secure email/password registration and login
- Google Sign-In integration
- User profile management with income type selection
- Firebase Authentication for secure session management

#### 2. Income-Type Personalization
**Fixed Earner Dashboard:**
- Monthly budget tracking and visualization
- Salary alert notifications
- Safe-to-spend calculations
- Next payday countdown
- Recurring bill management

**Variable Earner Dashboard:**
- Weekly income/expense tracking
- Runway period calculator (days until funds depleted)
- Income volatility alerts
- Emergency fund management
- Flexible budget adjustments

**Hybrid Earner Dashboard:**
- Dual income stream tracking (salary + gigs)
- Cross-funding journal
- Income optimization tools
- Tax forecast alerts
- Transaction stream segregation

#### 3. Budget Management
- Create and manage budgets by category
- Real-time budget tracking with progress indicators
- Automatic spend calculation
- Budget overspending alerts
- Monthly/weekly budget cycles based on income type

#### 4. Transaction Management
- Manual transaction entry (income/expense)
- Category-based organization
- Transaction history with filtering
- Source tracking for income streams
- Date-based transaction queries

#### 5. Rule Engine (Planned Feature)
- User-defined automation rules
- Conditional fund allocation
- Smart savings triggers
- Expense categorization rules
- Conflict resolution protocol

#### 6. OCR Receipt Scanning (Experimental)
- Camera-based receipt capture
- Automated data extraction (amount, date, merchant)
- Manual verification and editing
- Receipt image storage

---

## 🛠️ Technical Architecture

### Technology Stack

#### Frontend
- **Framework:** Flutter 3.9.0
- **Language:** Dart
- **UI Components:** Material Design
- **State Management:** StatefulWidget (with consideration for Provider/Riverpod)

#### Backend & Database
- **Authentication:** Firebase Authentication
- **Database:** Cloud Firestore
- **Storage:** Firebase Storage (for receipt images)
- **Hosting:** Firebase Hosting (for configuration)

#### Development Tools
- **IDE:** Android Studio / VS Code
- **Version Control:** Git
- **Design:** Figma (UI/UX prototyping)
- **Build System:** Gradle

### System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Application                   │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Auth Screen │  │ Home Screen  │  │ Transaction  │  │
│  │   - Login    │  │  - Dashboard │  │    Screen    │  │
│  │   - Signup   │  │  - Stats     │  │  - Add/Edit  │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐   │
│  │            Firebase Service Layer                 │   │
│  │  - Authentication  - Firestore Queries            │   │
│  │  - Transaction CRUD  - Budget Management          │   │
│  └──────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │    Models    │  │    Utils     │  │    Theme     │  │
│  │  - User      │  │  - Currency  │  │  - Colors    │  │
│  │  - Trans.    │  │  - Formatter │  │  - Styles    │  │
│  │  - Budget    │  │              │  │              │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    Firebase Backend                      │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Firebase   │  │     Cloud    │  │   Firebase   │  │
│  │     Auth     │  │   Firestore  │  │   Storage    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Database Schema

#### Users Collection
```javascript
users/{userId}
  - uid: string
  - email: string
  - fullName: string
  - username: string
  - incomeType: string (fixed/variable/hybrid)
  - monthlyIncome: number (optional)
  - targetSavings: number (optional)
  - createdAt: timestamp
```

#### Transactions Subcollection
```javascript
transactions/{userId}/userTransactions/{transactionId}
  - id: string
  - userId: string
  - type: string (income/expense)
  - category: string
  - amount: number
  - description: string
  - date: timestamp
  - source: string (optional)
```

#### Budgets Subcollection
```javascript
budgets/{userId}/userBudgets/{budgetId}
  - id: string
  - userId: string
  - category: string
  - amount: number
  - spent: number
  - period: string (weekly/monthly)
  - startDate: timestamp
  - endDate: timestamp
```

---

## 📦 Installation & Setup

### Prerequisites
- Flutter SDK (3.9.0 or higher)
- Android Studio or VS Code with Flutter extensions
- Firebase account
- Android device or emulator (Android 5.0+)

### Setup Instructions

#### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/budget_tracker_app.git
cd budget_tracker_app
```

#### 2. Install Dependencies
```bash
flutter pub get
```

#### 3. Firebase Configuration

The project already includes Firebase configuration files:
- `android/app/google-services.json`
- `lib/firebase_options.dart`

**Note:** For security, you should create your own Firebase project:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project named "dee-s-budget-app"
3. Add an Android app with package name: `com.example.budget_tracker_app`
4. Download `google-services.json` and place in `android/app/`
5. Run FlutterFire CLI:
```bash
flutterfire configure
```

#### 4. Enable Firebase Services

In Firebase Console, enable:
- **Authentication** → Email/Password & Google providers
- **Firestore Database** → Start in production mode
- **Storage** → Default bucket

#### 5. Configure Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /userTransactions/{transactionId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /userBudgets/{budgetId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

#### 6. Run the Application
```bash
flutter run
```

---

## 🎨 Application Screenshots

### Authentication Flow
- **Login Screen** - Clean interface with email/password input
- **Signup Screen** - Income type selection during registration
- **Splash Screen** - Brand identity display during app loading

### Dashboard Views
- **Fixed Earner Dashboard** - Monthly budget tracker with stability metrics
- **Variable Earner Dashboard** - Weekly tracking with runway period
- **Hybrid Earner Dashboard** - Dual-stream income management

### Budget & Transaction Management
- **Add Transaction Screen** - Quick entry for income/expenses
- **Transactions List** - Chronological transaction history
- **Budget Progress** - Visual indicators for spending limits

---

## 🔧 Configuration

### Theme Customization
Edit `lib/theme/app_theme.dart` to customize colors:

```dart
class AppTheme {
  static const primaryBlue = Color(0xFF1E88E5);
  static const darkBlue = Color(0xFF0D47A1);
  static const green = Color(0xFF4CAF50);
  static const red = Color(0xFFF44336);
  static const orange = Color(0xFFFF9800);
}
```

### Currency Format
The app uses Nigerian Naira (₦) by default. Modify `lib/utils/currency_formatter.dart` to change currency:

```dart
static String format(double amount) {
  final formatter = NumberFormat.currency(
    symbol: '₦', // Change currency symbol here
    decimalDigits: 2,
  );
  return formatter.format(amount);
}
```

---

## 📊 Project Scope & Limitations

### Included Features ✅
- Android platform support
- User authentication and profile management
- Income-type specific dashboards
- Manual transaction entry
- Budget tracking and visualization
- Basic rule engine framework
- Firebase cloud synchronization

### Known Limitations ⚠️
- **No Banking Integration** - No direct API connection to Nigerian banks
- **Manual Entry Only** - Transactions must be entered manually or via OCR
- **Android Only** - iOS version not implemented
- **Limited OCR Accuracy** - Receipt scanning requires manual verification
- **No AI/ML Features** - No predictive analytics or intelligent forecasting
- **Single Language** - English only, no local language support
- **No Investment Tracking** - Focus is on budgeting, not portfolio management
- **Basic Reporting** - Limited export and analytics capabilities

### Future Enhancements 🔮
- iOS version development
- Bank account integration (via Paystack, Flutterwave APIs)
- Advanced rule engine with conflict resolution
- Machine learning for spending predictions
- Local language support (Yoruba, Igbo, Hausa)
- Receipt OCR improvement
- Bill payment reminders
- Collaborative budgets (family/group budgets)
- Export to CSV/PDF

---

## 🧪 Testing

### Manual Testing Checklist
- [ ] User can register with email/password
- [ ] User can login with existing credentials
- [ ] Income type selection works during signup
- [ ] Dashboard displays correctly for each income type
- [ ] Transactions can be added and viewed
- [ ] Budgets update when expenses are logged
- [ ] User can logout successfully

### Test Environment
- **Device:** Android emulator (Pixel 5, API 30)
- **Flutter Version:** 3.9.0
- **Test Approach:** Scenario-based manual testing

### Known Issues 🐛
1. **Gradle Build Issues** - Occasional dependency conflicts during Android build
2. **OCR Accuracy** - Low accuracy on handwritten or poorly lit receipts
3. **Firebase Auth Delays** - Occasional timeout during sign-in under poor network
4. **UI Responsiveness** - Some layout issues on smaller screens (< 5.5 inches)

---

## 📚 Documentation

### Academic Documentation
- **Project Proposal** - Initial project specification and objectives
- **Literature Review** - Research on PFM tools, behavioral finance, Nigerian context
- **System Design Report** - Technical architecture and methodology
- **User Manual** - End-user guide (planned)
- **Testing Report** - Validation and evaluation results (planned)

### Code Documentation
- **Inline Comments** - Key functions and complex logic documented
- **README Files** - Setup and configuration instructions
- **API Documentation** - Firebase service methods documented

### External Resources
- [Flutter Documentation](https://docs.flutter.dev)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Figma Design](https://www.figma.com/design/24AP4uBEP9F6KdILa1RpGQ/)
- [Claude AI Chat History](https://claude.ai/share/500151b4-a49a-4c04-87c0-fc773513a491)

---

## 🤝 Contributing

This is an academic project. Contributions are not currently accepted, but feedback and suggestions are welcome.

### Contact
- **Email:** [Your Email]
- **Institution:** National Open University of Nigeria
- **Supervisor:** [Supervisor Name]

---

## 📄 License

This project is developed for academic purposes as part of a final year project at the National Open University of Nigeria. All rights reserved.

### Third-Party Licenses
- Flutter - BSD 3-Clause License
- Firebase - Google Terms of Service
- Material Design Icons - Apache License 2.0

---

## 🙏 Acknowledgments

- **National Open University of Nigeria** - Academic support and guidance
- **Project Supervisor** - [Name] for continuous feedback and direction
- **Firebase Team** - For free-tier services enabling rapid development
- **Flutter Community** - For extensive documentation and packages
- **Claude AI** - For development assistance and code review
- **Nigerian Fintech Research** - Studies informing contextual design decisions

---

## 📈 Project Timeline

- **Week 1-2:** Requirements gathering and literature review
- **Week 3-4:** UI/UX design in Figma, Firebase setup
- **Week 5-8:** Core feature implementation (Auth, Dashboard, Transactions)
- **Week 9-12:** Budget management and rule engine development
- **Week 13-14:** OCR integration and testing
- **Week 15-16:** Documentation, bug fixes, and final delivery

---

## 🎓 Academic Context

This project fulfills the requirements for the final year project in Computer Science at the National Open University of Nigeria. It demonstrates:

- **Technical Proficiency** - Mobile app development with Flutter and Firebase
- **Research Skills** - Literature review on behavioral finance and Nigerian fintech
- **Problem-Solving** - Addressing real-world financial management challenges
- **Innovation** - Income-type personalization in PFM tools
- **Contextual Awareness** - Design aligned with Nigerian socio-economic realities

---

**Version:** 1.0.0  
**Last Updated:** October 2024  
**Status:** Development Complete, Testing In Progress# Dee's Budget App - Mobile Budget & Expense Tracking Application

[![Flutter](https://img.shields.io/badge/Flutter-3.9.0-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Integrated-FFCA28?logo=firebase)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com)

## 📋 Project Information

**Title:** Design and Implementation of a Mobile Budget & Expense Tracking App

**Student:** Deborah Chibuzo Okere  
**Matric Number:** NOU213070643  
**Institution:** National Open University of Nigeria  
**Academic Session:** 2024/2025

---

## 🎯 Project Overview

Dee's Budget App is a mobile financial management application designed specifically for Nigerian users with diverse income structures. The application addresses the critical gap in existing Personal Finance Management (PFM) tools by providing **income-type personalized** budgeting experiences for:

- **Fixed Earners** - Salaried workers with stable monthly income
- **Variable Earners** - Gig workers, freelancers with irregular income
- **Hybrid Earners** - Users with both fixed salary and variable side income

### Key Innovation

Unlike conventional budgeting apps that assume stable income patterns, this application provides:

✅ **Income-type specific dashboards** tailored to each user's earning pattern  
✅ **Rule-based automation** for intelligent fund allocation  
✅ **Cash-first design** accommodating Nigeria's cash-dominant economy  
✅ **Offline-capable** functionality for areas with limited connectivity  
✅ **Context-aware** features aligned with Nigerian financial behaviors

---

## 🚀 Features

### Core Functionality

#### 1. Authentication & User Management
- Secure email/password registration and login
- Google Sign-In integration
- User profile management with income type selection
- Firebase Authentication for secure session management

#### 2. Income-Type Personalization
**Fixed Earner Dashboard:**
- Monthly budget tracking and visualization
- Salary alert notifications
- Safe-to-spend calculations
- Next payday countdown
- Recurring bill management

**Variable Earner Dashboard:**
- Weekly income/expense tracking
- Runway period calculator (days until funds depleted)
- Income volatility alerts
- Emergency fund management
- Flexible budget adjustments

**Hybrid Earner Dashboard:**
- Dual income stream tracking (salary + gigs)
- Cross-funding journal
- Income optimization tools
- Tax forecast alerts
- Transaction stream segregation

#### 3. Budget Management
- Create and manage budgets by category
- Real-time budget tracking with progress indicators
- Automatic spend calculation
- Budget overspending alerts
- Monthly/weekly budget cycles based on income type

#### 4. Transaction Management
- Manual transaction entry (income/expense)
- Category-based organization
- Transaction history with filtering
- Source tracking for income streams
- Date-based transaction queries

#### 5. Rule Engine (Planned Feature)
- User-defined automation rules
- Conditional fund allocation
- Smart savings triggers
- Expense categorization rules
- Conflict resolution protocol

#### 6. OCR Receipt Scanning (Experimental)
- Camera-based receipt capture
- Automated data extraction (amount, date, merchant)
- Manual verification and editing
- Receipt image storage

---

## 🛠️ Technical Architecture

### Technology Stack

#### Frontend
- **Framework:** Flutter 3.9.0
- **Language:** Dart
- **UI Components:** Material Design
- **State Management:** StatefulWidget (with consideration for Provider/Riverpod)

#### Backend & Database
- **Authentication:** Firebase Authentication
- **Database:** Cloud Firestore
- **Storage:** Firebase Storage (for receipt images)
- **Hosting:** Firebase Hosting (for configuration)

#### Development Tools
- **IDE:** Android Studio / VS Code
- **Version Control:** Git
- **Design:** Figma (UI/UX prototyping)
- **Build System:** Gradle

### System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Application                   │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Auth Screen │  │ Home Screen  │  │ Transaction  │  │
│  │   - Login    │  │  - Dashboard │  │    Screen    │  │
│  │   - Signup   │  │  - Stats     │  │  - Add/Edit  │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐   │
│  │            Firebase Service Layer                 │   │
│  │  - Authentication  - Firestore Queries            │   │
│  │  - Transaction CRUD  - Budget Management          │   │
│  └──────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │    Models    │  │    Utils     │  │    Theme     │  │
│  │  - User      │  │  - Currency  │  │  - Colors    │  │
│  │  - Trans.    │  │  - Formatter │  │  - Styles    │  │
│  │  - Budget    │  │              │  │              │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    Firebase Backend                      │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Firebase   │  │     Cloud    │  │   Firebase   │  │
│  │     Auth     │  │   Firestore  │  │   Storage    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Database Schema

#### Users Collection
```javascript
users/{userId}
  - uid: string
  - email: string
  - fullName: string
  - username: string
  - incomeType: string (fixed/variable/hybrid)
  - monthlyIncome: number (optional)
  - targetSavings: number (optional)
  - createdAt: timestamp
```

#### Transactions Subcollection
```javascript
transactions/{userId}/userTransactions/{transactionId}
  - id: string
  - userId: string
  - type: string (income/expense)
  - category: string
  - amount: number
  - description: string
  - date: timestamp
  - source: string (optional)
```

#### Budgets Subcollection
```javascript
budgets/{userId}/userBudgets/{budgetId}
  - id: string
  - userId: string
  - category: string
  - amount: number
  - spent: number
  - period: string (weekly/monthly)
  - startDate: timestamp
  - endDate: timestamp
```

---

## 📦 Installation & Setup

### Prerequisites
- Flutter SDK (3.9.0 or higher)
- Android Studio or VS Code with Flutter extensions
- Firebase account
- Android device or emulator (Android 5.0+)

### Setup Instructions

#### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/budget_tracker_app.git
cd budget_tracker_app
```

#### 2. Install Dependencies
```bash
flutter pub get
```

#### 3. Firebase Configuration

The project already includes Firebase configuration files:
- `android/app/google-services.json`
- `lib/firebase_options.dart`

**Note:** For security, you should create your own Firebase project:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project named "dee-s-budget-app"
3. Add an Android app with package name: `com.example.budget_tracker_app`
4. Download `google-services.json` and place in `android/app/`
5. Run FlutterFire CLI:
```bash
flutterfire configure
```

#### 4. Enable Firebase Services

In Firebase Console, enable:
- **Authentication** → Email/Password & Google providers
- **Firestore Database** → Start in production mode
- **Storage** → Default bucket

#### 5. Configure Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /userTransactions/{transactionId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /userBudgets/{budgetId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

#### 6. Run the Application
```bash
flutter run
```

---

## 🎨 Application Screenshots

### Authentication Flow
- **Login Screen** - Clean interface with email/password input
- **Signup Screen** - Income type selection during registration
- **Splash Screen** - Brand identity display during app loading

### Dashboard Views
- **Fixed Earner Dashboard** - Monthly budget tracker with stability metrics
- **Variable Earner Dashboard** - Weekly tracking with runway period
- **Hybrid Earner Dashboard** - Dual-stream income management

### Budget & Transaction Management
- **Add Transaction Screen** - Quick entry for income/expenses
- **Transactions List** - Chronological transaction history
- **Budget Progress** - Visual indicators for spending limits

---

## 🔧 Configuration

### Theme Customization
Edit `lib/theme/app_theme.dart` to customize colors:

```dart
class AppTheme {
  static const primaryBlue = Color(0xFF1E88E5);
  static const darkBlue = Color(0xFF0D47A1);
  static const green = Color(0xFF4CAF50);
  static const red = Color(0xFFF44336);
  static const orange = Color(0xFFFF9800);
}
```

### Currency Format
The app uses Nigerian Naira (₦) by default. Modify `lib/utils/currency_formatter.dart` to change currency:

```dart
static String format(double amount) {
  final formatter = NumberFormat.currency(
    symbol: '₦', // Change currency symbol here
    decimalDigits: 2,
  );
  return formatter.format(amount);
}
```

---

## 📊 Project Scope & Limitations

### Included Features ✅
- Android platform support
- User authentication and profile management
- Income-type specific dashboards
- Manual transaction entry
- Budget tracking and visualization
- Basic rule engine framework
- Firebase cloud synchronization

### Known Limitations ⚠️
- **No Banking Integration** - No direct API connection to Nigerian banks
- **Manual Entry Only** - Transactions must be entered manually or via OCR
- **Android Only** - iOS version not implemented
- **Limited OCR Accuracy** - Receipt scanning requires manual verification
- **No AI/ML Features** - No predictive analytics or intelligent forecasting
- **Single Language** - English only, no local language support
- **No Investment Tracking** - Focus is on budgeting, not portfolio management
- **Basic Reporting** - Limited export and analytics capabilities

### Future Enhancements 🔮
- iOS version development
- Bank account integration (via Paystack, Flutterwave APIs)
- Advanced rule engine with conflict resolution
- Machine learning for spending predictions
- Local language support (Yoruba, Igbo, Hausa)
- Receipt OCR improvement
- Bill payment reminders
- Collaborative budgets (family/group budgets)
- Export to CSV/PDF

---

## 🧪 Testing

### Manual Testing Checklist
- [ ] User can register with email/password
- [ ] User can login with existing credentials
- [ ] Income type selection works during signup
- [ ] Dashboard displays correctly for each income type
- [ ] Transactions can be added and viewed
- [ ] Budgets update when expenses are logged
- [ ] User can logout successfully

### Test Environment
- **Device:** Android emulator (Pixel 5, API 30)
- **Flutter Version:** 3.9.0
- **Test Approach:** Scenario-based manual testing

### Known Issues 🐛
1. **Gradle Build Issues** - Occasional dependency conflicts during Android build
2. **OCR Accuracy** - Low accuracy on handwritten or poorly lit receipts
3. **Firebase Auth Delays** - Occasional timeout during sign-in under poor network
4. **UI Responsiveness** - Some layout issues on smaller screens (< 5.5 inches)

---

## 📚 Documentation

### Academic Documentation
- **Project Proposal** - Initial project specification and objectives
- **Literature Review** - Research on PFM tools, behavioral finance, Nigerian context
- **System Design Report** - Technical architecture and methodology
- **User Manual** - End-user guide (planned)
- **Testing Report** - Validation and evaluation results (planned)

### Code Documentation
- **Inline Comments** - Key functions and complex logic documented
- **README Files** - Setup and configuration instructions
- **API Documentation** - Firebase service methods documented

### External Resources
- [Flutter Documentation](https://docs.flutter.dev)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Figma Design](https://www.figma.com/design/24AP4uBEP9F6KdILa1RpGQ/)
- [Claude AI Chat History](https://claude.ai/share/500151b4-a49a-4c04-87c0-fc773513a491)

---

## 🤝 Contributing

This is an academic project. Contributions are not currently accepted, but feedback and suggestions are welcome.

### Contact
- **Email:** [Your Email]
- **Institution:** National Open University of Nigeria
- **Supervisor:** [Supervisor Name]

---

## 📄 License

This project is developed for academic purposes as part of a final year project at the National Open University of Nigeria. All rights reserved.

### Third-Party Licenses
- Flutter - BSD 3-Clause License
- Firebase - Google Terms of Service
- Material Design Icons - Apache License 2.0

---

## 🙏 Acknowledgments

- **National Open University of Nigeria** - Academic support and guidance
- **Project Supervisor** - [Name] for continuous feedback and direction
- **Firebase Team** - For free-tier services enabling rapid development
- **Flutter Community** - For extensive documentation and packages
- **Claude AI** - For development assistance and code review
- **Nigerian Fintech Research** - Studies informing contextual design decisions

---

## 📈 Project Timeline

- **Week 1-2:** Requirements gathering and literature review
- **Week 3-4:** UI/UX design in Figma, Firebase setup
- **Week 5-8:** Core feature implementation (Auth, Dashboard, Transactions)
- **Week 9-12:** Budget management and rule engine development
- **Week 13-14:** OCR integration and testing
- **Week 15-16:** Documentation, bug fixes, and final delivery

---

## 🎓 Academic Context

This project fulfills the requirements for the final year project in Computer Science at the National Open University of Nigeria. It demonstrates:

- **Technical Proficiency** - Mobile app development with Flutter and Firebase
- **Research Skills** - Literature review on behavioral finance and Nigerian fintech
- **Problem-Solving** - Addressing real-world financial management challenges
- **Innovation** - Income-type personalization in PFM tools
- **Contextual Awareness** - Design aligned with Nigerian socio-economic realities

---

**Version:** 1.0.0  
**Last Updated:** October 2024  
**Status:** Development Complete, Testing In Progress