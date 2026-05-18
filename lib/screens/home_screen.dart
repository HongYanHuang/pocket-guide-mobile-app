import 'package:flutter/cupertino.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/spacing.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';
import 'package:pocket_guide_mobile/services/active_tour_service.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/screens/map_tour_screen.dart';
import 'package:pocket_guide_mobile/screens/create_tour_screen.dart';
import 'package:pocket_guide_mobile/widgets/home/category_rail.dart';
import 'package:pocket_guide_mobile/widgets/home/city_picker_sheet.dart';
import 'package:pocket_guide_mobile/widgets/home/continue_walking_banner.dart';
import 'package:pocket_guide_mobile/widgets/home/tour_card_compact.dart';
import 'package:pocket_guide_mobile/widgets/home/tour_card_large.dart';

class HomeScreen extends StatefulWidget {
  /// Called when the user taps a tour card — navigates to the detail view.
  /// Provided by the parent (MainScreen) to avoid a circular import with
  /// TourWithTranscriptScreen which is still defined in main.dart.
  final void Function(String tourId)? onTourTap;

  const HomeScreen({super.key, this.onTourTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();

  List<City> _cities = [];
  List<CategoryItem> _apiCategories = [];
  List<TourSummary> _tours = [];
  bool _loadingTours = true;

  /// Slug of the currently selected city; null = Nearby / show all.
  String? _selectedCitySlug;

  /// Slug of the currently selected category; null = "All".
  String? _selectedCategorySlug;

  /// Active tour state restored from SharedPreferences.
  String? _activeTourId;
  int _activeTourDay = 1;

  // ── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadCities();
    _loadCategories();
    _loadTours();
    _loadActiveTour();
  }

  Future<void> _loadCities() async {
    final cities = await _api.getCityObjects();
    if (mounted) setState(() => _cities = cities);
  }

  Future<void> _loadCategories() async {
    final cats = await _api.getCategories(city: _selectedCitySlug);
    if (mounted) setState(() => _apiCategories = cats);
  }

  Future<void> _loadTours() async {
    final tours = await _api.getAllTours(
      city: _selectedCitySlug,
      category: _selectedCategorySlug,
    );
    if (mounted)
      setState(() {
        _tours = tours;
        _loadingTours = false;
      });
  }

  Future<void> _loadActiveTour() async {
    try {
      final id = await ActiveTourService().getActiveTourId();
      final day = await ActiveTourService().getActiveDay();
      if (mounted)
        setState(() {
          _activeTourId = id;
          _activeTourDay = day;
        });
    } catch (e) {
      print('Failed to load active tour state: $e');
    }
  }

  // ── Computed properties ──────────────────────────────────────────

  /// Labels for the category rail: "All" prepended, then API-sourced categories.
  List<String> get _categoryLabels =>
      ['All', ..._apiCategories.map((c) => c.label)];

  /// Index of the active category pill (0 = "All").
  int get _activeCategoryIndex {
    if (_selectedCategorySlug == null) return 0;
    final idx = _apiCategories.indexWhere((c) => c.slug == _selectedCategorySlug);
    return idx < 0 ? 0 : idx + 1;
  }

  /// Tours from the server (already filtered), personalised first.
  List<TourSummary> get _filteredTours {
    final result = List<TourSummary>.from(_tours);
    result.sort(
      (a, b) =>
          ((b.isPersonalized ?? false) ? 1 : 0) -
          ((a.isPersonalized ?? false) ? 1 : 0),
    );
    return result;
  }

  /// The active TourSummary if we have an active tour ID that's in the list.
  TourSummary? get _activeTour {
    if (_activeTourId == null) return null;
    try {
      return _tours.firstWhere((t) => t.tourId == _activeTourId);
    } catch (_) {
      return null;
    }
  }

  // ── Navigation ───────────────────────────────────────────────────

  void _openTour(String tourId) {
    widget.onTourTap?.call(tourId);
  }

  Future<void> _resumeActiveTour() async {
    if (_activeTourId == null) return;
    // MapTourScreen needs a full TourDetail — fetch it before navigating.
    final tourDetail = await _api.getTourById(_activeTourId!);
    if (!mounted || tourDetail == null) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => MapTourScreen(
          tourDetail: tourDetail,
          isActiveMode: true,
          initialDay: _activeTourDay,
        ),
      ),
    );
  }

  void _openCreateTour() {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const CreateTourScreen()),
    );
  }

  void _showCityPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CityPickerSheet(
        selectedSlug: _selectedCitySlug,
        cities: _cities,
        onPick: (slug) {
          setState(() {
            _selectedCitySlug = slug;
            _selectedCategorySlug = null; // reset category on city change
            _loadingTours = true;
          });
          _loadCategories();
          _loadTours();
        },
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final activeTour = _activeTour;
    final filteredTours = _filteredTours;
    final categories = _categoryLabels;
    final cityName = _selectedCitySlug == null
        ? 'Nearby'
        : (_cities
                  .where((c) => c.slug == _selectedCitySlug)
                  .map((c) => c.name)
                  .firstOrNull ??
              'Nearby');

    return ColoredBox(
      color: PGColors.rawiPaper,
      child: CustomScrollView(
        slivers: [
          // Status bar spacer
          SliverToBoxAdapter(child: SizedBox(height: topPadding)),

          // ── City pill + avatar row ────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
              child: Row(
                children: [
                  // City pill
                  GestureDetector(
                    onTap: _showCityPicker,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                      decoration: BoxDecoration(
                        color: PGColors.rawiInk,
                        borderRadius: BorderRadius.circular(PGRadius.pill),
                        boxShadow: [
                          BoxShadow(
                            color: PGColors.rawiInk.withOpacity(0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _cityIcon(cityName),
                            style: const TextStyle(fontSize: 17),
                          ),
                          const SizedBox(width: 8),
                          Text(cityName, style: RawiTypography.cityPill()),
                          const SizedBox(width: 6),
                          const Icon(
                            CupertinoIcons.chevron_down,
                            size: 11,
                            color: PGColors.rawiPaper,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // User avatar placeholder
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFC9A67A), Color(0xFF6E5733)],
                      ),
                      border: Border.all(color: PGColors.rawiHair, width: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Category rail ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: CategoryRail(
                categories: categories,
                activeIndex: _activeCategoryIndex.clamp(
                  0,
                  (categories.length - 1).clamp(0, 999),
                ),
                onChanged: (i) {
                  final slug = i == 0 ? null : _apiCategories[i - 1].slug;
                  if (slug == _selectedCategorySlug) return;
                  setState(() {
                    _selectedCategorySlug = slug;
                    _loadingTours = true;
                  });
                  _loadTours();
                },
              ),
            ),
          ),

          // ── Continue walking (if active) ────────────────
          if (activeTour != null)
            SliverToBoxAdapter(
              child: ContinueWalkingBanner(
                tour: activeTour,
                currentDay: _activeTourDay,
                onTap: _resumeActiveTour,
              ),
            ),

          // ── Nearby / Featured rail (no active tour) ─────
          if (activeTour == null && filteredTours.isNotEmpty)
            SliverToBoxAdapter(
              child: _NearbyRail(
                cityName: cityName,
                tours: filteredTours.take(3).toList(),
                onTap: (id) => _openTour(id),
              ),
            ),

          // ── Tour count + "Personalized" header ──────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${filteredTours.length}',
                            style: RawiTypography.sectionTitle(
                              color: PGColors.rawiAccent,
                            ),
                          ),
                          TextSpan(
                            text: filteredTours.length == 1
                                ? ' tour found'
                                : ' tours found',
                            style: RawiTypography.sectionTitle(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Personalized shortcut button
                  GestureDetector(
                    onTap: _openCreateTour,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(PGRadius.pill),
                        border: Border.all(
                          color: PGColors.rawiAccent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Personalized',
                            style: RawiTypography.meta(
                              color: PGColors.rawiAccent,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          const Text('🔒', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading state ────────────────────────────────
          if (_loadingTours)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            ),

          // ── Empty state ──────────────────────────────────
          if (!_loadingTours && filteredTours.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 40,
                ),
                child: Center(
                  child: Text(
                    'No tours found for this filter.',
                    style: RawiTypography.place(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          // ── Tour cards ───────────────────────────────────
          if (!_loadingTours)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i < filteredTours.length) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: TourCardLarge(
                          tour: filteredTours[i],
                          onTap: () => _openTour(filteredTours[i].tourId),
                        ),
                      );
                    }
                    // CTA at end of list
                    return _CreateTourCTA(onTap: _openCreateTour);
                  },
                  childCount: filteredTours.isEmpty
                      ? 0
                      : filteredTours.length + 1,
                ),
              ),
            ),

          // Bottom safe area
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + 100,
            ),
          ),
        ],
      ),
    );
  }

  String _cityIcon(String cityName) {
    if (cityName == 'Nearby') return '🧭';
    return _cities
            .where((c) => c.name == cityName)
            .firstOrNull
            ?.emoji ??
        '📍';
  }
}

