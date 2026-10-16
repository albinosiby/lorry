import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/design_system/design_system.dart';
import '../../../config/routes/routes.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.welcome),
        ),
      ),
      body: PageBody(
        narrow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Brand(),
            const SizedBox(height: 32),
            PageHeading(
              'GET STARTED',
              'What brings you to LORRY LINK?',
              'Select how you want to use the platform. We will customize your experience accordingly.',
            ),
            const SizedBox(height: 12),

            // ── Option 1: Customer / Shipper ──
            _RoleCard(
              title: 'Get a truck for your load',
              tag: 'Customer / Shipper',
              description:
                  'Post parcels & cargo loads, discover nearby verified trucks, book instantly, and track shipments in real-time.',
              icon: Icons.inventory_2_rounded,
              accentColor: const Color(0xFF1E88E5),
              features: const [
                'Post any cargo or parcel load',
                'Find verified trucks near you',
                'Live 24/7 GPS load tracking',
              ],
              onTap: () => context.go('${Routes.signUp}?role=shipper'),
            ),
            const SizedBox(height: 20),

            // ── Option 2: Transporter / Driver ──
            _RoleCard(
              title: 'Get load for your truck',
              tag: 'Transporter / Driver',
              description:
                  'Browse high-paying freight loads on your routes, accept bookings, navigate directly, and track daily earnings.',
              icon: Icons.local_shipping_rounded,
              accentColor: const Color(0xFF2E7D32),
              features: const [
                'Discover open loads along your route',
                'Turn-by-turn Google Maps navigation',
                'Freight payment & finance tracker',
              ],
              onTap: () => context.go('${Routes.signUp}?role=driver'),
            ),
            const SizedBox(height: 32),

            // Sign In link for existing users
            Center(
              child: TextButton(
                onPressed: () => context.go(Routes.signIn),
                child: Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    children: [
                      TextSpan(
                        text:
                            '${localize(context, 'Already have an account? ')} ',
                      ),
                      TextSpan(
                        text: localize(context, 'Sign in'),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.tag,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.features,
    required this.onTap,
  });

  final String title;
  final String tag;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<String> features;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: accentColor.withValues(alpha: .12),
        highlightColor: accentColor.withValues(alpha: .06),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? .35 : .25),
              width: 1.5,
            ),
            color: isDark
                ? accentColor.withValues(alpha: .08)
                : accentColor.withValues(alpha: .04),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? .25 : .15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 28, color: accentColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: LocalizedText(
                            tag,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        LocalizedText(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: accentColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LocalizedText(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: accentColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LocalizedText(
                          feature,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
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
      ),
    );
  }
}
