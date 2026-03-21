import 'package:flutter/material.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';
import 'package:pocket_guide_mobile/screens/login_screen.dart';
import 'package:pocket_guide_mobile/screens/auth_callback_screen.dart';
import 'package:pocket_guide_mobile/screens/create_tour_screen.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const PocketGuideApp());
}

class PocketGuideApp extends StatelessWidget {
  const PocketGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check current URL to handle OAuth callback
    final uri = Uri.base;
    String initialRoute = '/';

    // If we're at /auth/callback, go directly there
    if (uri.path == '/auth/callback') {
      initialRoute = '/auth/callback';
    }

    return MaterialApp(
      title: 'Pocket Guide',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const AuthCheckScreen(),
        '/auth/callback': (context) => const AuthCallbackScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}

// Auth Check Screen - determines whether to show login or main app
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Small delay for splash effect
    await Future.delayed(const Duration(milliseconds: 500));

    final isAuthenticated = await _authService.isAuthenticated();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => isAuthenticated
              ? const MainScreen()
              : const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              'Pocket Guide',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          ],
        ),
      ),
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
    const AccountsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateTourScreen(),
            ),
          );
        },
        elevation: 4,
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'Home', 0),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(Icons.person, 'Account', 1),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
          ],
        ),
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

// Tours List Widget with Tabs
class ToursList extends StatefulWidget {
  final String city;

  const ToursList({super.key, required this.city});

  @override
  State<ToursList> createState() => _ToursListState();
}

class _ToursListState extends State<ToursList> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  late TabController _tabController;
  List<dynamic> _myTours = [];
  List<TourSummary> _publicTours = [];
  bool _loadingMyTours = true;
  bool _loadingPublicTours = true;
  String? _errorMyTours;
  String? _errorPublicTours;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllTours();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ToursList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.city != oldWidget.city) {
      _loadAllTours();
    }
  }

  Future<void> _loadAllTours() async {
    _loadMyTours();
    _loadPublicTours();
  }

  Future<void> _loadMyTours() async {
    setState(() {
      _loadingMyTours = true;
      _errorMyTours = null;
    });

    try {
      final accessToken = await _authService.getAccessToken();
      if (accessToken != null) {
        final allMyTours = await _apiService.getMyTours(accessToken);
        // Filter by selected city
        final filteredTours = allMyTours.where((tour) {
          final tourCity = tour['city'] as String?;
          return tourCity?.toLowerCase() == widget.city.toLowerCase();
        }).toList();

        setState(() {
          _myTours = filteredTours;
          _loadingMyTours = false;
        });
      } else {
        setState(() {
          _myTours = [];
          _loadingMyTours = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMyTours = e.toString();
        _loadingMyTours = false;
      });
    }
  }

  Future<void> _loadPublicTours() async {
    setState(() {
      _loadingPublicTours = true;
      _errorPublicTours = null;
    });

    try {
      final tours = await _apiService.getToursByCity(widget.city);
      setState(() {
        _publicTours = tours;
        _loadingPublicTours = false;
      });
    } catch (e) {
      setState(() {
        _errorPublicTours = e.toString();
        _loadingPublicTours = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Tours'),
            Tab(text: 'Public Tours'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMyToursTab(),
              _buildPublicToursTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyToursTab() {
    if (_loadingMyTours) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMyTours != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Failed to load tours', style: TextStyle(color: Colors.red.shade600)),
            const SizedBox(height: 8),
            Text(_errorMyTours!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMyTours,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_myTours.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tour_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No tours created yet',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to create your first tour',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myTours.length,
      itemBuilder: (context, index) {
        final tour = _myTours[index] as Map<String, dynamic>;
        return _buildTourCard(
          context,
          tourId: tour['tour_id'] as String,
          title: tour['title_display'] as String? ?? tour['tour_id'] as String,
          days: tour['duration_days'] as int,
          city: tour['city'] as String,
          totalPois: tour['total_pois'] as int,
        );
      },
    );
  }

  Widget _buildPublicToursTab() {
    if (_loadingPublicTours) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorPublicTours != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Failed to load tours', style: TextStyle(color: Colors.red.shade600)),
            const SizedBox(height: 8),
            Text(_errorPublicTours!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPublicTours,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_publicTours.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tour_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No public tours available for ${widget.city}',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _publicTours.length,
      itemBuilder: (context, index) {
        final tour = _publicTours[index];
        return _buildTourCard(
          context,
          tourId: tour.tourId,
          title: tour.titleDisplay ?? tour.tourId,
          days: tour.durationDays,
          city: tour.city,
          totalPois: tour.totalPois,
        );
      },
    );
  }

  Widget _buildTourCard(
    BuildContext context, {
    required String tourId,
    required String title,
    required int days,
    required String city,
    required int totalPois,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TourWithTranscriptScreen(tourId: tourId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('$days days'),
                  const SizedBox(width: 16),
                  Icon(Icons.location_city, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(city),
                  const Spacer(),
                  Icon(Icons.place, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('$totalPois POIs'),
                ],
              ),
            ],
          ),
        ),
      ),
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
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final AuthService _authService = AuthService();
  bool _loading = false;

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);

      await _authService.logout();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Account'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: _handleLogout,
                ),
              ],
            ),
    );
  }
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

