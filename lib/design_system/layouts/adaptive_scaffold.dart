import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../modules/auth/cubit/session_cubit.dart';
import '../../modules/profile/models/profile_model.dart';
import '../design_system.dart';

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) {
    final shipper =
        context.watch<SessionCubit>().state.profile?.role == UserRole.shipper;
    final labels = [
      'Home',
      shipper ? 'Post Load' : 'Find Loads',
      shipper ? 'My Loads' : 'My Trips',
      'Profile',
    ];
    final icons = [
      Icons.grid_view_rounded,
      shipper ? Icons.add_box_outlined : Icons.search,
      shipper ? Icons.inventory_2_outlined : Icons.route_outlined,
      Icons.person_outline,
    ];
    final width = MediaQuery.sizeOf(context).width;
    void select(int index) {
      if (!shipper && index == 1) {
        context.go('/loads/find');
        return;
      }
      if (!shipper && index == 2) {
        context.go('/trips');
        return;
      }
      shell.goBranch(index, initialLocation: index == shell.currentIndex);
    }

    final content = Row(
      children: [
        if (width >= 1200)
          SizedBox(
            width: 240,
            child: NavigationDrawer(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: select,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 32, 16, 32),
                  child: Brand(),
                ),
                for (var i = 0; i < 4; i++)
                  NavigationDrawerDestination(
                    icon: Icon(icons[i]),
                    label: Text(labels[i]),
                  ),
              ],
            ),
          )
        else if (width >= 600)
          NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: select,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (var i = 0; i < 4; i++)
                NavigationRailDestination(
                  icon: Icon(icons[i]),
                  label: Text(labels[i]),
                ),
            ],
          ),
        Expanded(child: shell),
      ],
    );
    final isHome = shell.currentIndex == 0;

    return Scaffold(
      appBar: isHome
          ? null
          : AppBar(
              title: Text(labels[shell.currentIndex]),
              actions: [
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => context.push('/notifications'),
                  icon: const Icon(Icons.notifications_none),
                ),
                const SizedBox(width: 12),
              ],
            ),
      body: content,
      bottomNavigationBar: width < 600
          ? NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: select,
              destinations: [
                for (var i = 0; i < 4; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
              ],
            )
          : null,
    );
  }
}
