import 'dart:ui';
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
import 'package:pocket_guide_mobile/widgets/network_image_with_fallback.dart';
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
                                    style: PGTypography.body.copyWith(
                                      decoration: TextDecoration.none,
                                    ),
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

        // Extract cover image URL if available
        String? coverImageUrl;
        try {
          if (tour['images'] != null) {
            final images = tour['images'] as Map<String, dynamic>;
            if (images['cover'] != null) {
              final cover = images['cover'] as Map<String, dynamic>;
              if (cover['url'] != null) {
                coverImageUrl = '${ApiService.baseUrl}${cover['url']}';
              }
            }
          }
        } catch (e) {
          // Silently ignore if image extraction fails
        }

        return _buildTourCard(
          context,
          tourId: tour['tour_id'] as String,
          title: tour['title_display'] as String? ?? tour['tour_id'] as String,
          days: tour['duration_days'] as int,
          city: tour['city'] as String,
          totalPois: tour['total_pois'] as int,
          coverImageUrl: coverImageUrl,
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
    String? coverImageUrl,
  }) {
    return PGTourCard(
      title: title,
      subtitle: city,
      duration: '$days days',
      poiCount: totalPois,
      coverImageUrl: coverImageUrl,
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
        title: Text(
          'Logout',
          style: PGTypography.headline.copyWith(
            decoration: TextDecoration.none,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: PGTypography.body.copyWith(
            decoration: TextDecoration.none,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: PGColors.brand,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Logout',
              style: TextStyle(decoration: TextDecoration.none),
            ),
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
                                decoration: TextDecoration.none,
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
  Map<String, dynamic>? _rawTourData; // Store raw API response for images
  bool _loading = true;
  String? _error;

  Map<String, POISwap> _pendingSwaps = {};

  // Cache transcript futures to prevent redundant API calls
  final Map<String, Future<SectionedTranscriptData?>> _transcriptCache = {};

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

      // Fetch raw tour data to extract images (not typed in generated API)
      try {
        final dio = _apiService.dio;
        if (accessToken != null) {
          dio.options.headers['Authorization'] = 'Bearer $accessToken';
        }
        final rawResponse = await dio.get(
          '/tours/${widget.tourId}',
          queryParameters: {'language': 'en'},
        );
        _rawTourData = rawResponse.data as Map<String, dynamic>;
      } catch (e) {
        print('Failed to fetch raw tour data: $e');
        _rawTourData = null;
      }

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

  // Helper to extract cover image URL from tour detail
  String? _getCoverImageUrl(TourDetail tourDetail) {
    if (_rawTourData == null) return null;

    try {
      // Access the images field from raw API response data
      if (_rawTourData!['images'] != null) {
        final images = _rawTourData!['images'] as Map<String, dynamic>;
        if (images['cover'] != null) {
          final cover = images['cover'] as Map<String, dynamic>;
          if (cover['url'] != null) {
            return '${ApiService.baseUrl}${cover['url']}';
          }
        }
      }
    } catch (e) {
      print('Error extracting cover image URL: $e');
    }
    return null;
  }

  // Helper to extract total duration hours from raw data
  double? _getTotalDurationHours() {
    if (_rawTourData == null) return null;
    try {
      if (_rawTourData!['total_duration_hours'] != null) {
        return (_rawTourData!['total_duration_hours'] as num).toDouble();
      }
    } catch (e) {
      print('Error extracting total duration hours: $e');
    }
    return null;
  }

  // Helper to extract total walking km from raw data
  double? _getTotalWalkingKm() {
    if (_rawTourData == null) return null;
    try {
      if (_rawTourData!['total_walking_km'] != null) {
        return (_rawTourData!['total_walking_km'] as num).toDouble();
      }
    } catch (e) {
      print('Error extracting total walking km: $e');
    }
    return null;
  }

  // Helper to format duration from hours to readable string
  // For per-day durations, always show hours (showDays=false in day headers)
  String _formatDuration(double hours, {bool showDays = false}) {
    if (showDays && hours > 24) {
      final days = (hours / 24).round();
      return '$days ${days == 1 ? 'day' : 'days'}';
    }

    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (m == 0) {
      return '$h hours';
    }
    return '$h hours $m min';
  }

  // Helper to format walking distance
  String _formatWalkingDistance(double km) {
    return '${km.toStringAsFixed(2)} km';
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
    final coverImageUrl = _tourDetail != null ? _getCoverImageUrl(_tourDetail!) : null;

    if (_loading) {
      return CupertinoPageScaffold(
        backgroundColor: PGColors.background,
        child: Center(
          child: CupertinoActivityIndicator(color: PGColors.brand),
        ),
      );
    }

    if (_error != null) {
      return CupertinoPageScaffold(
        backgroundColor: PGColors.background,
        child: Center(
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
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: PGSpacing.s),
                Text(
                  _error!,
                  style: PGTypography.footnote.copyWith(
                    color: PGColors.textSecondary,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: PGColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Collapsing header with cover image (1:1 aspect ratio)
              if (coverImageUrl != null)
                SliverAppBar(
                  expandedHeight: screenWidth,
                  pinned: false,
                  backgroundColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: NetworkImageWithFallback(
                      imageUrl: coverImageUrl,
                      fit: BoxFit.cover,
                      fallbackIcon: CupertinoIcons.photo_on_rectangle,
                    ),
                  ),
                ),

              // Title and metadata section
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.all(PGSpacing.l),
                  color: PGColors.background,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tourDetail?.metadata?.titleDisplay ?? 'Tour',
                        style: PGTypography.title1,
                      ),
                      // City, duration, and walking distance in one row
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: PGSpacing.m),
                        child: Row(
                          children: [
                          // City
                          Icon(
                            CupertinoIcons.location_solid,
                            size: 16,
                            color: PGColors.textTertiary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _tourDetail?.metadata?.city ?? '',
                            style: PGTypography.caption1,
                          ),
                          // Duration
                          if (_getTotalDurationHours() != null) ...[
                            SizedBox(width: PGSpacing.m),
                            Text(
                              '·',
                              style: PGTypography.caption1,
                            ),
                            SizedBox(width: PGSpacing.m),
                            Icon(
                              CupertinoIcons.time,
                              size: 16,
                              color: PGColors.textTertiary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              _formatDuration(_getTotalDurationHours()!, showDays: true),
                              style: PGTypography.caption1,
                            ),
                          ],
                          // Walking distance
                          if (_getTotalWalkingKm() != null) ...[
                            SizedBox(width: PGSpacing.m),
                            Text(
                              '·',
                              style: PGTypography.caption1,
                            ),
                            SizedBox(width: PGSpacing.m),
                            Icon(
                              CupertinoIcons.arrow_right_arrow_left,
                              size: 16,
                              color: PGColors.textTertiary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              _formatWalkingDistance(_getTotalWalkingKm()!),
                              style: PGTypography.caption1,
                            ),
                          ],
                        ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tour content
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, dayIndex) {
                    final itinerary = _tourDetail!.itinerary.toList();
                    final day = itinerary[dayIndex];

                    return _DaySection(
                      key: ValueKey('day-${day.day}'),
                      day: day,
                      initiallyExpanded: dayIndex == 0,
                      tourDetail: _tourDetail!,
                      pendingSwaps: _pendingSwaps,
                      onShowAlternatives: _showAlternatives,
                      onFetchSectionedTranscript: _fetchSectionedTranscript,
                    );
                  },
                  childCount: _tourDetail!.itinerary.length,
                ),
              ),

              // Bottom padding to prevent floating button from blocking content
              SliverPadding(
                padding: EdgeInsets.only(bottom: 160),
              ),
            ],
          ),

          // Back button overlay
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Container(
                margin: EdgeInsets.all(PGSpacing.m),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: PGBackButton(),
              ),
            ),
          ),

          // Apply changes button (if needed)
          if (hasPendingChanges)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  margin: EdgeInsets.all(PGSpacing.m),
                  child: CupertinoButton(
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
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Floating map button with gradient background overlay
          if (!_loading && _error == null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.6),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
                child: Center(
                  child: Container(
                    margin: EdgeInsets.only(bottom: 24),
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(
                        horizontal: PGSpacing.xl,
                        vertical: PGSpacing.m,
                      ),
                      color: PGColors.brand,
                      borderRadius: BorderRadius.circular(PGRadius.l),
                      onPressed: _openMapPreview,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.map_fill,
                            color: PGColors.white,
                            size: 20,
                          ),
                          SizedBox(width: PGSpacing.s),
                          Text(
                            'Map',
                            style: PGTypography.body.copyWith(
                              color: PGColors.white,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<SectionedTranscriptData?> _fetchSectionedTranscript(String poiName, String city) async {
    final poiId = poiName.toLowerCase().replaceAll(' ', '-').replaceAll("'", '');
    final cacheKey = '${widget.tourId}/$city/$poiId';

    // Return cached future if exists
    if (_transcriptCache.containsKey(cacheKey)) {
      print('✅ Using cached transcript for: $city/$poiId');
      return _transcriptCache[cacheKey]!;
    }

    // Create and cache new future
    print('🆕 Fetching sectioned transcript for: $city/$poiId (tour: ${widget.tourId}, language: en)');
    final future = _fetchTranscriptFromAPI(poiId, city);
    _transcriptCache[cacheKey] = future;
    return future;
  }

  Future<SectionedTranscriptData?> _fetchTranscriptFromAPI(String poiId, String city) async {
    try {
      String language = 'en';
      if (_tourDetail?.metadata?.languages != null && _tourDetail!.metadata!.languages!.isNotEmpty) {
        language = _tourDetail!.metadata!.languages!.first;
      }

      final response = await _apiService.fetchSectionedTranscript(city, poiId, widget.tourId, language);
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

class _DaySection extends StatefulWidget {
  final TourDay day;
  final bool initiallyExpanded;
  final TourDetail tourDetail;
  final Map<String, POISwap> pendingSwaps;
  final Function(TourPOI, String, int, int, bool) onShowAlternatives;
  final Future<SectionedTranscriptData?> Function(String, String) onFetchSectionedTranscript;

  const _DaySection({
    super.key,
    required this.day,
    required this.initiallyExpanded,
    required this.tourDetail,
    required this.pendingSwaps,
    required this.onShowAlternatives,
    required this.onFetchSectionedTranscript,
  });

  @override
  State<_DaySection> createState() => _DaySectionState();
}

class _DaySectionState extends State<_DaySection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    print('🔵 Day ${widget.day.day} initState called - initiallyExpanded: ${widget.initiallyExpanded}');
  }

  @override
  void didUpdateWidget(_DaySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('🟡 Day ${widget.day.day} didUpdateWidget called - current _isExpanded: $_isExpanded');
  }

  @override
  Widget build(BuildContext context) {
    print('🟢 Day ${widget.day.day} build called - _isExpanded: $_isExpanded');
    return _buildContent();
  }

  Widget _buildContent() {

  // Helper to format duration from hours to readable string
  // For per-day durations, always show hours (showDays=false in day headers)
  String _formatDuration(double hours, {bool showDays = false}) {
    if (showDays && hours > 24) {
      final days = (hours / 24).round();
      return '$days ${days == 1 ? 'day' : 'days'}';
    }

    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (m == 0) {
      return '$h hours';
    }
    return '$h hours $m min';
  }

  // Helper to format walking distance
  String _formatWalkingDistance(double km) {
    return '${km.toStringAsFixed(2)} km';
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            print('🔴 Day ${widget.day.day} button pressed - toggling from $_isExpanded to ${!_isExpanded}');
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: PGSpacing.l,
              vertical: PGSpacing.m,
            ),
            color: PGColors.gray100,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Day ${widget.day.day}',
                        style: PGTypography.title2.copyWith(
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.time,
                            size: 14,
                            color: PGColors.textTertiary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _formatDuration(widget.day.totalHours.toDouble()),
                            style: PGTypography.caption1.copyWith(
                              decoration: TextDecoration.none,
                            ),
                          ),
                          SizedBox(width: PGSpacing.m),
                          Icon(
                            CupertinoIcons.arrow_right_arrow_left,
                            size: 14,
                            color: PGColors.textTertiary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _formatWalkingDistance(widget.day.totalWalkingKm.toDouble()),
                            style: PGTypography.caption1.copyWith(
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isExpanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 20,
                  color: PGColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        // POIs list
        if (_isExpanded)
          ...widget.day.pois.asMap().entries.map((entry) {
            final poiIndex = entry.key;
            final poi = entry.value;
            final poiKey = '${widget.day.day}-$poiIndex';
            final isSwapped = widget.pendingSwaps.containsKey(poiKey);
            final currentPOI = isSwapped ? widget.pendingSwaps[poiKey]!.replacementPoi : poi.poi;

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
                            decoration: TextDecoration.none,
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
                              style: PGTypography.headline.copyWith(
                                decoration: TextDecoration.none,
                              ),
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
                                  style: PGTypography.subheadline.copyWith(
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Alternatives button
                      Builder(
                        builder: (context) {
                          final hasBackups = widget.tourDetail.backupPois != null &&
                                            widget.tourDetail.backupPois!.containsKey(poi.poi);

                          if (!hasBackups) return const SizedBox.shrink();

                          return CupertinoButton(
                            padding: EdgeInsets.symmetric(
                              horizontal: PGSpacing.s,
                              vertical: PGSpacing.xs,
                            ),
                            minSize: 0,
                            onPressed: () => widget.onShowAlternatives(poi, currentPOI, widget.day.day, poiIndex, isSwapped),
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
                                    decoration: TextDecoration.none,
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
                _buildInlineTranscript(currentPOI, widget.tourDetail.metadata!.city, poi),
                if (poiIndex < widget.day.pois.length - 1)
                  Divider(height: 1, color: PGColors.divider),
              ],
            );
          }).toList(),
      ],
    );
  }

  Widget _buildInlineTranscript(String poiName, String city, TourPOI poi) {
    return FutureBuilder<SectionedTranscriptData?>(
      future: widget.onFetchSectionedTranscript(poiName, city),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: PGSpacing.paddingL,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CupertinoActivityIndicator(color: PGColors.brand),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final sectionedData = snapshot.data!;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: PGSpacing.l, vertical: PGSpacing.m),
          color: PGColors.gray100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sectionedData.sections.map((section) {
              return _SectionCardExpanded(
                section: section,
                audioUrl: section.audioFile,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// Section Card with Audio Player (Collapsible transcript)
class _SectionCardExpanded extends StatefulWidget {
  final TranscriptSection section;
  final String? audioUrl;

  const _SectionCardExpanded({
    required this.section,
    this.audioUrl,
  });

  @override
  State<_SectionCardExpanded> createState() => _SectionCardExpandedState();
}

class _SectionCardExpandedState extends State<_SectionCardExpanded> {
  final _audioService = BackgroundAudioService.instance;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isExpanded = false; // Collapsed by default
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
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

    _audioService.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

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
    return Container(
      margin: EdgeInsets.only(bottom: PGSpacing.m),
      padding: PGSpacing.paddingL,
      decoration: BoxDecoration(
        color: PGColors.surface,
        borderRadius: PGRadius.radiusM,
        border: Border.all(color: PGColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title - tappable to expand/collapse
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.section.title,
                        style: PGTypography.headline.copyWith(
                          color: PGColors.brand,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: PGSpacing.xs),
                      Text(
                        widget.section.knowledgePoint,
                        style: PGTypography.subheadline.copyWith(
                          color: PGColors.textTertiary,
                          fontStyle: FontStyle.italic,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                  size: 20,
                  color: PGColors.textSecondary,
                ),
              ],
            ),
          ),
          SizedBox(height: PGSpacing.m),

          // Audio Player
          if (widget.audioUrl != null)
            Container(
              padding: EdgeInsets.all(PGSpacing.m),
              decoration: BoxDecoration(
                color: PGColors.gray100,
                borderRadius: BorderRadius.circular(PGRadius.s),
              ),
              child: Row(
                children: [
                  // Play/Pause Button
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    onPressed: _togglePlayPause,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: PGColors.brand,
                        shape: BoxShape.circle,
                      ),
                      child: _isLoading
                          ? Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CupertinoActivityIndicator(color: PGColors.white),
                              ),
                            )
                          : Icon(
                              _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                              color: PGColors.white,
                              size: 20,
                            ),
                    ),
                  ),
                  SizedBox(width: PGSpacing.m),
                  // Progress info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Progress bar (simplified since we can't use Slider easily)
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: PGColors.gray300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _duration.inMilliseconds > 0
                                ? _position.inMilliseconds / _duration.inMilliseconds
                                : 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: PGColors.brand,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: PGTypography.caption2.copyWith(
                                color: PGColors.textTertiary,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            Text(
                              _duration.inSeconds > 0
                                  ? _formatDuration(_duration)
                                  : _formatDuration(Duration(seconds: widget.section.estimatedDurationSeconds)),
                              style: PGTypography.caption2.copyWith(
                                color: PGColors.textTertiary,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Transcript text (only when expanded)
          if (_isExpanded) ...[
            SizedBox(height: PGSpacing.m),
            Text(
              widget.section.transcript,
              style: PGTypography.body.copyWith(
                color: PGColors.textSecondary,
                height: 1.5,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
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

