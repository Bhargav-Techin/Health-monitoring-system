import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:logging/logging.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'health_card.dart';
import 'hospitals_page.dart';
import 'history_page.dart';
import 'models/health_data.dart';
import 'services/firebase_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final AudioPlayer audioPlayer = AudioPlayer();
  final Logger _logger = Logger('HealthMonitor');
  final FirebaseService _firebaseService = FirebaseService();

  late AnimationController _pulseController;
  late AnimationController _statusController;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _statusColorAnimation;

  bool isLoading = false;
  bool hasAnomaly = false;
  bool hasError = false;
  String statusMessage = '';
  Timer? _refreshTimer;
  List<HealthData> healthHistory = [];
  Map<String, dynamic> healthData = {
    'heart_rate': 0.00,
    'spo2': 0.00,
    'temperature': 0.00,
  };

  final String thingSpeakApiKey = 'DS0XB3E2TMOX1QP4';
  final int channelId = 2997540;

  String get _aiModelBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else {
      return 'http://10.0.2.2:5000';
    }
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupLogging();
    _fetchData();
    _startRefreshTimer();
    _listenToAnomaly();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _statusController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _statusColorAnimation = ColorTween(
      begin: Colors.blue,
      end: Colors.orange,
    ).animate(_statusController);

    _pulseController.repeat(reverse: true);
  }

  void _setupLogging() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
      if (record.error != null) {
        debugPrint('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        debugPrint('Stack trace: ${record.stackTrace}');
      }
    });
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      _fetchData();
    });
  }

  void _listenToAnomaly() {
    _firebaseService.anomalyStream.listen((isAnomaly) {
      setState(() {
        hasAnomaly = isAnomaly ?? false;
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _statusController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      hasAnomaly = false;
      hasError = false;
      statusMessage = 'Fetching data...';
    });

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        _logger.info(
          'Fetching data from ThingSpeak... (Attempt ${retryCount + 1})',
        );
        final response = await http
            .get(
          Uri.parse(
            'https://api.thingspeak.com/channels/$channelId/feeds.json?api_key=$thingSpeakApiKey&results=1',
          ),
        )
            .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Connection to ThingSpeak timed out');
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['feeds'] != null && data['feeds'].isNotEmpty) {
            final feed = data['feeds'][0];
            _logger.info('Data received from ThingSpeak: $feed');

            final newHealthData = {
              'temperature':
                  double.tryParse(feed['field1']?.toString() ?? '37.5') ?? 37.5,
              'heart_rate':
                  double.tryParse(feed['field2']?.toString() ?? '0') ?? 0,
              'spo2': double.tryParse(feed['field3']?.toString() ?? '0') ?? 0,
            };

            setState(() {
              healthData = newHealthData;
              statusMessage = 'Data fetched successfully';
            });

            healthHistory.insert(
                0,
                HealthData(
                  timestamp: DateTime.now(),
                  heartRate: newHealthData['heart_rate'] as double,
                  spo2: newHealthData['spo2'] as double,
                  temperature: newHealthData['temperature'] as double,
                  hasAnomaly: hasAnomaly,
                ));
            if (healthHistory.length > 100) {
              healthHistory.removeRange(100, healthHistory.length);
            }

            if (healthData['heart_rate'] > 0 || healthData['spo2'] > 0) {
              await _checkForAnomalies(healthData);
            } else {
              setState(() {
                hasError = true;
                statusMessage = 'Invalid data received from ThingSpeak';
              });
            }
            break;
          } else {
            _logger.warning('No data available from ThingSpeak');
            setState(() {
              hasError = true;
              statusMessage = 'No data available from ThingSpeak';
            });
            break;
          }
        } else {
          _logger.severe('Error fetching data: ${response.statusCode}');
          setState(() {
            hasError = true;
            statusMessage = 'Error fetching data: ${response.statusCode}';
          });
          break;
        }
      } catch (e, stackTrace) {
        _logger.severe('Error connecting to ThingSpeak', e, stackTrace);
        setState(() {
          hasError = true;
          statusMessage = 'Error connecting to ThingSpeak: ${e.toString()}';
        });
        break;
      }
    }

    setState(() {
      isLoading = false;
    });
  }

