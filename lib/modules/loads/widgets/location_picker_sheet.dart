import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lorry_link/config/app_config.dart';
import 'package:lorry_link/utils/services/place_search_service.dart';

class PickedMapLocation {
  const PickedMapLocation(this.latitude, this.longitude, {this.placeName});

  final double latitude, longitude;
  final String? placeName;
}

Future<PickedMapLocation?> showLocationPicker(
  BuildContext context, {
  required String title,
  String initialQuery = '',
  double? latitude,
  double? longitude,
  required Future<List<PlaceSearchResult>> Function(String) search,
}) => showModalBottomSheet<PickedMapLocation>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _LocationPickerSheet(
    title: title,
    initialQuery: initialQuery,
    latitude: latitude,
    longitude: longitude,
    search: search,
  ),
);

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({
    required this.title,
    required this.initialQuery,
    required this.latitude,
    required this.longitude,
    required this.search,
  });

  final String title;
  final String initialQuery;
  final double? latitude, longitude;
  final Future<List<PlaceSearchResult>> Function(String) search;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  static const _kerala = LatLng(10.1632, 76.6413);
  late final query = TextEditingController(text: widget.initialQuery);
  final mapController = MapController();
  late LatLng selected = widget.latitude == null || widget.longitude == null
      ? _kerala
      : LatLng(widget.latitude!, widget.longitude!);
  String? selectedPlaceName;
  List<PlaceSearchResult> results = const [];
  bool searching = false;
  String? searchError;
  Timer? _searchDebounce;
  int _searchRequest = 0;

  @override
  void initState() {
    super.initState();
    if (widget.latitude != null && widget.longitude != null) {
      selected = LatLng(widget.latitude!, widget.longitude!);
      if (widget.initialQuery.trim().isNotEmpty) {
        selectedPlaceName = widget.initialQuery.trim();
      }
    }
    // Automatically search for entered location name if provided
    if (widget.initialQuery.trim().length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search(
          hideKeyboard: true,
          autoSelectFirst: widget.latitude == null || widget.longitude == null,
        );
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    query.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        results = const [];
        searchError = null;
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 700),
      () => _search(hideKeyboard: false),
    );
  }

  Future<void> _search({
    bool hideKeyboard = true,
    bool autoSelectFirst = false,
  }) async {
    _searchDebounce?.cancel();
    if (hideKeyboard && mounted) FocusScope.of(context).unfocus();
    final term = query.text.trim();
    if (term.length < 2) {
      if (mounted) {
        setState(() {
          results = const [];
          searchError = 'Enter at least two characters to search.';
        });
      }
      return;
    }
    final request = ++_searchRequest;
    if (mounted) {
      setState(() {
        searching = true;
        searchError = null;
      });
    }
    try {
      final found = await widget
          .search(term)
          .timeout(const Duration(seconds: 10));
      if (!mounted || request != _searchRequest) return;
      setState(() {
        results = found;
        searching = false;
        if (found.isNotEmpty && autoSelectFirst) {
          final first = found.first;
          final point = LatLng(first.latitude, first.longitude);
          selected = point;
          selectedPlaceName = first.label;
          mapController.move(point, 15);
        } else if (found.isEmpty && autoSelectFirst) {
          searchError = 'No exact location found for "$term". Please pick on map.';
        }
      });
    } catch (error) {
      if (!mounted || request != _searchRequest) return;
      setState(() {
        results = const [];
        searching = false;
        searchError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _selectResult(PlaceSearchResult result) {
    final point = LatLng(result.latitude, result.longitude);
    setState(() {
      selected = point;
      selectedPlaceName = result.label;
      query.text = result.label;
      results = const [];
      searchError = null;
    });
    mapController.move(point, 15);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Move or tap the map to mark the exact place. The place name you entered will be kept.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: query,
                textInputAction: TextInputAction.search,
                onChanged: _scheduleSearch,
                onSubmitted: (_) => _search(hideKeyboard: true, autoSelectFirst: true),
                decoration: InputDecoration(
                  labelText: 'Search a city, town, landmark or address',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Search place',
                          onPressed: () => _search(hideKeyboard: true, autoSelectFirst: true),
                          icon: const Icon(Icons.arrow_forward),
                        ),
                ),
              ),
              if (searchError != null) ...[
                const SizedBox(height: 6),
                Text(
                  searchError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (results.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 128,
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(result.label),
                          subtitle: Text(
                            '${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}',
                          ),
                          onTap: () => _selectResult(result),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: selected,
                          initialZoom: widget.latitude == null ? 7 : 15,
                          onTap: (_, point) => setState(() {
                            selected = point;
                            // If tapped on the map without searching or if query is empty, do not set place name
                            if (results.isEmpty || query.text.trim().isEmpty) {
                              selectedPlaceName = null;
                            }
                          }),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: AppConfig.mapTileUrl,
                            userAgentPackageName: 'com.lorrylink.lorry_link',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: selected,
                                width: 52,
                                height: 52,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 42,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Positioned(
                        right: 8,
                        bottom: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            child: Text(
                              '© OpenStreetMap',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${selected.latitude.toStringAsFixed(6)}, ${selected.longitude.toStringAsFixed(6)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  PickedMapLocation(
                    selected.latitude,
                    selected.longitude,
                    placeName: selectedPlaceName,
                  ),
                ),
                icon: const Icon(Icons.check),
                label: const Text('Use this map location'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
