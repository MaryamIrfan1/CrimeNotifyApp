// lib/services/priority_calculator.dart
import 'dart:math';
import 'package:latlong2/latlong.dart';

class PriorityCalculator {
  // Crime severity weights (40% of total score)
  static const Map<String, double> SEVERITY_WEIGHTS = {
    'Murder': 10.0,
    'Rape': 10.0,
    'Kidnapping': 9.5,
    'Armed Robbery': 9.0,
    'Assault': 8.0,
    'Robbery': 7.5,
    'Burglary': 6.5,
    'Theft': 5.0,
    'Fraud': 4.0,
    'Vandalism': 3.0,
    'Other': 2.0,
  };

  // Danger keywords for description analysis
  static const List<String> WEAPON_KEYWORDS = [
    'gun',
    'knife',
    'weapon',
    'armed',
    'pistol',
    'rifle',
    'blade'
  ];

  static const List<String> URGENCY_KEYWORDS = [
    'help',
    'emergency',
    'urgent',
    'danger',
    'attacking',
    'bleeding',
    'injured',
    'dying',
    'threatening'
  ];

  static const List<String> VIOLENCE_KEYWORDS = [
    'fight',
    'hitting',
    'beating',
    'stabbing',
    'shooting',
    'attack'
  ];

  /// Main priority calculation function
  static double calculatePriority({
    required String crimeType,
    required String description,
    required DateTime timestamp,
    required LatLng location,
    bool hasPhotos = false,
    bool hasVideo = false,
  }) {
    double score = 0.0;

    // 1. Base severity score (40% weight)
    double severityScore = SEVERITY_WEIGHTS[crimeType] ?? 5.0;
    score += severityScore * 0.4;

    // 2. Time urgency (20% weight)
    double timeScore = _calculateTimeUrgency(timestamp);
    score += timeScore * 0.2;

    // 3. Description danger level (20% weight)
    double dangerScore = _analyzeDangerLevel(description);
    score += dangerScore * 0.2;

    // 4. Location risk (10% weight)
    double locationScore = _calculateLocationRisk(location);
    score += locationScore * 0.1;

    // 5. Evidence quality (10% weight)
    double evidenceScore = _calculateEvidenceScore(hasPhotos, hasVideo);
    score += evidenceScore * 0.1;

    return min(score, 10.0); // Cap at 10.0
  }

  /// Time urgency: Recent crimes get higher priority
  static double _calculateTimeUrgency(DateTime timestamp) {
    int minutesAgo = DateTime.now().difference(timestamp).inMinutes;

    if (minutesAgo < 5) return 10.0; // Just happened
    if (minutesAgo < 15) return 8.0; // Very recent
    if (minutesAgo < 30) return 6.0; // Recent
    if (minutesAgo < 60) return 4.0; // Within hour
    return 2.0; // Older
  }

  /// Analyze description for danger indicators
  static double _analyzeDangerLevel(String description) {
    String lowerDesc = description.toLowerCase();
    double score = 5.0; // Base score

    // Check for weapon mentions
    int weaponCount =
        WEAPON_KEYWORDS.where((keyword) => lowerDesc.contains(keyword)).length;
    score += weaponCount * 2.0;

    // Check for urgency indicators
    int urgencyCount =
        URGENCY_KEYWORDS.where((keyword) => lowerDesc.contains(keyword)).length;
    score += urgencyCount * 1.5;

    // Check for violence indicators
    int violenceCount = VIOLENCE_KEYWORDS
        .where((keyword) => lowerDesc.contains(keyword))
        .length;
    score += violenceCount * 1.0;

    // Check for victim mentions
    if (lowerDesc.contains('victim') ||
        lowerDesc.contains('injured') ||
        lowerDesc.contains('hurt')) {
      score += 2.0;
    }

    // Check for "in progress" indicators
    if (lowerDesc.contains('happening now') ||
        lowerDesc.contains('right now') ||
        lowerDesc.contains('in progress')) {
      score += 3.0;
    }

    return min(score, 10.0);
  }

  /// Calculate location risk based on area
  static double _calculateLocationRisk(LatLng location) {
    // Simple heuristic: areas closer to known high-crime coordinates
    // In real app, you'd use historical crime data

    // Example high-risk area (you can modify these)
    List<LatLng> highRiskAreas = [
      LatLng(33.5651, 73.0169), // Example: Downtown area
      LatLng(33.6844, 73.0479), // Example: Market area
    ];

    double minDistance = double.infinity;
    const Distance distCalc = Distance();

    for (var riskArea in highRiskAreas) {
      double dist = distCalc.as(LengthUnit.Kilometer, location, riskArea);
      if (dist < minDistance) minDistance = dist;
    }

    // Closer to high-risk area = higher score
    if (minDistance < 1.0) return 10.0; // Within 1km
    if (minDistance < 3.0) return 8.0; // Within 3km
    if (minDistance < 5.0) return 6.0; // Within 5km
    if (minDistance < 10.0) return 4.0; // Within 10km
    return 2.0; // Far from known risk areas
  }

  /// Evidence quality score
  static double _calculateEvidenceScore(bool hasPhotos, bool hasVideo) {
    double score = 5.0; // Base score

    if (hasVideo) {
      score += 3.0; // Video is most valuable
    } else if (hasPhotos) score += 1.5; // Photos are good

    return score;
  }

  /// Get priority color based on score
  static String getPriorityColor(double score) {
    if (score >= 8.0) return '#D32F2F'; // Red
    if (score >= 6.0) return '#FF6F00'; // Orange
    if (score >= 4.0) return '#FBC02D'; // Yellow
    return '#388E3C'; // Green
  }

  /// Get priority level text
  static String getPriorityLevel(double score) {
    if (score >= 8.0) return 'CRITICAL';
    if (score >= 6.0) return 'HIGH';
    if (score >= 4.0) return 'MEDIUM';
    return 'LOW';
  }
}
