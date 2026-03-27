import 'package:flutter/cupertino.dart';
import 'colors.dart';
import 'typography.dart';
import 'spacing.dart';
import 'components/pg_button.dart';
import 'components/pg_card.dart';
import 'components/pg_navigation.dart';

/// Preview screen to showcase all design system components
/// Navigate to this screen to see all components in action
class DesignSystemPreview extends StatefulWidget {
  const DesignSystemPreview({super.key});

  @override
  State<DesignSystemPreview> createState() => _DesignSystemPreviewState();
}

class _DesignSystemPreviewState extends State<DesignSystemPreview> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PGColors.background,
      navigationBar: PGNavigationBar(
        title: 'Design System',
        leading: PGBackButton(),
        trailing: PGNavButton(
          icon: CupertinoIcons.info,
          onPressed: () {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: Text('Design System'),
                content: Text(
                  'Minimalist black & white with dark green accent',
                ),
                actions: [
                  CupertinoDialogAction(
                    child: Text('OK'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: PGSpacing.screen,
          children: [
            // Colors section
            _buildSection(
              title: 'Colors',
              child: Column(
                children: [
                  _buildColorRow('Brand', PGColors.brand),
                  _buildColorRow('Brand Light', PGColors.brandLight),
                  _buildColorRow('Brand Dark', PGColors.brandDark),
                  SizedBox(height: PGSpacing.l),
                  _buildColorRow('Black', PGColors.black),
                  _buildColorRow('Gray 900', PGColors.gray900),
                  _buildColorRow('Gray 600', PGColors.gray600),
                  _buildColorRow('Gray 300', PGColors.gray300),
                  _buildColorRow('White', PGColors.white, showBorder: true),
                ],
              ),
            ),

            SizedBox(height: PGSpacing.xxl),

            // Typography section
            _buildSection(
              title: 'Typography',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Large Title', style: PGTypography.largeTitle),
                  SizedBox(height: PGSpacing.s),
                  Text('Title 1', style: PGTypography.title1),
                  SizedBox(height: PGSpacing.s),
                  Text('Title 2', style: PGTypography.title2),
                  SizedBox(height: PGSpacing.s),
                  Text('Headline', style: PGTypography.headline),
                  SizedBox(height: PGSpacing.s),
                  Text('Body Text', style: PGTypography.body),
                  SizedBox(height: PGSpacing.s),
                  Text('Callout', style: PGTypography.callout),
                  SizedBox(height: PGSpacing.s),
                  Text('Subheadline', style: PGTypography.subheadline),
                  SizedBox(height: PGSpacing.s),
                  Text('Footnote', style: PGTypography.footnote),
                  SizedBox(height: PGSpacing.s),
                  Text('Caption', style: PGTypography.caption1),
                ],
              ),
            ),

            SizedBox(height: PGSpacing.xxl),

            // Buttons section
            _buildSection(
              title: 'Buttons',
              child: Column(
                children: [
                  PGButton(
                    text: 'Primary Button',
                    onPressed: () {},
                    isFullWidth: true,
                  ),
                  SizedBox(height: PGSpacing.m),
                  PGButton(
                    text: 'With Icon',
                    icon: CupertinoIcons.play_fill,
                    onPressed: () {},
                    isFullWidth: true,
                  ),
                  SizedBox(height: PGSpacing.m),
                  PGButtonSecondary(
                    text: 'Secondary Button',
                    onPressed: () {},
                    isFullWidth: true,
                  ),
                  SizedBox(height: PGSpacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: PGButton(
                          text: 'Small',
                          onPressed: () {},
                          size: PGButtonSize.small,
                        ),
                      ),
                      SizedBox(width: PGSpacing.m),
                      Expanded(
                        child: PGButton(
                          text: 'Medium',
                          onPressed: () {},
                          size: PGButtonSize.medium,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: PGSpacing.m),
                  PGButtonText(
                    text: 'Text Button',
                    icon: CupertinoIcons.arrow_right,
                    onPressed: () {},
                  ),
                  SizedBox(height: PGSpacing.m),
                  PGButton(
                    text: 'Loading',
                    onPressed: () {},
                    isLoading: true,
                    isFullWidth: true,
                  ),
                  SizedBox(height: PGSpacing.m),
                  PGButton(
                    text: 'Disabled',
                    onPressed: null,
                    isFullWidth: true,
                  ),
                ],
              ),
            ),

            SizedBox(height: PGSpacing.xxl),

            // Cards section
            _buildSection(
              title: 'Cards',
              child: Column(
                children: [
                  PGTourCard(
                    title: 'Rome Walking Tour',
                    subtitle: 'Historical landmarks',
                    duration: '3 days',
                    poiCount: 15,
                    onTap: () {},
                  ),
                  SizedBox(height: PGSpacing.m),
                  PGTourCard(
                    title: 'Private Tour',
                    subtitle: 'Custom itinerary',
                    duration: '2 days',
                    poiCount: 8,
                    isPrivate: true,
                    onTap: () {},
                  ),
                  SizedBox(height: PGSpacing.m),
                  PGPOICard(
                    number: 1,
                    name: 'Colosseum',
                    description: 'Ancient Roman amphitheater',
                    completed: false,
                    onTap: () {},
                  ),
                  SizedBox(height: PGSpacing.m),
                  PGPOICard(
                    number: 2,
                    name: 'Roman Forum',
                    description: 'Historic plaza',
                    completed: true,
                    onTap: () {},
                  ),
                  SizedBox(height: PGSpacing.m),
                  PGContentCard(
                    title: 'About This Tour',
                    content: Text(
                      'This is a sample content card with a title and body text. '
                      'It can contain any widget as content.',
                      style: PGTypography.body,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: PGSpacing.xxl),

            // Spacing examples
            _buildSection(
              title: 'Spacing',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSpacingExample('XS', PGSpacing.xs),
                  _buildSpacingExample('S', PGSpacing.s),
                  _buildSpacingExample('M', PGSpacing.m),
                  _buildSpacingExample('L', PGSpacing.l),
                  _buildSpacingExample('XL', PGSpacing.xl),
                  _buildSpacingExample('XXL', PGSpacing.xxl),
                ],
              ),
            ),

            SizedBox(height: PGSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: PGTypography.title2,
        ),
        SizedBox(height: PGSpacing.l),
        child,
      ],
    );
  }

  Widget _buildColorRow(String name, Color color, {bool showBorder = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: PGSpacing.s),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: PGRadius.radiusS,
              border: showBorder
                  ? Border.all(color: PGColors.border, width: 1)
                  : null,
            ),
          ),
          SizedBox(width: PGSpacing.m),
          Text(name, style: PGTypography.body),
        ],
      ),
    );
  }

  Widget _buildSpacingExample(String label, double spacing) {
    return Padding(
      padding: EdgeInsets.only(bottom: PGSpacing.m),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: PGTypography.callout,
            ),
          ),
          Container(
            width: spacing,
            height: 20,
            color: PGColors.brand,
          ),
          SizedBox(width: PGSpacing.m),
          Text(
            '${spacing.toInt()}px',
            style: PGTypography.footnote,
          ),
        ],
      ),
    );
  }
}