// Tour Detail Screen with Inline Transcripts (NEW UI)
class TourWithTranscriptScreen extends StatefulWidget {
  final String tourId;

  const TourWithTranscriptScreen({super.key, required this.tourId});

  @override
  State<TourWithTranscriptScreen> createState() => _TourWithTranscriptScreenState();
}

class _TourWithTranscriptScreenState extends State<TourWithTranscriptScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  TourDetail? _tourDetail;
  bool _loading = true;
  String? _error;

  Map<String, POISwap> _pendingSwaps = {};

  @override
  void initState() {
    super.initState();
    _fetchTourDetails();
  }

  Future<void> _fetchTourDetails() async {
    try {
      // Get access token for private tours
      final accessToken = await _authService.getAccessToken();

      // Fetch tour details with auth token (required for private tours)
      final tourDetail = await _apiService.getTourById(
        widget.tourId,
        accessToken: accessToken,
      );

      setState(() {
        _tourDetail = tourDetail;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load tour: $e';
        _loading = false;
      });
    }
  }

  Future<void> _applyChanges() async {
    if (_pendingSwaps.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Changes'),
        content: Text('Apply ${_pendingSwaps.length} POI replacement(s) to this tour?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Applying changes...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Prepare request body
      final replacements = _pendingSwaps.values.map((swap) {
        return {
          'original_poi': swap.originalPoi,
          'replacement_poi': swap.replacementPoi,
          'day': swap.dayNumber,
        };
      }).toList();

      final requestBody = {
        'replacements': replacements,
        'mode': 'simple',
        'language': _tourDetail?.metadata?.languages?.first ?? 'en',
      };

      // Call batch replace API
      await _apiService.batchReplacePOIs(widget.tourId, requestBody);

      // Refresh tour details
      await _fetchTourDetails();

      // Clear pending swaps
      setState(() {
        _pendingSwaps.clear();
      });

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes applied successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPendingChanges = _pendingSwaps.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_tourDetail?.metadata?.titleDisplay ?? 'New Tour UI'),
        actions: [
          if (hasPendingChanges)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: Text('Apply ${_pendingSwaps.length}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                onPressed: _applyChanges,
              ),
            ),
        ],
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
                      Text(_error!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : _buildTourContent(),
    );
  }

  Widget _buildTourContent() {
    final itinerary = _tourDetail!.itinerary.toList();

    return ListView.builder(
      itemCount: itinerary.length,
      itemBuilder: (context, dayIndex) {
        final day = itinerary[dayIndex];
        final dayNumber = day.day;
        final pois = day.pois.toList();

        return ExpansionTile(
          initiallyExpanded: dayIndex == 0,
          title: Text('Day $dayNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
          children: pois.asMap().entries.map((entry) {
            final poiIndex = entry.key;
            final poi = entry.value;
            final poiKey = '$dayNumber-$poiIndex';
            final isSwapped = _pendingSwaps.containsKey(poiKey);
            final currentPOI = isSwapped ? _pendingSwaps[poiKey]!.replacementPoi : poi.poi;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: isSwapped ? Colors.yellow.shade50 : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        '${poiIndex + 1}',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      currentPOI,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('${poi.estimatedHours.toStringAsFixed(1)} hours'),
                      ],
                    ),
                    trailing: Builder(
                      builder: (context) {
                        final hasBackups = _tourDetail!.backupPois != null &&
                                          _tourDetail!.backupPois!.containsKey(poi.poi);

                        if (!hasBackups) return const SizedBox.shrink();

                        return TextButton.icon(
                          icon: Icon(Icons.swap_horiz, size: 16, color: Colors.blue.shade700),
                          label: Text(
                            'Alternatives',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          onPressed: () => _showAlternatives(poi, currentPOI, dayNumber, poiIndex, isSwapped),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                _buildInlineTranscript(currentPOI, _tourDetail!.metadata!.city, poi),
                if (poiIndex < pois.length - 1)
                  Divider(height: 1, color: Colors.grey.shade300),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildInlineTranscript(String poiName, String city, TourPOI poi) {
    return FutureBuilder<SectionedTranscriptData?>(
      future: _fetchSectionedTranscript(poiName, city),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final sectionedData = snapshot.data!;
        final poiId = poiName.toLowerCase().replaceAll(' ', '-').replaceAll("'", '');

        return Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.headphones, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Audio Guide (${sectionedData.totalSections} sections • ${(sectionedData.estimatedDurationSeconds / 60).toStringAsFixed(0)} min)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...sectionedData.sections.map((section) {
                // Use POI audio URL for "Full Narrative" section if available
                String? audioUrl;
                if (section.title == 'Full Narrative' && poi.audioAvailable == true && poi.audioUrl != null) {
                  audioUrl = '${ApiService.baseUrl}${poi.audioUrl}';
                } else if (section.audioFile != null) {
                  audioUrl = _apiService.getAudioUrl(city, poiId, section.audioFile!);
                }

                return _SectionCard(
                  section: section,
                  audioUrl: audioUrl,
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Future<SectionedTranscriptData?> _fetchSectionedTranscript(String poiName, String city) async {
    try {
      final poiId = poiName.toLowerCase().replaceAll(' ', '-').replaceAll("'", '');
      final tourId = widget.tourId;
      String language = 'en';
      if (_tourDetail?.metadata?.languages != null && _tourDetail!.metadata!.languages!.isNotEmpty) {
        language = _tourDetail!.metadata!.languages!.first;
      }

      final response = await _apiService.fetchSectionedTranscript(city, poiId, tourId, language);
      return response;
    } catch (e) {
      print('Error fetching sectioned transcript: $e');
      return null;
    }
  }

  Future<void> _showAlternatives(TourPOI poi, String currentPOI, int dayNumber, int poiIndex, bool isSwapped) async {
    final backupOptions = _tourDetail!.backupPois![poi.poi]!.toList();
    final poiKey = '$dayNumber-$poiIndex';

    showDialog(
      context: context,
      builder: (context) => _AlternativesDialog(
        poi: poi,
        currentPOI: currentPOI,
        dayNumber: dayNumber,
        poiIndex: poiIndex,
        isSwapped: isSwapped,
        backupOptions: backupOptions,
        currentSwap: isSwapped ? _pendingSwaps[poiKey] : null,
        onSave: (POISwap? swap) {
          setState(() {
            if (swap != null) {
              _pendingSwaps[poiKey] = swap;
            } else {
              _pendingSwaps.remove(poiKey);
            }
          });
        },
      ),
    );
  }
}

// Alternatives Dialog
class _AlternativesDialog extends StatefulWidget {
  final TourPOI poi;
  final String currentPOI;
  final int dayNumber;
  final int poiIndex;
  final bool isSwapped;
  final List<BackupPOI> backupOptions;
  final POISwap? currentSwap;
  final Function(POISwap?) onSave;

  const _AlternativesDialog({
    required this.poi,
    required this.currentPOI,
    required this.dayNumber,
    required this.poiIndex,
    required this.isSwapped,
    required this.backupOptions,
    required this.currentSwap,
    required this.onSave,
  });

  @override
  State<_AlternativesDialog> createState() => _AlternativesDialogState();
}

class _AlternativesDialogState extends State<_AlternativesDialog> {
  String? _selectedPOI;

  @override
  void initState() {
    super.initState();
    _selectedPOI = widget.currentSwap?.replacementPoi;
  }

  @override
  Widget build(BuildContext context) {
    final hasChanges = _selectedPOI != widget.currentSwap?.replacementPoi;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.swap_horiz, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          const Expanded(child: Text('Alternative POIs')),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current POI
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current POI',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.currentPOI,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Available Alternatives:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Backup options list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.backupOptions.length,
                itemBuilder: (context, index) {
                  final backup = widget.backupOptions[index];
                  final isSelected = _selectedPOI == backup.poi;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isSelected ? Colors.yellow.shade50 : null,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedPOI = null;
                          } else {
                            _selectedPOI = backup.poi;
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    backup.poi,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Selected',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green.shade900,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${(backup.similarityScore * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              backup.reason,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Revert button if swapped
            if (widget.isSwapped && _selectedPOI != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Revert to Original'),
                onPressed: () {
                  setState(() {
                    _selectedPOI = null;
                  });
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: hasChanges || _selectedPOI != null
              ? () {
                  if (_selectedPOI != null) {
                    widget.onSave(POISwap(
                      originalPoi: widget.poi.poi,
                      replacementPoi: _selectedPOI!,
                      dayNumber: widget.dayNumber,
                      poiIndexInDay: widget.poiIndex,
                    ));
                  } else {
                    widget.onSave(null);
                  }
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Section Card with Audio Player
class _SectionCard extends StatefulWidget {
  final TranscriptSection section;
  final String? audioUrl;

  const _SectionCard({
    required this.section,
    this.audioUrl,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isExpanded = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
        _isLoading = state == PlayerState.playing && _position == Duration.zero;
      });
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  Future<void> _togglePlayPause() async {
    if (widget.audioUrl == null) return;

    try {
      if (_isPlaying) {
        // Update UI immediately for better responsiveness
        setState(() {
          _isPlaying = false;
        });
        await _audioPlayer.pause();
      } else {
        // Update UI immediately for better responsiveness
        setState(() {
          _isPlaying = true;
          _isLoading = _position == Duration.zero;
        });
        if (_position == Duration.zero) {
          await _audioPlayer.play(UrlSource(widget.audioUrl!));
        } else {
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      print('Error playing audio: $e');
      // Revert state on error
      setState(() {
        _isPlaying = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play audio: $e')),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.section.sectionNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.section.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.section.knowledgePoint,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Only show estimated duration badge if no audio player
                  if (widget.audioUrl == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatDuration(Duration(seconds: widget.section.estimatedDurationSeconds)),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          // Audio Player
          if (widget.audioUrl != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  // Play/Pause Button
                  IconButton(
                    icon: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
                            ),
                          )
                        : Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.blue.shade700,
                          ),
                    onPressed: _togglePlayPause,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  // Progress Bar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: _duration.inMilliseconds > 0
                              ? _position.inMilliseconds / _duration.inMilliseconds
                              : 0,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                            Text(
                              _duration.inSeconds > 0
                                  ? _formatDuration(_duration)
                                  : '--:--',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Transcript (Expandable)
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transcript',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.section.transcript,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

