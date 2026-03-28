import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';
import 'package:pocket_guide_mobile/services/background_audio_service.dart';
import 'package:pocket_guide_mobile/screens/login_screen.dart';
import 'package:pocket_guide_mobile/screens/auth_callback_screen.dart';
import 'package:pocket_guide_mobile/screens/create_tour_screen.dart';
import 'package:pocket_guide_mobile/screens/map_tour_screen.dart';
import 'package:pocket_guide_mobile/design_system/preview_screen.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';
import 'package:pocket_guide_mobile/design_system/spacing.dart';
import 'package:pocket_guide_mobile/design_system/components/pg_navigation.dart';
import 'package:pocket_guide_mobile/design_system/components/pg_button.dart';
import 'package:pocket_guide_mobile/design_system/components/pg_card.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: PGColors.brand),
        scaffoldBackgroundColor: PGColors.background,
        useMaterial3: true,
        // Use Cupertino-style colors where possible
        primaryColor: PGColors.brand,
        dividerColor: PGColors.divider,
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
      backgroundColor: PGColors.brand,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.map_fill,
              size: 100,
              color: PGColors.white,
            ),
            const SizedBox(height: 24),
            Text(
              'Pocket Guide',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: PGColors.white,
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
    return Stack(
      children: [
        Scaffold(
          backgroundColor: PGColors.background,
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: PGTabBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: [
              PGTabItem(
                icon: CupertinoIcons.house,
                activeIcon: CupertinoIcons.house_fill,
                label: 'Tours',
              ),
              PGTabItem(
                icon: CupertinoIcons.person,
                activeIcon: CupertinoIcons.person_fill,
                label: 'Account',
              ),
            ],
          ),
        ),
        // Floating action button overlay (using Material FAB for functionality)
        Positioned(
          right: 16,
          bottom: 70,
          child: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const CreateTourScreen(),
                ),
              );
            },
            backgroundColor: PGColors.brand,
            elevation: 4,
            child: Icon(CupertinoIcons.add, size: 32, color: PGColors.white),
          ),
        ),
      ],
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
    return CupertinoPageScaffold(
      backgroundColor: PGColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large title header
          PGLargeNavigationBar(
            title: _selectedCity ?? 'Select City',
            showChevron: true,
            onTitleTap: _showCitySelector,
            trailing: PGNavButton(
              icon: CupertinoIcons.paintbrush,
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => const DesignSystemPreview(),
                  ),
                );
              },
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
                          CupertinoIcons.map,
                          size: 80,
                          color: PGColors.gray300,
                        ),
                        SizedBox(height: PGSpacing.l),
                        Text(
                          'Select a destination to view tours',
                          style: PGTypography.body.copyWith(
                            color: PGColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: PGSpacing.m),
                        PGButtonText(
                          text: 'Choose City',
                          onPressed: _showCitySelector,
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
      decoration: BoxDecoration(
        color: PGColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(PGRadius.l)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: PGSpacing.m),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: PGColors.gray300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: PGSpacing.paddingL,
            child: Text(
              'Select Destination',
              style: PGTypography.title2,
            ),
          ),
          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: PGSpacing.l),
            child: CupertinoSearchTextField(
              controller: _searchController,
              onChanged: _filterCities,
              placeholder: 'Search cities...',
              style: PGTypography.body,
              backgroundColor: PGColors.gray100,
            ),
          ),
          SizedBox(height: PGSpacing.l),
          // Popular Cities label
          Padding(
            padding: EdgeInsets.symmetric(horizontal: PGSpacing.l),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Popular Cities',
                style: PGTypography.headline,
              ),
            ),
          ),
          SizedBox(height: PGSpacing.s),
          // Cities list
          Flexible(
            child: widget.loading
                ? Center(
                    child: Padding(
                      padding: PGSpacing.paddingXL,
                      child: CupertinoActivityIndicator(
                        color: PGColors.brand,
                      ),
                    ),
                  )
                : _filteredCities.isEmpty
                    ? Center(
                        child: Padding(
                          padding: PGSpacing.paddingXL,
                          child: Text(
                            'No cities found',
                            style: PGTypography.body.copyWith(
                              color: PGColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _filteredCities.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: PGColors.divider,
                          indent: PGSpacing.l + 40,
                        ),
                        itemBuilder: (context, index) {
                          final city = _filteredCities[index];
                          return CupertinoButton(
                            padding: EdgeInsets.symmetric(
                              horizontal: PGSpacing.l,
                              vertical: PGSpacing.m,
                            ),
                            onPressed: () => widget.onCitySelected(city),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.building_2_fill,
                                  color: PGColors.brand,
                                  size: 24,
                                ),
                                SizedBox(width: PGSpacing.l),
                                Expanded(
                                  child: Text(
                                    city,
                                    style: PGTypography.body,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          SizedBox(height: PGSpacing.l),
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
      print('🔑 _loadMyTours: Access token retrieved: ${accessToken != null ? "EXISTS (${accessToken.substring(0, accessToken.length > 20 ? 20 : accessToken.length)}...)" : "NULL"}');
      if (accessToken != null) {
        print('📡 _loadMyTours: Calling getMyTours with token...');
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
        // Text-based tabs with underline
        Padding(
          padding: EdgeInsets.symmetric(horizontal: PGSpacing.l),
          child: Row(
            children: [
              _buildTextTab('My Tours', 0),
              SizedBox(width: PGSpacing.xl),
              _buildTextTab('Public Tours', 1),
            ],
          ),
        ),
        SizedBox(height: PGSpacing.m),
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

  Widget _buildTextTab(String label, int index) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.index = index;
        });
      },
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: PGTypography.title3.copyWith(
                color: isSelected ? PGColors.textPrimary : PGColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            SizedBox(height: PGSpacing.xs),
            Container(
              height: 2,
              decoration: BoxDecoration(
                color: isSelected ? PGColors.brand : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyToursTab() {
    if (_loadingMyTours) {
      return Center(
        child: CupertinoActivityIndicator(color: PGColors.brand),
      );
    }

    if (_errorMyTours != null) {
      return Center(
        child: Padding(
          padding: PGSpacing.screen,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 60,
                color: PGColors.error,
              ),
              SizedBox(height: PGSpacing.l),
              Text(
                'Failed to load tours',
                style: PGTypography.headline.copyWith(color: PGColors.error),
              ),
              SizedBox(height: PGSpacing.s),
              Text(
                _errorMyTours!,
                style: PGTypography.footnote.copyWith(
                  color: PGColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: PGSpacing.l),
              PGButton(
                text: 'Retry',
                onPressed: _loadMyTours,
              ),
            ],
          ),
        ),
      );
    }

    if (_myTours.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.map,
              size: 80,
              color: PGColors.gray300,
            ),
            SizedBox(height: PGSpacing.l),
            Text(
              'No tours created yet',
              style: PGTypography.body.copyWith(
                color: PGColors.textSecondary,
              ),
            ),
            SizedBox(height: PGSpacing.s),
            Text(
              'Tap the + button to create your first tour',
              style: PGTypography.subheadline.copyWith(
                color: PGColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: PGSpacing.paddingL,
      itemCount: _myTours.length,
      separatorBuilder: (context, index) => SizedBox(height: PGSpacing.m),
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
      return Center(
        child: CupertinoActivityIndicator(color: PGColors.brand),
      );
    }

    if (_errorPublicTours != null) {
      return Center(
        child: Padding(
          padding: PGSpacing.screen,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 60,
                color: PGColors.error,
              ),
              SizedBox(height: PGSpacing.l),
              Text(
                'Failed to load tours',
                style: PGTypography.headline.copyWith(color: PGColors.error),
              ),
              SizedBox(height: PGSpacing.s),
              Text(
                _errorPublicTours!,
                style: PGTypography.footnote.copyWith(
                  color: PGColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: PGSpacing.l),
              PGButton(
                text: 'Retry',
                onPressed: _loadPublicTours,
              ),
            ],
          ),
        ),
      );
    }

    if (_publicTours.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.map,
              size: 80,
              color: PGColors.gray300,
            ),
            SizedBox(height: PGSpacing.l),
            Text(
              'No public tours available for ${widget.city}',
              style: PGTypography.body.copyWith(
                color: PGColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: PGSpacing.paddingL,
      itemCount: _publicTours.length,
      separatorBuilder: (context, index) => SizedBox(height: PGSpacing.m),
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
    return PGTourCard(
      title: title,
      subtitle: city,
      duration: '$days days',
      poiCount: totalPois,
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => TourWithTranscriptScreen(tourId: tourId),
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
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final AuthService _authService = AuthService();
  bool _loading = false;

  Future<void> _handleLogout() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Logout', style: PGTypography.headline),
        content: Text(
          'Are you sure you want to logout?',
          style: PGTypography.body,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: PGColors.brand)),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
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
          CupertinoPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PGColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large title header
          PGLargeNavigationBar(
            title: 'Account',
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CupertinoActivityIndicator(color: PGColors.brand),
                  )
                : ListView(
                    padding: EdgeInsets.symmetric(horizontal: PGSpacing.l),
                    children: [
                      SizedBox(height: PGSpacing.l),
                  // Logout button
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _handleLogout,
                    child: Container(
                      padding: PGSpacing.paddingL,
                      decoration: BoxDecoration(
                        color: PGColors.surface,
                        borderRadius: PGRadius.radiusM,
                        border: Border.all(color: PGColors.error, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.arrow_right_square,
                            color: PGColors.error,
                            size: 24,
                          ),
                          SizedBox(width: PGSpacing.l),
                          Expanded(
                            child: Text(
                              'Logout',
                              style: PGTypography.body.copyWith(
                                color: PGColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

  // Open map in preview mode (no GPS tracking)
  void _openMapPreview() {
    if (_tourDetail == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MapTourScreen(
          tourDetail: _tourDetail!,
          isActiveMode: false, // Preview mode
        ),
      ),
    );
  }

  // Start tour in active mode (with GPS tracking)
  void _startTour() {
    if (_tourDetail == null) return;

    // TODO: Request location permission before navigation
    // For now, just navigate to active mode
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MapTourScreen(
          tourDetail: _tourDetail!,
          isActiveMode: true, // Active mode with GPS
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPendingChanges = _pendingSwaps.isNotEmpty;

    return CupertinoPageScaffold(
      backgroundColor: PGColors.background,
      navigationBar: PGNavigationBar(
        title: _tourDetail?.metadata?.titleDisplay ?? 'Tour',
        leading: PGBackButton(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPendingChanges)
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                onPressed: _applyChanges,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: PGSpacing.m,
                    vertical: PGSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: PGColors.brand,
                    borderRadius: BorderRadius.circular(PGRadius.s),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.cloud_upload,
                        size: 14,
                        color: PGColors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Apply ${_pendingSwaps.length}',
                        style: PGTypography.caption1.copyWith(
                          color: PGColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (hasPendingChanges) SizedBox(width: PGSpacing.s),
            PGNavButton(
              icon: CupertinoIcons.map,
              onPressed: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => CupertinoActionSheet(
                    title: Text('Map View'),
                    actions: [
                      CupertinoActionSheetAction(
                        child: Text('Preview in Map'),
                        onPressed: () {
                          Navigator.pop(context);
                          _openMapPreview();
                        },
                      ),
                      CupertinoActionSheetAction(
                        child: Text('Start Tour'),
                        onPressed: () {
                          Navigator.pop(context);
                          _startTour();
                        },
                      ),
                    ],
                    cancelButton: CupertinoActionSheetAction(
                      isDefaultAction: true,
                      child: Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: _loading
            ? Center(
                child: CupertinoActivityIndicator(color: PGColors.brand),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: PGSpacing.screen,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_triangle,
                            size: 60,
                            color: PGColors.error,
                          ),
                          SizedBox(height: PGSpacing.l),
                          Text(
                            'Failed to load tour',
                            style: PGTypography.headline.copyWith(
                              color: PGColors.error,
                            ),
                          ),
                          SizedBox(height: PGSpacing.s),
                          Text(
                            _error!,
                            style: PGTypography.footnote.copyWith(
                              color: PGColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildTourContent(),
      ),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: PGSpacing.l,
                    vertical: PGSpacing.m,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Serial number as plain text
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${poiIndex + 1}',
                          style: PGTypography.title2.copyWith(
                            color: PGColors.textSecondary,
                          ),
                        ),
                      ),
                      SizedBox(width: PGSpacing.m),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPOI,
                              style: PGTypography.headline,
                            ),
                            SizedBox(height: PGSpacing.xs),
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.time,
                                  size: 14,
                                  color: PGColors.textTertiary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${poi.estimatedHours.toStringAsFixed(1)} hours',
                                  style: PGTypography.subheadline,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Alternatives button
                      Builder(
                        builder: (context) {
                          final hasBackups = _tourDetail!.backupPois != null &&
                                            _tourDetail!.backupPois!.containsKey(poi.poi);

                          if (!hasBackups) return const SizedBox.shrink();

                          return CupertinoButton(
                            padding: EdgeInsets.symmetric(
                              horizontal: PGSpacing.s,
                              vertical: PGSpacing.xs,
                            ),
                            minSize: 0,
                            onPressed: () => _showAlternatives(poi, currentPOI, dayNumber, poiIndex, isSwapped),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.arrow_2_squarepath,
                                  size: 16,
                                  color: PGColors.brand,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Swap',
                                  style: PGTypography.caption1.copyWith(
                                    color: PGColors.brand,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
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
  final _audioService = BackgroundAudioService.instance;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isExpanded = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    // Listen to playback state changes
    _audioService.playbackStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlaybackState.playing;
          _isLoading = state == PlaybackState.buffering;
          if (state == PlaybackState.completed) {
            _position = Duration.zero;
          }
        });
      }
    });

    // Listen to position changes
    _audioService.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    // Listen to duration changes
    _audioService.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (widget.audioUrl == null) return;

    try {
      if (_isPlaying) {
        await _audioService.pause();
      } else {
        if (_position == Duration.zero) {
          setState(() {
            _isLoading = true;
          });
          await _audioService.play(
            url: widget.audioUrl!,
            title: widget.section.title,
            subtitle: 'Section ${widget.section.sectionNumber}',
          );
        } else {
          await _audioService.resume();
        }
      }
    } catch (e) {
      print('Error playing audio: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play audio: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
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

