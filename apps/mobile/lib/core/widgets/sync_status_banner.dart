import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../sync/sync_engine.dart';
import '../theme/theme_provider.dart';

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final syncEngine = context.watch<SyncEngine>();
    final tokens = context.watch<ThemeProvider>().tokens;

    // Hide banner when online and zero pending changes
    if (syncEngine.isOnline && syncEngine.pendingCount == 0 && syncEngine.state != SyncEngineState.syncing) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    Color fgColor;
    IconData icon;
    String message;
    bool showSyncButton = true;

    if (!syncEngine.isOnline) {
      bgColor = tokens.paidLateContainer;
      fgColor = tokens.paidLate;
      icon = Icons.cloud_off_rounded;
      message = syncEngine.pendingCount > 0
          ? 'Offline — ${syncEngine.pendingCount} change${syncEngine.pendingCount > 1 ? 's' : ''} queued'
          : 'Working offline (Changes will sync automatically)';
      showSyncButton = false;
    } else if (syncEngine.state == SyncEngineState.syncing) {
      bgColor = tokens.primaryContainer;
      fgColor = tokens.primary;
      icon = Icons.sync_rounded;
      message = 'Syncing ${syncEngine.pendingCount} item${syncEngine.pendingCount > 1 ? 's' : ''}...';
      showSyncButton = false;
    } else if (syncEngine.state == SyncEngineState.error) {
      bgColor = tokens.unpaidOverdueContainer;
      fgColor = tokens.unpaidOverdue;
      icon = Icons.sync_problem_rounded;
      message = 'Sync failed. Will retry automatically.';
      showSyncButton = true;
    } else {
      bgColor = tokens.paidOnTimeContainer;
      fgColor = tokens.paidOnTime;
      icon = Icons.cloud_done_rounded;
      message = 'All changes synced';
      showSyncButton = false;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: bgColor,
      child: Row(
        children: [
          Icon(icon, size: 18, color: fgColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
          ),
          if (showSyncButton) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => syncEngine.syncNow(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: fgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Sync Now',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
