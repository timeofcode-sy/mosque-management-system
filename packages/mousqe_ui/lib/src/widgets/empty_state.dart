import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

/// حالة فارغة: تقول ماذا سيظهر هنا وكيف يبدأ المستخدم (جرد الشاشات)، بأيقونة من [NzIcons]
/// وزرّ إجراءٍ اختياري.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = NzIcons.archive,
    this.onRetry,
    this.actionLabel = 'إعادة المحاولة',
  });

  final String message;

  /// اسمُ أيقونةٍ من [NzIcons].
  final String icon;
  final VoidCallback? onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NzSpace.s5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مسدّسُ البيت بأيقونةٍ في وسطه: مكانُ الصور في الهوية (لا صور للطلاب أو الرسوم).
              SizedBox.square(
                dimension: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipPath(
                      clipper: const _HexClipper(),
                      child: ColoredBox(
                        color: c.surfaceSunken,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    NzIcon(icon, size: 30, color: c.inkMuted),
                  ],
                ),
              ),
              const SizedBox(height: NzSpace.s3),
              Text(
                message,
                style: NzType.body.copyWith(color: c.ink),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: NzSpace.s4),
                OutlinedButton(onPressed: onRetry, child: Text(actionLabel)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// حالة خطأ: نفس تركيب [EmptyState] بأيقونة تحذير، ورسالتُها تقول ما حدث وكيف يُصلح.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) =>
      EmptyState(message: message, icon: NzIcons.warning, onRetry: onRetry);
}

class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h * 0.21)
      ..lineTo(w, h * 0.79)
      ..lineTo(w / 2, h)
      ..lineTo(0, h * 0.79)
      ..lineTo(0, h * 0.21)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
