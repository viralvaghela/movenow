import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/history_provider.dart';
import '../../domain/history_event.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Activity History",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(historyProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => _showClearDialog(context, ref),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.brightness == Brightness.dark
                    ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: state.events.isEmpty && state.hourlySteps.isEmpty
                      ? _buildEmptyState(context)
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Chart Card
                              if (state.hourlySteps.isNotEmpty) ...[
                                _buildChartCard(context, state.hourlySteps),
                                const SizedBox(height: 24),
                              ],

                              // Analytics Summary Card
                              _buildSummaryCard(context, state.events),
                              const SizedBox(height: 20),

                              // Hotspot Card
                              _buildHotspotCard(context, state.inactivityHotspotText),
                              const SizedBox(height: 28),

                              // Badges and Milestones Section
                              _buildBadgesSection(context, state),
                              const SizedBox(height: 28),

                              // Timeline Header
                              Text(
                                "Timeline Today",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Timeline list
                              _buildTimelineList(context, state.events),
                            ],
                          ),
                        ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 80,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "No activity history yet",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "Walk around to trigger step tracking and records.",
            style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(BuildContext context, List<HourlyStep> hourlySteps) {
    final theme = Theme.of(context);

    // Limit to last 7 data points to fit the screen beautifully
    final displaySteps = hourlySteps.take(7).toList().reversed.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B).withOpacity(0.6)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hourly Steps",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Steps recorded per hour",
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: displaySteps.map((e) => e.steps).fold<int>(100, (maxVal, steps) => steps > maxVal ? steps : maxVal).toDouble() * 1.1,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => theme.brightness == Brightness.dark
                        ? const Color(0xFF334155)
                        : Colors.white,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        "${rod.toY.toInt()} steps",
                        TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= displaySteps.length) {
                          return const SizedBox();
                        }
                        final dateHour = displaySteps[index].dateHour;
                        // Extract hour: "2026-06-19 14" -> "14:00"
                        final parts = dateHour.split(' ');
                        final hour = parts.length > 1 ? "${parts[1]}:00" : "";
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            hour,
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(displaySteps.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: displaySteps[index].steps.toDouble(),
                        color: theme.colorScheme.primary,
                        width: 12,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 10, // Just a placeholder back draw
                          color: theme.brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.black.withOpacity(0.04),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, List<HistoryEvent> events) {
    final theme = Theme.of(context);

    // Sum calculations
    final walkEvents = events.where((e) => e.type == 'walk');
    final totalSteps = walkEvents.fold<int>(0, (sum, e) => sum + e.steps);
    final totalDistance = walkEvents.fold<double>(0.0, (sum, e) => sum + e.distance);
    final totalAlarms = events.where((e) => e.type == 'alarm_trigger').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B).withOpacity(0.6)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Session Summary",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(context, "$totalSteps", "Walk Steps", Colors.purple),
              _buildSummaryItem(
                context,
                totalDistance >= 1000
                    ? "${(totalDistance / 1000).toStringAsFixed(1)} km"
                    : "${totalDistance.toInt()} m",
                "Walk Distance",
                Colors.blue,
              ),
              _buildSummaryItem(context, "$totalAlarms", "Alarms Triggered", Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineList(BuildContext context, List<HistoryEvent> events) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isLast = index == events.length - 1;

        return _buildTimelineItem(context, event, isLast);
      },
    );
  }

  Widget _buildTimelineItem(BuildContext context, HistoryEvent event, bool isLast) {
    final theme = Theme.of(context);
    final String timeStr = DateFormat('hh:mm a').format(event.timestamp);

    Color eventColor;
    IconData eventIcon;
    String eventTitle;
    String eventDesc = event.details;

    switch (event.type) {
      case 'walk':
        eventColor = const Color(0xFF10B981);
        eventIcon = Icons.directions_walk_rounded;
        eventTitle = "Walk Active";
        if (eventDesc.isEmpty) {
          eventDesc = "Completed walk of ${event.steps} steps (${event.distance.toInt()}m) in ${event.durationSeconds}s.";
        }
        break;
      case 'alarm_trigger':
        eventColor = Colors.red;
        eventIcon = Icons.notifications_active_rounded;
        eventTitle = "Alarm Triggered";
        break;
      case 'alarm_dismiss':
        eventColor = Colors.orange;
        eventIcon = Icons.notifications_off_rounded;
        eventTitle = "Alarm Dismissed";
        if (eventDesc.isEmpty) {
          eventDesc = "Alarm stopped after ${event.durationSeconds} seconds.";
        }
        break;
      case 'inactivity':
      default:
        eventColor = Colors.blueGrey;
        eventIcon = Icons.info_outline_rounded;
        eventTitle = "System Event";
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Line & Bullet points
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: eventColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: eventColor.withOpacity(0.3), width: 2),
                ),
                child: Icon(eventIcon, color: eventColor, size: 16),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Event Card details
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF1E293B).withOpacity(0.4)
                    : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.02),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        eventTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: eventColor,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    eventDesc,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear History"),
        content: const Text("Are you sure you want to delete all activity logs and timeline history? This action is permanent."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              ref.read(historyProvider.notifier).clearHistory();
              Navigator.pop(context);
            },
            child: const Text("Clear All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildHotspotCard(BuildContext context, String hotspotText) {
    final theme = Theme.of(context);
    final isNoHotspot = hotspotText.contains("No inactivity hotspots");
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNoHotspot 
            ? theme.colorScheme.primary.withOpacity(0.08) 
            : Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNoHotspot 
              ? theme.colorScheme.primary.withOpacity(0.2) 
              : Colors.orange.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isNoHotspot ? Icons.lightbulb_outline_rounded : Icons.warning_amber_rounded,
            color: isNoHotspot ? theme.colorScheme.primary : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNoHotspot ? "Habit Tip" : "Inactivity Hotspot Alert",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isNoHotspot ? theme.colorScheme.primary : Colors.orange[850],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hotspotText,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(BuildContext context, HistoryState state) {
    final theme = Theme.of(context);
    
    final badges = [
      _BadgeItem(
        title: "Chair Dodger",
        description: "Disrupted sitting 5 times in a single day",
        icon: Icons.run_circle_outlined,
        color: Colors.green,
        isUnlocked: state.isChairDodger,
      ),
      _BadgeItem(
        title: "Active Legend",
        description: "Maintained a 14-day tracking streak",
        icon: Icons.workspace_premium_outlined,
        color: Colors.amber,
        isUnlocked: state.isActiveLegend,
      ),
      _BadgeItem(
        title: "Night Owl",
        description: "Dismissed an alarm during evening hours",
        icon: Icons.nights_stay_outlined,
        color: Colors.indigo,
        isUnlocked: state.isNightOwl,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Badges & Milestones",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "${badges.where((b) => b.isUnlocked).length} / ${badges.length} Unlocked",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: badges.length,
          itemBuilder: (context, idx) {
            final badge = badges[idx];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: badge.isUnlocked 
                    ? badge.color.withOpacity(0.08) 
                    : theme.brightness == Brightness.dark 
                        ? Colors.white.withOpacity(0.02) 
                        : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: badge.isUnlocked 
                      ? badge.color.withOpacity(0.2) 
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: badge.isUnlocked 
                          ? badge.color.withOpacity(0.12) 
                          : Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      badge.icon,
                      color: badge.isUnlocked ? badge.color : Colors.grey,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    badge.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: badge.isUnlocked 
                          ? theme.textTheme.bodyLarge?.color 
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge.description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BadgeItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;

  _BadgeItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
  });
}
