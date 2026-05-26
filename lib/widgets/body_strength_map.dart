import 'package:bodychart_heatmap/bodychart_heatmap.dart';
import 'package:flutter/material.dart';

class BodyStrengthMap extends StatelessWidget {
  const BodyStrengthMap({
    super.key,
    required this.trainedMuscleGroups,
    required this.highlightFullBody,
    this.isDepleted = false,
  });

  final Set<String> trainedMuscleGroups;
  final bool highlightFullBody;
  final bool isDepleted;

  static const double _singleBodyWidth = 148;

  static const Set<String> _allFrontBodyParts = {
    'neck',
    'shoulder',
    'chest',
    'arm',
    'abs',
    'leg',
  };

  static const Set<String> _allBackBodyParts = {
    'neck',
    'shoulder',
    'back',
    'arm',
    'butt',
    'leg',
  };

  @override
  Widget build(BuildContext context) {
    final selection = highlightFullBody
        ? const _BodyPartSelection(
            frontParts: _allFrontBodyParts,
            backParts: _allBackBodyParts,
          )
        : _selectedBodyPartsFromMuscleGroups();

    final hasFocus = selection.hasFocus;
    final activeColor = isDepleted
        ? const Color(0xFFFF3B30)
        : const Color(0xFF00E5FF);
    final softActiveColor = isDepleted
        ? const Color(0xFFFF6B5F)
        : const Color(0xFF00E5FF);

    return Container(
      width: double.infinity,
      height: 380,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF061018),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.14),
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
                  glowColor: activeColor,
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
                      activeColor.withValues(
                        alpha: hasFocus ? 0.18 : 0.08,
                      ),
                      const Color(0xFF071018).withValues(alpha: 0.30),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BodySideChart(
                viewType: BodyViewType.front,
                baseParts: _allFrontBodyParts,
                selectedParts: selection.frontParts,
                width: _singleBodyWidth,
                activeColor: activeColor,
                softActiveColor: softActiveColor,
              ),
              const SizedBox(width: 8),
              _BodySideChart(
                viewType: BodyViewType.back,
                baseParts: _allBackBodyParts,
                selectedParts: selection.backParts,
                width: _singleBodyWidth,
                activeColor: activeColor,
                softActiveColor: softActiveColor,
              ),
            ],
          ),
          if (hasFocus)
            IgnorePointer(
              child: Container(
                width: _singleBodyWidth * 2.15,
                height: _singleBodyWidth * 1.95,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: softActiveColor.withValues(alpha: 0.28),
                      blurRadius: highlightFullBody ? 58 : 44,
                      spreadRadius: highlightFullBody ? 8 : 4,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  _BodyPartSelection _selectedBodyPartsFromMuscleGroups() {
    final frontParts = <String>{};
    final backParts = <String>{};
    for (final muscleGroup in trainedMuscleGroups) {
      final selection = _bodyPartsForMuscleGroup(muscleGroup);
      frontParts.addAll(selection.frontParts);
      backParts.addAll(selection.backParts);
    }

    return _BodyPartSelection(
      frontParts: frontParts,
      backParts: backParts,
    );
  }

  _BodyPartSelection _bodyPartsForMuscleGroup(String muscleGroup) {
    final normalized = _normalize(muscleGroup);

    if (normalized.contains('full') ||
        normalized.contains('fullbody') ||
        normalized.contains('ganzkoerper') ||
        normalized.contains('ganzkörper')) {
      return const _BodyPartSelection(
        frontParts: _allFrontBodyParts,
        backParts: _allBackBodyParts,
      );
    }

    if (normalized.contains('push')) {
      return const _BodyPartSelection(
        frontParts: {'chest', 'shoulder'},
        backParts: {'arm'},
      );
    }

    if (normalized.contains('pull')) {
      return const _BodyPartSelection(
        frontParts: {'arm'},
        backParts: {'back'},
      );
    }

    if (normalized.contains('upper') ||
        normalized.contains('oberkoerper') ||
        normalized.contains('oberkörper')) {
      return const _BodyPartSelection(
        frontParts: {'shoulder', 'chest', 'arm', 'abs'},
        backParts: {'shoulder', 'back', 'arm'},
      );
    }

    if (normalized.contains('lower') ||
        normalized.contains('unterkoerper') ||
        normalized.contains('unterkörper')) {
      return const _BodyPartSelection(
        frontParts: {'leg'},
        backParts: {'leg', 'butt'},
      );
    }

    if (normalized.contains('chest') ||
        normalized.contains('brust') ||
        normalized.contains('pec')) {
      return const _BodyPartSelection(frontParts: {'chest'});
    }

    if (normalized.contains('back') ||
        normalized.contains('ruecken') ||
        normalized.contains('rucken') ||
        normalized.contains('rücken') ||
        normalized.contains('lat') ||
        normalized.contains('trapezius')) {
      return const _BodyPartSelection(backParts: {'back'});
    }

    if (normalized.contains('shoulder') ||
        normalized.contains('shoulders') ||
        normalized.contains('schulter') ||
        normalized.contains('schultern') ||
        normalized.contains('delt')) {
      return const _BodyPartSelection(
        frontParts: {'shoulder'},
        backParts: {'shoulder'},
      );
    }

    if (normalized.contains('biceps') || normalized.contains('bizeps')) {
      return const _BodyPartSelection(frontParts: {'arm'});
    }

    if (normalized.contains('triceps') || normalized.contains('trizeps')) {
      return const _BodyPartSelection(backParts: {'arm'});
    }

    if (normalized.contains('forearm') || normalized.contains('unterarm')) {
      return const _BodyPartSelection();
    }

    if (normalized.contains('arm') || normalized.contains('arme')) {
      return const _BodyPartSelection(
        frontParts: {'arm'},
        backParts: {'arm'},
      );
    }

    if (normalized.contains('abs') ||
        normalized.contains('core') ||
        normalized.contains('bauch') ||
        normalized.contains('oblique')) {
      return const _BodyPartSelection(frontParts: {'abs'});
    }

    if (normalized.contains('glute') ||
        normalized.contains('butt') ||
        normalized.contains('po')) {
      return const _BodyPartSelection(backParts: {'butt'});
    }

    if (normalized.contains('quad') || normalized.contains('quadrizeps')) {
      return const _BodyPartSelection(frontParts: {'leg'});
    }

    if (normalized.contains('hamstring')) {
      return const _BodyPartSelection(backParts: {'leg'});
    }

    if (normalized.contains('adductor') || normalized.contains('adduktor')) {
      return const _BodyPartSelection(frontParts: {'leg'});
    }

    if (normalized.contains('calf') ||
        normalized.contains('wade') ||
        normalized.contains('waden')) {
      return const _BodyPartSelection(backParts: {'leg'});
    }

    if (normalized.contains('leg') ||
        normalized.contains('legs') ||
        normalized.contains('bein') ||
        normalized.contains('beine')) {
      return const _BodyPartSelection(
        frontParts: {'leg'},
        backParts: {'leg'},
      );
    }

    if (normalized.contains('neck') || normalized.contains('nacken')) {
      return const _BodyPartSelection(
        frontParts: {'neck'},
        backParts: {'neck'},
      );
    }

    return const _BodyPartSelection();
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

class _BodySideChart extends StatelessWidget {
  const _BodySideChart({
    required this.viewType,
    required this.baseParts,
    required this.selectedParts,
    required this.width,
    required this.activeColor,
    required this.softActiveColor,
  });

  final BodyViewType viewType;
  final Set<String> baseParts;
  final Set<String> selectedParts;
  final double width;
  final Color activeColor;
  final Color softActiveColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Stack(
        alignment: Alignment.center,
        children: [
          BodyChart(
            selectedParts: baseParts,
            selectedColor: const Color(0xFF111A24),
            unselectedColor: const Color(0xFF050A0F),
            viewType: viewType,
            width: width,
          ),
          if (selectedParts.isNotEmpty)
            BodyChart(
              selectedParts: selectedParts,
              selectedColor: activeColor,
              unselectedColor: Colors.transparent,
              viewType: viewType,
              width: width,
            ),
        ],
      ),
    );
  }
}

class _BodyPartSelection {
  const _BodyPartSelection({
    this.frontParts = const <String>{},
    this.backParts = const <String>{},
  });

  final Set<String> frontParts;
  final Set<String> backParts;
  bool get hasFocus => frontParts.isNotEmpty || backParts.isNotEmpty;
}


class _CyberGridPainter extends CustomPainter {
  const _CyberGridPainter({
    required this.glowEnabled,
    required this.glowColor,
  });

  final bool glowEnabled;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.052)
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
          glowColor.withValues(alpha: glowEnabled ? 0.22 : 0.08),
          glowColor.withValues(alpha: glowEnabled ? 0.05 : 0.02),
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
      ..color = glowColor.withValues(alpha: 0.10)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(0, size.height * 0.48),
      Offset(size.width, size.height * 0.48),
      scanLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) {
    return oldDelegate.glowEnabled != glowEnabled ||
        oldDelegate.glowColor != glowColor;
  }
}