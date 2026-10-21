/// What a column of a holdings sheet holds, whichever platform exported it.
enum HoldingField {
  name,
  symbol,
  isin,
  amc,
  category,
  subCategory,
  folio,
  source,
  units,
  avgPrice,
  invested,
  current,
  price,
  gain,
  gainPct,
  xirr,
  asOf,
}

/// Header synonyms for holdings sheets (Groww, Zerodha, Kuvera, INDmoney,
/// brokers, CAMS/KFin ...), one registry for all platforms. A header is
/// normalised ([key]: lower case, brackets with units dropped, only letters and
/// digits kept, "%" as "pct") and looked up in the synonym table; a header not
/// listed falls back to fragments. The first column of a field wins.
abstract final class HoldingColumns {
  static const Map<HoldingField, Set<String>> _synonyms = {
    HoldingField.name: {
      'schemename', 'scheme', 'fundname', 'fund', 'stockname', 'security', //
      'securityname', 'instrument', 'instrumentname', 'companyname',
      'company', 'holdingname', 'holding', 'name', 'assetname', 'asset',
      'scripname', 'scrip', 'script', 'productname', 'schemenameamc',
    },
    HoldingField.symbol: {
      'symbol', 'ticker', 'tradingsymbol', 'scripsymbol', 'stocksymbol', //
      'scripcode', 'tickersymbol',
    },
    HoldingField.isin: {'isin', 'isincode', 'isinno', 'isinnumber', 'isinnum'},
    HoldingField.amc: {
      'amc', 'amcname', 'fundhouse', 'fundhousename', //
      'assetmanagementcompany', 'mutualfund',
    },
    HoldingField.category: {
      'category', 'assetclass', 'assettype', 'schemetype', 'schemecategory', //
      'sector', 'type',
    },
    HoldingField.subCategory: {
      'subcategory',
      'subcat',
      'schemesubcategory',
      'subassetclass',
    },
    HoldingField.folio: {
      'foliono',
      'folio',
      'folionumber',
      'folioid',
      'folionos',
    },
    HoldingField.source: {
      'source',
      'platform',
      'broker',
      'distributor',
      'channel',
    },
    HoldingField.units: {
      'units', 'unit', 'closingunits', 'closingunitbalance', 'unitbalance', //
      'balanceunits', 'availableunits', 'totalunits', 'currentunits',
      'quantity', 'qty', 'quantityavailable', 'netquantity', 'netqty',
      'holdingqty', 'holdingquantity', 'totalquantity', 'totalqty',
      'currentquantity', 'openquantity', 'shares', 'noofshares',
    },
    HoldingField.avgPrice: {
      'averageprice', 'avgprice', 'avgcost', 'averagecost',
      'averagebuyprice', //
      'avgbuyprice', 'averagenav', 'avgnav', 'buyaverage', 'buyavg',
      'avgcostprice', 'averagecostprice', 'purchasenav', 'buyprice',
      'costprice', 'unitcost', 'averagepurchaseprice', 'avgpurchaseprice',
    },
    HoldingField.invested: {
      'investedvalue', 'investedamount', 'invested', 'investment', //
      'investmentvalue', 'investmentamount', 'totalinvestment',
      'totalinvestments', 'totalinvested', 'totalcost', 'costvalue', 'cost',
      'purchasevalue', 'purchaseamount', 'buyvalue', 'buyamount',
      'amountinvested', 'investedamt', 'valueatcost', 'holdingcost',
      'acquisitioncost', 'costofinvestment', 'totalbuyvalue',
      'totalpurchasecost',
    },
    HoldingField.current: {
      'currentvalue', 'currentamount', 'currentamt', 'curval', 'marketvalue', //
      'currentmarketvalue', 'valuation', 'closingvalue', 'presentvalue',
      'current', 'value', 'totalvalue', 'latestvalue', 'marketval',
      'valueatmarketprice', 'valueatmarket', 'openvalue', 'portfoliovalue',
      'currentinvestmentvalue',
    },
    HoldingField.price: {
      'nav', 'currentnav', 'latestnav', 'ltp', 'lastprice', 'closingprice', //
      'previousclosingprice', 'prevclosingprice', 'previousclose',
      'closeprice', 'marketprice', 'currentprice', 'price',
      'lasttradedprice', 'cmp', 'latestprice', 'currentmarketprice',
      'navperunit',
    },
    HoldingField.gain: {
      'returns', 'return', 'gain', 'gains', 'gainloss', 'profitloss', //
      'profitandloss', 'pl', 'pnl', 'unrealizedpl', 'unrealisedpl',
      'unrealizedgain', 'unrealisedgain', 'unrealizedprofitloss',
      'unrealisedprofitloss', 'unrealizedgainloss', 'unrealisedgainloss',
      'totalreturns', 'absolutereturns', 'absolutereturn', 'netpl', 'totalpl',
      'overallgain', 'overallgainloss', 'gainlossamount', 'profitlossamount',
      'profit', 'unrealized', 'unrealised', 'unrealizedprofit',
      'unrealisedprofit',
    },
    HoldingField.gainPct: {
      'returnspct', 'returnpct', 'returnspercent', 'returnspercentage', //
      'plpct', 'pnlpct', 'unrealizedplpct', 'unrealisedplpct',
      'profitlosspct', 'gainlosspct', 'gainpct', 'absolutereturnspct',
      'absolutereturnpct', 'totalreturnpct', 'totalreturnspct',
      'gainlosspercent', 'percentagereturn', 'netchg', 'netchange',
    },
    HoldingField.xirr: {
      'xirr', 'xirrpct', 'annualisedreturns', 'annualizedreturns', //
      'annualisedreturn', 'annualizedreturn', 'cagr', 'irr', 'xirrreturns',
    },
    HoldingField.asOf: {
      'asondate', 'asofdate', 'valuationdate', 'navdate', 'holdingdate', //
      'asof', 'asat',
    },
  };

