# WildPath — Flutter Camping Trip Planner (WIP)

## Quick Start

```bash
cd wildpath
flutter pub get
flutter run          # Android device/emulator
flutter run -d chrome  # Web (Chrome)
```

## File Map

```
lib/
├── main.dart                     App entry · shell · bottom nav · top bar
├── theme/app_theme.dart          Colors + ThemeData
├── models/
│   ├── trip_model.dart           Trip data + helpers
│   ├── gear_item.dart            GearItem + default lists for all 8 trip types
│   └── meal_item.dart            MealItem · BudgetItem · EmergencyContact
├── services/
│   ├── storage_service.dart      SharedPreferences persistence
│   └── weather_service.dart      Cloudflare Worker + Open-Meteo fallback
├── screens/
│   ├── onboarding_screen.dart    3-step welcome flow
│   ├── plan_screen.dart          Trip form + Summary + guided flow button
│   ├── gear_screen.dart          Checklist · swipe-to-delete · guided flow button
│   ├── meals_screen.dart         Day-by-day planner + guided flow button
│   ├── conditions_screen.dart    Weather · 7-day forecast · NWS alerts
│   └── more_screen.dart          Map · My Trips · Emergency · Budget ·
│                                 Passes & Permits · My Profile · About
└── widgets/common_widgets.dart   Shared UI components
```

## Guided Flow (matches original HTML)

Plan → Next: Pack Your Gear → Gear → Next: Plan Your Meals → Meals → Next: Track Your Budget (More)

## Trip Types (all 8)

Campsites · RV or Van · Backpacking · On the Water · Cabins · Off-Grid · Group Camp · Glamping

Each type has a custom default gear list.

## Weather Setup

Edit `lib/services/weather_service.dart`:

```dart
const String kWorkerUrl = 'https://your-worker.workers.dev';
```

Replace with your Cloudflare Worker URL. If left as placeholder, the app falls
back to Open-Meteo + weather.gov directly.

## Google Places Setup

Location autocomplete and address-to-coordinate lookups use Google Places
Autocomplete plus Place Details through a local `.env` file.

1. Copy `.env.example` to `.env`.
2. Paste your real key into:

```env
MAPS_API_KEY=your-google-geocoding-api-key
```

3. Run normally:

```bash
flutter pub get
flutter run
```

`.env` is ignored by git, so your real key will not be committed. The app reads
`MAPS_API_KEY` at startup from `lib/main.dart` and uses it in
`lib/services/weather_service.dart`.

Make sure the Google Cloud project for this key has `Places API` enabled.

## More Menu — All 7 Sections

| Section | Contents |
|---------|---------|
| Map | Campsite coords + Open in Google Maps |
| My Trips | Saved trips · Load · Delete |
| Emergency Info | Dial 911/USFS/NPS · Trip info for rescuers · 2 contacts |
| Budget | Limit · Add expenses · Swipe to delete |
| Passes & Permits | image_picker placeholder |
| My Profile | Name · Email · Camp style · Notifications |
| About WildPath | Version · Contact · Credits |

## Build APK

```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

## Build App Bundle

```bash
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

## Android Release Signing

The Android project now reads release signing values from `android/key.properties`.

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Update the values to point at your upload keystore.
3. Keep the keystore file and `key.properties` out of version control.

Example:

```properties
storeFile=../upload-keystore.jks
storePassword=your-store-password
keyAlias=upload
keyPassword=your-key-password
```

If `android/key.properties` is missing, release builds fall back to the debug keystore so local verification still works, but that APK is not suitable for Play submission.

## Android Test Commands

```bash
flutter devices
flutter run -d <device-id>
flutter build apk --debug
flutter build apk --release
```

## Known Web Note

Running on Chrome shows a "missing Noto font" warning for some emoji — this
is web-only and does not appear on Android. Emoji render natively on device.

## Developer

testdev.b@gmail.com
