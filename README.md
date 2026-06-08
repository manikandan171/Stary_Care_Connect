# StrayCare Connect 🐾

A comprehensive Flutter application designed to facilitate the rescue, treatment, and management of stray animals. The app connects citizens, volunteers, NGOs, and veterinary professionals to ensure efficient animal rescue operations.

## 🌟 Key Features

*   **Role-Based System**: Distinct interfaces and capabilities for Citizens, Volunteers, NGOs, and Vets.
*   **Real-time Tracking**: Track the status of an animal report from discovery to recovery.
*   **Geo-Location**: View and manage nearby rescue cases using map integration.
*   **Medical Records**: Dedicated section for veterinarians to log diagnoses, treatments, and recovery status.
*   **Scalable Backend**: Powered by Firebase (Authentication, Firestore Database, Storage).
*   **Immutable Audit Logs**: Comprehensive rescue logs ensure transparency and accountability.

## 📱 User Roles

1.  **Citizen**: Report injured animals, upload photos, and track the status of reported rescues.
2.  **Volunteer**: Discover nearby rescue cases, accept missions, update status, and coordinate with clinics.
3.  **NGO**: Oversee area operations, assign volunteers to specific cases, and view analytical data.
4.  **Vet**: Receive emergency alerts, create detailed medical records, and log treatments for rescued animals.

## 🛠️ Technology Stack

*   **Frontend**: Flutter (Dart)
*   **State Management**: Riverpod
*   **Backend**: Firebase (Auth, Firestore, Storage)
*   **Location & Maps**: Geolocator, OpenStreetMap (flutter_map) / Geocoding

## 🚀 Getting Started

To run this project locally:

1.  Ensure you have [Flutter](https://docs.flutter.dev/get-started/install) installed.
2.  Clone the repository.
3.  Run `flutter pub get` to install dependencies.
4.  Configure Firebase for your environment (add `google-services.json` / `GoogleService-Info.plist` and `firebase_options.dart`).
5.  Run `flutter run` on your preferred device or emulator.

## 🔒 Security & Architecture

The app employs robust Firebase security rules to ensure data privacy based on roles. Images are stored securely in Firebase Storage, and references are kept in Firestore. Detailed architecture and database schemas can be found in `ARCHITECTURE.md`.
