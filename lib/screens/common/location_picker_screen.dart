import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../services/location/location_service.dart';

/// Point chosen on the map, together with the address resolved for it.
class PickedLocation {
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.pincode,
  });

  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? pincode;
}

/// Full-screen map for picking a point. Uses OpenStreetMap tiles, so it needs
/// no API key and incurs no billing.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialQuery,
    this.title = 'Choose location',
  });

  final double? initialLatitude;
  final double? initialLongitude;

  /// Address details already typed elsewhere in the form. With no coordinates
  /// to start from, the map opens on this instead of a default city, so the
  /// pin lands near the place the user has been describing.
  final String? initialQuery;

  final String title;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

/// Address shown for the current pin. [resolving] drives the progress hint.
class _Address {
  const _Address({
    this.text,
    this.city,
    this.pincode,
    this.latitude,
    this.longitude,
    this.resolving = false,
  });

  final String? text;
  final String? city;
  final String? pincode;

  /// The point this address was resolved for. Panning moves the pin faster
  /// than the geocoder can keep up, so this is what proves the two agree.
  final double? latitude;
  final double? longitude;

  final bool resolving;

  bool describes(LatLng point) =>
      latitude == point.latitude && longitude == point.longitude;
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // Koramangala, Bangalore — matches the sample data used elsewhere.
  static const _fallbackCenter = LatLng(12.9352, 77.6245);

  /// Roughly a metre per pixel, so the pin can be placed on a single building
  /// rather than a block.
  static const _zoom = 17.5;

  final _mapController = MapController();
  final _locationService = LocationService();

  // Panning updates these notifiers instead of calling setState, so the map
  // is never rebuilt mid-gesture. Rebuilding it from onPositionChanged would
  // feed the callback again and can loop until the frame budget is gone.
  late final ValueNotifier<LatLng> _center;
  final _address = ValueNotifier<_Address>(const _Address(resolving: true));
  final _locating = ValueNotifier<bool>(false);
  final _searching = ValueNotifier<bool>(false);
  final _confirming = ValueNotifier<bool>(false);
  final _search = TextEditingController();

  Timer? _geocodeDebounce;
  int _geocodeRequest = 0;

