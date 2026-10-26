import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/portal_notification_models.dart';
import '../../services/i_api_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// In-app inbox: the server owns the recipient, unread state and event code.
/// This is refreshed on demand and periodically; it is not system push.
class RealNotificationContent extends StatefulWidget {
  const RealNotificationContent({super.key});

  @override
  State<RealNotificationContent> createState() =>
      _RealNotificationContentState();
}

class _RealNotificationContentState extends State<RealNotificationContent> {
  PortalNotificationInbox? _inbox;
  String? _error;
  bool _loading = false;
  String? _openingId;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final inbox = await context.read<AuthViewModel>().getNotifications();
      if (mounted) setState(() => _inbox = inbox);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được thông báo. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(PortalNotification item) async {
    if (_openingId != null) return;
    setState(() => _openingId = item.id);
    try {
      if (!item.read) {
        await context.read<AuthViewModel>().markNotificationRead(item.id);
        // The inbox refresh must not keep the notification tap waiting to
        // open a ticket. The server remains the source of the unread count.
        unawaited(_load());
      }
      if (!mounted) return;
      final path = item.customerPath;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thông báo này không có trang chi tiết trong App.'),
          ),
        );
      } else {
        // push() completes only when the detail route is popped. Waiting for
        // it kept this row's spinner alive while the customer viewed or
        // decided a quotation, sometimes until logout reset the shell.
        context.go(path);
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không đánh dấu đã đọc (${error.statusCode ?? 'mạng'}): ${error.message}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = _inbox;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  inbox == null
                      ? 'Thông báo trong ứng dụng'
                      : '${inbox.unreadCount} chưa đọc · Thông báo trong ứng dụng',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              IconButton(
                tooltip: 'Tải thông báo mới',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
                TextButton(onPressed: _load, child: const Text('Thử lại')),
              ],
            ),
          ),
        Expanded(
          child: _loading && inbox == null
              ? const Center(child: CircularProgressIndicator())
              : inbox == null
              ? const Center(child: Text('Chưa tải được thông báo.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: inbox.items.isEmpty ? 1 : inbox.items.length,
                    itemBuilder: (context, index) {
                      if (inbox.items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(
                            child: Text(
                              'Chưa có thông báo trong tài khoản này.',
                            ),
                          ),
                        );
                      }
                      final item = inbox.items[index];
                      return Card(
                        color: item.read
                            ? AppColors.white
                            : AppColors.primaryLight,
                        child: ListTile(
                          leading: Icon(
                            item.type == 'QUOTATION_AWAITING_CUSTOMER'
                                ? Icons.request_quote_rounded
                                : Icons.notifications_outlined,
                          ),
                          title: Text(item.message),
                          subtitle: item.createdAt == null
                              ? null
                              : Text('${item.createdAt!.toLocal()}'),
                          trailing: _openingId == item.id
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : item.customerPath == null
                              ? null
                              : const Icon(Icons.chevron_right),
                          onTap: () => _open(item),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
