import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/design_system/design_system.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBody(
      narrow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Brand(large: true),
          const SizedBox(height: 48),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: AppTheme.green,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -35,
                  child: Icon(
                    Icons.public,
                    size: 250,
                    color: Colors.white.withValues(alpha: .07),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.local_shipping_rounded,
                    size: 110,
                    color: Color(0xFFD5E9A9),
                  ),
                ),
                const Positioned(
                  bottom: 22,
                  left: 24,
                  child: LocalizedText(
                    'EVERY LOAD. A NEW POSSIBILITY.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          LocalizedText(
            'The right load.\nThe right connection.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          const LocalizedText(
            'Connect your cargo with the people who move it. Find loads, arrange trips, and keep every delivery in view.',
          ),
          const SizedBox(height: 28),
          AppButton(
            label: 'Get started',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.go('/role-selection'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go('/sign-in'),
            child: const LocalizedText('I already have an account'),
          ),
          const SizedBox(height: 32),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.route_outlined, size: 16),
              SizedBox(width: 8),
              LocalizedText(
                'Built for the road ahead',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
