import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:pocket_guide_api/pocket_guide_api.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/spacing.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';

// City emojis are a rawi design easter egg — one icon per known city.
// Unknown cities fall back to a generic pin.
const _kCityIcons = <String, String>{
  'Rome': '🏛️',
  'Kyoto': '⛩️',
  'Lisbon': '🚋',
  'Marrakech': '🕌',
  'Taipei': '🏙️',
  'Paris': '🗼',
  'London': '🎡',
  'Tokyo': '🗾',
  'New York': '🗽',
  'Barcelona': '🎨',
  'Amsterdam': '🚲',
  'Venice': '🚤',
  'Florence': '🌻',
  'Berlin': '🐻',
};

const _kNearby = 'Nearby';

class CityPickerSheet extends StatelessWidget {
  /// null slug = "Nearby" (show all)
  final String? selectedSlug;
  final List<City> cities;
  final ValueChanged<String?> onPick; // null = Nearby

  const CityPickerSheet({
    super.key,
    required this.selectedSlug,
    required this.cities,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PGColors.rawiPaper,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
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
              color: PGColors.rawiHair,
              borderRadius: BorderRadius.circular(PGRadius.pill),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHOOSE A CITY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.12 * 11,
                    color: PGColors.rawiInk3,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Set where you\'re walking today.',
                    style: RawiTypography.meta()),
              ],
            ),
          ),
          // Divider
          Container(height: 0.5, color: PGColors.rawiHair),
          // Nearby option
          _CityRow(
            icon: '🧭',
            name: _kNearby,
            subtitle: 'GPS · within 50 km',
            isActive: selectedSlug == null,
            onTap: () {
              onPick(null);
              Navigator.pop(context);
            },
          ),
          // City list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: cities.length,
              itemBuilder: (context, i) {
                final city = cities[i];
                final isActive = selectedSlug == city.slug;
                return _CityRow(
                  icon: _kCityIcons[city.name] ?? '📍',
                  name: city.name,
                  subtitle: city.country ?? '',
                  isActive: isActive,
                  onTap: () {
                    onPick(city.slug);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          SizedBox(
              height: MediaQuery.of(context).padding.bottom + PGSpacing.l),
        ],
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  final String icon;
  final String name;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  const _CityRow({
    required this.icon,
    required this.name,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        color: isActive
            ? PGColors.rawiAccentSoft
            : Colors.transparent,
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? PGColors.rawiAccentSoft
                    : PGColors.rawiPaper2,
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 19)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.01 * 16,
                      color: PGColors.rawiInk,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(subtitle, style: RawiTypography.meta()),
                  ],
                ],
              ),
            ),
            if (isActive)
              const Icon(CupertinoIcons.checkmark,
                  size: 16, color: PGColors.rawiAccent),
          ],
        ),
      ),
    );
  }
}
