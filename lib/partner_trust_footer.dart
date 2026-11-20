import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';

/// The small "who we work with" strip at the bottom of the sign-in screen.
///
/// Needs two logo files (see SETUP_STEPS.md):
///   assets/images/9psb_logo.png   and   assets/images/cbn_logo.png
/// If a logo file is missing the text still shows, without crashing.
class PartnerTrustFooter extends StatelessWidget {
  const PartnerTrustFooter({super.key});

  static const String _ninepsbLogo = 'assets/images/9psb_logo.png';
  static const String _cbnLogo = 'assets/images/cbn_logo.png';

  // How all the normal words look.
  static const TextStyle _baseStyle = TextStyle(
    fontSize: 14.5,
    color: Color.fromARGB(255, 39, 41, 44),
    height: 1.3,
  );

  // How ONLY the word "CBN" looks. Change anything here and only "CBN" changes.
  //   fontWeight: FontWeight.w400 (normal) ... w600 ... w800 (extra bold)
  //   fontStyle:  FontStyle.italic  or  FontStyle.normal
  //   color:      AppColors.teal, AppColors.textPrimary, Colors.black, Color(0xFF006838) ...
  //   letterSpacing: 0.5   (spreads the letters a little)
  //   fontFamily: 'YourFont'  (only if that font is added in pubspec.yaml; see the note below)
  static const TextStyle _cbnStyle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 19,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            _line(const [
              TextSpan(text: 'In partnership with 9 Payment Service Bank'),
            ], _ninepsbLogo),
            const SizedBox(height: 8),
            // The licence line is about the bank. Keep it clear that it is 9PSB (not SabiSpend)
            // that holds the CBN licence.
            _line(const [
              TextSpan(text: '9PSB is duly licensed by the '),
              TextSpan(text: 'CBN', style: _cbnStyle),
            ], _cbnLogo),
          ],
        ),
      ),
    );
  }

  Widget _line(List<InlineSpan> spans, String logoAsset) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text.rich(TextSpan(style: _baseStyle, children: spans)),
        Image.asset(
          logoAsset,
          height: 23,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
