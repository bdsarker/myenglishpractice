import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';

class ShimmerWordDetail extends StatelessWidget {
  const ShimmerWordDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surface,
      highlightColor: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _box(height: 32, width: 200),
            const SizedBox(height: 8),
            _box(height: 16, width: 120),
            const SizedBox(height: 24),
            // Five 88px placeholders are wider than a small phone. Clipped the
            // same way the real synonym row scrolls, rather than overflowing.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: List.generate(
                  5,
                  (_) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _box(height: 32, width: 80),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _box(height: 80, width: double.infinity),
            const SizedBox(height: 24),
            _box(height: 16, width: 140),
            const SizedBox(height: 12),
            ...List.generate(3, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _box(height: 60, width: double.infinity),
            )),
          ],
        ),
      ),
    );
  }

  Widget _box({required double height, required double width}) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
      );
}
