import 'package:flutter_test/flutter_test.dart';
import 'package:wildpath/services/weather_service.dart';

void main() {
  group('WeatherService.parseStructuredPlaceDetails', () {
    test('extracts country and region from structured address components', () {
      final details = WeatherService.parseStructuredPlaceDetails([
        {
          'longText': 'Broadford',
          'shortText': 'Broadford',
          'types': ['locality', 'political']
        },
        {
          'longText': 'Scotland',
          'shortText': 'Scotland',
          'types': ['administrative_area_level_1', 'political']
        },
        {
          'longText': 'United Kingdom',
          'shortText': 'GB',
          'types': ['country', 'political']
        },
      ]);

      expect(details.locality, 'Broadford');
      expect(details.region, 'Scotland');
      expect(details.country, 'United Kingdom');
      expect(details.bestLocalityLabel, 'Broadford');
    });

    test('falls back to postal town when locality is absent', () {
      final details = WeatherService.parseStructuredPlaceDetails([
        {
          'longText': 'Golspie',
          'shortText': 'Golspie',
          'types': ['postal_town']
        },
        {
          'longText': 'Scotland',
          'shortText': 'Scotland',
          'types': ['administrative_area_level_1', 'political']
        },
        {
          'longText': 'United Kingdom',
          'shortText': 'GB',
          'types': ['country', 'political']
        },
      ]);

      expect(details.locality, 'Golspie');
      expect(details.region, 'Scotland');
      expect(details.country, 'United Kingdom');
    });

    test('supports reverse geocode style long_name keys', () {
      final details = WeatherService.parseStructuredPlaceDetails([
        {
          'long_name': 'Sooke',
          'short_name': 'Sooke',
          'types': ['locality', 'political']
        },
        {
          'long_name': 'British Columbia',
          'short_name': 'BC',
          'types': ['administrative_area_level_1', 'political']
        },
        {
          'long_name': 'Canada',
          'short_name': 'CA',
          'types': ['country', 'political']
        },
      ]);

      expect(details.locality, 'Sooke');
      expect(details.region, 'British Columbia');
      expect(details.country, 'Canada');
    });
  });
}
