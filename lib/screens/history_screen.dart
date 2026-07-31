import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/workout_session.dart';
import '../models/workout_set.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050A0F),
        foregroundColor: const Color(0xFFEAF2F4),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'History',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<Box<WorkoutSession>>(
          valueListenable: Hive.box<WorkoutSession>('workout_sessions').listenable(),
          builder: (context, sessionBox, _) {
            final sessions = sessionBox.values.toList()
              ..sort((a, b) => b.date.compareTo(a.date));

            if (sessions.isEmpty) {
              return const _EmptyHistory();
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _HistorySessionCard(session: sessions[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.24),
                ),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFF7DD3FC),
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Noch keine History',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFEAF2F4),
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sobald du ein Workout abschliesst, wird es hier gespeichert.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8A93A3),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySessionCard extends StatelessWidget {
  const _HistorySessionCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final title = session.dayName.trim().isEmpty ? 'Workout' : session.dayName.trim();
    final subtitleParts = <String>[
      _formatDate(session.date),
      if (session.workoutPlanName.trim().isNotEmpty) session.workoutPlanName.trim(),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF09131B),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.06),
            blurRadius: 24,
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: const Color(0xFF7DD3FC),
          collapsedIconColor: const Color(0xFF7DD3FC),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
              ),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Color(0xFF7DD3FC),
            ),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFEAF2F4),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitleParts.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8A93A3),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${session.totalSets} Sätze',
                style: const TextStyle(
                  color: Color(0xFFEAF2F4),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${session.totalReps} Wdh.',
                style: const TextStyle(
                  color: Color(0xFF8A93A3),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          children: [
            _HistoryStatsRow(session: session),
            const SizedBox(height: 12),
            for (final entry in session.exerciseSets.entries) ...[
              _ExerciseHistoryRow(
                name: session.exerciseNameFor(entry.key),
                sets: entry.value,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryStatsRow extends StatelessWidget {
  const _HistoryStatsRow({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SmallStat(label: 'Sätze', value: '${session.totalSets}'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SmallStat(label: 'Wdh.', value: '${session.totalReps}'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SmallStat(label: 'Volumen', value: _formatVolume(session.totalVolume)),
        ),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF050A0F),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8A93A3),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFEAF2F4),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseHistoryRow extends StatelessWidget {
  const _ExerciseHistoryRow({required this.name, required this.sets});

  final String name;
  final List<WorkoutSet> sets;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF050A0F),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFFEAF2F4),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (var index = 0; index < sets.length; index++)
                _SetChip(
                  setNumber: index + 1,
                  set: sets[index],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetChip extends StatelessWidget {
  const _SetChip({required this.setNumber, required this.set});

  final int setNumber;
  final WorkoutSet set;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        '$setNumber: ${set.reps} x ${_formatWeight(set.weight)}',
        style: const TextStyle(
          color: Color(0xFF7DD3FC),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString().padLeft(4, '0');
  return '$day.$month.$year';
}

String _formatWeight(double weight) {
  if (weight <= 0) {
    return 'Bodyweight';
  }

  final rounded = weight.roundToDouble();

  if (rounded == weight) {
    return '${rounded.toInt()} kg';
  }

  return '${weight.toStringAsFixed(1)} kg';
}

String _formatVolume(double volume) {
  if (volume <= 0) {
    return 'BW';
  }

  final rounded = volume.roundToDouble();

  if (rounded == volume) {
    return '${rounded.toInt()} kg';
  }

  return '${volume.toStringAsFixed(1)} kg';
}
