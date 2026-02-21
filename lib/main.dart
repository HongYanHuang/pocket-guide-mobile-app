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

// POI Swap tracking class
class POISwap {
  final String originalPoi;
  final String replacementPoi;
  final int dayNumber;
  final int poiIndexInDay;

  POISwap({
    required this.originalPoi,
    required this.replacementPoi,
    required this.dayNumber,
    required this.poiIndexInDay,
  });

  String get key => '$dayNumber-$poiIndexInDay';
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  final ApiService _apiService = ApiService();
  TourDetail? _tourDetail;
  bool _loading = true;
  String? _error;
  bool _isMapMode = false;
  bool _showBackupOptions = false;

  // Track pending POI swaps
  Map<String, POISwap> _pendingSwaps = {};
  bool _applying = false;

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

  // Get all currently selected POIs (including swapped ones)
  Set<String> _getAllSelectedPOIs() {
    final selectedPOIs = <String>{};

    if (_tourDetail == null) return selectedPOIs;

    final itinerary = _tourDetail!.itinerary.toList();
    for (int dayIndex = 0; dayIndex < itinerary.length; dayIndex++) {
      final day = itinerary[dayIndex];
      final pois = day.pois.toList();

      for (int poiIndex = 0; poiIndex < pois.length; poiIndex++) {
        final poi = pois[poiIndex];
        final swapKey = '${dayIndex + 1}-$poiIndex';

        // Check if this POI has been swapped
        if (_pendingSwaps.containsKey(swapKey)) {
          selectedPOIs.add(_pendingSwaps[swapKey]!.replacementPoi);
        } else {
          selectedPOIs.add(poi.poi);
        }
      }
    }

    return selectedPOIs;
  }

  // Check if a backup POI is already selected elsewhere
  bool _isBackupPOIAlreadySelected(String backupPoi, int currentDay, int currentPoiIndex) {
    final selectedPOIs = _getAllSelectedPOIs();

    // Remove the current POI from the set to allow self-selection
    if (_tourDetail != null) {
      final itinerary = _tourDetail!.itinerary.toList();
      if (currentDay - 1 < itinerary.length) {
        final day = itinerary[currentDay - 1];
        final pois = day.pois.toList();
        if (currentPoiIndex < pois.length) {
          final swapKey = '$currentDay-$currentPoiIndex';
          if (_pendingSwaps.containsKey(swapKey)) {
            selectedPOIs.remove(_pendingSwaps[swapKey]!.replacementPoi);
          } else {
            selectedPOIs.remove(pois[currentPoiIndex].poi);
          }
        }
      }
    }

    return selectedPOIs.contains(backupPoi);
  }

  // Handle POI swap
  void _handlePOISwap(String originalPoi, String backupPoi, int dayNumber, int poiIndexInDay) {
    setState(() {
      final swapKey = '$dayNumber-$poiIndexInDay';

      // If swapping back to original, remove from pending swaps
      if (backupPoi == originalPoi) {
        _pendingSwaps.remove(swapKey);
      } else {
        _pendingSwaps[swapKey] = POISwap(
          originalPoi: originalPoi,
          replacementPoi: backupPoi,
          dayNumber: dayNumber,
          poiIndexInDay: poiIndexInDay,
        );
      }
    });
  }

  // Get the currently displayed POI (either original or swapped)
  String _getCurrentPOI(String originalPoi, int dayNumber, int poiIndexInDay) {
    final swapKey = '$dayNumber-$poiIndexInDay';
    if (_pendingSwaps.containsKey(swapKey)) {
      return _pendingSwaps[swapKey]!.replacementPoi;
    }
    return originalPoi;
  }

  // Check if there are duplicates in the current selection
  bool _hasDuplicates() {
    final selectedPOIs = _getAllSelectedPOIs();
    if (_tourDetail == null) return false;

    final itinerary = _tourDetail!.itinerary.toList();
    int totalPOIs = 0;
    for (final day in itinerary) {
      totalPOIs += day.pois.length;
    }

    return selectedPOIs.length != totalPOIs;
  }

