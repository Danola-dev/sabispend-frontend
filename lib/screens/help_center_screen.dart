import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';
import 'contact_support_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  // TODO: expand this list with real, finalized FAQ content before launch.
  static final List<_FaqItem> _faqs = [
    _FaqItem(
      question: 'How does my payout plan work?',
      answer:
          'You choose a frequency (daily, weekly, biweekly, or monthly) '
          'and an amount. Your locked balance is released to your spendable '
          'balance on that schedule. Once set, your plan stays locked until '
          'your next payout — you can change it then.',
    ),
    _FaqItem(
      question: 'What happens if I run out of money before my next payout?',
      answer:
          'You\'re not stuck. You can unlock part of your locked balance early, '
          'anytime — just choose the amount you need. It moves straight into '
          'your spendable balance.',
    ),
    _FaqItem(
      question: 'How do I add money to my account?',
      answer:
          'Go to Add Funds on your home screen to see your dedicated '
          'account number. Any transfer to that account is added to your '
          'locked balance automatically.',
    ),
    _FaqItem(
      question: 'Why do I need to verify my BVN?',
      answer:
          'BVN verification is required by our banking partner to '
          'generate your personal account number and keep your funds '
          'secure, in line with CBN regulations.',
    ),
    _FaqItem(
      question: 'Are there fees for sending money or paying bills?',
      answer:
          'Some transfers and bill payments include a small fee, shown '
          'clearly before you confirm any transaction. Go Pro members get '
          'reduced or waived fees on eligible transactions.',
    ),
    _FaqItem(
      question: 'How do I delete my account?',
      answer:
          'Go to Profile > Delete account. Note that any locked '
          'balance must be withdrawn first, and this action can\'t be undone.',
    ),
  ];

  List<_FaqItem> get _filteredFaqs {
    if (_query.trim().isEmpty) return _faqs;
    final q = _query.toLowerCase();
    return _faqs
        .where(
          (f) =>
              f.question.toLowerCase().contains(q) ||
              f.answer.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          'Help center',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Search for help',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14.5,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.teal,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _filteredFaqs.isEmpty
                  ? const Center(
                      child: Text(
                        'No results found',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemCount: _filteredFaqs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) =>
                          _FaqTile(item: _filteredFaqs[index]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ContactSupportScreen(),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.tealTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 17,
                        color: AppColors.teal,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Still need help? Contact support',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.teal,
                        ),
                      ),
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
}

class _FaqItem {
  final String question;
  final String answer;

  _FaqItem({required this.question, required this.answer});
}

class _FaqTile extends StatefulWidget {
  final _FaqItem item;

  const _FaqTile({required this.item});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.question,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.remove : Icons.add,
                  size: 18,
                  color: AppColors.teal,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Text(
                widget.item.answer,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
