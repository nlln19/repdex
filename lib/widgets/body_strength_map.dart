import 'package:bodychart_heatmap/bodychart_heatmap.dart';
import 'package:flutter/material.dart';

class BodyStrengthMap extends StatelessWidget {
  const BodyStrengthMap({
    super.key,
    required this.trainedMuscleGroups,
    required this.highlightFullBody,
  });

  final Set<String> trainedMuscleGroups;
  final bool highlightFullBody;

  static const double _bodyWidth = 315;

  static const Set<String> _allBodyParts = {
    'neck',
    'shoulder',
    'chest',
    'arm',
    'abs',
    'back',
    'butt',
    'leg',
  };

  @override
  Widget build(BuildContext context) {
    final selectedParts = highlightFullBody
        ? _allBodyParts
        : _selectedBodyPartsFromMuscleGroups();

    final hasFocus = selectedParts.isNotEmpty;

    return Container(
      width: double.infinity,
      height: 380,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF061018),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.14),
            blurRadius: 34,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CyberGridPainter(
                  glowEnabled: hasFocus,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.9,
                    colors: [
                      const Color(0xFF00E5FF).withOpacity(
                        hasFocus ? 0.18 : 0.08,
                      ),
                      const Color(0xFF071018).withOpacity(0.30),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: _bodyWidth,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Basis-Layer:
                // Alle Körperteile dunkel, Kopf bleibt durch unselectedColor schwarz.
                BodyChart(
                  selectedParts: _allBodyParts,
                  selectedColor: const Color(0xFF111A24),
                  unselectedColor: const Color(0xFF050A0F),
                  viewType: BodyViewType.both,
                  width: _bodyWidth,
                ),

                // Fokus-Layer:
                // Heute trainierte Muskelgruppen leuchten blau.
                if (selectedParts.isNotEmpty)
                  BodyChart(
                    selectedParts: selectedParts,
                    selectedColor: const Color(0xFF00E5FF),
                    unselectedColor: Colors.transparent,
                    viewType: BodyViewType.both,
                    width: _bodyWidth,
                  ),

                if (selectedParts.isNotEmpty)
                  IgnorePointer(
                    child: Container(
                      width: _bodyWidth * 0.95,
                      height: _bodyWidth * 1.35,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.28),
                            blurRadius: highlightFullBody ? 58 : 44,
                            spreadRadius: highlightFullBody ? 8 : 4,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Set<String> _selectedBodyPartsFromMuscleGroups() {
    final selectedParts = <String>{};

    for (final muscleGroup in trainedMuscleGroups) {
      selectedParts.addAll(_bodyPartsForMuscleGroup(muscleGroup));
    }

    return selectedParts;
  }

  Set<String> _bodyPartsForMuscleGroup(String muscleGroup) {
    final normalized = _normalize(muscleGroup);

    if (normalized.contains('full') ||
        normalized.contains('fullbody') ||
        normalized.contains('ganzkoerper') ||
        normalized.contains('ganzkörper')) {
      return _allBodyParts;
    }

    if (normalized.contains('push')) {
      return {'chest', 'shoulder', 'arm'};
    }

    if (normalized.contains('pull')) {
      return {'back', 'arm'};
    }

    if (normalized.contains('upper') ||
        normalized.contains('oberkoerper') ||
        normalized.contains('oberkörper')) {
      return {'shoulder', 'chest', 'arm', 'abs', 'back'};
    }

    if (normalized.contains('lower') ||
        normalized.contains('unterkoerper') ||
        normalized.contains('unterkörper')) {
      return {'leg', 'butt'};
    }

    if (normalized.contains('chest') ||
        normalized.contains('brust') ||
        normalized.contains('pec')) {
      return {'chest'};
    }

    if (normalized.contains('back') ||
        normalized.contains('ruecken') ||
        normalized.contains('rucken') ||
        normalized.contains('rücken') ||
        normalized.contains('lat') ||
        normalized.contains('trapezius')) {
      return {'back'};
    }

    if (normalized.contains('shoulder') ||
        normalized.contains('shoulders') ||
        normalized.contains('schulter') ||
        normalized.contains('schultern') ||
        normalized.contains('delt')) {
      return {'shoulder'};
    }

    if (normalized.contains('arm') ||
        normalized.contains('arme') ||
        normalized.contains('biceps') ||
        normalized.contains('bizeps') ||
        normalized.contains('triceps') ||
        normalized.contains('trizeps') ||
        normalized.contains('forearm') ||
        normalized.contains('unterarm')) {
      return {'arm'};
    }

    if (normalized.contains('abs') ||
        normalized.contains('core') ||
        normalized.contains('bauch') ||
        normalized.contains('oblique')) {
      return {'abs'};
    }

    if (normalized.contains('glute') ||
        normalized.contains('butt') ||
        normalized.contains('po')) {
      return {'butt'};
    }

    if (normalized.contains('leg') ||
        normalized.contains('legs') ||
        normalized.contains('bein') ||
        normalized.contains('beine') ||
        normalized.contains('quad') ||
        normalized.contains('quadrizeps') ||
        normalized.contains('hamstring') ||
        normalized.contains('adductor') ||
        normalized.contains('adduktor') ||
        normalized.contains('calf') ||
        normalized.contains('wade') ||
        normalized.contains('waden')) {
      return {'leg'};
    }

    if (normalized.contains('neck') || normalized.contains('nacken')) {
      return {'neck'};
    }

    return {};
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll('/', ' ');
  }
}

class _CyberGridPainter extends CustomPainter {
  const _CyberGridPainter({
    required this.glowEnabled,
  });

  final bool glowEnabled;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.052)
      ..strokeWidth = 1;

    const spacing = 26.0;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final center = Offset(size.width / 2, size.height / 2);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5FF).withOpacity(glowEnabled ? 0.22 : 0.08),
          const Color(0xFF00E5FF).withOpacity(glowEnabled ? 0.05 : 0.02),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: size.width * 0.58,
        ),
      );

    canvas.drawCircle(
      center,
      size.width * 0.58,
      glowPaint,
    );

    final scanLinePaint = Paint()
      ..color = const Color(0xFF7DD3FC).withOpacity(0.06)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(0, size.height * 0.48),
      Offset(size.width, size.height * 0.48),
      scanLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) {
    return oldDelegate.glowEnabled != glowEnabled;
  }
}