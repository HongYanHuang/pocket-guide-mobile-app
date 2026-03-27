import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showDatePicker;
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';
import 'package:pocket_guide_mobile/design_system/spacing.dart';
import 'package:pocket_guide_mobile/design_system/components/pg_navigation.dart';
import 'package:pocket_guide_mobile/design_system/components/pg_button.dart';
import 'package:pocket_guide_mobile/design_system/components/pg_card.dart';
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
            title: Text('Error'),
            content: Text('Failed to load cities: $e'),
            actions: [
              CupertinoDialogAction(
                child: Text('OK'),
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
          title: Text('Missing Information'),
          content: Text('Please select a city'),
          actions: [
            CupertinoDialogAction(
              child: Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        throw Exception('Not authenticated');
      }

      // Prepare interests
      final selectedInterestsList = _selectedInterests.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      print('🚀 Generating tour for $_selectedCity, $_days days');

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

      print('✅ Tour generated with ID: $tourId');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.of(context).pop(tourId);
      }
    } catch (e) {
      print('❌ Tour generation failed: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Generation Failed'),
            content: Text('Failed to generate tour: $e'),
            actions: [
              CupertinoDialogAction(
                child: Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PGColors.background,
      navigationBar: PGNavigationBar(
        title: 'Create Tour',
        leading: PGBackButton(),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: PGSpacing.screen,
              children: [
                SizedBox(height: PGSpacing.l),

                // City Selection
                _buildSectionTitle('Destination'),
                SizedBox(height: PGSpacing.m),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showCityPicker(),
                  child: Container(
                    padding: PGSpacing.paddingL,
                    decoration: BoxDecoration(
                      color: PGColors.surface,
                      borderRadius: PGRadius.radiusM,
                      border: Border.all(color: PGColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedCity ?? 'Select a city',
                          style: PGTypography.body.copyWith(
                            color: _selectedCity != null
                                ? PGColors.textPrimary
                                : PGColors.textSecondary,
                          ),
                        ),
                        Icon(
                          CupertinoIcons.chevron_down,
                          size: 20,
                          color: PGColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: PGSpacing.xxl),

                // Duration & Start Date
                _buildSectionTitle('Duration & Date'),
                SizedBox(height: PGSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: PGSpacing.paddingL,
                        decoration: BoxDecoration(
                          color: PGColors.surface,
                          borderRadius: PGRadius.radiusM,
                          border: Border.all(color: PGColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Days', style: PGTypography.caption1),
                            SizedBox(height: PGSpacing.xs),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _showDaysPicker(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _days.toString(),
                                    style: PGTypography.headline,
                                  ),
                                  SizedBox(width: PGSpacing.xs),
                                  Icon(
                                    CupertinoIcons.chevron_down,
                                    size: 16,
                                    color: PGColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: PGSpacing.m),
                    Expanded(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _selectDate(context),
                        child: Container(
                          padding: PGSpacing.paddingL,
                          decoration: BoxDecoration(
                            color: PGColors.surface,
                            borderRadius: PGRadius.radiusM,
                            border: Border.all(color: PGColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Date', style: PGTypography.caption1),
                              SizedBox(height: PGSpacing.xs),
                              Text(
                                DateFormat('MMM d, y').format(_startDate),
                                style: PGTypography.body,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: PGSpacing.xxl),

                // Interests
                _buildSectionTitle('Interests'),
                SizedBox(height: PGSpacing.m),
                Wrap(
                  spacing: PGSpacing.s,
                  runSpacing: PGSpacing.s,
                  children: _selectedInterests.keys.map((interest) {
                    final isSelected = _selectedInterests[interest]!;
                    return CupertinoButton(
                      padding: EdgeInsets.symmetric(
                        horizontal: PGSpacing.l,
                        vertical: PGSpacing.s,
                      ),
                      color: isSelected ? PGColors.brand : PGColors.surface,
                      borderRadius: BorderRadius.circular(PGRadius.l),
                      minSize: 0,
                      onPressed: () {
                        setState(() {
                          _selectedInterests[interest] =
                              !_selectedInterests[interest]!;
                        });
                      },
                      child: Text(
                        interest,
                        style: PGTypography.callout.copyWith(
                          color: isSelected ? PGColors.white : PGColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: PGSpacing.xxl),

                // Pace & Walking
                _buildSectionTitle('Preferences'),
                SizedBox(height: PGSpacing.m),
                _buildPreferenceRow('Pace', _pace, {
                  'relaxed': 'Relaxed',
                  'normal': 'Normal',
                  'fast': 'Fast',
                }, (value) {
                  setState(() => _pace = value);
                }),
                SizedBox(height: PGSpacing.m),
                _buildPreferenceRow('Walking', _walking, {
                  'light': 'Light',
                  'moderate': 'Moderate',
                  'intensive': 'Intensive',
                }, (value) {
                  setState(() => _walking = value);
                }),
                SizedBox(height: PGSpacing.xxl),

                // Must-see POIs
                _buildSectionTitle('Must-See Places (Optional)'),
                SizedBox(height: PGSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _mustSeeController,
                        placeholder: 'Enter a place name',
                        padding: PGSpacing.paddingL,
                        decoration: BoxDecoration(
                          color: PGColors.surface,
                          borderRadius: PGRadius.radiusM,
                          border: Border.all(color: PGColors.border),
                        ),
                        style: PGTypography.body,
                      ),
                    ),
                    SizedBox(width: PGSpacing.m),
                    CupertinoButton(
                      padding: PGSpacing.paddingL,
                      color: PGColors.brand,
                      borderRadius: BorderRadius.circular(PGRadius.m),
                      minSize: 0,
                      onPressed: _addMustSeePOI,
                      child: Icon(CupertinoIcons.add, color: PGColors.white),
                    ),
                  ],
                ),
                if (_mustSeePOIs.isNotEmpty) ...[
                  SizedBox(height: PGSpacing.m),
                  Wrap(
                    spacing: PGSpacing.s,
                    runSpacing: PGSpacing.s,
                    children: _mustSeePOIs.map((poi) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: PGSpacing.m,
                          vertical: PGSpacing.s,
                        ),
                        decoration: BoxDecoration(
                          color: PGColors.gray100,
                          borderRadius: BorderRadius.circular(PGRadius.s),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(poi, style: PGTypography.callout),
                            SizedBox(width: PGSpacing.s),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 0,
                              onPressed: () => _removeMustSeePOI(poi),
                              child: Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 18,
                                color: PGColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                SizedBox(height: PGSpacing.xxl),

                // Start/End Location
                _buildSectionTitle('Start Location (Optional)'),
                SizedBox(height: PGSpacing.m),
                CupertinoTextField(
                  controller: _startLocationController,
                  placeholder: 'e.g., Hotel name or address',
                  padding: PGSpacing.paddingL,
                  decoration: BoxDecoration(
                    color: PGColors.surface,
                    borderRadius: PGRadius.radiusM,
                    border: Border.all(color: PGColors.border),
                  ),
                  style: PGTypography.body,
                ),
                SizedBox(height: PGSpacing.l),
                Row(
                  children: [
                    CupertinoSwitch(
                      value: _useDifferentEndLocation,
                      activeColor: PGColors.brand,
                      onChanged: (value) {
                        setState(() => _useDifferentEndLocation = value);
                      },
                    ),
                    SizedBox(width: PGSpacing.m),
                    Text(
                      'Different end location',
                      style: PGTypography.body,
                    ),
                  ],
                ),
                if (_useDifferentEndLocation) ...[
                  SizedBox(height: PGSpacing.m),
                  CupertinoTextField(
                    controller: _endLocationController,
                    placeholder: 'End location',
                    padding: PGSpacing.paddingL,
                    decoration: BoxDecoration(
                      color: PGColors.surface,
                      borderRadius: PGRadius.radiusM,
                      border: Border.all(color: PGColors.border),
                    ),
                    style: PGTypography.body,
                  ),
                ],
                SizedBox(height: PGSpacing.xxl * 2),

                // Generate Button
                PGButton(
                  text: 'Generate Tour',
                  icon: CupertinoIcons.sparkles,
                  onPressed: _generateTour,
                  isFullWidth: true,
                  size: PGButtonSize.large,
                ),
                SizedBox(height: PGSpacing.xxl),
              ],
            ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: PGColors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    padding: PGSpacing.paddingXL,
                    decoration: BoxDecoration(
                      color: PGColors.surface,
                      borderRadius: PGRadius.radiusL,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoActivityIndicator(
                          radius: 20,
                          color: PGColors.brand,
                        ),
                        SizedBox(height: PGSpacing.l),
                        Text(
                          'Generating your tour...',
                          style: PGTypography.headline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: PGTypography.title3,
    );
  }

  Widget _buildPreferenceRow(
    String label,
    String currentValue,
    Map<String, String> options,
    Function(String) onChanged,
  ) {
    return Container(
      padding: PGSpacing.paddingL,
      decoration: BoxDecoration(
        color: PGColors.surface,
        borderRadius: PGRadius.radiusM,
        border: Border.all(color: PGColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PGTypography.caption1),
          SizedBox(height: PGSpacing.s),
          CupertinoSlidingSegmentedControl<String>(
            groupValue: currentValue,
            children: options.map(
              (key, value) => MapEntry(
                key,
                Padding(
                  padding: EdgeInsets.symmetric(vertical: PGSpacing.s),
                  child: Text(value, style: PGTypography.callout),
                ),
              ),
            ),
            onValueChanged: (value) {
              if (value != null) onChanged(value);
            },
            thumbColor: PGColors.brand,
            backgroundColor: PGColors.gray100,
          ),
        ],
      ),
    );
  }

  void _showCityPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: PGColors.background,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: Text('Done'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedCity = _cities[index];
                  });
                },
                scrollController: FixedExtentScrollController(
                  initialItem: _selectedCity != null
                      ? _cities.indexOf(_selectedCity!)
                      : 0,
                ),
                children: _cities
                    .map((city) => Center(
                          child: Text(city, style: PGTypography.body),
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
        height: 250,
        color: PGColors.background,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: Text('Done'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _days = index + 1;
                  });
                },
                scrollController: FixedExtentScrollController(
                  initialItem: _days - 1,
                ),
                children: List.generate(
                  14,
                  (index) => Center(
                    child: Text(
                      '${index + 1} ${(index + 1) == 1 ? 'day' : 'days'}',
                      style: PGTypography.body,
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
}
