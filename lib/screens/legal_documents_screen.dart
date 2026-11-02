import 'package:flutter/material.dart';
import 'package:first_app/app_colors.dart';

/// Reusable screen for rendering a legal document (Privacy Policy, Terms
/// of Service, etc). Both are needed for Apple/Google App Store review —
/// they must be accessible in-app, not just linked in the store listing.
///
/// IMPORTANT: this is a substantive DRAFT tailored to how the app
/// actually works, not generic filler — but it is still a draft. Before
/// launch, have a lawyer familiar with the Nigeria Data Protection Act
/// 2023 (NDPA) and CBN/fintech consumer regulations review it, in
/// particular the limitation-of-liability and dispute-resolution
/// sections. Replace every [BRACKETED] placeholder with your real
/// business details before publishing.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final List<LegalSection> sections;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  factory LegalDocumentScreen.privacyPolicy() {
    return LegalDocumentScreen(
      title: 'Privacy Policy',
      lastUpdated: 'Last updated: 01/09/2026',
      sections: [
        LegalSection(
          heading: 'Who we are',
          body:
              'SabiSpend is operated by DAMIBIUDIV VENTURES LIMITED, a business registered in Nigeria with CAC registration '
              'number: 1708911, registered address at NIIT Road, Etegwe, Yenagoa, Bayelsa State. This '
              'policy explains what personal data we collect when you use '
              'our app, why we collect it, and the rights you have over it '
              'under the Nigeria Data Protection Act, 2023 (NDPA).',
        ),
        LegalSection(
          heading: 'Information we collect',
          body:
              'To create an account and use the app, we collect: your full '
              'name, phone number, and email address at '
              'signup; your Bank Verification Number (BVN) and the details '
              'of a bank account you nominate, which we submit to our '
              'licensed payment processing partner to verify your identity '
              'and generate your personal deposit account number; your '
              'transaction history within the app, including deposits, '
              'transfers, and payout schedule choices; and basic device '
              'information (device type, OS version, app version) used for '
              'security and troubleshooting. We do not collect your BVN for '
              'any purpose beyond identity verification, and we never store '
              'it in plain, unencrypted form.',
        ),
        LegalSection(
          heading: 'How we use your information',
          body:
              'We use your information to: verify your identity before '
              'enabling deposits or transfers (a legal requirement, not '
              'optional); generate and maintain your dedicated deposit '
              'account; process transfers you authorize; detect and '
              'prevent fraud; send you transaction notifications and '
              'one-time passcodes for account security; and respond to '
              'support requests. We do not use your financial data for '
              'targeted advertising, and we do not sell your personal data '
              'to third parties, ever.',
        ),
        LegalSection(
          heading: 'Who we share it with',
          body:
              'We share the minimum data necessary with: our licensed '
              'payment processing partner (currently Paystack), which '
              'handles BVN verification, deposit account generation, and '
              'the actual movement of money — they process this data under '
              'their own privacy and regulatory obligations as a licensed '
              'payment service provider; SMS/OTP delivery providers, solely '
              'to send verification codes; and Nigerian regulatory or law '
              'enforcement authorities, only where we are legally required '
              'to. We do not share your data with advertisers or data '
              'brokers.',
        ),
        LegalSection(
          heading: 'How we protect your data',
          body:
              'Sensitive identity data, including your BVN, is stored '
              'encrypted at rest and is never displayed in full within the '
              'app or our internal tools. Your login PIN and transaction '
              'PIN are stored as one-way cryptographic hashes — we cannot '
              'see or recover them, even internally. Access to production '
              'systems containing personal data is restricted to '
              'authorized personnel only. No system is perfectly secure, '
              'and we cannot guarantee absolute security, but we take these '
              'obligations seriously and will notify affected users and the '
              'NDPC of any data breach as required by law.',
        ),
        LegalSection(
          heading: 'How long we keep your data',
          body:
              'We retain your account and transaction data for as long as '
              'your account is active, and for a period afterward as '
              'required by Nigerian financial recordkeeping regulations, '
              'even if you delete your account. Data that is no longer '
              'legally required to be retained is deleted or irreversibly '
              'anonymized.',
        ),
        LegalSection(
          heading: 'Your rights',
          body:
              'Under the NDPA, you have the right to: access the personal '
              'data we hold about you; request correction of inaccurate '
              'data; request deletion of your data, subject to our legal '
              'obligation to retain certain financial records; object to '
              'certain processing; and lodge a complaint with the Nigeria '
              'Data Protection Commission (NDPC) if you believe your rights '
              'have been violated. To exercise any of these rights, contact '
              'us using the details below.',
        ),
        LegalSection(
          heading: 'Children',
          body:
              'This app is not intended for anyone under 15. We do not '
              'knowingly collect data from minors. If you believe a minor '
              'has created an account, contact us and we will investigate '
              'and remove it.',
        ),
        LegalSection(
          heading: 'Changes to this policy',
          body:
              'We may update this policy as our app or legal obligations '
              'change. We\'ll update the date at the top of this page, and '
              'notify you in-app of any material change before it takes '
              'effect.',
        ),
        LegalSection(
          heading: 'Contact us',
          body:
              'For any privacy question or to exercise your rights under '
              'the NDPA, contact us at sabispend@gmail.com. If you\'re '
              'unsatisfied with our response, you may lodge a complaint '
              'with the Nigeria Data Protection Commission at ndpc.gov.ng.',
        ),
      ],
    );
  }

  factory LegalDocumentScreen.termsOfService() {
    return LegalDocumentScreen(
      title: 'Terms of Service',
      lastUpdated: 'Last updated: 01/09/2026',
      sections: [
        LegalSection(
          heading: 'Acceptance of these terms',
          body:
              'By creating an account with SabiSpend, you agree to these '
              'Terms of Service and our Privacy Policy. If you don\'t agree, '
              'please don\'t use the app. These terms form a binding '
              'agreement between you and SabiSpend.',
        ),
        LegalSection(
          heading: 'Who can use this app',
          body:
              'You must be at least 18 years old, a resident of Nigeria '
              'with a valid Bank Verification Number (BVN), and legally '
              'able to enter into this agreement. You may only create one '
              'account, and it must be in your own real name — accounts '
              'may not be created on behalf of someone else or under a '
              'false identity.',
        ),
        LegalSection(
          heading: 'Identity verification',
          body:
              'Before you can fund your wallet, you must complete identity '
              'verification by submitting your BVN and a bank account in '
              'your name, which we verify through our licensed payment '
              'processing partner. We may decline, suspend, or reverse '
              'verification, and may request additional information, at '
              'our reasonable discretion, particularly where required for '
              'fraud prevention or regulatory compliance.',
        ),
        LegalSection(
          heading: 'How your wallet works',
          body:
              'Money you deposit is held as "locked balance" and released '
              'to your "spendable balance" according to the payout '
              'schedule you set. You may access part of your locked '
              'balance early ("Early Unlock") at any time; doing so does '
              'not incur a fee under our current pricing, though we may '
              'introduce fees or limits on this feature in the future with '
              'reasonable prior notice. We do not pay interest on any '
              'balance held in the app.',
        ),
        LegalSection(
          heading: 'Transfers and fees',
          body:
              'You may transfer your spendable balance to your own bank '
              'account or to a third party you specify. Transfers are '
              'subject to a service fee, disclosed to you before you '
              'confirm each transfer, in addition to any applicable '
              'government charges (such as stamp duty on qualifying '
              'transfer amounts). Once you confirm a transfer, it cannot '
              'be cancelled or reversed by us, except where the transfer '
              'itself fails for a technical or banking reason, in which '
              'case the full amount debited — including fees — is returned '
              'to your spendable balance.',
        ),
        LegalSection(
          heading: 'Your security responsibilities',
          body:
              'You are responsible for keeping your login PIN, transaction '
              'PIN, and device access secure. Never share your PIN or '
              'one-time passcodes with anyone, including someone claiming '
              'to represent us — we will never ask for them. You must '
              'notify us immediately if you suspect unauthorized access to '
              'your account. We are not liable for losses resulting from '
              'your failure to keep your credentials secure.',
        ),
        LegalSection(
          heading: 'Prohibited use',
          body:
              'You may not use this app for money laundering, terrorist '
              'financing, fraud, or any other illegal activity; to '
              'circumvent our identity verification requirements; to '
              'access another user\'s account without authorization; or to '
              'interfere with the app\'s normal operation. We may suspend '
              'or terminate accounts we reasonably believe are involved in '
              'prohibited activity, and may be required to report such '
              'activity to relevant authorities.',
        ),
        LegalSection(
          heading: 'Third-party services',
          body:
              'We rely on licensed third parties — including our payment '
              'processing partner — to move and verify money on your '
              'behalf. While we choose these partners carefully, we are '
              'not responsible for delays, failures, or errors that '
              'originate entirely on their systems and are outside our '
              'reasonable control, though we will make reasonable efforts '
              'to help resolve such issues on your behalf.',
        ),
        LegalSection(
          heading: 'Account suspension and termination',
          body:
              'You may close your account at any time, provided your '
              'locked balance has first been withdrawn. We may suspend or '
              'terminate your account if we reasonably suspect fraud, '
              'illegal activity, or a breach of these terms, or where '
              'required by law or our regulatory obligations. Where '
              'reasonably possible, we will notify you and give you the '
              'opportunity to withdraw your funds before termination.',
        ),
        LegalSection(
          heading: 'No investment or financial advice',
          body:
              'This app is a tool for managing your own money — it does '
              'not provide investment, tax, or financial advice, and '
              'nothing in the app should be interpreted as a '
              'recommendation to make any particular financial decision.',
        ),
        LegalSection(
          heading: 'Contact us',
          body:
              'Questions about these terms can be sent to '
              'sabispend@gmail.com.',
        ),
      ],
    );
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
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lastUpdated,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color.fromARGB(255, 118, 123, 132),
                ),
              ),
              const SizedBox(height: 20),
              ...sections.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.heading,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        section.body,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 67, 71, 75),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class LegalSection {
  final String heading;
  final String body;

  const LegalSection({required this.heading, required this.body});
}
