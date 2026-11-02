import 'dart:async';

import 'package:first_app/screens/add_funds_screen.dart';
import 'package:first_app/screens/airtime_screen.dart';
import 'package:first_app/screens/data_screen.dart';
import 'package:first_app/screens/electricity_screen.dart';
import 'package:first_app/screens/cable_screen.dart';
import 'package:first_app/screens/send_to_bank_screen.dart';
import 'package:first_app/screens/transaction_history_screen.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../wallet_api.dart';
import '../api_client.dart';
import '../transactions_api.dart';
import '../transaction_display_helpers.dart';
import '../token_storage.dart';
import '../push_notification_service.dart';
import 'notifications_screen.dart';
import '../notifications_api.dart';
import 'go_pro_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isNewSignup;
  final void Function(int index)? onNavigateToTab;
  const HomeScreen({
    super.key,
    this.onNavigateToTab,
    required this.isNewSignup,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Accounts that have already been shown the "Let's get you set up"
  // reminder. STATIC on purpose: HomeScreen is rebuilt every time the user
  // signs back in or changes their PIN, and a normal field would be reset
  // each time, which is what made the reminder keep coming back. This
  // survives those rebuilds for as long as the app is running.
  static final Set<String> _reminderShownFor = {};

  Timer? _reminderTimer;
  StreamSubscription<void>? _pushSub;

  var isShowing = false;
  var isLockedBalanceShowing = false;

  String _userFirstName = '';

  int _unreadNotificationCount = 0;

  WalletData? _walletData;
  bool _isLoadingWallet = true;

  List<TransactionResult> _transactions = [];
  bool _isLoadingTransactions = true;

  // Guards automatic refreshes (push / app resume) so they never pile up.
  bool _isAutoRefreshing = false;
  DateTime? _lastRefreshAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fetchWallet();
    _fetchUnreadCount();
    _fetchTransactions();
    _loadUserName();

    // A push arrived while the app is open (e.g. a deposit) — refresh.
    _pushSub = PushNotificationService.onForegroundMessage.listen(
      (_) => _autoRefreshAfterPush(),
    );

    if (widget.isNewSignup) _scheduleSetupReminder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushSub?.cancel();
    _reminderTimer?.cancel();
    super.dispose();
  }

  /// Shows the setup reminder 5 seconds in, but only if this account has
  /// never been shown it before.
  Future<void> _scheduleSetupReminder() async {
    // Keyed by phone number (unique per account), so a DIFFERENT person
    // creating an account on the same phone still gets their own reminder.
    final phone = await LocalUserCache.getCachedPhone();
    final key = (phone != null && phone.isNotEmpty) ? phone : '_unknown';

    if (!mounted || _reminderShownFor.contains(key)) return;

    _reminderTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      // Checked again at the moment it would show, and recorded BEFORE
      // showing, so it can never appear twice.
      if (_reminderShownFor.contains(key)) return;
      _reminderShownFor.add(key);
      _showSetupReminderOverlay();
    });
  }

  // Covers a deposit that landed while the app was in the background or
  // closed — refreshes as soon as the user comes back to it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // Biometric prompts and permission dialogs also trigger "resumed" —
    // skip if we refreshed moments ago.
    final last = _lastRefreshAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _autoRefresh();
  }

  /// Used by pull-to-refresh. Awaits everything so the spinner disappears
  /// only once the balance, history and badge are genuinely up to date.
  Future<void> _refreshAll() async {
    _lastRefreshAt = DateTime.now();
    try {
      await Future.wait([
        _fetchWallet(),
        _fetchTransactions(),
        _fetchUnreadCount(),
      ]);
    } catch (_) {
      // Individual fetches already handle their own errors; anything else
      // (like an expired session) is handled by the next real request.
    }
  }

  Future<void> _autoRefresh() async {
    if (_isAutoRefreshing) return;
    _isAutoRefreshing = true;
    try {
      await _refreshAll();
    } finally {
      _isAutoRefreshing = false;
    }
  }

  Future<void> _autoRefreshAfterPush() async {
    // Small pause so the backend has finished committing the credit/debit
    // that triggered the push before we ask for the new balance.
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    await _autoRefresh();
  }

  Future<void> _loadUserName() async {
    final name = await LocalUserCache.getCachedName();
    if (mounted) {
      setState(() {
        _userFirstName = (name != null && name.trim().isNotEmpty)
            ? name.trim().split(' ').first
            : '';
      });
    }
  }

  Future<void> _fetchWallet() async {
    try {
      final data = await WalletApi.getWallet();
      if (mounted) {
        setState(() {
          _walletData = data;
          _isLoadingWallet = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final count = await NotificationsApi.getUnreadCount();
      if (mounted) setState(() => _unreadNotificationCount = count);
    } on ApiException catch (_) {}
  }

  Future<void> _fetchTransactions() async {
    try {
      final history = await TransactionsApi.getHistory();
      if (mounted) {
        setState(() {
          _transactions = history.take(3).toList();
          _isLoadingTransactions = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _isLoadingTransactions = false);
    }
  }

  String _formatNaira(double amount) {
    final wholeAmount = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < wholeAmount.length; i++) {
      if (i != 0 && (wholeAmount.length - i) % 3 == 0) buffer.write(',');
      buffer.write(wholeAmount[i]);
    }
    return '₦ $buffer';
  }

  String _frequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Daily plan';
      case 'weekly':
        return 'Weekly plan';
      case 'biweekly':
        return 'Biweekly plan';
      case 'monthly':
        return 'Monthly plan';
      default:
        return '$frequency plan';
    }
  }

  String _nextPayoutLabel() {
    final plan = _walletData?.currentPlan;
    if (plan == null) return 'No active plan';

    final daysLeft = plan.nextEditableDate.difference(DateTime.now()).inDays;
    if (daysLeft <= 0) return 'Payout available now';
    if (daysLeft == 1) return 'Next payout tomorrow';
    return 'Next payout in $daysLeft days';
  }

  void _showSetupReminderOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Setup reminder',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(animation.value),
          child: Opacity(
            opacity: animation.value.clamp(0, 1),
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.tealTint,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.rocket_launch_outlined,
                          size: 26,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Let\'s get you set up',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Fund your account, then set a payout plan so you can start spending.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: Color.fromARGB(255, 56, 60, 64),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AddFundsScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.tealDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Fund account',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onNavigateToTab?.call(2);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.teal),
                            ),
                            child: const Text(
                              'Set payout plan',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.teal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: _buildHeader(),
            ),
            Expanded(
              // Pull down anywhere in this area to refresh balance,
              // recent activity and the notification badge.
              child: RefreshIndicator(
                color: AppColors.teal,
                onRefresh: _refreshAll,
                child: SingleChildScrollView(
                  // Without this, pull-to-refresh silently does nothing
                  // whenever the content is short enough not to scroll.
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 7, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBalanceCard(context),
                      const SizedBox(height: 15),
                      _buildSendToBankButton(context),
                      const SizedBox(height: 20),
                      _buildSecondaryCards(context),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
                      const SizedBox(height: 20),
                      _buildGoProBanner(context),
                      const SizedBox(height: 20),
                      _buildRecentActivity(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final greetingText = _userFirstName.isNotEmpty
        ? 'Hi, $_userFirstName'
        : 'Hi there';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greetingText,
              style: const TextStyle(
                fontSize: 19,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Welcome!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                )
                .then((_) => _fetchUnreadCount());
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.tealTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none,
                  color: AppColors.teal,
                  size: 20,
                ),
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD64545),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      _unreadNotificationCount > 9
                          ? '9+'
                          : '$_unreadNotificationCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(BuildContext context) {
    final spendable = _walletData?.spendableBalance ?? 0;
    final planLabel = _walletData?.currentPlan != null
        ? _frequencyLabel(_walletData!.currentPlan!.frequency)
        : 'No plan yet';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Spendable balance',
                style: TextStyle(fontSize: 15, color: Colors.white),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    isShowing = !isShowing;
                  });
                },
                icon: isShowing
                    ? Icon(Icons.visibility, color: Colors.white70)
                    : Icon(Icons.visibility_off, color: Colors.white70),
                iconSize: 22,
              ),
            ],
          ),
          const SizedBox(height: 1),
          _isLoadingWallet
              ? const SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isShowing ? _formatNaira(spendable) : '****',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isLoadingWallet ? 'Loading...' : _nextPayoutLabel(),
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  planLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoProBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.teal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Unlock AI chat & more',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tealDark,
                        ),
                      ),
                      Text(
                        'Go Pro for advanced insights',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 72, 108, 152),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const GoProScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Go Pro',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendToBankButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) {
                  return SendToBankScreen();
                },
              ),
            )
            .then((_) {
              _fetchWallet();
              _fetchTransactions();
            });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 241, 240, 240),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.arrow_upward, size: 16, color: AppColors.teal),
            SizedBox(width: 6),
            Text(
              'Send to bank',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (
        icon: Icons.call,
        label: 'Airtime',
        builder: (BuildContext c) => const AirtimeScreen(),
      ),
      (
        icon: Icons.wifi,
        label: 'Data',
        builder: (BuildContext c) => const DataScreen(),
      ),
      (
        icon: Icons.bolt,
        label: 'Electricity',
        builder: (BuildContext c) => const ElectricityScreen(),
      ),
      (
        icon: Icons.live_tv_sharp,
        label: 'Cable',
        builder: (BuildContext c) => const CableScreen(),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((a) {
        return Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: a.builder)).then((_) {
                  _fetchWallet();
                  _fetchTransactions();
                });
              },
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 245, 243, 243),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(a.icon, color: AppColors.teal, size: 28),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              a.label,
              style: const TextStyle(
                fontSize: 13.7,
                color: Color.fromARGB(255, 31, 34, 37),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSecondaryCards(BuildContext context) {
    final locked = _walletData?.lockedBalance ?? 0;

    return Row(
      children: [
        Expanded(
          child: _secondaryCard(
            Icons.lock_outline,
            'Locked balance',
            _isLoadingWallet
                ? '...'
                : (isLockedBalanceShowing ? _formatNaira(locked) : '****'),
            isValueHidden: !isLockedBalanceShowing,
            onToggleVisibility: () {
              setState(() => isLockedBalanceShowing = !isLockedBalanceShowing);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (context) => AddFundsScreen()));
            },
            child: _secondaryCard(
              Icons.arrow_downward,
              'Add funds',
              'Deposit now →',
              isLink: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _secondaryCard(
    IconData icon,
    String label,
    String value, {
    bool isLink = false,
    bool? isValueHidden,
    VoidCallback? onToggleVisibility,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 242, 241, 241),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: AppColors.teal),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (onToggleVisibility != null)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onToggleVisibility,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      isValueHidden == true
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 16,
                      color: AppColors.teal,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isLink ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: isLink ? AppColors.teal : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent activity',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (_transactions.isNotEmpty)
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TransactionHistoryScreen(),
                  ),
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isLoadingTransactions)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            ),
          )
        else if (_transactions.isEmpty)
          _buildEmptyActivityState()
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _transactions.asMap().entries.map((entry) {
                final index = entry.key;
                final txn = entry.value;
                final outgoing = transactionIsOutgoing(txn.transactionType);
                final sign = outgoing ? '-' : '+';
                final amountColor = outgoing
                    ? const Color(0xFFD64545)
                    : AppColors.teal;

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: index == 0
                        ? null
                        : const Border(
                            top: BorderSide(
                              color: AppColors.border,
                              width: 0.5,
                            ),
                          ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.tealTint,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              transactionIconFor(txn.transactionType),
                              size: 19,
                              color: AppColors.teal,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transactionTitleFor(txn.transactionType),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Color.fromARGB(255, 0, 0, 0),
                                ),
                              ),
                              Text(
                                formatTransactionTime(txn.createdAt),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color.fromARGB(255, 107, 112, 119),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '$sign${_formatNaira(txn.amount)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: amountColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyActivityState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppColors.tealTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.teal,
              size: 25,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your deposits and payouts will show up here.',
            style: TextStyle(
              fontSize: 14,
              color: Color.fromARGB(255, 122, 130, 145),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
