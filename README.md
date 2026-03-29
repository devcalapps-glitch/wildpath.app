# WildPath — Flutter Camping Trip Planner (WIP)

## Quick Start

```bash
cd wildpath
flutter pub get
flutter run          # Android device/emulator
flutter run -d chrome  # Web (Chrome)
```

---

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
│   ├── weather_service.dart      Google Places API + Open-Meteo + weather.gov
│   ├── notification_service.dart Local push notifications + trip reminders
│   └── background_service.dart   WorkManager weather alert worker
├── screens/
│   ├── splash_screen.dart        Animated launch screen
│   ├── onboarding_screen.dart    3-step welcome flow
│   ├── plan_screen.dart          Trip form + Summary + guided flow
│   ├── gear_screen.dart          Checklist · swipe-to-delete · guided flow
│   ├── meals_screen.dart         Day-by-day planner + guided flow
│   ├── permits_screen.dart       Permit upload + manual entry + Save Trip CTA
│   ├── conditions_screen.dart    Weather · 7-day forecast · NWS alerts
│   └── more_screen.dart          Map · Budget · Emergency · Profile · About
└── widgets/common_widgets.dart   Shared UI components
```

---

## Navigation

5 bottom tabs with Material icons:

| Tab | Icon | Contents |
|-----|------|----------|
| Plan | `terrain_rounded` | Trip form → Gear → Meals → Budget → Permits (sub-tabs) |
| Weather | `wb_cloudy_outlined` | Current conditions + 7-day forecast + alerts |
| Map | `map_outlined` | Campsite map with location pin |
| My Trips | `backpack_outlined` | Saved trips · Load · Delete |
| More | `grid_view_rounded` | Emergency Info · Budget · Profile · About |

### Plan Hub Sub-tabs

Plan (0) → Gear (1) → Meals (2) → Budget (3) → Permits (4)

Guided flow: Plan → Pack Your Gear → Plan Your Meals → Track Your Budget → Add Permit → Save Trip

---

## Trip Types (all 8)

Campsites · RV or Van · Backpacking · On the Water · Cabins · Off-Grid · Group Camp · Glamping

Each type has a custom default gear list.

---

## More Menu — All Sections

| Section | Contents |
|---------|----------|
| Map | Campsite pin (specific locations) or area view (cities/regions) · Open in Google Maps |
| Emergency Info | Local emergency numbers by country · Trip info for rescuers · 2 contacts |
| Budget | Trip limit · Add expenses (slide-out sheet) · Swipe to delete · Balance summary |
| Passes & Permits | Upload permit images · Manual entry · Save Trip CTA |
| My Profile | Name · Email · Camp style · Notifications |
| About WildPath | Version · Contact · Credits |

### Emergency Info — Location-Responsive Numbers

Emergency numbers automatically adapt to the trip's GPS coordinates:

| Region | Emergency | Service 1 | Service 2 |
|--------|-----------|-----------|-----------|
| United States | 911 | USFS | NPS |
| Canada | 911 | Parks Canada | BC Emergency |
| Australia | 000 | Parks Australia | SES |
| New Zealand | 111 | DOC | LandSAR |
| United Kingdom | 999 | Mountain Rescue | Coastguard |
| Europe | 112 | Alpine Rescue | Local SAR |
| International | 112 | Local Rescue | Local Park |

---

## Environment Setup

### Google Places API

Location autocomplete uses Google Places API via a local `.env` file.

1. Copy `.env.example` to `.env`
2. Add your key:

```env
MAPS_API_KEY=your-google-places-api-key
```

3. Enable `Places API (New)` in your Google Cloud project.

`.env` is git-ignored — your key will not be committed.

### Weather

Weather data comes from [Open-Meteo](https://open-meteo.com/) (free, no key required) and [weather.gov](https://www.weather.gov/) alerts (US only, no key required).

---

## Build

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Release App Bundle (Play Store)
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

### Android Release Signing

1. Copy `android/key.properties.example` to `android/key.properties`
2. Fill in your keystore values:

```properties
storeFile=../upload-keystore.jks
storePassword=your-store-password
keyAlias=upload
keyPassword=your-key-password
```

If `android/key.properties` is missing, release builds fall back to the debug keystore (not suitable for Play Store submission).

---

## Known Notes

- Chrome (web) shows a "missing Noto font" warning for some emoji — Android-only issue, does not appear on device.
- `weather.gov` alerts are US-only; international trips show Open-Meteo data only.

---

## Developer

dev.cal.apps@gmail.com
