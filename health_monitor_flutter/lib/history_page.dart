// Complete updated history_page.dart - FULL FILE
import 'package:flutter/material.dart';
import 'models/health_data.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'graph_page.dart';
import 'hospitals_page.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  final List<HealthData> healthHistory;

  const HistoryPage({super.key, required this.healthHistory});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  bool showOnlyAnomalies = false;
  String searchQuery = '';
  String selectedTimeRange = 'All';
  String selectedRiskLevel = 'All';
  
  final List<String> timeRanges = [
    'All',
    'Today',
    'Last 7 Days',
    'Last 30 Days'
  ];
  
  final List<String> riskLevels = [
    'All',
    'Critical',
    'Moderate',
    'Low',
    'Unknown'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<HealthData> get filteredHistory {
    var filtered = widget.healthHistory;

    if (showOnlyAnomalies) {
      filtered = filtered.where((data) => data.hasAnomaly).toList();
    }

    if (selectedRiskLevel != 'All') {
      filtered = filtered.where((data) => data.riskLevel == selectedRiskLevel).toList();
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((data) {
        final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(data.timestamp);
        return dateStr.toLowerCase().contains(searchQuery.toLowerCase()) ||
               (data.aiResult?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
               (data.recommendation?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    final now = DateTime.now();
    switch (selectedTimeRange) {
      case 'Today':
        filtered = filtered
            .where((data) =>
                data.timestamp.year == now.year &&
                data.timestamp.month == now.month &&
                data.timestamp.day == now.day)
            .toList();
        break;
      case 'Last 7 Days':
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        filtered = filtered
            .where((data) => data.timestamp.isAfter(sevenDaysAgo))
            .toList();
        break;
      case 'Last 30 Days':
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        filtered = filtered
            .where((data) => data.timestamp.isAfter(thirtyDaysAgo))
            .toList();
        break;
    }

    return filtered;
  }

  Map<String, int> get statisticsSummary {
    final filtered = filteredHistory;
    return {
      'total': filtered.length,
      'anomalies': filtered.where((d) => d.hasAnomaly).length,
      'critical': filtered.where((d) => d.riskLevel == 'Critical').length,
      'moderate': filtered.where((d) => d.riskLevel == 'Moderate').length,
      'low': filtered.where((d) => d.riskLevel == 'Low').length,
      'normal': filtered.where((d) => !d.hasAnomaly).length,
    };
  }

  Future<void> _downloadCSV(BuildContext context) async {
    if (filteredHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      final StringBuffer csvBuffer = StringBuffer();
      csvBuffer.writeln('Timestamp,Heart Rate (bpm),SpO2 (%),Temperature (°C),Has Anomaly,AI Result,Confidence (%),Risk Level,Urgency,Recommendation,Normal Probability,Anomaly Probability');
      
      for (final data in filteredHistory) {
        csvBuffer.writeln(
          '${data.timestamp.toIso8601String()},'
          '${data.heartRate},'
          '${data.spo2},'
          '${data.temperature},'
          '${data.hasAnomaly ? 'Yes' : 'No'},'
          '"${data.aiResult ?? 'N/A'}",'
          '${data.confidence != null ? (data.confidence! * 100).toStringAsFixed(1) : 'N/A'},'
          '${data.riskLevel},'
          '${data.urgencyLevel ?? 'N/A'},'
          '"${data.recommendation?.replaceAll('"', '""') ?? 'N/A'}",'
          '${data.normalProbability?.toStringAsFixed(3) ?? 'N/A'},'
          '${data.anomalyProbability?.toStringAsFixed(3) ?? 'N/A'}',
        );
      }
      
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/ai_health_history_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csvBuffer.toString());
      
      await Share.shareFiles(
        [path], 
        text: 'AI Health Analysis History - ${filteredHistory.length} records',
        subject: 'Medical AI Analysis Export',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${filteredHistory.length} records'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearAllData() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1F2E),
          title: const Text(
            'Clear All Data',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete all health history? This action cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.healthHistory.clear();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All health data cleared'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Clear All', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Text('History'),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.1),
            ),
            child: IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export CSV',
              onPressed: () => _downloadCSV(context),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.1),
            ),
            child: IconButton(
              icon: const Icon(Icons.show_chart),
              tooltip: 'View Graphs',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GraphPage(healthHistory: filteredHistory),
                  ),
                );
              },
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'clear_all':
                  _clearAllData();
                  break;
                case 'hospitals':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HospitalsPage(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'hospitals',
                child: Row(
                  children: [
                    Icon(Icons.local_hospital, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Find Hospitals'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All Data'),
                  ],
                ),
              ),
            ],
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
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    
                    // Filter Controls
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F2E),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Search Field
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search by date, AI result, or recommendation...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                            ),
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Time Range Filter
                          Row(
                            children: [
                              const Icon(Icons.access_time, color: Color(0xFF00E5FF), size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Time Range:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: timeRanges.map((range) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ChoiceChip(
                                          label: Text(
                                            range,
                                            style: TextStyle(
                                              color: selectedTimeRange == range
                                                  ? Colors.black
                                                  : Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          selected: selectedTimeRange == range,
                                          selectedColor: const Color(0xFF00E5FF),
                                          backgroundColor: const Color(0xFF2A2F3E),
                                          onSelected: (selected) {
                                            setState(() {
                                              selectedTimeRange = range;
                                            });
                                          },
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Risk Level Filter
                          Row(
                            children: [
                              const Icon(Icons.security, color: Color(0xFF00E5FF), size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Risk Level:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: riskLevels.map((level) {
                                      Color chipColor = Colors.grey;
                                      switch (level) {
                                        case 'Critical':
                                          chipColor = Colors.red;
                                          break;
                                        case 'Moderate':
                                          chipColor = Colors.orange;
                                          break;
                                        case 'Low':
                                          chipColor = Colors.green;
                                          break;
                                      }
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ChoiceChip(
                                          label: Text(
                                            level,
                                            style: TextStyle(
                                              color: selectedRiskLevel == level
                                                  ? Colors.white
                                                  : Colors.white70,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          selected: selectedRiskLevel == level,
                                          selectedColor: chipColor,
                                          backgroundColor: const Color(0xFF2A2F3E),
                                          onSelected: (selected) {
                                            setState(() {
                                              selectedRiskLevel = level;
                                            });
                                          },
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Anomaly Toggle
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2F3E),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.filter_alt,
                                  color: Color(0xFF00E5FF),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Show only anomalies:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: showOnlyAnomalies,
                                  onChanged: (value) {
                                    setState(() {
                                      showOnlyAnomalies = value;
                                    });
                                  },
                                  activeColor: const Color(0xFF00E5FF),
                                  inactiveTrackColor: Colors.grey[700],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Statistics Summary
                    if (filteredHistory.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.analytics, color: Color(0xFF00E5FF)),
                                SizedBox(width: 8),
                                Text(
                                  'Analysis Summary',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatCard(
                                  'Total',
                                  statisticsSummary['total'].toString(),
                                  Icons.timeline,
                                  Colors.blue,
                                ),
                                _buildStatCard(
                                  'Anomalies',
                                  statisticsSummary['anomalies'].toString(),
                                  Icons.warning,
                                  Colors.red,
                                ),
                                _buildStatCard(
                                  'Critical',
                                  statisticsSummary['critical'].toString(),
                                  Icons.emergency,
                                  Colors.red,
                                ),
                                _buildStatCard(
                                  'Normal',
                                  statisticsSummary['normal'].toString(),
                                  Icons.check_circle,
                                  Colors.green,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (statisticsSummary['total']! > 0)
                              Center(
                                child: Text(
                                  'Anomaly Rate: ${((statisticsSummary['anomalies']! / statisticsSummary['total']!) * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: statisticsSummary['anomalies']! > 0 ? Colors.orange : Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // History List
                    Expanded(
                      child: filteredHistory.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[800]?.withOpacity(0.3),
                                    ),
                                    child: Icon(
                                      searchQuery.isNotEmpty || selectedTimeRange != 'All' || selectedRiskLevel != 'All' || showOnlyAnomalies
                                          ? Icons.search_off
                                          : Icons.history,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    searchQuery.isNotEmpty || selectedTimeRange != 'All' || selectedRiskLevel != 'All' || showOnlyAnomalies
                                        ? 'No matching records found'
                                        : 'No history available',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.grey[400],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    searchQuery.isNotEmpty || selectedTimeRange != 'All' || selectedRiskLevel != 'All' || showOnlyAnomalies
                                        ? 'Try adjusting your filters'
                                        : 'AI analysis data will appear here once collected',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (searchQuery.isNotEmpty || selectedTimeRange != 'All' || selectedRiskLevel != 'All' || showOnlyAnomalies) ...[
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          searchQuery = '';
                                          selectedTimeRange = 'All';
                                          selectedRiskLevel = 'All';
                                          showOnlyAnomalies = false;
                                        });
                                      },
                                      icon: const Icon(Icons.clear_all),
                                      label: const Text('Clear Filters'),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredHistory.length,
                              itemBuilder: (context, index) {
                                final data = filteredHistory[index];
                                return _buildHistoryCard(data, index);
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(HealthData data, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A1F2E),
                    const Color(0xFF2A2F3E),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: data.riskColor.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(
                  color: data.riskColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _showDetailedView(data),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(data.timestamp),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('HH:mm:ss').format(data.timestamp),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    data.riskColor.withOpacity(0.2),
                                    data.riskColor.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: data.riskColor.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    data.hasAnomaly ? Icons.warning : Icons.check_circle,
                                    color: data.riskColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    data.riskLevel,
                                    style: TextStyle(
                                      color: data.riskColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        // AI Analysis Section
                        if (data.aiResult != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2F3E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.psychology,
                                      color: data.riskColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'AI Analysis: ${data.aiResult}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: data.riskColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (data.confidence != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'Confidence: ${(data.confidence! * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: data.confidence,
                                          backgroundColor: Colors.grey[700],
                                          valueColor: AlwaysStoppedAnimation<Color>(data.riskColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (data.recommendation != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: data.riskColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: data.riskColor.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.lightbulb_outline,
                                          color: data.riskColor,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            data.recommendation!,
                                            style: TextStyle(
                                              color: data.riskColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        
                        // Vital Signs Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMetricColumn(
                              'Heart Rate',
                              '${data.heartRate.toStringAsFixed(1)}',
                              'bpm',
                              const Color(0xFFFF6B6B),
                              data.isHeartRateNormal,
                            ),
                            _buildMetricColumn(
                              'SpO2',
                              '${data.spo2.toStringAsFixed(1)}',
                              '%',
                              const Color(0xFF00E5FF),
                              data.isSpO2Normal,
                            ),
                            _buildMetricColumn(
                              'Temperature',
                              '${data.temperature.toStringAsFixed(1)}',
                              '°C',
                              const Color(0xFFFFB74D),
                              data.isTemperatureNormal,
                            ),
                          ],
                        ),
                        
                        // Probability Bars (if available)
                        if (data.normalProbability != null && data.anomalyProbability != null) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'AI Probability Breakdown:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildProbabilityRow('Normal', data.normalProbability!, Colors.green),
                          const SizedBox(height: 4),
                          _buildProbabilityRow('Anomaly', data.anomalyProbability!, Colors.red),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricColumn(String label, String value, String unit, Color color, bool isNormal) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isNormal ? Icons.check_circle : Icons.warning,
              size: 12,
              color: isNormal ? Colors.green : Colors.orange,
            ),
          ],
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProbabilityRow(String label, double probability, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: probability,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${(probability * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _showDetailedView(HealthData data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: data.riskColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    data.hasAnomaly ? Icons.warning : Icons.check_circle,
                    color: data.riskColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detailed AI Analysis',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMMM yyyy, HH:mm:ss').format(data.timestamp),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Vital Signs Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2F3E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vital Signs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Heart Rate', '${data.heartRate.toStringAsFixed(1)} bpm', 
                      color: const Color(0xFFFF6B6B), isNormal: data.isHeartRateNormal),
                  _buildDetailRow('SpO2', '${data.spo2.toStringAsFixed(1)}%', 
                      color: const Color(0xFF00E5FF), isNormal: data.isSpO2Normal),
                  _buildDetailRow('Temperature', '${data.temperature.toStringAsFixed(2)}°C', 
                      color: const Color(0xFFFFB74D), isNormal: data.isTemperatureNormal),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // AI Analysis Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2F3E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology, color: data.riskColor, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'AI Analysis Results',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('AI Result', data.aiResult ?? 'N/A', color: data.riskColor),
                  _buildDetailRow('Risk Level', data.riskLevel, color: data.riskColor),
                  if (data.confidence != null)
                    _buildDetailRow('AI Confidence', '${(data.confidence! * 100).toStringAsFixed(1)}%', color: data.riskColor),
                  if (data.urgencyLevel != null)
                    _buildDetailRow('Urgency Level', data.urgencyLevel!, color: data.riskColor),
                ],
              ),
            ),
            
            // Probability Breakdown
            if (data.normalProbability != null && data.anomalyProbability != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2F3E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Probability Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildProbabilityBar('Normal', data.normalProbability!, Colors.green),
                    const SizedBox(height: 8),
                    _buildProbabilityBar('Anomaly', data.anomalyProbability!, Colors.red),
                  ],
                ),
              ),
            ],
            
            // Recommendation Section
            if (data.recommendation != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: data.riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: data.riskColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: data.riskColor, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'AI Recommendation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.recommendation!,
                      style: TextStyle(
                        fontSize: 16,
                        color: data.riskColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Action Buttons for Critical Cases
            if (data.hasAnomaly && data.riskLevel == 'Critical') ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emergency, color: Colors.red, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'Critical Alert - Immediate Action Required',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const HospitalsPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.local_hospital),
                            label: const Text('Find Hospital'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Add emergency call functionality if needed
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Emergency services: Call 911 or local emergency number'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            },
                            icon: const Icon(Icons.call),
                            label: const Text('Emergency'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color, bool? isNormal}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isNormal != null) ...[
                Icon(
                  isNormal ? Icons.check_circle : Icons.warning,
                  size: 16,
                  color: isNormal ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color ?? Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilityBar(String label, double probability, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Text(
              '${(probability * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: probability,
          backgroundColor: Colors.grey[700],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}