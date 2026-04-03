import 'package:flutter_test/flutter_test.dart';
import 'package:wildpath/models/trip_model.dart';

void main() {
  group('TripModel locationSearchQuery', () {
    test('rebuilds a fuller query when stored campsite only mirrors display',
        () {
      final trip = TripModel(
        id: 'trip-1',
        campsite: 'Sedona, Arizona',
        country: 'United States',
        region: 'Arizona',
        destination: 'Sedona',
      );

      expect(trip.locationDisplay, 'Sedona, Arizona');
      expect(trip.locationSearchQuery, 'Sedona, Arizona, United States');
    });

    test('preserves a richer stored search label from a resolved selection',
        () {
      final trip = TripModel(
        id: 'trip-2',
        campsite: 'Mather Campground, Grand Canyon Village, AZ 86023, USA',
        country: 'United States',
        region: 'Arizona',
        destination: 'Mather Campground, Grand Canyon Village',
      );

      expect(
        trip.locationSearchQuery,
        'Mather Campground, Grand Canyon Village, AZ 86023, USA',
      );
    });
  });

  group('TripModel countriesMatch', () {
    test('treats UK constituent countries as matching the United Kingdom', () {
      expect(TripModel.countriesMatch('Scotland', 'United Kingdom'), isTrue);
      expect(TripModel.countriesMatch('United Kingdom', 'Scotland'), isTrue);
      expect(TripModel.countriesMatch('Wales', 'United Kingdom'), isTrue);
      expect(TripModel.countriesMatch('England', 'United Kingdom'), isTrue);
      expect(
        TripModel.countriesMatch('Northern Ireland', 'United Kingdom'),
        isTrue,
      );
    });

    test('still rejects unrelated countries', () {
      expect(TripModel.countriesMatch('Canada', 'United Kingdom'), isFalse);
    });
  });

  group('TripModel placeId', () {
    test('round-trips placeId through json', () {
      final trip = TripModel(
        id: 'trip-3',
        destination: 'Cage Creek',
        placeId: 'place-123',
      );

      final restored = TripModel.fromJson(trip.toJson());
      expect(restored.placeId, 'place-123');
    });

    test('reads legacy place_id payloads', () {
      final trip = TripModel.fromJson({
        'id': 'trip-4',
        'destination': 'Cage Creek',
        'place_id': 'legacy-place-456',
      });

      expect(trip.placeId, 'legacy-place-456');
    });
  });
}
