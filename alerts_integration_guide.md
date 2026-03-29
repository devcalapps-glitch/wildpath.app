# WildPath — Alerts & News Integration Guide

## Current Architecture

The **Weather** tab and the **News** section inside it are powered by two data sources and one local rule engine. No external news API or CMS is involved.

---

## Data Sources

### 1. Open-Meteo (weather data)
- **URL:** `https://api.open-meteo.com/v1/forecast`
- **Auth:** None — completely free, no API key required
- **Called by:** `WeatherService._fetchOpenMeteo()` in `lib/services/weather_service.dart`
- **Payload requested:**
  - `current`: temperature, apparent temperature, humidity, precipitation, weather code, wind speed
  - `daily`: max/min temp, precipitation sum, weather code — 7-day window
  - `timezone=auto` so times are local to the coordinates
- **Timeout:** 10 seconds
- **Result type:** `WeatherData` (parsed from `WeatherData.fromOpenMeteo()`)

### 2. NWS Alerts API (official US weather alerts)
- **URL:** `https://api.weather.gov/alerts/active?point={lat},{lng}`
- **Auth:** None — public US government API
- **Called by:** Same `_fetchOpenMeteo()` method, after the Open-Meteo call succeeds
- **Timeout:** 6 seconds (shorter — treated as optional enrichment)
- **Failure handling:** Wrapped in `try/catch {}` — if it fails, the app still shows weather with an empty alerts list
- **Result type:** `List<WeatherAlert>` — up to 5 alerts taken from `features[]`
- **Severity mapping:**

  | NWS severity string | Emoji shown |
  |---|---|
  | `extreme` | 🆘 |
  | `severe` | ⛈ |
  | anything else | ⚠ |

- **US-only limitation:** `api.weather.gov` only covers US locations. For international coordinates it returns a non-200 or empty response, which is silently ignored — no alerts are shown.

---

## WMO Weather Code → Condition/Emoji Mapping

Open-Meteo uses WMO weather interpretation codes (integers). These are decoded in `WeatherData._wmoCondition()` and `_wmoEmoji()`:

| WMO range | Condition | Emoji |
|---|---|---|
| 0 | Clear Sky | ☀ |
| 1–2 | Partly Cloudy | ⛅ |
| 3 | Overcast | ☁ |
| 4–49 | Fog | 🌫 |
| 50–67 | Drizzle / Rain | 🌧 |
| 68–77 | Snow | ❄ |
| 78–82 | Rain Showers | 🌦 |
| 83–86 | Snow Showers | 🌨 |
| 87–99 | Thunderstorm | ⛈ |

---

## News Tab — Local Rule Engine

The News tab (`_ConditionsSection.news`) does **not** call any external news API. All cards are generated locally in `_buildCampgroundNews()` in `lib/screens/conditions_screen.dart`.

### How cards are generated

The method takes the live `WeatherData` and evaluates rules in order. Up to **4 cards** are returned (`.take(4)`).

| Rule | Card title | Source label |
|---|---|---|
| `w.alerts.isNotEmpty` | "Active area alerts for {location}" | National Weather Service alert feed |
| Forecast has ≥1 day with precipMm ≥ 5 | "Wet setup conditions possible" | Open-Meteo forecast |
| Current wind ≥ 15 mph | "Wind-sensitive campsite setup" | Open-Meteo current conditions |
| Lowest forecast overnight ≤ 36°F | "Cold overnight temperatures" | Open-Meteo forecast |
| Highest forecast daytime ≥ 88°F | "Hot daytime exposure window" | Open-Meteo forecast |
| Trip type = `Backpacking` | "Backcountry conditions check recommended" | WildPath trip briefing |
| Trip type = `RV or Van` | "Vehicle access and parking check" | WildPath trip briefing |
| Always (fallback) | "Campground bulletin board check" | WildPath trip briefing |

### Dynamic values interpolated into card body
- `{location}` — first 2 comma-parts of the location label (e.g., "Sedona, Arizona")
- `{wetDays}` — count of forecast days with ≥5mm precipitation
- `{windMph}` — rounded current wind speed
- `{coldNight}` — rounded minimum overnight temp across the 7-day forecast
- `{hotDay}` — rounded maximum daytime temp across the 7-day forecast

---

## Trigger Flow

```
User enters campsite location in Plan tab
        ↓
ConditionsScreen.didUpdateWidget() detects campsite change
        ↓
_load(location) called
        ↓
If trip has saved lat/lng → use them directly
Else → WeatherService.geocode(location) → Google Places API for coordinates
        ↓
WeatherService.fetchWeather(lat, lng)
  → Open-Meteo API (weather + 7-day forecast)
  → NWS Alerts API (US only, optional)
        ↓
WeatherData stored in _ConditionsScreenState._weather
        ↓
Forecast tab → renders 7-day cards
Alerts tab  → renders WeatherAlert list (or "No active alerts")
News tab    → _buildCampgroundNews(WeatherData) → rule engine → up to 4 cards
```

---

## Adding a Real News Source

To replace or supplement the rule-engine cards with live data (e.g., NPS RSS, USFS alerts, recreation.gov notices), the integration point is:

1. **Add a method to `WeatherService`** that fetches and parses the external feed given `lat`/`lng` or a park name. Return a `List<_CampgroundNewsItem>` (or a new model).
2. **Store the result in `_ConditionsScreenState`** alongside `_weather`.
3. **Merge or replace** the `newsItems` list in `_buildCampgroundNews()` with the live results.
4. **Handle loading/error state** — the existing `_loading` bool can cover this, or add a separate `_newsLoading` flag.

Candidate live sources:
- **NPS Alerts RSS:** `https://www.nps.gov/feeds/alerts.xml?parkCode={code}` — requires mapping location to a park code
- **USDA Forest Service Alerts:** `https://www.fs.usda.gov/alerts` — no public structured API currently
- **InciWeb (wildfire):** `https://inciweb.nwcg.gov/feeds/rss/incidents/` — RSS, filterable by state
- **AirNow (air quality):** `https://www.airnowapi.org/aq/observation/latLong/current/` — requires free API key, returns AQI by coordinates (directly lat/lng-compatible, no park-code mapping needed)
