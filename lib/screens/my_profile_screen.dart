import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_app/app_colors.dart';

/// Opened when the account header on ProfileScreen is tapped.
/// Receives data from ProfileScreen so it renders instantly (no extra loading).
class MyProfileScreen extends StatelessWidget {
  final String name;
  final String email;
  final bool isKycActive;
  final String subscription;

  const MyProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.isKycActive,
    this.subscription = 'Free',
  });

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label copied'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'My profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              // Avatar
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.teal, AppColors.tealDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isKycActive) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 20, color: AppColors.teal),
                  ],
                ],
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _StatusChip(verified: isKycActive),
              const SizedBox(height: 28),

              // Personal info
              _SectionLabel('Personal information'),
              _InfoCard(
                rows: [
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Full name',
                    value: name,
                  ),
                  _InfoRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email address',
                    value: email.isNotEmpty ? email : 'Not set',
                    onCopy: email.isNotEmpty
                        ? () => _copy(context, 'Email', email)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Account info
              _SectionLabel('Account'),
              _InfoCard(
                rows: [
                  _InfoRow(
                    icon: Icons.shield_outlined,
                    label: 'Identity verification',
                    value: isKycActive ? 'Verified' : 'Not verified',
                    valueColor: isKycActive
                        ? AppColors.teal
                        : AppColors.textMuted,
                  ),
                  _InfoRow(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Plan',
                    value: subscription,
                  ),
                  _InfoRow(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Plan',
                    value: subscription,
                    valueColor: subscription == 'Pro' ? AppColors.teal : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool verified;
  const _StatusChip({required this.verified});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: verified ? AppColors.tealTint : AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: verified ? null : Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_user_outlined : Icons.info_outline,
            size: 16,
            color: verified ? AppColors.teal : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            verified ? 'Identity verified' : 'Verification pending',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: verified ? AppColors.tealDark : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onCopy;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onCopy,
  });
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final r = rows[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : const Border(
                      top: BorderSide(color: AppColors.border, width: 0.5),
                    ),
            ),
            child: Row(
              children: [
                Icon(r.icon, size: 20, color: AppColors.textPrimary),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 125, 130, 139),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: r.valueColor ?? AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (r.onCopy != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: r.onCopy,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
