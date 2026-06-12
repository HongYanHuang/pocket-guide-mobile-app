import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showDatePicker;
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';
import 'package:pocket_guide_mobile/design_system/spacing.dart';
import 'package:intl/intl.dart';

class CreateTourScreen extends StatefulWidget {
  const CreateTourScreen({super.key});

  @override
  State<CreateTourScreen> createState() => _CreateTourScreenState();
}

class _CreateTourScreenState extends State<CreateTourScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  // Form fields
  String? _selectedCity;
  int _days = 1;
  String _language = 'en';
  String _pace = 'normal';
  String _walking = 'moderate';
  DateTime _startDate = DateTime.now();

  // Interests
  final Map<String, bool> _selectedInterests = {
    'History': false,
    'Architecture': false,
    'Food & Dining': false,
    'Art & Museums': false,
    'Nature & Parks': false,
    'Shopping': false,
    'Nightlife': false,
    'Local Culture': false,
    'Religious Sites': false,
    'Photography': false,
  };

  // Must-see POIs
  final TextEditingController _mustSeeController = TextEditingController();
  final List<String> _mustSeePOIs = [];

  // Start/End location
  final TextEditingController _startLocationController = TextEditingController();
  final TextEditingController _endLocationController = TextEditingController();
  bool _useDifferentEndLocation = false;

  bool _isLoading = false;
  List<String> _cities = [];

  @override
  void initState() {
    super.initState();
    _loadCities();
    _setDefaultLanguage();
  }

  @override
  void dispose() {
    _mustSeeController.dispose();
    _startLocationController.dispose();
    _endLocationController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final cities = await _apiService.getCities();
      setState(() {
        _cities = cities;
        if (_cities.isNotEmpty) {
          _selectedCity = _cities[0];
        }
      });
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to load cities: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  void _setDefaultLanguage() {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final languageCode = systemLocale.languageCode;

    if (languageCode == 'zh') {
      _language = systemLocale.countryCode == 'CN' ? 'zh-cn' : 'zh-tw';
    } else if (['en', 'fr', 'es', 'ja', 'ko'].contains(languageCode)) {
      _language = languageCode;
    } else if (languageCode == 'pt') {
      _language = 'pt-br';
    } else {
      _language = 'en';
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  void _addMustSeePOI() {
    final poi = _mustSeeController.text.trim();
    if (poi.isNotEmpty && !_mustSeePOIs.contains(poi)) {
      setState(() {
        _mustSeePOIs.add(poi);
        _mustSeeController.clear();
      });
    }
  }

  void _removeMustSeePOI(String poi) {
    setState(() {
      _mustSeePOIs.remove(poi);
    });
  }

  Future<void> _generateTour() async {
    if (_selectedCity == null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Missing Information'),
          content: const Text('Please select a city'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) throw Exception('Not authenticated');

      final selectedInterestsList = _selectedInterests.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final response = await _apiService.generateTour(
        accessToken: accessToken,
        city: _selectedCity!,
        days: _days,
        language: _language,
        pace: _pace,
        walking: _walking,
        interests: selectedInterestsList.isEmpty ? null : selectedInterestsList,
        mustSee: _mustSeePOIs.isEmpty ? null : _mustSeePOIs,
        startLocation: _startLocationController.text.trim().isEmpty
            ? null
            : _startLocationController.text.trim(),
        endLocation: _useDifferentEndLocation &&
                _endLocationController.text.trim().isNotEmpty
            ? _endLocationController.text.trim()
            : null,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
      );

      final tourId = response['tour_id'] as String;
      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.of(context).pop(tourId);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Generation Failed'),
            content: Text('Failed to generate tour: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PGColors.rawiPaper2,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: PGColors.rawiPaper2,
        border: Border(
          bottom: BorderSide(color: PGColors.rawiHair),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(
            CupertinoIcons.back,
            color: PGColors.rawiInk,
          ),
        ),
        middle: Text(
          'Create Tour',
          style: PGTypography.headline.copyWith(color: PGColors.rawiInk),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.symmetric(
                horizontal: PGSpacing.l,
                vertical: PGSpacing.l,
              ),
              children: [
                // ── Destination ──────────────────────────────────────────
                _buildSectionHeader('Destination'),
                const SizedBox(height: 10),
                _buildDestinationDropdown(),
                SizedBox(height: PGSpacing.xxl),

                // ── Duration & Date ──────────────────────────────────────
                _buildSectionHeader('Duration & Date'),
                const SizedBox(height: 10),
                _buildDurationDateRow(),
                SizedBox(height: PGSpacing.xxl),

                // ── Interests ────────────────────────────────────────────
                _buildSectionHeader('Interests'),
                const SizedBox(height: 10),
                _buildInterestChips(),
                SizedBox(height: PGSpacing.xxl),

                // ── Preferences ──────────────────────────────────────────
                _buildSectionHeader('Preferences'),
                const SizedBox(height: 10),
                _buildSegmentCard(
                  label: 'Pace',
                  currentValue: _pace,
                  options: const {
                    'relaxed': 'Relaxed',
                    'normal': 'Normal',
                    'fast': 'Fast',
                  },
                  onChanged: (v) => setState(() => _pace = v),
                ),
                const SizedBox(height: 10),
                _buildSegmentCard(
                  label: 'Walking',
                  currentValue: _walking,
                  options: const {
                    'light': 'Light',
                    'moderate': 'Moderate',
                    'intensive': 'Intensive',
                  },
                  onChanged: (v) => setState(() => _walking = v),
                ),
                SizedBox(height: PGSpacing.xxl),

                // ── Must-See Places ───────────────────────────────────────
                _buildSectionHeader('Must-See Places (Optional)'),
                const SizedBox(height: 10),
                _buildMustSeeRow(),
                if (_mustSeePOIs.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildMustSeeTags(),
                ],
                SizedBox(height: PGSpacing.xxl),

                // ── Start Location ───────────────────────────────────────
                _buildSectionHeader('Start Location (Optional)'),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _startLocationController,
                  placeholder: 'e.g., Hotel name or address',
                ),
                const SizedBox(height: 14),
                _buildDifferentEndToggle(),
                if (_useDifferentEndLocation) ...[
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _endLocationController,
                    placeholder: 'End location',
                  ),
                ],
                SizedBox(height: PGSpacing.xxl * 2),

                // ── Generate button ──────────────────────────────────────
                _buildGenerateButton(),
                SizedBox(height: PGSpacing.xxl),
              ],
            ),

            // Loading overlay
            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  // ── Section components ─────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: PGTypography.title3.copyWith(
        color: PGColors.rawiInk,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildDestinationDropdown() {
    return GestureDetector(
      onTap: _showCityPicker,
      child: _card(
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedCity ?? 'Select a city',
                style: PGTypography.body.copyWith(
                  color: _selectedCity != null
                      ? PGColors.rawiInk
                      : PGColors.rawiInk4,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_down,
              size: 18,
              color: PGColors.rawiInk3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationDateRow() {
    return Row(
      children: [
        // Days
        Expanded(
          child: GestureDetector(
            onTap: _showDaysPicker,
            child: _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Days',
                    style: PGTypography.caption1.copyWith(
                      color: PGColors.rawiInk3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_days',
                        style: PGTypography.body.copyWith(
                          color: PGColors.rawiInk,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.chevron_down,
                        size: 14,
                        color: PGColors.rawiInk3,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Start Date
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDate(context),
            child: _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Date',
                    style: PGTypography.caption1.copyWith(
                      color: PGColors.rawiInk3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(_startDate),
                    style: PGTypography.body.copyWith(
                      color: PGColors.rawiInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInterestChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedInterests.keys.map((interest) {
        final selected = _selectedInterests[interest]!;
        return GestureDetector(
          onTap: () => setState(
            () => _selectedInterests[interest] = !selected,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? PGColors.rawiAccent : PGColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? PGColors.rawiAccent
                    : PGColors.rawiHair,
              ),
            ),
            child: Text(
              interest,
              style: PGTypography.callout.copyWith(
                color: selected ? PGColors.white : PGColors.rawiInk,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSegmentCard({
    required String label,
    required String currentValue,
    required Map<String, String> options,
    required void Function(String) onChanged,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: PGTypography.caption1.copyWith(color: PGColors.rawiInk3),
          ),
          const SizedBox(height: 10),
          CupertinoSlidingSegmentedControl<String>(
            groupValue: currentValue,
            thumbColor: PGColors.rawiAccent,
            backgroundColor: PGColors.rawiPaper3,
            children: options.map(
              (key, value) => MapEntry(
                key,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    value,
                    style: PGTypography.callout.copyWith(
                      color: currentValue == key
                          ? PGColors.white
                          : PGColors.rawiInk,
                      fontWeight: currentValue == key
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
            onValueChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMustSeeRow() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _mustSeeController,
            placeholder: 'Enter a place name',
            onSubmitted: (_) => _addMustSeePOI(),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _addMustSeePOI,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: PGColors.rawiAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.add,
              color: PGColors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMustSeeTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _mustSeePOIs.map((poi) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: PGColors.rawiPaper3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: PGColors.rawiHair),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                poi,
                style: PGTypography.callout.copyWith(color: PGColors.rawiInk),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _removeMustSeePOI(poi),
                child: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 16,
                  color: PGColors.rawiInk3,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDifferentEndToggle() {
    return Row(
      children: [
        CupertinoSwitch(
          value: _useDifferentEndLocation,
          activeTrackColor: PGColors.rawiAccent,
          onChanged: (v) => setState(() => _useDifferentEndLocation = v),
        ),
        const SizedBox(width: 12),
        Text(
          'Different end location',
          style: PGTypography.body.copyWith(color: PGColors.rawiInk),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _generateTour,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: PGColors.rawiAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.sparkles, color: PGColors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Generate Tour',
              style: PGTypography.body.copyWith(
                color: PGColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: PGColors.rawiInk.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: PGColors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(
                radius: 16,
                color: PGColors.rawiAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'Generating your tour...',
                style: PGTypography.body.copyWith(
                  color: PGColors.rawiInk,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared card shell ──────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PGColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PGColors.rawiHair),
      ),
      child: child,
    );
  }

  // ── Shared text field ──────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    void Function(String)? onSubmitted,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      onSubmitted: onSubmitted,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      style: PGTypography.body.copyWith(color: PGColors.rawiInk),
      placeholderStyle: PGTypography.body.copyWith(color: PGColors.rawiInk4),
      decoration: BoxDecoration(
        color: PGColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PGColors.rawiHair),
      ),
    );
  }

  // ── Pickers ────────────────────────────────────────────────────────────────

  void _showCityPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 260,
        color: PGColors.rawiPaper2,
        child: Column(
          children: [
            _buildPickerToolbar(context),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                onSelectedItemChanged: (i) =>
                    setState(() => _selectedCity = _cities[i]),
                scrollController: FixedExtentScrollController(
                  initialItem: _selectedCity != null
                      ? _cities.indexOf(_selectedCity!)
                      : 0,
                ),
                children: _cities
                    .map((c) => Center(
                          child: Text(c,
                              style: PGTypography.body
                                  .copyWith(color: PGColors.rawiInk)),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDaysPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 260,
        color: PGColors.rawiPaper2,
        child: Column(
          children: [
            _buildPickerToolbar(context),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                onSelectedItemChanged: (i) =>
                    setState(() => _days = i + 1),
                scrollController:
                    FixedExtentScrollController(initialItem: _days - 1),
                children: List.generate(
                  14,
                  (i) => Center(
                    child: Text(
                      '${i + 1} ${i == 0 ? 'day' : 'days'}',
                      style: PGTypography.body
                          .copyWith(color: PGColors.rawiInk),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerToolbar(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PGColors.rawiHair)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CupertinoButton(
            child:
                Text('Cancel', style: TextStyle(color: PGColors.rawiInk3)),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoButton(
            child: Text('Done',
                style: TextStyle(
                    color: PGColors.rawiAccent,
                    fontWeight: FontWeight.w600)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
}

