// Widgets d'habillage purement esthétiques (dégradé, filigrane, badges, avatars).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Fond en dégradé avec un filigrane maçonnique discret (équerre, compas,
/// étoile flamboyante). Aucune interaction : uniquement décoratif.
class BrBackground extends StatelessWidget {
  final Widget child;
  const BrBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: BrColors.backgroundGradient),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _WatermarkPainter()),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Halo doré très discret en haut de l'écran.
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          BrColors.gold.withValues(alpha: 0.10),
          BrColors.gold.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.06),
          radius: size.width * 0.85,
        ),
      );
    canvas.drawRect(Offset.zero & size, halo);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = BrColors.goldBright.withValues(alpha: 0.05);

    final center = Offset(size.width * 0.5, size.height * 0.52);
    final radius = math.min(size.width, size.height) * 0.32;

    // Cercle et étoile à cinq branches (filigrane).
    canvas.drawCircle(center, radius, stroke);
    final star = Path();
    for (var i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + i * 4 * math.pi / 5;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, stroke);

    // Équerre et compas stylisés.
    final compass = Path()
      ..moveTo(center.dx - radius * 0.55, center.dy + radius * 0.5)
      ..lineTo(center.dx, center.dy - radius * 0.6)
      ..lineTo(center.dx + radius * 0.55, center.dy + radius * 0.5);
    canvas.drawPath(compass, stroke);
    final square = Path()
      ..moveTo(center.dx - radius * 0.6, center.dy - radius * 0.15)
      ..lineTo(center.dx, center.dy + radius * 0.55)
      ..lineTo(center.dx + radius * 0.6, center.dy - radius * 0.15);
    canvas.drawPath(square, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Carte contrastée : coins arrondis, dégradé léger, ombre douce et bordure
/// dorée subtile. Purement visuel, ne modifie pas le comportement de l'enfant.
class BrCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;
  const BrCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = (accent ?? BrColors.gold).withValues(alpha: 0.28);
    final decorated = Container(
      decoration: BoxDecoration(
        gradient: BrColors.cardGradient,
        borderRadius: BorderRadius.circular(BrColors.radiusM),
        border: Border.all(color: borderColor),
        boxShadow: BrColors.softShadow,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(BrColors.radiusM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrColors.radiusM),
        child: decorated,
      ),
    );
  }
}

/// Petit titre de section doré, espacé.
class BrSectionTitle extends StatelessWidget {
  final String label;
  final IconData? icon;
  const BrSectionTitle(this.label, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: BrColors.gold, size: 16),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: const TextStyle(
            color: BrColors.gold,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(height: 1, color: BrColors.gold.withValues(alpha: 0.2)),
        ),
      ],
    );
  }
}

/// Avatar coloré à initiales (couleur stable dérivée du nom).
class BrAvatar extends StatelessWidget {
  final String firstName;
  final String lastName;
  final double size;
  final Color? color;
  const BrAvatar({
    super.key,
    required this.firstName,
    this.lastName = '',
    this.size = 44,
    this.color,
  });

  String get _initials {
    final a = firstName.trim();
    final b = lastName.trim();
    final first = a.isNotEmpty ? a[0] : '';
    final second = b.isNotEmpty ? b[0] : '';
    final initials = '$first$second'.toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? BrColors.forSeed('$firstName$lastName');
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.withValues(alpha: 0.85), c.withValues(alpha: 0.45)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: BrColors.softShadow,
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// Badge coloré générique (grade, statut, information).
class BrBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const BrBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge de grade maçonnique (couleur dérivée du grade).
class BrGradeBadge extends StatelessWidget {
  final String grade;
  const BrGradeBadge({super.key, required this.grade});

  @override
  Widget build(BuildContext context) {
    return BrBadge(
      label: grade,
      color: BrColors.forGrade(grade),
      icon: Icons.auto_awesome,
    );
  }
}
