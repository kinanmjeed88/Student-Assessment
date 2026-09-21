import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_components.dart';

class AsyncStateView extends StatelessWidget {
  const AsyncStateView({
    required this.state,
    required this.child,
    this.onRetry,
    this.loadingMessage = 'جارٍ تحميل البيانات…',
    super.key,
  });

  final AsyncValue<dynamic> state;
  final Widget child;
  final VoidCallback? onRetry;
  final String loadingMessage;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => _AsyncLoading(message: loadingMessage),
      error: (error, _) => _AsyncError(error: error, onRetry: onRetry),
      data: (_) => child,
    );
  }
}

class _AsyncLoading extends StatelessWidget {
  const _AsyncLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppSurfaceCard(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _AsyncError extends StatelessWidget {
  const _AsyncError({required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppEmptyState(
        icon: Icons.error_outline,
        title: 'تعذر تحميل البيانات',
        message: 'حدث خطأ أثناء قراءة البيانات المحلية.\n$error',
        action: onRetry == null
            ? null
            : FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
      ),
    );
  }
}
