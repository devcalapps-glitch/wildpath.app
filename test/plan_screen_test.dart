import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildpath/screens/plan_screen.dart';
import 'package:wildpath/models/trip_model.dart';
import 'package:wildpath/services/storage_service.dart';
import 'test_helpers.dart';

class _PlanScreenHarness extends StatefulWidget {
  final StorageService storage;
  final TripModel initialTrip;

  const _PlanScreenHarness({
    required this.storage,
    required this.initialTrip,
  });

  @override
  State<_PlanScreenHarness> createState() => _PlanScreenHarnessState();
}

class _PlanScreenHarnessState extends State<_PlanScreenHarness> {
  late TripModel _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.initialTrip;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: PlanScreen(
            storage: widget.storage,
            trip: _trip,
            onTripChanged: (trip) => setState(() => _trip = trip),
          ),
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mergeParsedLocationRegion', () {
    test('keeps the selected state when a result omits it', () {
      expect(
        mergeParsedLocationRegion(
          currentCountry: 'United States',
          currentRegion: 'Florida',
          parsedCountry: 'United States',
          parsedRegion: '',
        ),
        'Florida',
      );
    });

    test('uses the parsed state when the result includes one', () {
      expect(
        mergeParsedLocationRegion(
          currentCountry: 'United States',
          currentRegion: 'Florida',
          parsedCountry: 'United States',
          parsedRegion: 'Georgia',
        ),
        'Georgia',
      );
    });

    test('does not carry a state across countries', () {
      expect(
        mergeParsedLocationRegion(
          currentCountry: 'United States',
          currentRegion: 'Florida',
          parsedCountry: 'Canada',
          parsedRegion: '',
        ),
        isEmpty,
      );
    });
  });

  testWidgets('saving a trip clears the plan form', (tester) async {
    setUpFlutterSecureStorageMock();
    SharedPreferences.setMockInitialValues({
      'wildpath_user_country': 'United States',
      'wildpath_notif_trips': false,
    });

    final storage = StorageService();
    await storage.init();

    await tester.pumpWidget(_PlanScreenHarness(
      storage: storage,
      initialTrip: TripModel(id: 'trip-1', country: 'United States'),
    ));
    await tester.pumpAndSettle();

    final tripNameField = find.byType(TextFormField).at(0);
    final destinationField = find.byType(TextFormField).at(2);

    await tester.enterText(tripNameField, 'Test Trip');
    await tester.enterText(destinationField, 'Yosemite');
    await tester.pump();

    final saveTripButton = find.widgetWithText(ElevatedButton, 'Save Trip');
    await tester.ensureVisible(saveTripButton);
    await tester.tap(saveTripButton);
    await tester.pumpAndSettle();

    final confirmSaveButton =
        find.widgetWithText(ElevatedButton, '💾  SAVE TO MY TRIPS');
    await tester.tap(confirmSaveButton);
    await tester.pumpAndSettle();

    final refreshedFields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(refreshedFields.elementAt(0).controller!.text, isEmpty);
    expect(refreshedFields.elementAt(2).controller!.text, isEmpty);

    final savedTrips = storage.loadSavedTrips();
    expect(savedTrips, hasLength(1));
    expect(savedTrips.single.name, 'Test Trip');
    expect(savedTrips.single.destination, 'Yosemite');

    final currentTrip = storage.loadCurrentTrip();
    expect(currentTrip, isNotNull);
    expect(currentTrip!.id, isNot('trip-1'));
    expect(currentTrip.name, isEmpty);
    expect(currentTrip.destination, isEmpty);
  });

  testWidgets('destination drives read-only region and country fields',
      (tester) async {
    setUpFlutterSecureStorageMock();
    SharedPreferences.setMockInitialValues({
      'wildpath_user_country': 'United States',
    });

    final storage = StorageService();
    await storage.init();

    await tester.pumpWidget(_PlanScreenHarness(
      storage: storage,
      initialTrip: TripModel(
        id: 'trip-locked',
        country: 'United States',
        region: 'Arizona',
        destination: 'Cage Creek',
        placeId: 'place-123',
        lat: 34.123,
        lng: -111.456,
      ),
    ));
    await tester.pumpAndSettle();

    final fields = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(fields.elementAt(3).controller.text, 'Arizona');
    expect(fields.elementAt(3).readOnly, isTrue);
    expect(fields.elementAt(4).controller.text, 'United States');
    expect(fields.elementAt(4).readOnly, isTrue);
  });

  testWidgets('editing destination clears autopopulated region and country',
      (tester) async {
    setUpFlutterSecureStorageMock();
    SharedPreferences.setMockInitialValues({});

    final storage = StorageService();
    await storage.init();

    await tester.pumpWidget(_PlanScreenHarness(
      storage: storage,
      initialTrip: TripModel(
        id: 'trip-editing',
        country: 'United States',
        region: 'Arizona',
        destination: 'Cage Creek',
        placeId: 'place-123',
        lat: 34.123,
        lng: -111.456,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(2), 'New Spot');
    await tester.pump();

    final fields = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(fields.elementAt(3).controller.text, isEmpty);
    expect(fields.elementAt(4).controller.text, isEmpty);
  });
}
