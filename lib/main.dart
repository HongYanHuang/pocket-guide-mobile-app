import 'package:flutter/material.dart';

void main() {
  runApp(const PocketGuideApp());
}

class PocketGuideApp extends StatelessWidget {
  const PocketGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Guide',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const AccountsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Accounts',
          ),
        ],
      ),
    );
  }
}

// Home Screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedCity;

  // Popular cities list
  final List<String> _popularCities = [
    'Rome',
    'Paris',
    'London',
    'Tokyo',
    'New York',
    'Barcelona',
    'Amsterdam',
    'Venice',
    'Florence',
    'Berlin',
  ];

  void _showCitySelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CitySelectionBottomSheet(
        popularCities: _popularCities,
        onCitySelected: (city) {
          setState(() {
            _selectedCity = city;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Home'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Destination selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: _showCitySelector,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _selectedCity ?? 'Select Destination',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: _selectedCity != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _selectedCity != null
                            ? Colors.black
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
          ),
          // Tours list
          Expanded(
            child: _selectedCity == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.explore_outlined,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select a destination to view tours',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ToursList(city: _selectedCity!),
          ),
        ],
      ),
    );
  }
}

// City Selection Bottom Sheet
class CitySelectionBottomSheet extends StatefulWidget {
  final List<String> popularCities;
  final Function(String) onCitySelected;

  const CitySelectionBottomSheet({
    super.key,
    required this.popularCities,
    required this.onCitySelected,
  });

  @override
  State<CitySelectionBottomSheet> createState() => _CitySelectionBottomSheetState();
}

class _CitySelectionBottomSheetState extends State<CitySelectionBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredCities = [];

  @override
  void initState() {
    super.initState();
    _filteredCities = widget.popularCities;
  }

  void _filterCities(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCities = widget.popularCities;
      } else {
        _filteredCities = widget.popularCities
            .where((city) => city.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Select Destination',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCities,
              decoration: InputDecoration(
                hintText: 'Search cities...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterCities('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Popular Cities label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Popular Cities',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Cities list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredCities.length,
              itemBuilder: (context, index) {
                final city = _filteredCities[index];
                return ListTile(
                  leading: const Icon(Icons.location_city),
                  title: Text(city),
                  onTap: () => widget.onCitySelected(city),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Tours List Widget
class ToursList extends StatelessWidget {
  final String city;

  const ToursList({super.key, required this.city});

  @override
  Widget build(BuildContext context) {
    // Mock tour data - will be replaced with actual API data later
    final mockTours = [
      {
        'title': '$city Classic Tour',
        'days': 3,
        'price': '\$299',
        'rating': 4.8,
      },
      {
        'title': '$city Food & Culture',
        'days': 5,
        'price': '\$499',
        'rating': 4.9,
      },
      {
        'title': '$city Historical Journey',
        'days': 4,
        'price': '\$399',
        'rating': 4.7,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockTours.length,
      itemBuilder: (context, index) {
        final tour = mockTours[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tour['title'] as String,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${tour['days']} days'),
                    const SizedBox(width: 16),
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text('${tour['rating']}'),
                    const Spacer(),
                    Text(
                      tour['price'] as String,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Explore Screen
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Explore'),
      ),
      body: const Center(
        child: Text('Explore Screen'),
      ),
    );
  }
}

// Accounts Screen
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Accounts'),
      ),
      body: const Center(
        child: Text('Accounts Screen'),
      ),
    );
  }
}
