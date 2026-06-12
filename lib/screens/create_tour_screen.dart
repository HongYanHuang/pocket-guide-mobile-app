import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:intl/intl.dart';

class CreateTourScreen extends StatefulWidget {
  const CreateTourScreen({super.key});

  @override
  State<CreateTourScreen> createState() => _CreateTourScreenState();
}

class _CreateTourScreenState extends State<CreateTourScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  // Form state
  String? _selectedCity;
  // Duration: starts in hours mode at 4 h.
  // Hours mode: 2–8 h. Pressing + on 8 h switches to 1 day.
  // Days mode: 1–4 d. Pressing − on 1 day switches back to 8 h.
  bool _isDayMode = false;
  int _hours = 4;
  int _days = 1;
  DateTime _startDate = DateTime.now();
  String _language = 'en';
  String _pace = 'balanced';
  String _walking = 'moderate';

  // Interests
  final List<String> _interests = ['History'];
  final TextEditingController _customDraftController = TextEditingController();

  // Must-see
  final List<String> _mustSeePOIs = [];
  final TextEditingController _mustDraftController = TextEditingController();

  // Locations
  final TextEditingController _startLocationController =
      TextEditingController();
  final TextEditingController _endLocationController = TextEditingController();
  bool _useDifferentEndLocation = false;

  bool _isLoading = false;
  List<String> _cities = [];

  static const List<String> _presetInterests = [
    'History',
    'Architecture',
    'Food & Dining',
    'Art & Museums',
    'Nature & Parks',
    'Local Culture',
    'Religious Sites',
    'Photography',
    'Nightlife',
    'Shopping',
  ];

  bool _isCustomInterest(String val) => !_presetInterests
      .any((p) => p.toLowerCase() == val.toLowerCase());

  @override
  void initState() {
    super.initState();
    _loadCities();
    _setDefaultLanguage();
    _customDraftController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customDraftController.dispose();
    _mustDraftController.dispose();
    _startLocationController.dispose();
    _endLocationController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final cities = await _apiService.getCities();
      setState(() {
        _cities = cities;
        if (_cities.isNotEmpty) _selectedCity = _cities[0];
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

  void _addInterest(String val) {
    final v = val.trim();
    if (v.isEmpty) return;
    if (!_interests.any((i) => i.toLowerCase() == v.toLowerCase())) {
      setState(() => _interests.add(v));
    }
    _customDraftController.clear();
  }

  void _addMustSeePOI() {
    final v = _mustDraftController.text.trim();
    if (v.isNotEmpty) {
      setState(() {
        _mustSeePOIs.add(v);
        _mustDraftController.clear();
      });
    }
  }

  void _selectDate(BuildContext context) {
    DateTime tempDate = _startDate;
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 280,
        color: PGColors.rawiPaper2,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: PGColors.rawiHair)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: Text('Cancel',
                        style: TextStyle(color: PGColors.rawiInk3)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    child: Text('Done',
                        style: TextStyle(
                            color: PGColors.rawiAccent,
                            fontWeight: FontWeight.w600)),
                    onPressed: () {
                      setState(() => _startDate = tempDate);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _startDate,
                minimumDate:
                    DateTime.now().subtract(const Duration(days: 1)),
                maximumDate:
                    DateTime.now().add(const Duration(days: 365)),
                onDateTimeChanged: (dt) => tempDate = dt,
              ),
            ),
          ],
        ),
      ),
    );
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

      final response = await _apiService.generateTour(
        accessToken: accessToken,
        city: _selectedCity!,
        days: _isDayMode ? _days : 1,
        durationMode: _isDayMode ? 'days' : 'hours',
        hoursPerDay: _isDayMode ? null : _hours,
        language: _language,
        pace: _pace,
        walking: _walking,
        interests: _interests.isEmpty ? null : _interests,
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

      if (mounted) Navigator.of(context).pop(tourId);
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

  // ── Text style helpers (Source Sans 3 to match design font) ───────────────

  TextStyle get _fieldText => GoogleFonts.sourceSans3(
        fontSize: 15,
        color: PGColors.rawiInk,
        decoration: TextDecoration.none,
      );

  TextStyle get _fieldPlaceholder => GoogleFonts.sourceSans3(
        fontSize: 15,
        color: PGColors.rawiInk4,
        decoration: TextDecoration.none,
      );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return CupertinoPageScaffold(
      backgroundColor: PGColors.rawiPaper,
      child: DefaultTextStyle.merge(
        style: GoogleFonts.sourceSans3(
          decoration: TextDecoration.none,
        ),
        child: Stack(
        children: [
          Column(
            children: [
              SizedBox(
                  height: MediaQuery.of(context).padding.top + 4),
              _buildNavBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      20, 12, 20, 130 + bottomPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Intro paragraph
                      const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 22),
                        child: Text(
                          "Tell us what you're curious about — we'll narrate a walk just for you.",
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: PGColors.rawiInk2,
                          ),
                        ),
                      ),

                      _buildDestination(),
                      const SizedBox(height: 26),

                      _buildDurationDate(),
                      const SizedBox(height: 26),

                      _buildInterests(),
                      const SizedBox(height: 26),

                      _buildPaceSection(),
                      const SizedBox(height: 22),

                      _buildWalkingSection(),
                      const SizedBox(height: 26),

                      _buildMustSee(),
                      const SizedBox(height: 26),

                      _buildStartLocation(),
                      const SizedBox(height: 18),

                      _buildDiffEndToggle(),
                      if (_useDifferentEndLocation) ...[
                        const SizedBox(height: 14),
                        _buildEndLocation(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sticky generate button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter:
                    ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                      16, 12, 16, 12 + bottomPad),
                  decoration: BoxDecoration(
                    color: const Color(0xF0F6F1E7),
                    border: Border(
                      top: BorderSide(
                          color: PGColors.rawiHair, width: 0.5),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: _isLoading ? null : _generateTour,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: PGColors.rawiAccent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: _isLoading
                            ? [
                                const CupertinoActivityIndicator(
                                  color: PGColors.rawiPaper,
                                  radius: 9,
                                ),
                              ]
                            : [
                                const Icon(
                                  CupertinoIcons.sparkles,
                                  color: PGColors.rawiPaper,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Generate my tour',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: PGColors.rawiPaper,
                                  ),
                                ),
                              ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: PGColors.rawiInk.withValues(alpha: 0.35),
            ),
        ],
        ),
      ),
    );
  }

  // ── Nav bar ────────────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: PGColors.rawiPaper2,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.back,
                  color: PGColors.rawiInk,
                  size: 18,
                ),
              ),
            ),
            const Expanded(
              child: Text(
                'Create your tour',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PGColors.rawiInk,
                ),
              ),
            ),
            const SizedBox(width: 38),
          ],
        ),
      ),
    );
  }

  // ── Field label ────────────────────────────────────────────────────────────

  Widget _fieldLabel(String title,
      {String? hint, bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: title.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PGColors.rawiInk,
                letterSpacing: 1.04,
              ),
              children: optional
                  ? const [
                      TextSpan(
                        text: ' · optional',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: PGColors.rawiInk4,
                          letterSpacing: 0,
                          fontSize: 13,
                        ),
                      ),
                    ]
                  : [],
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Text(
              hint,
              style: const TextStyle(
                fontSize: 12.5,
                color: PGColors.rawiInk3,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Input box shell ────────────────────────────────────────────────────────

  Widget _inputBox(
      {required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ??
          const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: PGColors.rawiPaper,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: PGColors.rawiHair, width: 0.5),
      ),
      child: child,
    );
  }

  // ── Destination ────────────────────────────────────────────────────────────

  Widget _buildDestination() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Destination'),
        GestureDetector(
          onTap: _showCityPicker,
          child: _inputBox(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedCity ?? 'Select a city',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _selectedCity != null
                          ? PGColors.rawiInk
                          : PGColors.rawiInk4,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 14,
                  color: PGColors.rawiInk3,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Duration & Date ────────────────────────────────────────────────────────

  Widget _buildDurationDate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Duration & date',
            hint:
                "Date checks each spot's opening hours; length sets how much we fit in."),
        Row(
          children: [
            // Duration stepper (hours 2–8, then days 1–14)
            Expanded(
              flex: 10,
              child: _inputBox(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        if (_isDayMode) {
                          if (_days > 1) {
                            _days--;
                          } else {
                            // 1 day → 8 hours
                            _isDayMode = false;
                            _hours = 8;
                          }
                        } else {
                          if (_hours > 2) _hours--;
                        }
                      }),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: PGColors.rawiPaper2,
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Container(
                            width: 12,
                            height: 2,
                            decoration: BoxDecoration(
                              color: PGColors.rawiInk2,
                              borderRadius:
                                  BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          _isDayMode ? '$_days' : '$_hours',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: PGColors.rawiInk,
                          ),
                        ),
                        Text(
                          _isDayMode
                              ? (_days == 1 ? 'day' : 'days')
                              : (_hours == 1 ? 'hr' : 'hrs'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: PGColors.rawiInk3,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        if (_isDayMode) {
                          if (_days < 4) _days++;
                        } else {
                          if (_hours < 8) {
                            _hours++;
                          } else {
                            // 8 hours → 1 day
                            _isDayMode = true;
                            _days = 1;
                          }
                        }
                      }),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: PGColors.rawiAccent,
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.add,
                          color: PGColors.rawiPaper,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Date button
            Expanded(
              flex: 13,
              child: GestureDetector(
                onTap: () => _selectDate(context),
                child: _inputBox(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 0),
                  child: SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.calendar,
                          size: 18,
                          color: PGColors.rawiInk2,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Starts',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: PGColors.rawiInk3),
                            ),
                            Text(
                              DateFormat('MMM d, yyyy')
                                  .format(_startDate),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: PGColors.rawiInk,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Interests ──────────────────────────────────────────────────────────────

  Widget _buildInterests() {
    final hasContent =
        _customDraftController.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Interests',
            hint:
                'Type anything specific — a person, a theme, an era. This shapes what we tell you.'),

        // Hero input with accent border
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: PGColors.rawiPaper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: PGColors.rawiAccent, width: 1.5),
            boxShadow: [
              BoxShadow(
                color:
                    PGColors.rawiAccent.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding:
              const EdgeInsets.fromLTRB(14, 4, 4, 4),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.sparkles,
                color: PGColors.rawiAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoTextField(
                  controller: _customDraftController,
                  placeholder:
                      'e.g. "Caesar", "hidden courtyards"…',
                  placeholderStyle: _fieldPlaceholder,
                  style: _fieldText,
                  padding:
                      const EdgeInsets.symmetric(vertical: 9),
                  onSubmitted: (_) => _addInterest(
                      _customDraftController.text),
                  decoration: null,
                ),
              ),
              GestureDetector(
                onTap: hasContent
                    ? () => _addInterest(
                        _customDraftController.text)
                    : null,
                child: AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 150),
                  margin: const EdgeInsets.all(3),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: hasContent
                        ? PGColors.rawiAccent
                        : PGColors.rawiPaper2,
                    borderRadius:
                        BorderRadius.circular(9),
                  ),
                  child: Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: hasContent
                          ? PGColors.rawiPaper
                          : PGColors.rawiInk4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Selected interests as tags
        if (_interests.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interests
                .map(_buildInterestTag)
                .toList(),
          ),
        ],

        // Or pick a theme
        const SizedBox(height: 14),
        const Text(
          'Or pick a theme',
          style: TextStyle(
            fontSize: 12,
            color: PGColors.rawiInk3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // Preset chips (unchosen only)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presetInterests
              .where((p) => !_interests.any(
                  (i) => i.toLowerCase() == p.toLowerCase()))
              .map(_buildPresetChip)
              .toList(),
        ),
      ],
    );
  }

  Widget _buildInterestTag(String interest) {
    final custom = _isCustomInterest(interest);
    return Container(
      padding:
          const EdgeInsets.fromLTRB(13, 7, 8, 7),
      decoration: BoxDecoration(
        color:
            custom ? PGColors.rawiAccent : PGColors.rawiPaper2,
        borderRadius: BorderRadius.circular(99),
        border: custom
            ? null
            : Border.all(
                color: PGColors.rawiHair, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            interest,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.14,
              color: custom
                  ? PGColors.rawiPaper
                  : PGColors.rawiInk,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () =>
                setState(() => _interests.remove(interest)),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                // rgba(246,241,231,0.22) or rgba(27,25,21,0.08)
                color: custom
                    ? const Color(0x38F6F1E7)
                    : const Color(0x141B1915),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 8,
                  color: custom
                      ? PGColors.rawiPaper
                      : PGColors.rawiInk3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String preset) {
    return GestureDetector(
      onTap: () => _addInterest(preset),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: PGColors.rawiHair, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '+',
              style: TextStyle(
                color: PGColors.rawiAccent,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              preset,
              style: const TextStyle(
                color: PGColors.rawiInk2,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Segmented control ──────────────────────────────────────────────────────

  Widget _buildSegmented({
    required List<Map<String, String>> options,
    required String value,
    required void Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PGColors.rawiPaper2,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: PGColors.rawiHair, width: 0.5),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: options.map((o) {
          final active = o['key'] == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o['key']!),
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    vertical: 9, horizontal: 6),
                decoration: BoxDecoration(
                  color: active
                      ? PGColors.rawiAccent
                      : const Color(0x00000000),
                  borderRadius:
                      BorderRadius.circular(9),
                ),
                child: Text(
                  o['label']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: active
                        ? PGColors.rawiPaper
                        : PGColors.rawiInk2,
                    letterSpacing: -0.14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Pace ───────────────────────────────────────────────────────────────────

  Widget _buildPaceSection() {
    final hint = switch (_pace) {
      'relaxed' => 'More time at each stop — lots of breathing room.',
      'fast' => 'Tighter schedule — see more, linger less.',
      _ => 'A comfortable rhythm with time to pause.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Pace', hint: hint),
        _buildSegmented(
          options: const [
            {'key': 'relaxed', 'label': 'Relaxed'},
            {'key': 'balanced', 'label': 'Balanced'},
            {'key': 'fast', 'label': 'Fast'},
          ],
          value: _pace,
          onChanged: (v) => setState(() => _pace = v),
        ),
      ],
    );
  }

  // ── Walking ────────────────────────────────────────────────────────────────

  Widget _buildWalkingSection() {
    final hint = switch (_walking) {
      'light' => 'Short distances, minimal hills.',
      'lots' => 'Happy to cover ground for the best spots.',
      _ => 'A normal amount of walking between stops.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Walking', hint: hint),
        _buildSegmented(
          options: const [
            {'key': 'light', 'label': 'Light'},
            {'key': 'moderate', 'label': 'Moderate'},
            {'key': 'lots', 'label': 'Lots'},
          ],
          value: _walking,
          onChanged: (v) => setState(() => _walking = v),
        ),
      ],
    );
  }

  // ── Must-See ───────────────────────────────────────────────────────────────

  Widget _buildMustSee() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(
          'Must-see places',
          hint: 'Always included, whatever else we pick.',
          optional: true,
        ),
        Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _mustDraftController,
                placeholder: 'e.g. Trevi Fountain',
                placeholderStyle: _fieldPlaceholder,
                style: _fieldText,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                onSubmitted: (_) => _addMustSeePOI(),
                decoration: BoxDecoration(
                  color: PGColors.rawiPaper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: PGColors.rawiHair, width: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addMustSeePOI,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: PGColors.rawiInk,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.add,
                  color: PGColors.rawiPaper,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        if (_mustSeePOIs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _mustSeePOIs
                .asMap()
                .entries
                .map((e) => _buildMustSeeTag(e.key, e.value))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildMustSeeTag(int index, String label) {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(13, 7, 8, 7),
      decoration: BoxDecoration(
        color: PGColors.rawiPaper2,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
            color: PGColors.rawiHair, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.14,
              color: PGColors.rawiInk,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () =>
                setState(() => _mustSeePOIs.removeAt(index)),
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0x141B1915),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 8,
                  color: PGColors.rawiInk3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Start Location ─────────────────────────────────────────────────────────

  Widget _buildStartLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(
          'Start location',
          hint:
              "Where you'll begin — we'll make the first stop easy to reach.",
          optional: true,
        ),
        _locationField(
          controller: _startLocationController,
          placeholder: 'Hotel name or address',
        ),
      ],
    );
  }

  Widget _buildEndLocation() {
    return _locationField(
      controller: _endLocationController,
      placeholder: 'End address or place',
    );
  }

  Widget _locationField({
    required TextEditingController controller,
    required String placeholder,
  }) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: PGColors.rawiPaper,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: PGColors.rawiHair, width: 0.5),
      ),
      padding:
          const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.location,
            color: PGColors.rawiInk3,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              placeholderStyle: _fieldPlaceholder,
              style: _fieldText,
              padding: const EdgeInsets.symmetric(
                  vertical: 13),
              decoration: null,
            ),
          ),
        ],
      ),
    );
  }

  // ── End somewhere different ────────────────────────────────────────────────

  Widget _buildDiffEndToggle() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() =>
              _useDifferentEndLocation =
                  !_useDifferentEndLocation),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: _useDifferentEndLocation
                  ? PGColors.rawiAccent
                  : const Color(0x2E1B1915),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              alignment: _useDifferentEndLocation
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: PGColors.rawiPaper,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x381B1915),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'End somewhere different',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: PGColors.rawiInk,
                ),
              ),
              Text(
                'Finish at another spot, like your dinner reservation.',
                style: TextStyle(
                    fontSize: 12, color: PGColors.rawiInk3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── City picker ────────────────────────────────────────────────────────────

  void _showCityPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 260,
        color: PGColors.rawiPaper2,
        child: Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: PGColors.rawiHair)),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: Text('Cancel',
                        style: TextStyle(
                            color: PGColors.rawiInk3)),
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
            ),
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
                              style: TextStyle(
                                  color: PGColors.rawiInk)),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
