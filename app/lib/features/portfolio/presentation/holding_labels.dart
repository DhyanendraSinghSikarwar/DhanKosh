import 'package:hisaab/features/portfolio/domain/asset_class.dart';

/// UI label of a holding kind (FR-16-08).
String holdingKindLabel(HoldingKind k) => switch (k) {
      HoldingKind.mutualFund => 'Mutual funds',
      HoldingKind.stock => 'Stocks',
      HoldingKind.etf => 'ETFs',
      HoldingKind.epf => 'EPF',
      HoldingKind.nps => 'NPS',
      HoldingKind.ppf => 'PPF',
      HoldingKind.bond => 'Bonds',
      HoldingKind.gold => 'Gold',
      HoldingKind.fd => 'Deposits',
      HoldingKind.other => 'Others',
    };
