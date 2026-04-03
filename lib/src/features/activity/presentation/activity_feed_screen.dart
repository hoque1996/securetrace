import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/activity_repository.dart';
import '../domain/activity_event.dart';

class ActivityFeedScreen extends ConsumerWidget {
  const ActivityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI ACTIVITY FEED')),
      body: activityAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No recent activity detected.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (context, index) => const Divider(height: 32, color: Colors.white10),
            itemBuilder: (context, index) {
              final event = events[index];
              return _buildActivityItem(event);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildActivityItem(ActivityEvent event) {
    IconData icon;
    Color color;

    switch (event.type) {
      case ActivityType.alert:
        icon = Icons.warning_amber_rounded;
        color = Colors.redAccent;
        break;
      case ActivityType.backup:
        icon = Icons.cloud_done;
        color = Colors.blueAccent;
        break;
      case ActivityType.location:
        icon = Icons.location_on;
        color = Colors.greenAccent;
        break;
      case ActivityType.connection:
        icon = Icons.phonelink_setup;
        color = Colors.cyanAccent;
        break;
      default:
        icon = Icons.security;
        color = Colors.white70;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    DateFormat('HH:mm').format(event.timestamp),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(event.message, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }
}
