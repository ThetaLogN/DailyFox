import 'package:flutter/material.dart';

class AnimeFoxView extends StatelessWidget {
  final int rating;
  final int animationPhase;

  const AnimeFoxView(
      {super.key, required this.rating, required this.animationPhase});

  Color get foxMainColor {
    switch (rating) {
      case 1:
      case 2:
        return const Color.fromRGBO(204, 128, 77, 1);
      case 3:
      case 4:
        return const Color.fromRGBO(230, 153, 89, 1);
      case 5:
      case 6:
        return const Color.fromRGBO(242, 166, 89, 1);
      case 7:
      case 8:
        return const Color.fromRGBO(250, 179, 102, 1);
      case 9:
      case 10:
        return const Color.fromRGBO(255, 191, 115, 1);
      default:
        return const Color.fromRGBO(242, 166, 89, 1);
    }
  }

  Color get foxSecondaryColor => foxMainColor.withOpacity(0.8);

  Color get foxBellyColor => const Color.fromRGBO(245, 240, 224, 1);

  String get eyeType {
    if (animationPhase == 2) return "closed";
    switch (rating) {
      case 1:
      case 2:
        return "sad";
      case 3:
      case 4:
        return "neutral";
      case 5:
      case 6:
        return "normal";
      case 7:
      case 8:
        return "happy";
      case 9:
      case 10:
        return "sparkle";
      default:
        return "normal";
    }
  }

  double get tailPosition {
    switch (animationPhase) {
      case 0:
        return -25;
      case 1:
        return -15;
      case 2:
        return 15;
      case 3:
        return 25;
      default:
        return 0;
    }
  }