  @override
  void initState() {
    super.initState();
    final latitude = widget.initialLatitude;
    final longitude = widget.initialLongitude;
    final hasPoint = latitude != null && longitude != null;
    _center = ValueNotifier(
      hasPoint ? LatLng(latitude, longitude) : _fallbackCenter,
    );

    final query = widget.initialQuery?.trim() ?? '';
    if (!hasPoint && query.isNotEmpty) {
      _search.text = query;
      // The controller cannot move the map until it has been built.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final located = await _runSearch(query, announceMiss: false);
        // Nothing matched, so describe wherever the map actually opened.
        if (!located && mounted) _resolveAddress(_center.value);
      });
    } else {
      _resolveAddress(_center.value);
    }
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _mapController.dispose();
    _center.dispose();
    _address.dispose();
    _locating.dispose();
    _searching.dispose();
    _confirming.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onCameraMoved(MapCamera camera, bool hasGesture) {
    _center.value = camera.center;
    _address.value = _Address(
      text: _address.value.text,
      city: _address.value.city,
      pincode: _address.value.pincode,
      resolving: true,
    );
    // Reverse geocoding is rate limited, so only resolve once panning settles.
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(
      const Duration(milliseconds: 600),
      () => _resolveAddress(_center.value),
    );
  }

  Future<void> _resolveAddress(LatLng point) async {
    // Ignore results that arrive after the pin has moved on again.
    final request = ++_geocodeRequest;
    final location = await _locationService.describeCoordinates(
      point.latitude,
      point.longitude,
    );
    if (!mounted || request != _geocodeRequest) return;
    _address.value = _Address(
      text: location.address,
      city: location.city,
      pincode: location.pincode,
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }

  /// Moves the pin to a typed place, reporting whether anything was found.
  /// [announceMiss] is off when seeding the map from a half-filled form, where
  /// a miss is not worth complaining about.
  Future<bool> _runSearch(String query, {bool announceMiss = true}) async {
    if (query.trim().isEmpty) return false;

    _searching.value = true;
    try {
      final found = await _locationService.locateAddress(query);
      if (!mounted) return false;
      if (found == null) {
        if (announceMiss) {
          _showMessage('Could not find that place. Drag the map instead.');
        }
        return false;
      }
      _moveTo(found);
      return true;
    } finally {
      if (mounted) _searching.value = false;
    }
  }

  /// Recentres the map and adopts the address that came with the point.
  void _moveTo(LocationData location) {
    final point = LatLng(location.latitude, location.longitude);
    _mapController.move(point, _zoom);
    _center.value = point;
    _geocodeDebounce?.cancel();
    _geocodeRequest++;
    _address.value = _Address(
      text: location.address,
      city: location.city,
      pincode: location.pincode,
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  Future<void> _goToCurrentLocation() async {
    _locating.value = true;
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      _moveTo(location);
    } on AppException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not get your current location.');
    } finally {
      if (mounted) _locating.value = false;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirm() async {
    final point = _center.value;

    // Panning is debounced, so tapping straight after a drag would otherwise
    // return this point paired with the previous point's address. Resolve the
    // point actually under the pin before handing anything back.
    if (!_address.value.describes(point)) {
      _confirming.value = true;
      _geocodeDebounce?.cancel();
      await _resolveAddress(point);
      if (!mounted) return;
      _confirming.value = false;
    }

    final address = _address.value;
    if (!mounted) return;
    Navigator.of(context).pop(
      PickedLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        // Only pass an address that belongs to this exact point.
        address: address.describes(point) ? address.text : null,
        city: address.describes(point) ? address.city : null,
        pincode: address.describes(point) ? address.pincode : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center.value,
                    initialZoom: _zoom,
                    onPositionChanged: _onCameraMoved,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.nearkart.nearkart',
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _SearchField(
                    controller: _search,
                    searching: _searching,
                    onSearch: _runSearch,
                  ),
                ),
                // The pin points at the centre of the map, which is the
                // coordinate returned. The dot marks that centre exactly, so
                // there is no doubt about which spot is being saved.
                const IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_on,
                      size: 44,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const IgnorePointer(child: _CentreDot()),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _locating,
                    builder: (context, locating, _) =>
                        FloatingActionButton.small(
                          heroTag: 'useCurrentLocation',
                          onPressed: locating ? null : _goToCurrentLocation,
                          tooltip: 'Use my current location',
                          child: locating
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                        ),
                  ),
                ),
              ],
            ),
          ),
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Search above or drag the map to place the pin',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<_Address>(
                      valueListenable: _address,
                      builder: (context, address, _) => Text(
                        address.resolving
                            ? 'Finding address…'
                            : (address.text?.isNotEmpty == true
                                  ? address.text!
                                  : 'Address unavailable for this point'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<LatLng>(
                      valueListenable: _center,
                      builder: (context, center, _) => Text(
                        '${center.latitude.toStringAsFixed(6)}, '
                        '${center.longitude.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<bool>(
                      valueListenable: _confirming,
                      builder: (context, confirming, _) => FilledButton.icon(
                        onPressed: confirming ? null : _confirm,
                        icon: confirming
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          confirming
                              ? 'Confirming address…'
                              : 'Use this location',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marks the exact point that will be saved.
class _CentreDot extends StatelessWidget {
  const _CentreDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

/// Searches for a place by name, area or pincode.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.searching,
    required this.onSearch,
  });

  final TextEditingController controller;
  final ValueNotifier<bool> searching;
  final void Function(String query) onSearch;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: ValueListenableBuilder<bool>(
        valueListenable: searching,
        builder: (context, isSearching, _) => TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: onSearch,
          decoration: InputDecoration(
            hintText: 'Search area, street or pincode',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: isSearching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    tooltip: 'Search',
                    onPressed: () => onSearch(controller.text),
                  ),
          ),
        ),
      ),
    );
  }
}
