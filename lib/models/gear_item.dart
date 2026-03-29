class GearItem {
  String id;
  String label;
  String qty;
  String category;
  bool checked;
  bool isCustom;

  GearItem({
    required this.id,
    required this.label,
    this.qty = '',
    required this.category,
    this.checked = false,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'qty': qty,
        'category': category,
        'checked': checked,
        'isCustom': isCustom,
      };

  factory GearItem.fromJson(Map<String, dynamic> j) => GearItem(
        id: j['id'] ?? '',
        label: j['label'] ?? '',
        qty: j['qty'] ?? '',
        category: j['category'] ?? '',
        checked: j['checked'] ?? false,
        isCustom: j['isCustom'] ?? false,
      );

  GearItem copyWith({bool? checked}) => GearItem(
        id: id,
        label: label,
        qty: qty,
        category: category,
        checked: checked ?? this.checked,
        isCustom: isCustom,
      );
}

class GearLists {
  static Map<String, List<Map<String, String>>> byTripType(String tripType) {
    switch (tripType) {
      case 'Backpacking':
        return _backpacking;
      case 'RV or Van':
        return _rvVan;
      case 'On the Water':
        return _onTheWater;
      case 'Cabins':
        return _cabins;
      case 'Off-Grid':
        return _offGrid;
      case 'Group Camp':
        return _groupCamp;
      case 'Glamping':
        return _glamping;
      default:
        return _campsites;
    }
  }

  static const Map<String, List<Map<String, String>>> _campsites = {
    'Shelter & Sleep': [
      {'label': 'Tent', 'qty': ''},
      {'label': 'Tent footprint / groundsheet', 'qty': ''},
      {'label': 'Sleeping bag', 'qty': 'per person'},
      {'label': 'Sleeping pad', 'qty': 'per person'},
      {'label': 'Camp pillow', 'qty': 'per person'},
      {'label': 'Tarp or rain fly', 'qty': ''},
    ],
    'Kitchen & Food': [
      {'label': 'Camp stove', 'qty': ''},
      {'label': 'Fuel canisters', 'qty': '2+'},
      {'label': 'Cookpot and pan', 'qty': ''},
      {'label': 'Camp utensils set', 'qty': ''},
      {'label': 'Plates / bowls', 'qty': 'per person'},
      {'label': 'Cups / mugs', 'qty': 'per person'},
      {'label': 'Cooler with ice', 'qty': ''},
      {'label': 'Water jug', 'qty': '5 gal'},
      {'label': 'Camp soap and sponge', 'qty': ''},
      {'label': 'Dish basin', 'qty': ''},
      {'label': 'Trash bags', 'qty': '2-3'},
    ],
    'Safety & Navigation': [
      {'label': 'First-aid kit', 'qty': ''},
      {'label': 'Headlamp', 'qty': 'per person'},
      {'label': 'Extra batteries', 'qty': ''},
      {'label': 'Trail map (printed)', 'qty': ''},
      {'label': 'Compass', 'qty': ''},
      {'label': 'Emergency whistle', 'qty': ''},
      {'label': 'Bear canister or hang bag', 'qty': ''},
    ],
    'Clothing & Comfort': [
      {'label': 'Base layers', 'qty': 'per person'},
      {'label': 'Mid-layer fleece', 'qty': 'per person'},
      {'label': 'Rain jacket', 'qty': 'per person'},
      {'label': 'Hiking boots', 'qty': 'per person'},
      {'label': 'Camp sandals', 'qty': 'per person'},
      {'label': 'Warm hat and gloves', 'qty': ''},
      {'label': 'Sun hat', 'qty': 'per person'},
    ],
    'Hygiene & Essentials': [
      {'label': 'Toothbrush and toothpaste', 'qty': 'per person'},
      {'label': 'Biodegradable soap', 'qty': ''},
      {'label': 'Hand sanitizer', 'qty': ''},
      {'label': 'Toilet paper and trowel', 'qty': ''},
      {'label': 'Sunscreen SPF 30+', 'qty': ''},
      {'label': 'Bug repellent', 'qty': ''},
      {'label': 'Quick-dry towel', 'qty': 'per person'},
    ],
    'Camp Setup & Extras': [
      {'label': 'Camp chairs', 'qty': 'per person'},
      {'label': 'Camp table', 'qty': ''},
      {'label': 'Lantern or string lights', 'qty': ''},
      {'label': 'Firewood or fire starter', 'qty': ''},
      {'label': 'Matches and lighter', 'qty': ''},
      {'label': 'Multi-tool or knife', 'qty': ''},
      {'label': 'Power bank', 'qty': ''},
    ],
  };

  static const Map<String, List<Map<String, String>>> _backpacking = {
    'Pack & Carry': [
      {'label': 'Backpack (50-70L)', 'qty': ''},
      {'label': 'Pack rain cover', 'qty': ''},
      {'label': 'Trekking poles', 'qty': ''},
      {'label': 'Pack liner (dry bag)', 'qty': ''},
    ],
    'Shelter & Sleep': [
      {'label': 'Ultralight tent or bivy', 'qty': ''},
      {'label': 'Sleeping bag (3-season)', 'qty': 'per person'},
      {'label': 'Sleeping pad (R-value 2+)', 'qty': 'per person'},
    ],
    'Water & Food': [
      {'label': 'Water filter (Sawyer / Katadyn)', 'qty': ''},
      {'label': 'Water bottles or reservoir', 'qty': '2L+'},
      {'label': 'Purification tablets (backup)', 'qty': ''},
      {'label': 'Bear canister or Ursack', 'qty': ''},
      {'label': 'Backpacking stove and fuel', 'qty': ''},
      {'label': 'Freeze-dried meals', 'qty': 'per day'},
      {'label': 'High-calorie snacks', 'qty': ''},
      {'label': 'Spork and cook pot', 'qty': ''},
    ],
    'Safety & Navigation': [
      {'label': 'Topo map (waterproof / printed)', 'qty': ''},
      {'label': 'Compass', 'qty': ''},
      {'label': 'GPS device or loaded phone', 'qty': ''},
      {'label': 'Satellite messenger (inReach)', 'qty': ''},
      {'label': 'First-aid kit (lightweight)', 'qty': ''},
      {'label': 'Emergency bivy', 'qty': ''},
      {'label': 'Headlamp and spare batteries', 'qty': ''},
    ],
    'Clothing': [
      {'label': 'Moisture-wicking base layer', 'qty': ''},
      {'label': 'Insulating mid-layer', 'qty': ''},
      {'label': 'Waterproof shell jacket', 'qty': ''},
      {'label': 'Hiking pants', 'qty': ''},
      {'label': 'Trail runners or boots', 'qty': ''},
      {'label': 'Wool socks (x3 pairs)', 'qty': ''},
      {'label': 'Warm hat and gloves', 'qty': ''},
      {'label': 'Sun hat', 'qty': ''},
    ],
    'Leave No Trace': [
      {'label': 'Waste bags (WAG bags)', 'qty': ''},
      {'label': 'Cat hole trowel', 'qty': ''},
      {'label': 'Biodegradable soap', 'qty': ''},
    ],
  };

  static const Map<String, List<Map<String, String>>> _rvVan = {
    'Vehicle Prep': [
      {'label': 'Tire pressure check', 'qty': ''},
      {'label': 'Spare tire', 'qty': ''},
      {'label': 'Jump cables or jump starter', 'qty': ''},
      {'label': 'Tool kit (basic)', 'qty': ''},
    ],
    'Utilities & Hookups': [
      {'label': 'RV leveling blocks', 'qty': ''},
      {'label': 'Wheel chocks', 'qty': ''},
      {'label': 'Sewer hose kit', 'qty': ''},
      {'label': 'Fresh water hose', 'qty': ''},
      {'label': 'Power cord (30/50 amp)', 'qty': ''},
      {'label': 'Surge protector', 'qty': ''},
    ],
    'Kitchen & Food': [
      {'label': 'Propane tanks (full)', 'qty': ''},
      {'label': 'Cookware set', 'qty': ''},
      {'label': 'Dishes and utensils', 'qty': 'per person'},
      {'label': 'Dish soap and sponge', 'qty': ''},
      {'label': 'Cooler or 12V fridge', 'qty': ''},
      {'label': 'Trash bags', 'qty': ''},
    ],
    'Sleep & Comfort': [
      {'label': 'Bedding and blankets', 'qty': ''},
      {'label': 'Pillows', 'qty': 'per person'},
      {'label': 'Window covers / blackout curtains', 'qty': ''},
    ],
    'Outdoor Setup': [
      {'label': 'Camp chairs', 'qty': 'per person'},
      {'label': 'Awning or shade canopy', 'qty': ''},
      {'label': 'Outdoor rug', 'qty': ''},
    ],
    'Safety & Essentials': [
      {'label': 'Smoke detector (check battery)', 'qty': ''},
      {'label': 'CO detector', 'qty': ''},
      {'label': 'Fire extinguisher', 'qty': ''},
      {'label': 'First-aid kit', 'qty': ''},
      {'label': 'Flashlight or headlamp', 'qty': 'per person'},
    ],
  };

  static const Map<String, List<Map<String, String>>> _onTheWater = {
    'Watercraft & Paddling': [
      {'label': 'Kayak, canoe, or SUP', 'qty': ''},
      {'label': 'Paddles', 'qty': 'per person'},
      {'label': 'Dry bags', 'qty': ''},
      {'label': 'Bilge pump and sponge', 'qty': ''},
    ],
    'Safety & Essentials': [
      {'label': 'PFDs (life jackets)', 'qty': 'per person'},
      {'label': 'Throw rope', 'qty': ''},
      {'label': 'Float plan (filed)', 'qty': ''},
      {'label': 'Water filter or purification', 'qty': ''},
      {'label': 'Sunscreen (water-resistant)', 'qty': ''},
      {'label': 'Sun hat and sunglasses', 'qty': 'per person'},
      {'label': 'Whistle (on PFD)', 'qty': 'per person'},
      {'label': 'Signal mirror', 'qty': ''},
    ],
    'Shelter & Sleep': [
      {'label': 'Waterproof tent', 'qty': ''},
      {'label': 'Sleeping bag', 'qty': 'per person'},
      {'label': 'Sleeping pad', 'qty': 'per person'},
      {'label': 'Tarp', 'qty': ''},
    ],
    'Kitchen & Food': [
      {'label': 'Camp stove', 'qty': ''},
      {'label': 'Fuel', 'qty': ''},
      {'label': 'Cookware', 'qty': ''},
      {'label': 'Water-resistant food storage', 'qty': ''},
    ],
  };

  static const Map<String, List<Map<String, String>>> _cabins = {
    'Sleep & Comfort': [
      {'label': 'Sleeping bags or extra blankets', 'qty': 'per person'},
      {'label': 'Pillows', 'qty': 'per person'},
      {'label': 'Slippers or indoor shoes', 'qty': ''},
    ],
    'Kitchen & Food': [
      {'label': 'Groceries and meal plan', 'qty': ''},
      {'label': 'Coffee and tea supplies', 'qty': ''},
      {'label': 'Spices and condiments', 'qty': ''},
      {'label': 'Cooking oil', 'qty': ''},
      {'label': 'Dish soap and sponge', 'qty': ''},
      {'label': 'Trash bags', 'qty': ''},
    ],
    'Entertainment': [
      {'label': 'Board games or cards', 'qty': ''},
      {'label': 'Books', 'qty': ''},
      {'label': 'Bluetooth speaker', 'qty': ''},
    ],
    'Outdoor Gear': [
      {'label': 'Hiking boots', 'qty': 'per person'},
      {'label': 'Rain jackets', 'qty': 'per person'},
      {'label': 'Firewood (check if provided)', 'qty': ''},
      {'label': 'Bug spray', 'qty': ''},
    ],
    'Essentials & Safety': [
      {'label': 'Toiletries', 'qty': 'per person'},
      {'label': 'Towels', 'qty': 'per person'},
      {'label': 'First-aid kit', 'qty': ''},
      {'label': 'Phone chargers', 'qty': ''},
      {'label': 'Headlamp or flashlight', 'qty': 'per person'},
    ],
  };

  static const Map<String, List<Map<String, String>>> _offGrid = {
    'Power and Comms': [
      {'label': 'Solar panel', 'qty': ''},
      {'label': 'Power station or battery bank', 'qty': ''},
      {'label': 'Satellite communicator (Garmin inReach)', 'qty': ''},
      {'label': 'Walkie-talkies', 'qty': ''},
      {'label': 'Hand-crank or solar radio', 'qty': ''},
    ],
    'Water': [
      {'label': 'Water storage (5-10 gal)', 'qty': ''},
      {'label': 'Water filter and purification tabs', 'qty': ''},
      {'label': 'Collapsible water containers', 'qty': ''},
    ],
    'Shelter & Sleep': [
      {'label': 'Heavy-duty tent or wall tent', 'qty': ''},
      {'label': 'Ground tarp', 'qty': ''},
      {'label': 'Sleeping bag (rated for temps)', 'qty': 'per person'},
    ],
    'Tools and Repair': [
      {'label': 'Axe or hatchet', 'qty': ''},
      {'label': 'Folding saw', 'qty': ''},
      {'label': 'Shovel', 'qty': ''},
      {'label': 'Full tool kit', 'qty': ''},
      {'label': 'Paracord (100 ft)', 'qty': ''},
      {'label': 'Duct tape', 'qty': ''},
    ],
    'Kitchen & Food Storage': [
      {'label': 'Bear-proof cooler or canister', 'qty': ''},
      {'label': 'Dry food supply (extra days)', 'qty': ''},
      {'label': 'Camp stove and extra fuel', 'qty': ''},
    ],
    'Safety & Navigation': [
      {'label': 'First-aid kit (comprehensive)', 'qty': ''},
      {'label': 'Emergency bivy', 'qty': ''},
      {'label': 'Fire extinguisher', 'qty': ''},
      {'label': 'Matches, lighter, and ferro rod', 'qty': ''},
      {'label': 'Topographic map (paper)', 'qty': ''},
      {'label': 'Compass', 'qty': ''},
    ],
  };

  static const Map<String, List<Map<String, String>>> _groupCamp = {
    'Shelter & Shade': [
      {'label': 'Large group tent or multiple tents', 'qty': ''},
      {'label': 'Canopy or shade shelter (12x12+)', 'qty': ''},
      {'label': 'Tarps (extras)', 'qty': ''},
    ],
    'Kitchen & Food': [
      {'label': 'Camp stove (2-burner)', 'qty': ''},
      {'label': 'Large cookpots', 'qty': ''},
      {'label': 'Large cooler(s)', 'qty': ''},
      {'label': 'Serving utensils', 'qty': ''},
      {'label': 'Disposable plates, cups, utensils', 'qty': ''},
      {'label': 'Paper towels and napkins', 'qty': ''},
      {'label': 'Dish washing station', 'qty': ''},
      {'label': 'Extra trash bags', 'qty': '4+'},
    ],
    'Comfort & Fun': [
      {'label': 'Camp chairs', 'qty': 'per person'},
      {'label': 'Folding tables', 'qty': '2'},
      {'label': 'Bluetooth speaker', 'qty': ''},
      {'label': 'Group games (Kan Jam, cornhole)', 'qty': ''},
      {'label': 'Glow sticks and lanterns', 'qty': ''},
    ],
    'Safety & Essentials': [
      {'label': 'First-aid kit (large)', 'qty': ''},
      {'label': 'Headlamps for all', 'qty': 'per person'},
      {'label': 'Fire extinguisher', 'qty': ''},
      {'label': 'Emergency contacts list (printed)', 'qty': ''},
    ],
  };

  static const Map<String, List<Map<String, String>>> _glamping = {
    'Shelter & Comfort': [
      {'label': 'Bell tent or canvas tent', 'qty': ''},
      {'label': 'Real mattress or air mattress', 'qty': ''},
      {'label': 'Duvet and pillow set', 'qty': ''},
      {'label': 'Rugs and decor', 'qty': ''},
      {'label': 'String lights or fairy lights', 'qty': ''},
    ],
    'Kitchen & Hosting': [
      {'label': 'Cast iron skillet', 'qty': ''},
      {'label': 'Dutch oven', 'qty': ''},
      {'label': 'Camp kitchen table', 'qty': ''},
      {'label': 'Real dishes and glassware', 'qty': ''},
      {'label': 'Wine and cocktail supplies', 'qty': ''},
      {'label': 'French press or espresso maker', 'qty': ''},
      {'label': 'Charcuterie board items', 'qty': ''},
    ],
    'Ambiance': [
      {'label': 'Candles (in safe holders)', 'qty': ''},
      {'label': 'Outdoor rug', 'qty': ''},
      {'label': 'Throw blankets', 'qty': ''},
      {'label': 'Bluetooth speaker', 'qty': ''},
      {'label': 'Camera for golden-hour photos', 'qty': ''},
    ],
    'Essentials': [
      {'label': 'Toiletries and skincare', 'qty': ''},
      {'label': 'Towels (plush)', 'qty': 'per person'},
      {'label': 'Power bank', 'qty': ''},
      {'label': 'Portable fire pit', 'qty': ''},
      {'label': "S'mores kit", 'qty': ''},
    ],
  };
}