// ── Nearby / Featured horizontal rail ───────────────────────────────────────

class _NearbyRail extends StatelessWidget {
  final String cityName;
  final List<TourSummary> tours;
  final void Function(String tourId) onTap;

  const _NearbyRail({
    required this.cityName,
    required this.tours,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = cityName == 'Nearby' ? 'Near you' : 'Featured in $cityName';

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: RawiTypography.sectionTitle(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {}, // TODO: open map view
                  child: Text(
                    'Map',
                    style: RawiTypography.meta(
                      color: PGColors.rawiAccent,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: tours.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => TourCardCompact(
                tour: tours[i],
                onTap: () => onTap(tours[i].tourId),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create tour CTA ──────────────────────────────────────────────────────────

class _CreateTourCTA extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateTourCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: PGColors.rawiPaper2,
        border: Border.all(color: PGColors.rawiHair, width: 0.5),
        borderRadius: BorderRadius.circular(PGRadius.rawiCard),
      ),
      child: Column(
        children: [
          Text(
            'Can\'t find a tour that suits you?',
            style: RawiTypography.cardTitle(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Tell us what you\'re curious about — we\'ll narrate one just for you.',
            style: RawiTypography.ctaBody(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: PGColors.rawiAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.add,
                    size: 14,
                    color: PGColors.rawiPaper,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Create your personalized tour',
                    style: RawiTypography.meta(
                      color: PGColors.rawiPaper,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
