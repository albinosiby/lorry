import 'package:flutter/material.dart';
import 'package:lorry_link/design_system/design_system.dart';
import '../models/load_model.dart';

class LoadCard extends StatelessWidget {
  const LoadCard(
    this.load, {
    super.key,
    required this.onTap,
    this.showRequests = false,
  });
  final LoadModel load;
  final VoidCallback onTap;
  final bool showRequests;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping_outlined, size: 20),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    load.vehicle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusBadge(statusLabel(load.status)),
              ],
            ),
            const SizedBox(height: 18),
            RouteSummary(load.pickup, load.destination),
            const SizedBox(height: 16),
            Text(
              load.cargo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  load.priceLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(load.dateLabel, style: const TextStyle(fontSize: 12)),
                if (showRequests && load.requestCount > 0)
                  StatusBadge('${load.requestCount} requests'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class RouteSummary extends StatelessWidget {
  const RouteSummary(this.pickup, this.destination, {super.key});
  final String pickup, destination;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _point(context, pickup, true),
      Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 1,
            height: 15,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      _point(context, destination, false),
    ],
  );
  Widget _point(BuildContext context, String title, bool origin) => Row(
    children: [
      Icon(
        origin ? Icons.radio_button_checked : Icons.location_on_outlined,
        size: 15,
        color: origin ? Theme.of(context).colorScheme.primary : AppTheme.orange,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          placeLabel(title),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    ],
  );
}

class LoadGrid extends StatelessWidget {
  const LoadGrid({
    super.key,
    required this.loads,
    required this.onTap,
    this.showRequests = false,
  });
  final List<LoadModel> loads;
  final void Function(LoadModel) onTap;
  final bool showRequests;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= 900
          ? 3
          : c.maxWidth >= 600
          ? 2
          : 1;
      final width = (c.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: loads
            .map(
              (l) => SizedBox(
                width: width,
                child: LoadCard(
                  l,
                  onTap: () => onTap(l),
                  showRequests: showRequests,
                ),
              ),
            )
            .toList(),
      );
    },
  );
}