  double get earRotation => animationPhase % 2 == 0 ? 5 : -5;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: backgroundColors(rating),
                radius: 1.5,
              ),
            ),
          ),
          // Particles for high rating
          if (rating >= 8)
            ...List.generate(4, (index) {
              return Positioned(
                left: (-40 + (index * 20)).toDouble(),
                top: (-40 + (index * 20)).toDouble(),
                child: Opacity(
                  opacity: animationPhase % 2 == index % 2 ? 0.6 : 0.2,
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.yellow,
                    ),
                  ),
                ),
              );
            }),
          // Fox body
          Stack(
            children: [
              // Shadow
              Transform.translate(
                offset: const Offset(0, 5),
                child: CustomPaint(
                  size: const Size(105, 80),
                  painter:
                      EllipsePainter(color: Colors.black.withOpacity(0.15)),
                ),
              ),
              // Main body
              CustomPaint(
                size: const Size(95, 70),
                painter: EllipsePainter(
                  gradient: LinearGradient(
                    colors: [
                      foxMainColor,
                      foxSecondaryColor,
                      foxMainColor.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Transform.translate(
                  offset: const Offset(-15, -15),
                  child: CustomPaint(
                    size: const Size(35, 25),
                    painter: EllipsePainter(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              // Belly
              Transform.translate(
                offset: const Offset(0, 10),
                child: CustomPaint(
                  size: const Size(55, 40),
                  painter: EllipsePainter(
                    gradient: RadialGradient(
                      colors: [foxBellyColor, foxBellyColor.withOpacity(0.8)],
                      radius: 0.75,
                    ),
                  ),
                ),
              ),
              // Ears
              Transform.translate(
                offset: const Offset(0, -42),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Left ear
                    Transform.translate(
                      offset: const Offset(-22.5, 0),
                      child: Transform.rotate(
                        angle: earRotation * 3.14159 / 180,
                        child: Stack(
                          children: [
                            CustomPaint(
                              size: const Size(24, 30),
                              painter: TrianglePainter(
                                  color: Colors.black.withOpacity(0.1)),
                            ),
                            CustomPaint(
                              size: const Size(24, 30),
                              painter: TrianglePainter(
                                gradient: LinearGradient(
                                  colors: [foxMainColor, foxSecondaryColor],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, 3),
                              child: CustomPaint(
                                size: const Size(14, 18),
                                painter: TrianglePainter(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color.fromRGBO(102, 51, 38, 1),
                                      const Color.fromRGBO(77, 38, 26, 1),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 45),
                    // Right ear
                    Transform.translate(
                      offset: const Offset(22.5, 0),
                      child: Transform.rotate(
                        angle: -earRotation * 3.14159 / 180,
                        child: Stack(
                          children: [
                            Transform.translate(
                              offset: const Offset(-1, 1),
                              child: CustomPaint(
                                size: const Size(24, 30),
                                painter: TrianglePainter(
                                    color: Colors.black.withOpacity(0.1)),
                              ),
                            ),
                            CustomPaint(
                              size: const Size(24, 30),
                              painter: TrianglePainter(
                                gradient: LinearGradient(
                                  colors: [foxMainColor, foxSecondaryColor],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, 3),
                              child: CustomPaint(
                                size: const Size(14, 18),
                                painter: TrianglePainter(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color.fromRGBO(102, 51, 38, 1),
                                      const Color.fromRGBO(77, 38, 26, 1),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Face
              Transform.translate(
                offset: const Offset(0, -5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Eyes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimeEye(type: eyeType, isLeft: true),
                        const SizedBox(width: 20),
                        AnimeEye(type: eyeType, isLeft: false),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Nose
                    Transform.rotate(
                      angle: 180 * 3.14159 / 180,
                      child: CustomPaint(
                        size: const Size(6, 5),
                        painter: TrianglePainter(color: Colors.black),
                      ),
                    ),
                    // Mouth
                    AnimeMouth(rating: rating, animationPhase: animationPhase),
                    // Cheeks for high rating
                    if (rating >= 8)
                      Transform.translate(
                        offset: const Offset(0, -12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color.fromRGBO(230, 179, 128, 0.4),
                                    Colors.transparent,
                                  ],
                                  radius: 0.8,
                                ),
                              ),
                              child: Opacity(
                                opacity: animationPhase % 2 == 0 ? 0.6 : 0.3,
                                child: const SizedBox(),
                              ),
                            ),
                            const SizedBox(width: 25),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color.fromRGBO(230, 179, 128, 0.4),
                                    Colors.transparent,
                                  ],
                                  radius: 0.8,
                                ),
                              ),
                              child: Opacity(
                                opacity: animationPhase % 2 == 0 ? 0.6 : 0.3,
                                child: const SizedBox(),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Tail
              Transform.translate(
                offset: const Offset(-45, 28),
                child: Transform.rotate(
                  angle: tailPosition * 3.14159 / 180,
                  child: Stack(
                    children: [
                      // Tail shadow
                      Transform.translate(
                        offset: const Offset(0, 4),
                        child: CustomPaint(
                          size: const Size(50, 22),
                          painter: EllipsePainter(
                              color: Colors.black.withOpacity(0.15)),
                        ),
                      ),
                      // Main tail
                      CustomPaint(
                        size: const Size(48, 20),
                        painter: EllipsePainter(
                          gradient: LinearGradient(
                            colors: [
                              foxMainColor,
                              foxSecondaryColor,
                              foxMainColor.withOpacity(0.9),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                      // Tail tip
                      Transform.translate(
                        offset: const Offset(-13, -8),
                        child: CustomPaint(
                          size: const Size(20, 14),
                          painter: EllipsePainter(
                            gradient: RadialGradient(
                              colors: [
                                foxBellyColor,
                                foxBellyColor.withOpacity(0.9)
                              ],
                              radius: 0.75,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> backgroundColors(int rating) {
    switch (rating) {
      case 1:
      case 2:
        return [
          const Color.fromRGBO(230, 217, 204, 1),
          const Color.fromRGBO(217, 204, 191, 1),
          const Color.fromRGBO(204, 191, 179, 1),
        ];
      case 3:
      case 4:
        return [
          const Color.fromRGBO(235, 224, 209, 1),
          const Color.fromRGBO(224, 214, 199, 1),
          const Color.fromRGBO(214, 204, 189, 1),
        ];
      case 5:
      case 6:
        return [
          const Color.fromRGBO(242, 235, 217, 1),
          const Color.fromRGBO(230, 222, 204, 1),
          const Color.fromRGBO(217, 209, 191, 1),
        ];
      case 7:
      case 8:
        return [
          const Color.fromRGBO(235, 242, 224, 1),
          const Color.fromRGBO(224, 230, 214, 1),
          const Color.fromRGBO(214, 217, 204, 1),
        ];
      case 9:
      case 10:
        return [
          const Color.fromRGBO(224, 242, 235, 1),
          const Color.fromRGBO(214, 230, 224, 1),
          const Color.fromRGBO(204, 217, 214, 1),
        ];
      default:
        return [
          const Color.fromRGBO(230, 230, 230, 1),
          const Color.fromRGBO(217, 217, 217, 1),
          const Color.fromRGBO(204, 204, 204, 1),
        ];
    }
  }
}

class AnimeEye extends StatelessWidget {
  final String type;
  final bool isLeft;

  const AnimeEye({super.key, required this.type, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    if (type == "closed") {
      return Container(
        width: 18,
        height: 3,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(1.5),
          color: Colors.black,
        ),
      );
    }

    return Stack(
      children: [
        // Eye base
        CustomPaint(
          size: const Size(18, 16),
          painter: EllipsePainter(
            color: Colors.white,
            borderColor: Colors.black.withOpacity(0.2),
            borderWidth: 0.5,
          ),
        ),
        // Pupil
        if (type == "sad") ...[
          CustomPaint(
            size: const Size(7, 8),
            painter: EllipsePainter(color: Colors.black),
          ),
          // Tears
          Transform.translate(
            offset: const Offset(0, 12),
            child: CustomPaint(
              size: const Size(8, 10),
              painter: EllipsePainter(color: Colors.blue.withOpacity(0.7)),
            ),
          ),
          Transform.translate(
            offset: const Offset(-3, 18),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.6),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(2, 22),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.5),
              ),
            ),
          ),
        ] else if (type == "neutral") ...[
          CustomPaint(
            size: const Size(6, 7),
            painter: EllipsePainter(color: Colors.black),
          ),
        ] else if (type == "normal") ...[
          Stack(
            children: [
              CustomPaint(
                size: const Size(8, 9),
                painter: EllipsePainter(color: Colors.black),
              ),
              Transform.translate(
                offset: const Offset(-1.5, -1.5),
                child: Container(
                  width: 2,
                  height: 2,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ] else if (type == "happy") ...[
          Stack(
            children: [
              CustomPaint(
                size: const Size(9, 10),
                painter: EllipsePainter(color: Colors.black),
              ),
              Transform.translate(
                offset: const Offset(-2, -2),
                child: Container(
                  width: 2.5,
                  height: 2.5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ] else if (type == "sparkle") ...[
          Stack(
            children: [
              CustomPaint(
                size: const Size(9, 10),
                painter: EllipsePainter(color: Colors.black),
              ),
              Transform.translate(
                offset: const Offset(-1.5, -1.5),
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          CustomPaint(
            size: const Size(8, 9),
            painter: EllipsePainter(color: Colors.black),
          ),
        ],
      ],
    );
  }
}

class AnimeMouth extends StatelessWidget {
  final int rating;
  final int animationPhase;

  const AnimeMouth(
      {super.key, required this.rating, required this.animationPhase});

  @override
  Widget build(BuildContext context) {
    switch (rating) {
      case 1:
      case 2:
        return CustomPaint(
          size: const Size(16, 8),
          painter: MouthPainter(isHappy: false),
        );
      case 3:
      case 4:
        return Container(
          width: 8,
          height: 2,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(1),
            color: Colors.black,
          ),
        );
      case 5:
      case 6:
        return Container(
          width: 10,
          height: 2,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(1),
            color: Colors.black,
          ),
        );
      case 7:
      case 8:
        return Transform.scale(
          scale: animationPhase % 2 == 0 ? 1.1 : 1.0,
          child: CustomPaint(
            size: const Size(14, 4),
            painter: MouthPainter(isHappy: true),
          ),
        );
      case 9:
      case 10:
        return Transform.scale(
          scale: animationPhase % 2 == 0 ? 1.15 : 1.0,
          child: CustomPaint(
            size: const Size(18, 6),
            painter: MouthPainter(isHappy: true, lineWidth: 2.5),
          ),
        );
      default:
        return Container(
          width: 10,
          height: 2,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(1),
            color: Colors.black,
          ),
        );
    }
  }
}

class TrianglePainter extends CustomPainter {
  final Color? color;
  final Gradient? gradient;

  TrianglePainter({this.color, this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    if (color != null) {
      paint.color = color!;
    } else if (gradient != null) {
      paint.shader =
          gradient!.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class EllipsePainter extends CustomPainter {
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final double? borderWidth;

  EllipsePainter(
      {this.color, this.gradient, this.borderColor, this.borderWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    if (color != null) {
      paint.color = color!;
    } else if (gradient != null) {
      paint.shader =
          gradient!.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    canvas.drawOval(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    if (borderColor != null && borderWidth != null) {
      final borderPaint = Paint()
        ..color = borderColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth!;
      canvas.drawOval(
          Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MouthPainter extends CustomPainter {
  final bool isHappy;
  final double lineWidth;

  MouthPainter({required this.isHappy, this.lineWidth = 2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth;

    final path = Path();
    if (isHappy) {
      path.moveTo(0, 0);
      path.cubicTo(
        size.width / 4,
        size.height,
        3 * size.width / 4,
        size.height,
        size.width,
        0,
      );
    } else {
      path.moveTo(0, size.height);
      path.cubicTo(
        size.width / 4,
        0,
        3 * size.width / 4,
        0,
        size.width,
        size.height,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
