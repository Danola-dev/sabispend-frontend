import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'package:first_app/notifications_api.dart';
import 'package:first_app/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationResult> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await NotificationsApi.getList();
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleMarkAllRead() async {
    try {
      await NotificationsApi.markAllRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map(
              (n) => NotificationResult(
                id: n.id,
                notificationType: n.notificationType,
                title: n.title,
                body: n.body,
                isRead: true,
                metadata: n.metadata,
                createdAt: n.createdAt,
              ),
            )
            .toList();
      });
    } on ApiException catch (_) {
      // Silent failure here is fine — worst case, badge stays as-is
      // until next real fetch, no data was lost or corrupted.
    }
  }

  Future<void> _handleTapNotification(NotificationResult notification) async {
    if (!notification.isRead) {
      // Optimistic UI update — flip it locally immediately, don't wait
      // on the network round trip for the checkmark/bold-text to clear.
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = NotificationResult(
            id: notification.id,
            notificationType: notification.notificationType,
            title: notification.title,
            body: notification.body,
            isRead: true,
            metadata: notification.metadata,
            createdAt: notification.createdAt,
          );
        }
      });
      try {
        await NotificationsApi.markRead(notification.id);
      } on ApiException catch (_) {
        // Not worth surfacing an error for this — worst case it shows
        // as read locally but reverts on next fetch, no real harm done.
      }
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'deposit':
        return Icons.arrow_downward_rounded;
      case 'transfer_success':
        return Icons.arrow_upward_rounded;
      case 'transfer_failed':
        return Icons.error_outline_rounded;
      case 'payout_ready':
        return Icons.lock_open_rounded;
      case 'reminder':
        return Icons.notifications_active_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _iconColorFor(String type) {
    if (type == 'transfer_failed') return const Color(0xFFD64545);
    return AppColors.teal;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _handleMarkAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.teal,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.teal),
              )
            : _errorMessage != null
            ? _buildErrorState()
            : _notifications.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                color: AppColors.teal,
                onRefresh: _fetchNotifications,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return Dismissible(
                      key: ValueKey(notification.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: const Color(0xFFD64545),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) async {
                        setState(() => _notifications.removeAt(index));
                        try {
                          await NotificationsApi.deleteNotification(
                            notification.id,
                          );
                        } on ApiException catch (_) {
                          // Already removed from view — a failed delete just means it
                          // reappears next real fetch, no data corruption either way.
                        }
                      },
                      child: _buildNotificationRow(notification),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildNotificationRow(NotificationResult notification) {
    return InkWell(
      onTap: () => _handleTapNotification(notification),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        color: notification.isRead
            ? Colors.transparent
            : AppColors.tealTint.withOpacity(0.3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.tealTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconFor(notification.notificationType),
                size: 19,
                color: _iconColorFor(notification.notificationType),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8, top: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.tealTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.teal,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Deposits, transfers, and payout updates will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Color(0xFFD64545)),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _fetchNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