Future<void> _checkForAnomalies(Map<String, dynamic> data) async {
  try {
    if (data['heart_rate'] <= 0 || data['spo2'] <= 0) {
      _logger.warning('Invalid data for anomaly check: $data');
      setState(() {
        hasError = true;
        statusMessage = 'Invalid health data for anomaly detection';
      });
      return;
    }

    final requestData = {
      'heart_rate': data['heart_rate'],
      'spo2': data['spo2'],
      'temperature': data['temperature'],
    };

    _logger.info('Sending data to AI model: $requestData');
    _logger.info('Connecting to AI model at: $_aiModelBaseUrl/predict');

    final response = await http
        .post(
      Uri.parse('$_aiModelBaseUrl/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestData),
    )
        .timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Connection to AI model timed out');
      },
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> result = jsonDecode(response.body);
      _logger.info('AI model response: $result');

      // Fix: Check for 'prediction' field instead of 'is_anomaly'
      // prediction = 1 means anomaly, prediction = 0 means normal
      bool isAnomaly = result['prediction'] == 1;
      
      // Get confidence/probability for display
      double? confidence = result['confidence']?.toDouble();
      double? anomalyProbability = result['probabilities']?['anomaly']?.toDouble();
      
      // Use whichever probability value is available
      double displayProbability = confidence ?? anomalyProbability ?? 0.0;

      if (isAnomaly) {
        await _firebaseService.setAnomaly(true);
        setState(() {
          hasAnomaly = true;
          hasError = false;
          statusMessage =
              'Anomaly Detected: ${(displayProbability * 100).toStringAsFixed(1)}%';
        });
        try {
          await audioPlayer.play(
            UrlSource(
              'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
            ),
          );
        } catch (e) {
          _logger.warning('Could not play alert sound: $e');
        }
      } else {
        await _firebaseService.setAnomaly(false);
        setState(() {
          hasAnomaly = false;
          hasError = false;
          statusMessage = 'No Anomaly Detected';
        });
      }
    } else {
      _logger.severe('Error from AI model: ${response.statusCode}');
      _logger.severe('Response body: ${response.body}');
      setState(() {
        hasError = true;
        statusMessage = 'Error checking anomalies: ${response.statusCode}';
      });
    }
  } catch (e, stackTrace) {
    _logger.severe(
      'Error connecting to AI model: ${e.toString()}',
      e,
      stackTrace,
    );
    setState(() {
      hasError = true;
      statusMessage = 'Error connecting to AI model: ${e.toString()}';
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Text('Health Monitor'),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          _buildAppBarButton(
            Icons.history,
            'History',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HistoryPage(healthHistory: healthHistory),
              ),
            ),
          ),
          _buildAppBarButton(
            Icons.local_hospital,
            'Hospitals',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HospitalsPage()),
            ),
          ),
          _buildAppBarButton(
            Icons.refresh,
            'Refresh',
            isLoading ? null : _fetchData,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E14),
              Color(0xFF1A1F2E),
              Color(0xFF0A0E14),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                if (isLoading)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFF00E5FF)
                                            .withOpacity(0.3),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF00E5FF),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Fetching Health Data...',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.9,
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            children: [
                              HealthCard(
                                title: 'Heart Rate',
                                value:
                                    '${healthData['heart_rate'].toStringAsFixed(1)}',
                                unit: 'BPM',
                                icon: Icons.favorite,
                                color: hasError
                                    ? Colors.grey
                                    : const Color(0xFFFF6B6B),
                              ),
                              HealthCard(
                                title: 'SpO2',
                                value:
                                    '${healthData['spo2'].toStringAsFixed(1)}',
                                unit: '%',
                                icon: Icons.bloodtype,
                                color: hasError
                                    ? Colors.grey
                                    : const Color(0xFF00E5FF),
                              ),
                              HealthCard(
                                title: 'Temperature',
                                value:
                                    '${healthData['temperature'].toStringAsFixed(1)}',
                                unit: '°C',
                                icon: Icons.thermostat,
                                color: hasError
                                    ? Colors.grey
                                    : const Color(0xFFFFB74D),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF1DE9B6).withOpacity(0.15),
                                      const Color(0xFF1DE9B6).withOpacity(0.05),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFF1DE9B6)
                                        .withOpacity(0.2),
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () => _checkForAnomalies(healthData),
                                    child: const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.psychology,
                                            size: 40,
                                            color: Color(0xFF1DE9B6),
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'AI Analysis',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1DE9B6),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Tap to analyze',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        AnimatedBuilder(
                          animation: _statusController,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.all(20.0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: hasError
                                      ? [
                                          Colors.red.withOpacity(0.15),
                                          Colors.red.withOpacity(0.05),
                                        ]
                                      : hasAnomaly
                                          ? [
                                              Colors.orange.withOpacity(0.15),
                                              Colors.orange.withOpacity(0.05),
                                            ]
                                          : [
                                              Colors.green.withOpacity(0.15),
                                              Colors.green.withOpacity(0.05),
                                            ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: hasError
                                      ? Colors.red.withOpacity(0.3)
                                      : hasAnomaly
                                          ? Colors.orange.withOpacity(0.3)
                                          : Colors.green.withOpacity(0.3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (hasError
                                            ? Colors.red
                                            : hasAnomaly
                                                ? Colors.orange
                                                : Colors.green)
                                        .withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Icon(
                                      hasError
                                          ? Icons.error_outline
                                          : hasAnomaly
                                              ? Icons.warning_amber
                                              : Icons.check_circle_outline,
                                      key: ValueKey(hasError
                                          ? 'error'
                                          : hasAnomaly
                                              ? 'anomaly'
                                              : 'normal'),
                                      color: hasError
                                          ? Colors.red
                                          : hasAnomaly
                                              ? Colors.orange
                                              : Colors.green,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hasError
                                              ? 'System Error'
                                              : hasAnomaly
                                                  ? 'Health Alert'
                                                  : 'All Systems Normal',
                                          style: TextStyle(
                                            color: hasError
                                                ? Colors.red
                                                : hasAnomaly
                                                    ? Colors.orange
                                                    : Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          statusMessage,
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            fontSize: 14,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                      children: [
                        TextSpan(text: 'Made by '),
                        TextSpan(
                          text: 'Bhargav and Tathagata',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarButton(
      IconData icon, String tooltip, VoidCallback? onPressed) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.1),
      ),
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: 24,
      ),
    );
  }
}
