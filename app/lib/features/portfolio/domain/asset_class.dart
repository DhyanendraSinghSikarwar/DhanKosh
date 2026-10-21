/// Kind of holding (FR-16-08).
enum HoldingKind {
  mutualFund,
  stock,
  etf,
  epf,
  nps,
  ppf,
  bond,
  gold,
  fd,
  other
}

/// Where a holding figure came from.
enum HoldingSource { sms, email, statement, manual }

/// Net worth asset class; `cash` is liquid bank balances only.
enum AssetClass {
  equity('Equity'),
  retirement('Retirement'),
  debt('Debt & FD'),
  gold('Gold'),
  cash('Cash'),
  other('Others');

  const AssetClass(this.label);

  /// UI label.
  final String label;
}

/// Net worth breakdown part kinds (FR-16-06).
enum PartKind { bank, deposit, holding, loan, cardDue, others }

/// Liabilities that can be excluded (FR-16-04).
enum LiabilityKind { loans, cardDues }

/// Asset class of a holding kind (memory 16 section 3.2).
AssetClass assetClassOf(HoldingKind kind) => switch (kind) {
      HoldingKind.mutualFund ||
      HoldingKind.stock ||
      HoldingKind.etf =>
        AssetClass.equity,
      HoldingKind.epf ||
      HoldingKind.nps ||
      HoldingKind.ppf =>
        AssetClass.retirement,
      HoldingKind.fd || HoldingKind.bond => AssetClass.debt,
      HoldingKind.gold => AssetClass.gold,
      HoldingKind.other => AssetClass.other,
    };
