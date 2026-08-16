import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/connectivity_provider.dart';

class NetworkAwareWidget extends ConsumerWidget {
  final Widget child;

  const NetworkAwareWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isOnline ? 0 : 36,
          color: AppColors.error,
          child: isOnline
              ? null
              : const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, size: 14, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'No internet connection',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
