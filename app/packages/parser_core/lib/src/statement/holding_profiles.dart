import 'package:parser_core/src/text/rx.dart';

/// One known export layout: the platform, the sender pattern and the header
/// row.
class HoldingProfile {
  /// Creates a profile.
  HoldingProfile(
    this.platform,
    String sender,
    this.header, {
    required this.verified,
    String? label,
  })  : sender = rx(sender),
        label = label ?? platform;

  /// Platform name.
  final String platform;

  /// Sender (or file name) pattern.
  final RegExp sender;

  /// Header row of the export.
  final List<String> header;

  /// True where the layout was confirmed from a real export or the platform's
  /// own page.
  final bool verified;

  /// Display label.
  final String label;
}

/// The apps and brokers whose holdings exports are read, with the header row
/// each is known to use. `HoldingColumns` reads any of them by column names;
/// the profiles name the platform from the sender and document the layouts
/// (they are the fixtures of the profile tests).
abstract final class HoldingProfiles {
  /// Every known layout.
  static final List<HoldingProfile> all = [
    HoldingProfile(
      'Groww',
      'groww',
      [
        'Scheme Name', 'AMC', 'Category', 'Sub-category', 'Folio No.', //
        'Source', 'Units', 'Invested Value', 'Current Value', 'Returns',
        'XIRR',
      ],
      verified: true,
      label: 'Groww mutual funds',
    ),
    HoldingProfile(
      'Groww',
      'groww',
      [
        'Stock Name', 'ISIN', 'Quantity', 'Average buy price', 'Buy value', //
        'Closing price', 'Closing value', 'Unrealised P&L',
      ],
      verified: true,
      label: 'Groww stocks',
    ),
    HoldingProfile(
      'Zerodha',
      r'zerodha|kite\.|\bcoin\b',
      [
        'Symbol', 'ISIN', 'Sector', 'Quantity Available', //
        'Quantity Discrepant', 'Quantity Long Term',
        'Quantity Pledged (Margin)', 'Quantity Pledged (Loan)',
        'Average Price', 'Previous Closing Price', 'Unrealized P&L',
        'Unrealized P&L Pct.',
      ],
      verified: true,
      label: 'Zerodha Console',
    ),
    HoldingProfile(
      'Zerodha',
      r'zerodha|\bcoin\b',
      [
        'Instrument', 'Qty.', 'Avg. cost', 'LTP', 'Invested', 'Cur. val', //
        'P&L', 'Net chg.', 'Day chg.',
      ],
      verified: false,
      label: 'Zerodha Coin',
    ),
    HoldingProfile(
      'Kuvera',
      'kuvera',
      [
        'Scheme Name', 'Folio Number', 'Units', 'Average NAV', //
        'Invested Amount', 'Current NAV', 'Current Value', 'Gain/Loss',
        'XIRR',
      ],
      verified: false,
    ),
    HoldingProfile(
      'INDmoney',
      'indmoney',
      [
        'Fund Name', 'Folio Number', 'Units', 'Invested Value', //
        'Current Value', 'Returns', 'XIRR',
      ],
      verified: false,
    ),
    HoldingProfile(
      'Paytm Money',
      'paytm',
      [
        'Scheme Name', 'Folio No', 'Units', 'Invested Amount', //
        'Current Value', 'Returns (%)', 'XIRR',
      ],
      verified: false,
    ),
    HoldingProfile(
      'ET Money',
      'etmoney',
      [
        'Scheme Name', 'Folio Number', 'Units', 'Invested Amount', //
        'Current Value', 'Absolute Returns', 'XIRR',
      ],
      verified: false,
    ),
    HoldingProfile(
      'Upstox',
      'upstox',
      [
        'Company Name', 'ISIN', 'Quantity', 'Average Price', //
        'Last Traded Price', 'Invested Value', 'Current Value', 'P&L',
        'P&L %',
      ],
      verified: false,
    ),
    HoldingProfile(
      'Angel One',
      'angel',
      [
        'Symbol', 'ISIN', 'Quantity', 'Average Price', 'LTP', //
        'Invested Value', 'Current Value', 'Unrealized P&L',
        'Net Change %',
      ],
      verified: false,
    ),
    HoldingProfile(
      'Dhan',
      r'\bdhan',
      [
        'Trading Symbol', 'ISIN', 'Quantity', 'Avg Cost Price', 'LTP', //
        'Total Value', 'P&L', 'P&L %',
      ],
      verified: false,
    ),
    HoldingProfile(
      'ICICI Direct',
      'icici ?direct|icicisecurities',
      [
        'Stock Name', 'Stock Symbol', 'ISIN', 'Qty', 'Average Cost Price', //
        'Current Market Price', 'Value At Cost', 'Value At Market Price',
        'Unrealized P&L',
      ],
      verified: false,
    ),
    HoldingProfile(
      'HDFC Securities',
      'hdfcsec',
      [
        'Scrip Name', 'ISIN', 'Qty', 'Avg Price', 'CMP', 'Buy Value', //
        'Market Value', 'Unrealised Profit/Loss',
      ],
      verified: false,
    ),
    HoldingProfile(
      'Kotak Securities',
      'kotak ?sec|kotakneo',
      [
        'Security Name', 'ISIN', 'Quantity', 'Average Price', //
        'Closing Price', 'Total Cost', 'Market Value', 'Unrealised P&L',
      ],
      verified: false,
    ),
    HoldingProfile(
      'MFCentral',
      'mfcentral',
      [
        'Scheme Name', 'ISIN', 'Folio No', 'AMC', 'Closing Unit Balance', //
        'NAV', 'Cost Value', 'Market Value',
      ],
      verified: false,
    ),
    HoldingProfile(
      'CAMS',
      'cams',
      [
        'Scheme Name', 'Folio No', 'ISIN', 'Closing Unit Balance', 'NAV', //
        'Cost Value (INR)', 'Market Value (INR)',
      ],
      verified: false,
    ),
    HoldingProfile(
      'KFintech',
      'kfin|karvy',
      [
        'Fund Name', 'Scheme Name', 'Folio', 'Units', 'NAV', 'Cost Value', //
        'Current Value',
      ],
      verified: false,
    ),
  ];

  /// The platform a sender (or file name) belongs to, or null.
  static String? platformOf(String sender) {
    for (final p in all) {
      if (p.sender.hasMatch(sender)) return p.platform;
    }
    return null;
  }
}
