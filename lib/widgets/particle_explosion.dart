import 'dart:math';
import 'package:flutter/material.dart';

enum ExplosionType { burst, rain }

class ParticleExplosion extends StatefulWidget {
  final Widget child;
  final bool trigger;
  final String particleEmoji;
  final int particleCount;
  final ExplosionType type;

  const ParticleExplosion({
    super.key,
    required this.child,
    required this.trigger,
    this.particleEmoji = '🪙',
    this.particleCount = 20,
    this.type = ExplosionType.burst,
  });

  @override
  State<ParticleExplosion> createState() => _ParticleExplosionState();
}

class _ParticleExplosionState extends State<ParticleExplosion>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _controller.addListener(() {
      setState(() {
        for (var particle in _particles) {
          particle.update();
        }
      });
    });

    if (widget.trigger) {
      _generateParticles();
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ParticleExplosion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _generateParticles();
      _controller.forward(from: 0.0);
    }
  }

  void _generateParticles() {
    _particles.clear();
    for (int i = 0; i < widget.particleCount; i++) {
      if (widget.type == ExplosionType.rain) {
        // Lluvia desde la parte superior con variación en X
        double vx = (_random.nextDouble() - 0.5) * 4;
        double vy = _random.nextDouble() * 5 + 3; // Caída hacia abajo
        double startX = (_random.nextDouble() - 0.5) * 250;
        double startY = -100 - _random.nextDouble() * 50;
        _particles.add(
          _Particle(
            x: startX,
            y: startY,
            vx: vx,
            vy: vy,
            size: _random.nextDouble() * 12 + 18,
            opacity: 1.0,
            gravity: 0.25,
          ),
        );
      } else {
        // Explosión/Destello radial desde el centro
        double angle = _random.nextDouble() * 2 * pi;
        double speed = _random.nextDouble() * 8 + 4;
        _particles.add(
          _Particle(
            x: 0,
            y: 0,
            vx: cos(angle) * speed,
            vy: sin(angle) * speed,
            size: _random.nextDouble() * 14 + 16,
            opacity: 1.0,
            gravity: 0.15,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        widget.child,
        if (_controller.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ParticlePainter(
                  particles: _particles,
                  emoji: widget.particleEmoji,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double opacity;
  double gravity;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.gravity,
  });

  void update() {
    x += vx;
    y += vy;
    vy += gravity; // Gravedad
    opacity = (opacity - 0.02).clamp(0.0, 1.0);
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final String emoji;

  _ParticlePainter({required this.particles, required this.emoji});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (var p in particles) {
      // ✅ Corregido con llaves {}:
      if (p.opacity <= 0) {
        continue;
      }

      final textSpan = TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: p.size,
          color: Colors.white.withValues(alpha: p.opacity),
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx + p.x - (p.size / 2), center.dy + p.y - (p.size / 2)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
