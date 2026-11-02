/// A saved transfer recipient, so the user doesn't have to re-enter
/// account details every time they send to someone they've paid before.
class Beneficiary {
  final String accountName;
  final String accountNumber;
  final String bank;

  const Beneficiary({
    required this.accountName,
    required this.accountNumber,
    required this.bank,
  });
}

/// In-memory store for saved beneficiaries.
///
/// TODO: this is the seam to replace with real persistence (backend API
/// or local database) later. Everything reading/writing here already goes
/// through this single class, so swapping the storage mechanism won't
/// require touching the UI screens.
class BeneficiaryStore {
  BeneficiaryStore._internal();
  static final BeneficiaryStore instance = BeneficiaryStore._internal();

  final List<Beneficiary> _beneficiaries = [
    // A couple of seeded examples so the picker isn't empty during UI work.
    const Beneficiary(
      accountName: 'ADAEZE C. OKONKWO',
      accountNumber: '0123456789',
      bank: 'GTBank',
    ),
    const Beneficiary(
      accountName: 'CHUKWUDI B. EZE',
      accountNumber: '9876543210',
      bank: 'Access Bank',
    ),
  ];

  List<Beneficiary> get all => List.unmodifiable(_beneficiaries);

  bool isSaved({required String accountNumber, required String bank}) {
    return _beneficiaries.any(
      (b) => b.accountNumber == accountNumber && b.bank == bank,
    );
  }

  void save(Beneficiary beneficiary) {
    if (isSaved(
      accountNumber: beneficiary.accountNumber,
      bank: beneficiary.bank,
    ))
      return;
    _beneficiaries.insert(0, beneficiary);
  }
}
