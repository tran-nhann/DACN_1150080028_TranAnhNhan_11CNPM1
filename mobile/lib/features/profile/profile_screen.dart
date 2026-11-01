import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../shell/app_shell.dart';
import '../dashboard/revenue_report.dart';
import '../bookings/invoices_panel.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _busy = false;
  Future<void> _logout() async {
    if (_busy) return;
    final user = ref.read(authProvider).user;
    final confirmed = await showAsterConfirm(
      context,
      title: 'Đăng xuất?',
      details: user?.name ?? '',
      label: 'Đăng xuất',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final revoked = await ref.read(authProvider.notifier).logout();
    if (!revoked) {
      messenger.showSnackBar(
        const SnackBar(
          duration: Duration(days: 1),
          showCloseIcon: true,
          content: Text('Đã đăng xuất. Chưa thu hồi được phiên trên máy chủ.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenHeading(title: 'Thêm'),
          Surface(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 29,
                  backgroundColor: const Color(0xFFE5F2EB),
                  child: Text(
                    user.name.isEmpty ? 'A' : user.name.substring(0, 1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: AsterColors.teal,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AsterColors.ink,
                        ),
                      ),
                      Text(
                        user.roleLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '@${user.username}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (user.canAccessCustomers) ...[
            const SizedBox(height: 20),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AsterColors.border),
                ),
                leading: const Icon(
                  Icons.people_outline,
                  color: AsterColors.teal,
                ),
                title: const Text(
                  'Khách hàng',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/profile/customers'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: const Icon(
                Icons.room_service_outlined,
                color: AsterColors.teal,
              ),
              title: const Text(
                'Dịch vụ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile/services'),
            ),
          ),
          const SizedBox(height: 28),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Hóa đơn & phiếu thu'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showAsterSheet<void>(
                context: context,
                form: true,
                builder: (_) => const InvoicesPanel(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (user.isAdmin || user.role == 'manager') ...[
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const Icon(
                  Icons.insights_rounded,
                  color: AsterColors.navy,
                ),
                title: const Text(
                  'Doanh thu ước tính',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAsterSheet<void>(
                  context: context,
                  form: true,
                  builder: (_) => const RevenueReport(),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          SizedBox(
            width: double.infinity,
            child: PressScale(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _logout,
                icon: _busy
                    ? const AsterLoader(size: 18)
                    : const Icon(Icons.logout, size: 18),
                label: const Text('Đăng xuất'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
