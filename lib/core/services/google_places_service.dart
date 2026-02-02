import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stray_resuce_bih/core/models/vet_hospital.dart';
import 'package:stray_resuce_bih/core/services/location_service.dart';

/// Service to interact with Google Places API
class GooglePlacesService {
  // Singleton pattern
  static final GooglePlacesService _instance = GooglePlacesService._internal();
  factory GooglePlacesService() => _instance;
  GooglePlacesService._internal();

  // TODO: Replace with your actual Google Places API key
  static const String _apiKey = 'YOUR_GOOGLE_PLACES_API_KEY';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  /// Search for nearby veterinary hospitals
  /// 
  /// [latitude] - User's current latitude
  /// [longitude] - User's current longitude
  /// [radius] - Search radius in meters (default 5000m = 5km)
  Future<List<VetHospital>> searchNearbyVets({
    required double latitude,
    required double longitude,
    int radius = 5000,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/nearbysearch/json?'
        'location=$latitude,$longitude&'
        'radius=$radius&'
        'type=veterinary_care&'
        'key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];

        final vets = results
            .map((json) => VetHospital.fromJson(json as Map<String, dynamic>))
            .toList();

        // Calculate distance from user for each vet
        final locationService = LocationService(); 
        for (var vet in vets) {
          vet.distanceFromUser = locationService.calculateDistance(
            latitude,
            longitude,
            vet.latitude,
            vet.longitude,
          );
        }

        // Sort by distance (nearest first)
        vets.sort((a, b) {
          if (a.distanceFromUser == null) return 1;
          if (b.distanceFromUser == null) return -1;
          return a.distanceFromUser!.compareTo(b.distanceFromUser!);
        });

        return vets;
      } else {
        print('Error fetching vets: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching nearby vets: $e');
      return [];
    }
  }

  /// Get photo URL for a place
  String? getPhotoUrl(String? photoReference, {int maxWidth = 400}) {
    if (photoReference == null) return null;
    return '$_baseUrl/photo?maxwidth=$maxWidth&photo_reference=$photoReference&key=$_apiKey';
  }
}
