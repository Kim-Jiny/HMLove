import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/theme.dart';

class LocationPickerResult {
  final double latitude;
  final double longitude;
  final String label;

  const LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.label,
  });
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  NaverMapController? _mapController;
  String _addressLabel = '지도를 움직여 위치를 선택하세요';
  bool _isLoading = true;
  bool _isGeocoding = false;
  NLatLng _currentCenter = const NLatLng(37.5665, 126.9780);
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        try {
          permission = await Geolocator.requestPermission();
        } catch (_) {
          permission = LocationPermission.deniedForever;
        }
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        final goSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위치 권한 필요'),
            content: const Text('위치 선택을 위해 설정에서 위치 권한을 허용해주세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('설정으로 이동'),
              ),
            ],
          ),
        );
        if (goSettings == true) {
          await Geolocator.openAppSettings();
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final target = NLatLng(position.latitude, position.longitude);
      setState(() {
        _currentCenter = target;
        _isLoading = false;
      });

      _mapController?.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: target, zoom: 15),
      );
      _reverseGeocode(target);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onMapReady(NaverMapController controller) {
    _mapController = controller;
    setState(() => _ready = true);
    if (!_isLoading) {
      controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: _currentCenter, zoom: 15),
      );
    }
  }

  void _onCameraIdle() async {
    if (_mapController == null) return;
    final position = await _mapController!.getCameraPosition();
    final center = position.target;
    setState(() => _currentCenter = center);
    _reverseGeocode(center);
  }

  Future<void> _reverseGeocode(NLatLng point) async {
    setState(() => _isGeocoding = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=${point.latitude}&lon=${point.longitude}'
        '&zoom=18&addressdetails=1&accept-language=ko',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'HMLoveApp/1.0',
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null && mounted) {
          final parts = <String>[];
          final city = address['city'] ?? address['county'] ?? address['state'];
          final district = address['borough'] ?? address['suburb'] ?? address['town'] ?? address['village'];
          final road = address['road'] ?? address['pedestrian'] ?? address['neighbourhood'];
          final detail = address['building'] ?? address['amenity'] ?? address['shop'];
          if (city != null) parts.add(city.toString());
          if (district != null) parts.add(district.toString());
          if (road != null) parts.add(road.toString());
          if (detail != null) parts.add(detail.toString());
          if (parts.isEmpty) {
            final displayName = data['display_name'] as String?;
            if (displayName != null) {
              final segments = displayName.split(',').map((e) => e.trim()).toList();
              parts.addAll(segments.take(2));
            }
          }
          setState(() {
            _addressLabel = parts.isNotEmpty ? parts.join(' ') : '선택한 위치';
            _isGeocoding = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _addressLabel = '선택한 위치';
        _isGeocoding = false;
      });
    }
  }

  void _confirmLocation() {
    Navigator.pop(
      context,
      LocationPickerResult(
        latitude: _currentCenter.latitude,
        longitude: _currentCenter.longitude,
        label: _addressLabel,
      ),
    );
  }

  void _goToMyLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final target = NLatLng(position.latitude, position.longitude);
      _mapController?.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: target, zoom: 15),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 선택'),
      ),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: _currentCenter,
                zoom: 15,
              ),
              locationButtonEnable: false,
              scaleBarEnable: false,
              logoClickEnable: false,
            ),
            onMapReady: _onMapReady,
            onCameraIdle: _onCameraIdle,
          ),
          // Center pin (tip aligned exactly to map center)
          if (_ready)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 48),
                child: Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 48,
                ),
              ),
            ),
          // Pin shadow (at map center point)
          if (_ready)
            Center(
              child: Container(
                width: 6,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          // My location button
          Positioned(
            right: 16,
            bottom: 116,
            child: FloatingActionButton.small(
              heroTag: 'myLoc',
              backgroundColor: Colors.white,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location, color: AppTheme.textPrimary),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          // Bottom info bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isGeocoding)
                              const Text(
                                '주소를 찾는 중...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textHint,
                                ),
                              )
                            else
                              Text(
                                _addressLabel,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 2),
                            Text(
                              '${_currentCenter.latitude.toStringAsFixed(5)}, ${_currentCenter.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirmLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '이 위치 전송',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
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
}