  // Show summary of all pending changes
  Future<bool> _showChangesSummary() async {
    final swaps = _pendingSwaps.values.toList();

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm ${swaps.length} Change${swaps.length > 1 ? 's' : ''}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to apply the following changes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...swaps.map((swap) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Day ${swap.dayNumber}, POI ${swap.poiIndexInDay + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              swap.originalPoi,
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_downward, size: 12, color: Colors.green.shade700),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              swap.replacementPoi,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 8),
              Text(
                'All changes will be saved together.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply All'),
          ),
        ],
      ),
    ) ?? false;
  }

  // Apply all pending swaps to the API
  Future<void> _applyChanges() async {
    if (_pendingSwaps.isEmpty) return;

    // Check for duplicates before applying
    if (_hasDuplicates()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Duplicate POIs detected. Please review your selections.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show summary and get confirmation
    final confirmed = await _showChangesSummary();
    if (!confirmed) return;

    setState(() {
      _applying = true;
    });

    try {
      // Convert all pending swaps to the API format
      // IMPORTANT: We send ALL swaps in _pendingSwaps, ensuring no changes are lost
      final replacements = _pendingSwaps.values.map((swap) {
        return {
          'original_poi': swap.originalPoi,
          'replacement_poi': swap.replacementPoi,
          'day': swap.dayNumber,
        };
      }).toList();

      // Verify we have all swaps
      if (replacements.length != _pendingSwaps.length) {
        throw Exception('Mismatch in swap count! Expected ${_pendingSwaps.length}, got ${replacements.length}');
      }

      // Get the tour's language from metadata
      String language = 'en'; // Default to English
      if (_tourDetail?.metadata?.languages != null && _tourDetail!.metadata!.languages!.isNotEmpty) {
        language = _tourDetail!.metadata!.languages!.first;
      }

      final requestBody = {
        'replacements': replacements,
        'mode': 'simple',
        'language': language,
      };

      print('=== Applying POI Swaps ===');
      print('Total swaps to apply: ${_pendingSwaps.length}');
      print('Swaps details:');
      for (var i = 0; i < replacements.length; i++) {
        print('  ${i + 1}. Day ${replacements[i]['day']}: ${replacements[i]['original_poi']} → ${replacements[i]['replacement_poi']}');
      }
      print('Request body: $requestBody');
      print('=========================');

      final response = await _apiService.batchReplacePOIs(widget.tourId, requestBody);

      if (response.success) {
        setState(() {
          _pendingSwaps.clear();
          _applying = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully updated ${replacements.length} POI(s)'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload tour details to get updated data
        await _loadTourDetail();
      } else {
        throw Exception('Failed to apply changes');
      }
    } catch (e) {
      setState(() {
        _applying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error applying changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show transcript dialog for a POI
  Future<void> _showTranscript(String poiName, String city) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.description, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      poiName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<String>(
                  future: _fetchTranscript(poiName, city),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load transcript',
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      child: Text(
                        snapshot.data ?? 'No transcript available',
                        style: const TextStyle(fontSize: 14, height: 1.6),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fetch transcript content for a POI
  Future<String> _fetchTranscript(String poiName, String city) async {
    try {
      // Convert POI name to ID format (lowercase, replace spaces with hyphens)
      final poiId = poiName.toLowerCase().replaceAll(' ', '-').replaceAll("'", '');

      print('Fetching transcript for: $city/$poiId');

      final response = await _apiService.fetchTranscript(city, poiId);
      return response;
    } catch (e) {
      print('Error fetching transcript: $e');
      throw Exception('Could not load transcript: $e');
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
        // Backup Options Switch and Apply Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Column(
            children: [
              Row(
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
              if (_pendingSwaps.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade400),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_pendingSwaps.length} pending change${_pendingSwaps.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _applying ? null : _applyChanges,
                        icon: _applying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, size: 16),
                        label: Text(_applying ? 'Applying...' : 'Apply'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                  initiallyExpanded: dayIndex == 0, // Day 1 default open
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
                        final dayNumber = day.day;
                        final swapKey = '$dayNumber-$poiIndex';
                        final isSwapped = _pendingSwaps.containsKey(swapKey);
                        final currentPOI = _getCurrentPOI(poi.poi, dayNumber, poiIndex);

                        return Column(
                          children: [
                            Container(
                              color: isSwapped ? Colors.orange.shade50 : null,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSwapped ? Colors.orange : null,
                                  child: Text('${poiIndex + 1}'),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        currentPOI,
                                        style: TextStyle(
                                          fontWeight: isSwapped ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (isSwapped) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.swap_horiz, size: 16, color: Colors.orange.shade700),
                                    ],
                                  ],
                                ),
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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Transcript button
                                  IconButton(
                                    icon: const Icon(Icons.description_outlined, size: 20),
                                    onPressed: () => _showTranscript(currentPOI, _tourDetail!.metadata!.city),
                                    tooltip: 'View transcript',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  // Priority chip
                                  Chip(
                                    label: Text(
                                      poi.priority,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                  ),
                                ],
                              ),
                            ),
                            ),
                            // Show backup options if enabled
                            if (_showBackupOptions) ...[
                              Builder(
                                builder: (context) {
                                  // Always use the original POI (poi.poi) to look up backups
                                  // The backup list for the original POI contains all alternatives
                                  // We'll show them all and let the user select which one is current
                                  final hasBackups = _tourDetail!.backupPois != null && _tourDetail!.backupPois!.containsKey(poi.poi);

                                  return Column(
                                    children: [
                                      // If this POI was swapped, show option to revert
                                      if (isSwapped) ...[
                                        InkWell(
                                          onTap: () => _handlePOISwap(poi.poi, poi.poi, dayNumber, poiIndex),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            color: Colors.orange.shade50,
                                            child: Row(
                                              children: [
                                                Icon(Icons.undo, size: 16, color: Colors.orange.shade700),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Revert to: ${poi.poi}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.orange.shade900,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Tap to switch back to original POI',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.orange.shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Icon(Icons.chevron_right, color: Colors.orange.shade700),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                      // Show backup options if available
                                      if (hasBackups) ...[
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
                                                    'Alternative Options (tap to switch)',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.blue.shade900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              ..._tourDetail!.backupPois![poi.poi]!.map((backup) {
                                                final isAlreadySelected = _isBackupPOIAlreadySelected(backup.poi, dayNumber, poiIndex);
                                                final isCurrentlySelected = currentPOI == backup.poi;

                                                return InkWell(
                                                  onTap: isAlreadySelected && !isCurrentlySelected
                                                      ? null
                                                      : () => _handlePOISwap(poi.poi, backup.poi, dayNumber, poiIndex),
                                                  child: Opacity(
                                                    opacity: isAlreadySelected && !isCurrentlySelected ? 0.4 : 1.0,
                                                    child: Container(
                                                      margin: const EdgeInsets.only(bottom: 6),
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: isCurrentlySelected ? Colors.green.shade100 : Colors.white,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: isCurrentlySelected
                                                              ? Colors.green.shade400
                                                              : (isAlreadySelected ? Colors.red.shade200 : Colors.blue.shade200),
                                                          width: isCurrentlySelected ? 2 : 1,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          if (isCurrentlySelected)
                                                            Icon(Icons.check_circle, size: 16, color: Colors.green.shade700)
                                                          else if (isAlreadySelected)
                                                            Icon(Icons.block, size: 16, color: Colors.red.shade400)
                                                          else
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
                                                                    color: isCurrentlySelected
                                                                        ? Colors.green.shade900
                                                                        : (isAlreadySelected ? Colors.grey.shade600 : Colors.blue.shade900),
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
                                                                if (isAlreadySelected && !isCurrentlySelected)
                                                                  Text(
                                                                    'Already selected elsewhere',
                                                                    style: TextStyle(
                                                                      fontSize: 10,
                                                                      color: Colors.red.shade600,
                                                                      fontWeight: FontWeight.bold,
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
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ] else if (!isSwapped) ...[
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
                                  );
                                },
                              ),
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
