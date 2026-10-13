import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../auth/cubit/session_cubit.dart';
import '../../profile/models/profile_model.dart';
import '../../loads/widgets/load_card.dart';
import '../cubit/home_cubit.dart';
import '../models/home_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<SessionCubit>().state.profile!;
    final shipper = profile.role == UserRole.shipper;
    return PageBody(
      onRefresh: () => context.read<HomeCubit>().load(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeading(
            'Your logistics, connected',
            'Hello, ${profile.name.split(' ').first}.',
            shipper
                ? 'Let’s get your next load on the road.'
                : 'Your next opportunity is just down the road.',
          ),
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: AppTheme.green,
              borderRadius: BorderRadius.circular(24),
            ),
            child: LayoutBuilder(
              builder: (context, c) => Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LESS WAITING. MORE MOVING.',
                          style: TextStyle(
                            color: Color(0xFFD5E9A9),
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          shipper
                              ? 'Your cargo.\nIn good company.'
                              : 'A full truck.\nA better journey.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          shipper
                              ? 'Post a load and connect with available drivers.'
                              : 'Discover available loads, including your return route.',
                          style: const TextStyle(
                            color: Color(0xFFCDDDD4),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD5E9A9),
                            foregroundColor: AppTheme.green,
                          ),
                          onPressed: () => context.go(
                            shipper ? '/loads/new' : '/loads/find',
                          ),
                          icon: Icon(shipper ? Icons.add : Icons.search),
                          label: Text(shipper ? 'Post a load' : 'Find a load'),
                        ),
                      ],
                    ),
                  ),
                  if (c.maxWidth > 600)
                    const Padding(
                      padding: EdgeInsets.only(left: 40, right: 20),
                      child: Icon(
                        Icons.local_shipping_rounded,
                        size: 140,
                        color: Color(0xFFA3C1A5),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          BlocBuilder<HomeCubit, ResourceState<HomeModel>>(
            builder: (context, state) => ResourceView<HomeModel>(
              state: state,
              retry: () => context.read<HomeCubit>().load(),
              builder: (m) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final width = (c.maxWidth - 24) / 3;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _stat(
                            context,
                            '${m.open}',
                            shipper ? 'Open loads' : 'Available',
                            Icons.inventory_2_outlined,
                            width,
                          ),
                          _stat(
                            context,
                            '${m.active}',
                            'On the road',
                            Icons.route_outlined,
                            width,
                          ),
                          _stat(
                            context,
                            '${m.completed}',
                            'Delivered',
                            Icons.task_alt,
                            width,
                          ),
                        ],
                      );
                    },
                  ),
                  if (m.pending > 0) ...[
                    const SizedBox(height: 18),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.pending_actions),
                        title: Text(
                          '${m.pending} ${shipper ? 'incoming requests' : 'pending requests'}',
                        ),
                        subtitle: Text(
                          shipper
                              ? 'Review requests for your loads'
                              : 'We’ll let you know when a shipper responds',
                        ),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () =>
                            context.go(shipper ? '/loads/mine' : '/trips'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shipper ? 'Your recent loads' : 'Ready to move',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.go(shipper ? '/loads/mine' : '/loads/find'),
                        child: const Text('View all →'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (m.loads.isEmpty)
                    AppEmptyState(
                      shipper
                          ? 'Your first load starts here'
                          : 'No loads just yet',
                      shipper
                          ? 'Publish a load to start receiving booking requests.'
                          : 'Check back soon or adjust your search area.',
                      icon: Icons.local_shipping_outlined,
                    )
                  else
                    LoadGrid(
                      loads: m.loads.take(6).toList(),
                      showRequests: shipper,
                      onTap: (l) async {
                        await context.push('/loads/${l.id}');
                        if (context.mounted) context.read<HomeCubit>().load();
                      },
                    ),
                  const SizedBox(height: 18),
                  Text(
                    'Pull to refresh • Status updates every 45 seconds while open',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    double width,
  ) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}
