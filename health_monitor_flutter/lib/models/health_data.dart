import 'package:flutter/material.dart';

// Updated models/health_data.dart
class HealthData {
  final DateTime timestamp;
  final double heartRate;
  final double spo2;
  final double temperature;
  final bool hasAnomaly;
  
  // New AI prediction fields
  final double? anomalyProbability;
  final double? normalProbability;
  final double? confidence;
  final String? aiResult;
  final String? recommendation;
  final String? urgencyLevel;

  HealthData({
    required this.timestamp,
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    required this.hasAnomaly,
    this.anomalyProbability,
    this.normalProbability,
    this.confidence,
    this.aiResult,
    this.recommendation,
    this.urgencyLevel,
  });

  // Create from AI API response
  factory HealthData.fromAIResponse({
    required DateTime timestamp,
    required double heartRate,
    required double spo2,
    required double temperature,
    required Map<String, dynamic> aiResponse,
  }) {
    return HealthData(
      timestamp: timestamp,
      heartRate: heartRate,
      spo2: spo2,
      temperature: temperature,
      hasAnomaly: aiResponse['prediction'] == 1,
      anomalyProbability: aiResponse['probabilities']?['anomaly']?.toDouble(),
      normalProbability: aiResponse['probabilities']?['normal']?.toDouble(),
      confidence: aiResponse['confidence']?.toDouble(),
      aiResult: aiResponse['interpretation']?['result'],
      recommendation: aiResponse['interpretation']?['recommendation'],
      urgencyLevel: aiResponse['interpretation']?['urgency'],
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'heartRate': heartRate,
      'spo2': spo2,
      'temperature': temperature,
      'hasAnomaly': hasAnomaly,
      'anomalyProbability': anomalyProbability,
      'normalProbability': normalProbability,
      'confidence': confidence,
      'aiResult': aiResult,
      'recommendation': recommendation,
      'urgencyLevel': urgencyLevel,
    };
  }

  // Create from JSON
  factory HealthData.fromJson(Map<String, dynamic> json) {
    return HealthData(
      timestamp: DateTime.parse(json['timestamp']),
      heartRate: json['heartRate']?.toDouble() ?? 0.0,
      spo2: json['spo2']?.toDouble() ?? 0.0,
      temperature: json['temperature']?.toDouble() ?? 0.0,
      hasAnomaly: json['hasAnomaly'] ?? false,
      anomalyProbability: json['anomalyProbability']?.toDouble(),
      normalProbability: json['normalProbability']?.toDouble(),
      confidence: json['confidence']?.toDouble(),
      aiResult: json['aiResult'],
      recommendation: json['recommendation'],
      urgencyLevel: json['urgencyLevel'],
    );
  }

  // Get risk level based on urgency
  String get riskLevel {
    if (urgencyLevel == null) return 'Unknown';
    switch (urgencyLevel!.toLowerCase()) {
      case 'high':
        return 'Critical';
      case 'medium':
        return 'Moderate';
      case 'low':
        return 'Low';
      default:
        return 'Unknown';
    }
  }

  // Get color based on risk level
  Color get riskColor {
    switch (riskLevel) {
      case 'Critical':
        return Colors.red;
      case 'Moderate':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Check if vital signs are within normal ranges
  bool get isHeartRateNormal => heartRate >= 60 && heartRate <= 100;
  bool get isSpO2Normal => spo2 >= 95;
  bool get isTemperatureNormal => temperature >= 36.1 && temperature <= 37.2;

  // Get overall health status
  String get healthStatus {
    if (hasAnomaly) {
      return aiResult ?? 'Anomaly Detected';
    }
    
    if (isHeartRateNormal && isSpO2Normal && isTemperatureNormal) {
      return 'Excellent';
    } else if ((isHeartRateNormal ? 1 : 0) + 
               (isSpO2Normal ? 1 : 0) + 
               (isTemperatureNormal ? 1 : 0) >= 2) {
      return 'Good';
    } else {
      return 'Needs Attention';
    }
  }

  @override
  String toString() {
    return 'HealthData(timestamp: $timestamp, heartRate: $heartRate, spo2: $spo2, temperature: $temperature, hasAnomaly: $hasAnomaly, confidence: $confidence)';
  }
}