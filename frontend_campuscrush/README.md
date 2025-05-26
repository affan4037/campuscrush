# Campus Connect

A social networking app for university students.

## Features

- **Authentication**: Login, registration, email verification, and password reset
- **User Management**: Profile viewing and editing
- **Social Networking**: Posts, comments, reactions, and friend management
- **Notifications**: Real-time notifications for social interactions

## Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / VS Code with Flutter extensions

### Installation

1. Clone the repository
2. Navigate to the project directory
3. Install dependencies:
   ```
   flutter pub get
   ```
4. Run the app:
   ```
   flutter run
   ```

## Project Structure

```
lib/
├── components/           # Reusable UI components
├── modules/              # Feature modules
│   ├── auth/             # Authentication module
│   ├── user_management/  # User management module
│   ├── posts/            # Posts module
│   ├── comments/         # Comments module
│   ├── reactions/        # Reactions module
│   ├── friendships/      # Friendships module
│   └── notifications/    # Notifications module
├── services/             # API and storage services
├── utils/                # Utility functions and constants
└── main.dart             # App entry point
```

## Testing

To run the tests:
```
flutter test
```

## Authentication Module Testing

To test the authentication module, use the `AuthTestScreen` which provides a simple interface for testing login, registration, and logout functionality.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
