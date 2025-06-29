// services/medical_api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';

class MedicalApiService {
  static final MedicalApiService _instance = MedicalApiService._internal();
  factory MedicalApiService() => _instance;
  MedicalApiService._internal();

  final Logger _logger = Logger('MedicalApiService');
  
  // API Configuration
  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000'; // Android emulator
    } else if (Platform.isIOS) {
      return 'http://localhost:5000'; // iOS simulator
    } else {
      return 'http://localhost:5000'; // Default
    }
  }

  static const Duration timeout = Duration(seconds: 15);
  static const String apiKey = 'your_api_key_here'; // Add if you implement API key auth

  // Health check endpoint
  Future<ApiResponse<Map<String, dynamic>>> healthCheck() async {
    try {
      _logger.info('Checking API health at: $baseUrl');
      
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: _getHeaders(),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _logger.info('API Health: ${data['message']}');
        return ApiResponse.success(data);
      } else {
        _logger.warning('Health check failed: ${response.statusCode}');
        return ApiResponse.error('API health check failed: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Health check error: $e');
      return ApiResponse.error('Cannot reach medical AI API: $e');
    }
  }

  // Single prediction endpoint
  Future<ApiResponse<Map<String, dynamic>>> predictAnomaly({
    required double heartRate,
    required double temperature,
    required double spo2,
  }) async {
    try {
      final requestData = {
        'heart_rate': heartRate,
        'temperature': temperature,
        'spo2': spo2,
      };

      _logger.info('Sending prediction request: $requestData');

      final response = await http.post(
        Uri.parse('$baseUrl/predict'),
        headers: _getHeaders(),
        body: jsonEncode(requestData),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _logger.info('Prediction successful: ${data['interpretation']['result']}');
        return ApiResponse.success(data);
      } else {
        _logger.severe('Prediction failed: ${response.statusCode}');
        _logger.severe('Response body: ${response.body}');
        
        // Try to parse error message
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          return ApiResponse.error(errorData['error'] ?? 'Prediction failed');
        } catch (_) {
          return ApiResponse.error('Prediction failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      _logger.severe('Prediction error: $e');
      return ApiResponse.error('Network error during prediction: $e');
    }
  }

  // Batch prediction endpoint
  Future<ApiResponse<Map<String, dynamic>>> batchPredict({
    required List<Map<String, dynamic>> patients,
  }) async {
    try {
      final requestData = {'patients': patients};

      _logger.info('Sending batch prediction for ${patients.length} patients');

      final response = await http.post(
        Uri.parse('$baseUrl/batch_predict'),
        headers: _getHeaders(),
        body: jsonEncode(requestData),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _logger.info('Batch prediction successful');
        return ApiResponse.success(data);
      } else {
        _logger.severe('Batch prediction failed: ${response.statusCode}');
        return ApiResponse.error('Batch prediction failed: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Batch prediction error: $e');
      return ApiResponse.error('Network error during batch prediction: $e');
    }
  }

  // Get model information
  Future<ApiResponse<Map<String, dynamic>>> getModelInfo() async {
    try {
      _logger.info('Fetching model information');

      final response = await http.get(
        Uri.parse('$baseUrl/model_info'),
        headers: _getHeaders(),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _logger.info('Model info retrieved successfully');
        return ApiResponse.success(data);
      } else {
        _logger.warning('Model info request failed: ${response.statusCode}');
        return ApiResponse.error('Failed to get model info: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Model info error: $e');
      return ApiResponse.error('Network error getting model info: $e');
    }
  }

  // Test connection with retry logic
  Future<ApiResponse<bool>> testConnection({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      _logger.info('Testing connection (attempt $attempt/$maxRetries)');
      
      final healthResponse = await healthCheck();
      
      if (healthResponse.isSuccess) {
        final data = healthResponse.data!;
        if (data['model_loaded'] == true) {
          _logger.info('Connection test successful - Model ready');
          return ApiResponse.success(true);
        } else {
          _logger.warning('Connection successful but model not loaded');
          return ApiResponse.error('Medical AI model not loaded on server');
        }
      }
      
      if (attempt < maxRetries) {
        _logger.info('Retrying connection in 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    
    _logger.severe('Connection test failed after $maxRetries attempts');
    return ApiResponse.error('Cannot connect to medical AI server after $maxRetries attempts');
  }

  // Validate vital signs before sending
  static bool validateVitalSigns({
    required double heartRate,
    required double temperature,
    required double spo2,
  }) {
    return heartRate >= 30 && heartRate <= 200 &&
           temperature >= 30 && temperature <= 45 &&
           spo2 >= 70 && spo2 <= 100;
  }

  // Get validation error message
  static String? getValidationError({
    required double heartRate,
    required double temperature,
    required double spo2,
  }) {
    if (heartRate < 30 || heartRate > 200) {
      return 'Heart rate must be between 30-200 bpm';
    }
    if (temperature < 30 || temperature > 45) {
      return 'Temperature must be between 30-45°C';
    }
    if (spo2 < 70 || spo2 > 100) {
      return 'SpO2 must be between 70-100%';
    }
    return null;
  }

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // Add API key if authentication is implemented
    // headers['X-API-Key'] = apiKey;
    
    return headers;
  }
}

// Generic API response wrapper
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;
  final int? statusCode;

  ApiResponse.success(this.data)
      : isSuccess = true,
        error = null,
        statusCode = null;

  ApiResponse.error(this.error, [this.statusCode])
      : isSuccess = false,
        data = null;

  bool get isError => !isSuccess;
}

// Prediction result helper class
class PredictionResult {
  final int prediction;
  final Map<String, double> probabilities;
  final double confidence;
  final String result;
  final String recommendation;
  final String urgency;
  final Map<String, dynamic> input;

  PredictionResult({
    required this.prediction,
    required this.probabilities,
    required this.confidence,
    required this.result,
    required this.recommendation,
    required this.urgency,
    required this.input,
  });

  factory PredictionResult.fromApiResponse(Map<String, dynamic> data) {
    return PredictionResult(
      prediction: data['prediction'] ?? 0,
      probabilities: Map<String, double>.from(
        data['probabilities']?.map((k, v) => MapEntry(k, v?.toDouble() ?? 0.0)) ?? {}
      ),
      confidence: data['confidence']?.toDouble() ?? 0.0,
      result: data['interpretation']?['result'] ?? 'Unknown',
      recommendation: data['interpretation']?['recommendation'] ?? 'No recommendation',
      urgency: data['interpretation']?['urgency'] ?? 'Unknown',
      input: Map<String, dynamic>.from(data['input'] ?? {}),
    );
  }

  bool get isAnomaly => prediction == 1;
  bool get isCritical => urgency.toLowerCase() == 'high';
  bool get isModerate => urgency.toLowerCase() == 'medium';
  bool get isLowRisk => urgency.toLowerCase() == 'low';

  String get riskLevel {
    switch (urgency.toLowerCase()) {
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
}

// API Status tracker
class ApiStatus {
  static bool _isConnected = false;
  static bool _modelLoaded = false;
  static DateTime? _lastCheck;
  static String? _lastError;

  static bool get isConnected => _isConnected;
  static bool get isModelLoaded => _modelLoaded;
  static DateTime? get lastCheck => _lastCheck;
  static String? get lastError => _lastError;

  static void updateStatus({
    required bool connected,
    required bool modelLoaded,
    String? error,
  }) {
    _isConnected = connected;
    _modelLoaded = modelLoaded;
    _lastCheck = DateTime.now();
    _lastError = error;
  }

  static bool get isHealthy => _isConnected && _modelLoaded;
  
  static String get statusMessage {
    if (_lastError != null) return _lastError!;
    if (!_isConnected) return 'Not connected to AI server';
    if (!_modelLoaded) return 'AI model not loaded';
    return 'AI system ready';
  }
}