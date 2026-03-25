import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wildpath/models/gear_item.dart';
import 'package:wildpath/models/meal_item.dart';
import 'package:wildpath/models/trip_model.dart';
import 'package:wildpath/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService trip scoping', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
    });

    test('keeps gear, meals, budget, and contacts isolated per trip', () async {
      const tripA = 'trip-a';
      const tripB = 'trip-b';

      await storage.saveGear(tripA, [
        GearItem(id: 'g1', label: 'Tent', category: 'Shelter'),
      ]);
      await storage.saveGear(tripB, [
        GearItem(id: 'g2', label: 'Stove', category: 'Kitchen'),
      ]);

      await storage.saveMeals(tripA, [
        MealItem(
          id: 'm1',
          dateKey: '2026-03-27',
          mealType: MealType.breakfast,
          name: 'Oatmeal',
        ),
      ]);
      await storage.saveMeals(tripB, [
        MealItem(
          id: 'm2',
          dateKey: '2026-04-01',
          mealType: MealType.dinner,
          name: 'Pasta',
        ),
      ]);

      await storage.saveBudget(tripA, [
        BudgetItem(
          id: 'b1',
          description: 'Camp fee',
          amount: 24,
          category: BudgetCategory.campsite,
        ),
      ]);
      await storage.setBudgetTotal(tripA, 100);
      await storage.saveBudget(tripB, [
        BudgetItem(
          id: 'b2',
          description: 'Fuel',
          amount: 40,
          category: BudgetCategory.fuel,
        ),
      ]);
      await storage.setBudgetTotal(tripB, 150);

      await storage.saveEmContacts(tripA, [
        EmergencyContact(id: 'e1', name: 'Alex', phone: '111'),
      ]);
      await storage.saveEmContacts(tripB, [
        EmergencyContact(id: 'e2', name: 'Blair', phone: '222'),
      ]);

      expect(storage.loadGear(tripA).single.label, 'Tent');
      expect(storage.loadGear(tripB).single.label, 'Stove');
      expect(storage.loadMeals(tripA).single.name, 'Oatmeal');
      expect(storage.loadMeals(tripB).single.name, 'Pasta');
      expect(storage.loadBudget(tripA).single.description, 'Camp fee');
      expect(storage.loadBudget(tripB).single.description, 'Fuel');
      expect(storage.budgetTotal(tripA), 100);
      expect(storage.budgetTotal(tripB), 150);
      expect(storage.loadEmContacts(tripA).single.name, 'Alex');
      expect(storage.loadEmContacts(tripB).single.name, 'Blair');
    });

    test('migrates legacy single-trip data into the current trip', () async {
      SharedPreferences.setMockInitialValues({
        'wildpath_current_trip_v2': TripModel(id: 'legacy-trip').toJsonString(),
        'wildpath_gear_v2':
            '[{"id":"g1","label":"Tent","qty":"","category":"Shelter","checked":false,"isCustom":false}]',
        'wildpath_meals_v2':
            '[{"id":"m1","dateKey":"2026-03-27","mealType":"breakfast","name":"Eggs","note":""}]',
        'wildpath_budget_v2':
            '[{"id":"b1","description":"Fee","amount":30,"category":"campsite"}]',
        'wildpath_budget_total_v2': 120.0,
        'wildpath_em_contacts_v2': '[{"id":"e1","name":"Casey","phone":"333"}]',
      });

      final migrated = StorageService();
      await migrated.init();

      expect(migrated.loadGear('legacy-trip').single.label, 'Tent');
      expect(migrated.loadMeals('legacy-trip').single.name, 'Eggs');
      expect(migrated.loadBudget('legacy-trip').single.description, 'Fee');
      expect(migrated.budgetTotal('legacy-trip'), 120);
      expect(migrated.loadEmContacts('legacy-trip').single.name, 'Casey');
    });
  });
}