  /// Parts of a header that map it when it is not listed; checked in this
  /// order, so "avg price" is not read as a price.
  static const List<(HoldingField?, List<String>)> _fragments = [
    (
      null,
      [
        'longterm', 'pledged', 'collateral', 'discrepant', 'daychange', //
        'daychg', 'daypl', 'todays', 'weight', 'allocation', 'ofportfolio',
        'dayschange',
      ],
    ),
    (
      HoldingField.avgPrice,
      [
        'avgprice', 'avgcost', 'averageprice', 'averagecost', 'avgbuy', //
        'averagebuy', 'averagenav', 'avgnav',
      ],
    ),
    (HoldingField.xirr, ['xirr', 'cagr']),
    (
      HoldingField.invested,
      [
        'invested', 'investment', 'buyvalue', 'costvalue', 'purchasevalue', //
        'totalcost', 'valueatcost',
      ],
    ),
    (
      HoldingField.current,
      [
        'currentvalue', 'marketvalue', 'closingvalue', 'curval', //
        'presentvalue', 'currentamount', 'valuation', 'valueatmarket',
      ],
    ),
    (
      HoldingField.price,
      [
        'ltp',
        'closingprice',
        'currentprice',
        'marketprice',
        'currentnav',
        'latestnav',
      ],
    ),
    (
      HoldingField.gainPct,
      [
        'returnspercent', 'gainpercent', 'profitpercent', 'returnspct', //
        'gainpct', 'profitpct', 'plpct',
      ],
    ),
    (
      HoldingField.gain,
      ['gain', 'profit', 'returns', 'unrealized', 'unrealised'],
    ),
    (HoldingField.units, ['units', 'quantity', 'qty']),
    (HoldingField.folio, ['folio']),
    (HoldingField.isin, ['isin']),
    (HoldingField.amc, ['amc']),
    (HoldingField.category, ['category']),
    (HoldingField.source, ['platform']),
    (
      HoldingField.name,
      ['schemename', 'fundname', 'stockname', 'securityname', 'companyname'],
    ),
  ];

  static final RegExp _bracket = RegExp(r'\(([^)]*)\)');
  static final RegExp _nonAlnum = RegExp('[^a-z0-9]');

  /// A header cell reduced to letters and digits: "Unrealized P&L Pct." ->
  /// "unrealizedplpct"; "Returns (%)" -> "returnspct".
  static String key(String header) {
    var s = header.toLowerCase().replaceAll(' ', ' ');
    s = s.replaceAllMapped(
      _bracket,
      (m) => (m.group(1) ?? '').contains('%') ? ' pct' : '',
    );
    s = s.replaceAll('%', ' pct ');
    return s.replaceAll(_nonAlnum, '');
  }

  /// The field a header names, or null.
  static HoldingField? fieldOf(String header) {
    final k = key(header);
    if (k.isEmpty || k.length > 40) return null;
    for (final e in _synonyms.entries) {
      if (e.value.contains(k)) return e.key;
    }
    for (final (field, parts) in _fragments) {
      if (parts.any(k.contains)) return field;
    }
    return null;
  }

  /// Column index per field in a header row; the first column of a field wins.
  static Map<HoldingField, int> map(List<String> cells) {
    final out = <HoldingField, int>{};
    for (var i = 0; i < cells.length; i++) {
      final f = fieldOf(cells[i]);
      if (f == null) continue;
      out.putIfAbsent(f, () => i);
    }
    return out;
  }

  /// True when [cells] head a holdings table: at least three known fields, a
  /// name (name, symbol or ISIN), and enough to work out a current value (a
  /// value, units with a price, or invested with a gain). A table in dollars is
  /// left to the text reader, which converts at the statement's rate.
  static bool isHeader(List<String> cells) {
    if (cells.any((c) {
      if (c.contains(r'$')) return true;
      final k = key(c);
      return k == 'usd' || k.endsWith('usd');
    })) {
      return false;
    }
    final m = map(cells);
    if (m.length < 3) return false;
    final named = m.containsKey(HoldingField.name) ||
        m.containsKey(HoldingField.symbol) ||
        m.containsKey(HoldingField.isin);
    final f = m.keys.toSet();
    final value = f.contains(HoldingField.current) ||
        (f.contains(HoldingField.units) && f.contains(HoldingField.price)) ||
        (f.contains(HoldingField.invested) && f.contains(HoldingField.gain));
    // A table of dated transactions (units x NAV = amount) is not a holding
    // unless it states a current value.
    if (!f.contains(HoldingField.current) &&
        cells.any((c) {
          final k = key(c);
          return (k.endsWith('date') &&
                  !_synonyms[HoldingField.asOf]!.contains(k)) ||
              k == 'transactiontype';
        })) {
      return false;
    }
    // Every cell of a data row is a figure or a long name; a header is short
    // words.
    return named && value && !cells.any((c) => c.length > 60);
  }
}
