import 'package:flutter/material.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';
import 'package:intl/intl.dart';

class CreateTourScreen extends StatefulWidget {
  const CreateTourScreen({super.key});

  @override
  State<CreateTourScreen> createState() => _CreateTourScreenState();
}

class _CreateTourScreenState extends State<CreateTourScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

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
  final TextEditingController _customInterestController = TextEditingController();

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
    _customInterestController.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cities: $e')),
        );
      }
    }
  }

  void _setDefaultLanguage() {
    // Get system language
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final languageCode = systemLocale.languageCode;

    // Map to supported languages
    if (languageCode == 'zh') {
      _language = systemLocale.countryCode == 'CN' ? 'zh-cn' : 'zh-tw';
    } else if (['en', 'fr', 'es', 'ja', 'ko'].contains(languageCode)) {
      _language = languageCode;
    } else if (languageCode == 'pt') {
      _language = 'pt-br';
    } else {
      _language = 'en'; // Default to English
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a city')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get access token
      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        throw Exception('Not authenticated');
      }

      // Collect selected interests
      final interests = <String>[];
      _selectedInterests.forEach((interest, selected) {
        if (selected) {
          interests.add(interest.toLowerCase());
        }
      });

      // Add custom interest if provided
      final customInterest = _customInterestController.text.trim();
      if (customInterest.isNotEmpty) {
        interests.add(customInterest.toLowerCase());
      }

      // Validate start location format (lat,lng)
      String? startLocation;
      if (_startLocationController.text.isNotEmpty) {
        final startLoc = _startLocationController.text.trim();
        if (!_validateLatLng(startLoc)) {
          throw Exception('Invalid start location format. Use: lat,lng (e.g., 41.8902,12.4922)');
        }
        startLocation = startLoc;
      }

      // Validate end location format
      String? endLocation;
      if (_useDifferentEndLocation && _endLocationController.text.isNotEmpty) {
        final endLoc = _endLocationController.text.trim();
        if (!_validateLatLng(endLoc)) {
          throw Exception('Invalid end location format. Use: lat,lng (e.g., 41.8902,12.4922)');
        }
        endLocation = endLoc;
      }

      // Generate tour
      final result = await _apiService.generateTour(
        accessToken: accessToken,
        city: _selectedCity!.toLowerCase(),
        days: _days,
        interests: interests.isEmpty ? null : interests,
        mustSee: _mustSeePOIs.isEmpty ? null : _mustSeePOIs,
        pace: _pace,
        walking: _walking,
        language: _language,
        startLocation: startLocation,
        endLocation: endLocation,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tour created: ${result['title_display']}'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to tour details
        final tourId = result['tour_id'] as String;
        Navigator.pushNamed(
          context,
          '/tour-detail',
          arguments: {
            'tourId': tourId,
            'city': _selectedCity,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate tour: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _validateLatLng(String input) {
    final parts = input.split(',');
    if (parts.length != 2) return false;

    try {
      final lat = double.parse(parts[0].trim());
      final lng = double.parse(parts[1].trim());
      return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Your Tour'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // City Selector
                _buildSectionTitle('Destination', required: true),
                DropdownButtonFormField<String>(
                  value: _selectedCity,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select a city',
                  ),
                  items: _cities.map((city) {
                    return DropdownMenuItem(
                      value: city,
                      child: Text(city),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCity = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a city';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Duration
                _buildSectionTitle('Duration', required: true),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _days.toString(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          suffixText: 'days',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final days = int.tryParse(value);
                          if (days == null || days < 1 || days > 14) {
                            return 'Must be 1-14 days';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          final days = int.tryParse(value);
                          if (days != null) {
                            setState(() {
                              _days = days;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Date',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: () => _selectDate(context),
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Language
                _buildSectionTitle('Language', required: true),
                DropdownButtonFormField<String>(
                  value: _language,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'zh-tw', child: Text('繁體中文')),
                    DropdownMenuItem(value: 'zh-cn', child: Text('简体中文')),
                    DropdownMenuItem(value: 'fr', child: Text('Français')),
                    DropdownMenuItem(value: 'es', child: Text('Español')),
                    DropdownMenuItem(value: 'pt-br', child: Text('Português (Brasil)')),
                    DropdownMenuItem(value: 'ja', child: Text('日本語')),
                    DropdownMenuItem(value: 'ko', child: Text('한국어')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _language = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Pace
                _buildSectionTitle('Pace', required: true),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'relaxed', label: Text('Relaxed'), icon: Icon(Icons.self_improvement)),
                    ButtonSegment(value: 'normal', label: Text('Normal'), icon: Icon(Icons.directions_walk)),
                    ButtonSegment(value: 'packed', label: Text('Packed'), icon: Icon(Icons.directions_run)),
                  ],
                  selected: {_pace},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _pace = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 8),
                _buildHelpText('Relaxed: 2-3 POIs/day • Normal: 4-5 POIs/day • Packed: 6+ POIs/day'),
                const SizedBox(height: 24),

                // Walking Tolerance
                _buildSectionTitle('Walking Tolerance', required: true),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'low', label: Text('Low'), icon: Icon(Icons.accessible)),
                    ButtonSegment(value: 'moderate', label: Text('Moderate'), icon: Icon(Icons.directions_walk)),
                    ButtonSegment(value: 'high', label: Text('High'), icon: Icon(Icons.hiking)),
                  ],
                  selected: {_walking},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _walking = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 8),
                _buildHelpText('Low: <3km/day • Moderate: 3-6km/day • High: >6km/day'),
                const SizedBox(height: 24),

                // Interests
                _buildSectionTitle('Interests'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedInterests.keys.map((interest) {
                    return FilterChip(
                      label: Text(interest),
                      selected: _selectedInterests[interest]!,
                      onSelected: (selected) {
                        setState(() {
                          _selectedInterests[interest] = selected;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customInterestController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Tell us what you dive in...',
                    prefixIcon: Icon(Icons.lightbulb_outline),
                  ),
                ),
                const SizedBox(height: 24),

                // Must-see POIs
                _buildSectionTitle('Must-See Places'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mustSeeController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter POI name',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        onSubmitted: (_) => _addMustSeePOI(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addMustSeePOI,
                      icon: const Icon(Icons.add_circle),
                      color: Theme.of(context).colorScheme.primary,
                      iconSize: 32,
                    ),
                  ],
                ),
                if (_mustSeePOIs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _mustSeePOIs.map((poi) {
                      return Chip(
                        label: Text(poi),
                        onDeleted: () => _removeMustSeePOI(poi),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 24),

                // Start Location
                _buildSectionTitle('Start Location'),
                TextField(
                  controller: _startLocationController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'lat,lng (e.g., 41.8902,12.4922)',
                    prefixIcon: Icon(Icons.my_location),
                  ),
                ),
                const SizedBox(height: 8),
                _buildHelpText('Optional: Enter coordinates for your accommodation'),
                const SizedBox(height: 24),

                // End Location
                CheckboxListTile(
                  title: const Text('Use different end location'),
                  value: _useDifferentEndLocation,
                  onChanged: (value) {
                    setState(() {
                      _useDifferentEndLocation = value ?? false;
                      if (!_useDifferentEndLocation) {
                        _endLocationController.clear();
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                if (_useDifferentEndLocation) ...[
                  TextField(
                    controller: _endLocationController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'lat,lng (e.g., 41.9028,12.4964)',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Generate Button
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generateTour,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Tour'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text(
                          'Generating Your Tour',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This may take up to 60 seconds...',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (required)
            Text(
              ' *',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHelpText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
      ),
    );
  }
}
