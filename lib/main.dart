import 'package:flutter/material.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';

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
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
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
  final ApiService _apiService = ApiService();
  List<String> _cities = [];
  bool _loadingCities = true;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    setState(() => _loadingCities = true);
    try {
      final cities = await _apiService.getCities();
      setState(() {
        _cities = cities;
        _loadingCities = false;
      });
    } catch (e) {
      setState(() => _loadingCities = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cities: $e')),
        );
      }
    }
  }

  void _showCitySelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CitySelectionBottomSheet(
        cities: _cities,
        loading: _loadingCities,
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
  final List<String> cities;
  final bool loading;
  final Function(String) onCitySelected;

  const CitySelectionBottomSheet({
    super.key,
    required this.cities,
    required this.loading,
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
    _filteredCities = widget.cities;
  }

  @override
  void didUpdateWidget(CitySelectionBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cities != oldWidget.cities) {
      _filteredCities = widget.cities;
    }
  }

  void _filterCities(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCities = widget.cities;
      } else {
        _filteredCities = widget.cities
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
            child: widget.loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _filteredCities.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('No cities found'),
                        ),
                      )
                    : ListView.builder(
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
class ToursList extends StatefulWidget {
  final String city;

  const ToursList({super.key, required this.city});

  @override
  State<ToursList> createState() => _ToursListState();
}

class _ToursListState extends State<ToursList> {
  final ApiService _apiService = ApiService();
  List<TourSummary> _tours = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTours();
  }

  @override
  void didUpdateWidget(ToursList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.city != oldWidget.city) {
      _loadTours();
    }
  }

  Future<void> _loadTours() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tours = await _apiService.getToursByCity(widget.city);
      setState(() {
        _tours = tours;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Failed to load tours', style: TextStyle(color: Colors.red.shade600)),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTours,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_tours.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tour_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No tours available for ${widget.city}',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tours.length,
      itemBuilder: (context, index) {
        final tour = _tours[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TourDetailScreen(tourId: tour.tourId),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tour.tourId,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('${tour.durationDays} days'),
                      const SizedBox(width: 16),
                      Icon(Icons.location_city, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(tour.city),
                      const Spacer(),
                      Icon(Icons.place, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('${tour.totalPois} POIs'),
                    ],
                  ),
                ],
              ),
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

// Tour Detail Screen
class TourDetailScreen extends StatefulWidget {
  final String tourId;

  const TourDetailScreen({super.key, required this.tourId});

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  final ApiService _apiService = ApiService();
  TourDetail? _tourDetail;
  bool _loading = true;
  String? _error;
  bool _isMapMode = false;
  bool _showBackupOptions = false;

  @override
  void initState() {
    super.initState();
    _loadTourDetail();
  }

  Future<void> _loadTourDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tour = await _apiService.getTourById(widget.tourId);
      setState(() {
        _tourDetail = tour;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_tourDetail?.metadata?.city ?? 'Tour Details'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text('Failed to load tour', style: TextStyle(color: Colors.red.shade600)),
                      const SizedBox(height: 8),
                      Text(_error!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTourDetail,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _tourDetail == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, size: 80, color: Colors.blue.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Tour details unavailable',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'This tour exists but detailed itinerary is not yet available. The tour may still be processing or may have been created without a full itinerary.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Back to Tours'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Tour Metadata
                        _buildTourMetadata(),
                        // Content (List or Map mode)
                        Expanded(
                          child: _isMapMode ? _buildMapMode() : _buildListMode(),
                        ),
                      ],
                    ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                setState(() {
                  _isMapMode = !_isMapMode;
                });
              },
              icon: Icon(_isMapMode ? Icons.list : Icons.map),
              label: Text(_isMapMode ? 'List View' : 'Map View'),
            ),
    );
  }

  Widget _buildTourMetadata() {
    final metadata = _tourDetail!.metadata;
    final itinerary = _tourDetail!.itinerary.toList();

    // Calculate total walking distance from all days
    final totalDistance = itinerary.fold<num>(
      0,
      (sum, day) => sum + day.totalWalkingKm,
    );

    // Get duration from itinerary length
    final durationDays = itinerary.length;

    // Try to get interests from input parameters (it's a JsonObject, so we need to handle it)
    final List<String> interests = [];
    try {
      final inputParams = _tourDetail!.inputParameters;
      if (inputParams.value is Map) {
        final params = inputParams.value as Map;
        if (params['interests'] is List) {
          interests.addAll((params['interests'] as List).cast<String>());
        }
      }
    } catch (e) {
      // Ignore if can't parse
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metadata.city,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(
                '$durationDays days',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(width: 24),
              Icon(Icons.directions_walk, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(
                '${totalDistance.toStringAsFixed(1)} km',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          if (interests.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: interests.map((interest) {
                return Chip(
                  label: Text(interest, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.blue.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListMode() {
    final itinerary = _tourDetail!.itinerary.toList();

    return Column(
      children: [
        // Backup Options Switch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              const Text('Show Backup Options'),
              const Spacer(),
              Switch(
                value: _showBackupOptions,
                onChanged: (value) {
                  setState(() {
                    _showBackupOptions = value;
                  });
                },
              ),
            ],
          ),
        ),
        // Itinerary List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: itinerary.length,
            itemBuilder: (context, dayIndex) {
              final day = itinerary[dayIndex];
              final pois = day.pois.toList();

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  title: Text(
                    'Day ${day.day}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${pois.length} POIs • ${day.totalHours.toStringAsFixed(1)} hours'),
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pois.length,
                      itemBuilder: (context, poiIndex) {
                        final poi = pois[poiIndex];

                        return Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                child: Text('${poiIndex + 1}'),
                              ),
                              title: Text(poi.poi),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (poi.reason.isNotEmpty)
                                    Text(
                                      poi.reason,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text('${poi.estimatedHours.toStringAsFixed(1)} hours'),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  poi.priority,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                              ),
                            ),
                            // Show backup options if enabled
                            if (_showBackupOptions) ...[
                              if (_tourDetail!.backupPois != null && _tourDetail!.backupPois!.containsKey(poi.poi)) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  color: Colors.blue.shade50,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.swap_horiz, size: 16, color: Colors.blue.shade700),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Alternative Options',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ..._tourDetail!.backupPois![poi.poi]!.take(3).map((backup) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              margin: const EdgeInsets.only(top: 4),
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade400,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    backup.poi,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.blue.shade900,
                                                    ),
                                                  ),
                                                  if (backup.reason.isNotEmpty)
                                                    Text(
                                                      backup.reason,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  if (backup.substituteScenario.isNotEmpty)
                                                    Text(
                                                      backup.substituteScenario,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontStyle: FontStyle.italic,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${(backup.similarityScore * 100).toInt()}%',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green.shade800,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                      if (_tourDetail!.backupPois![poi.poi]!.length > 3)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            '+${_tourDetail!.backupPois![poi.poi]!.length - 3} more options',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue.shade700,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  color: Colors.grey.shade100,
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'No backup options available for this POI',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                            if (poiIndex < pois.length - 1)
                              Divider(height: 1, color: Colors.grey.shade300),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMapMode() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Map View',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Map integration coming soon',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
