/// A known payment or bank app (FR-04-01).
class PaymentApp {
  /// Creates a [PaymentApp].
  const PaymentApp(
    this.packageName,
    this.displayName, {
    this.isUpiApp = false,
    this.isChatApp = false,
  });

  /// Android package.
  final String packageName;

  /// Name shown to the user and used as the parse sender.
  final String displayName;

  /// Default channel becomes UPI when the parser finds none.
  final bool isUpiApp;

  /// Also posts chats (WhatsApp); needs the chat guard (FR-04-05).
  final bool isChatApp;
}

/// The built-in apps the user switched off, and the extra apps they added
/// themselves (FR-04-19, FR-04-20).
class WatchedApps {
  /// Creates a [WatchedApps].
  const WatchedApps({this.disabled = const {}, this.extra = const {}});

  /// Built-in packages the user turned off; they are not read.
  final Set<String> disabled;

  /// Packages the user added, mapped to the label to show and parse with.
  final Map<String, String> extra;

  /// Nothing changed from the defaults.
  bool get isDefault => disabled.isEmpty && extra.isEmpty;
}

/// The built-in allow-list, plus resolution against the user's own choices
/// (FR-04-01, FR-04-19, FR-04-20).
abstract final class PaymentApps {
  /// Every built-in package.
  static const all = <PaymentApp>[
    PaymentApp(
      'com.google.android.apps.nbu.paisa.user',
      'Google Pay',
      isUpiApp: true,
    ),
    PaymentApp('com.phonepe.app', 'PhonePe', isUpiApp: true),
    PaymentApp('net.one97.paytm', 'Paytm', isUpiApp: true),
    PaymentApp('in.org.npci.upiapp', 'BHIM', isUpiApp: true),
    PaymentApp('com.dreamplug.androidapp', 'CRED', isUpiApp: true),
    PaymentApp(
      'in.amazon.mShop.android.shopping',
      'Amazon Pay',
      isUpiApp: true,
    ),
    PaymentApp('com.mobikwik_new', 'MobiKwik', isUpiApp: true),
    PaymentApp('com.naviapp', 'Navi', isUpiApp: true),
    PaymentApp('money.super.payments', 'super.money', isUpiApp: true),
    PaymentApp('com.freecharge.android', 'Freecharge'),
    PaymentApp('com.sbi.upi', 'BHIM SBI Pay', isUpiApp: true),
    PaymentApp('com.sbi.lotusintouch', 'YONO SBI'),
    PaymentApp('com.snapwork.hdfc', 'HDFC Bank'),
    PaymentApp('com.csam.icici.bank.imobile', 'ICICI iMobile'),
    PaymentApp('com.axis.mobile', 'Axis Mobile'),
    PaymentApp('com.msf.kbank.mobile', 'Kotak Bank'),
    PaymentApp('com.samsung.android.spay', 'Samsung Wallet'),
    PaymentApp('com.samsung.android.spaymini', 'Samsung Pay Mini'),
    // Added 2026-11-05 (FR-04-19): UPI and bank apps that also pay without a
    // bank SMS. Package names verified against their store listings.
    PaymentApp('indwin.c3.shareapp', 'slice', isUpiApp: true),
    PaymentApp('money.jupiter', 'Jupiter', isUpiApp: true),
    PaymentApp('com.epifi.paisa', 'Fi Money', isUpiApp: true),
    PaymentApp('com.myairtelapp', 'Airtel Thanks', isUpiApp: true),
    PaymentApp('com.jio.myjio', 'MyJio', isUpiApp: true),
    PaymentApp('org.altruist.BajajExperia', 'Bajaj Finserv', isUpiApp: true),
    PaymentApp('com.hdfcbank.payzapp', 'PayZapp', isUpiApp: true),
    PaymentApp('com.idfcfirstbank.optimus', 'IDFC FIRST Bank'),
    PaymentApp('com.bankofbaroda.mconnect', 'bob World'),
    PaymentApp('com.bankofbaroda.upi', 'BHIM Baroda Pay', isUpiApp: true),
    PaymentApp('com.canarabank.mobility', 'Canara ai1'),
    PaymentApp('com.fedmobile', 'Fed Mobile'),
    PaymentApp(
      'com.whatsapp',
      'WhatsApp Pay',
      isUpiApp: true,
      isChatApp: true,
    ),
    PaymentApp(
      'com.whatsapp.w4b',
      'WhatsApp Pay',
      isUpiApp: true,
      isChatApp: true,
    ),
  ];

  /// Every built-in package name.
  static List<String> get packages => [for (final a in all) a.packageName];

  /// The built-in app for [packageName], or null when it is not one.
  static PaymentApp? byPackage(String packageName) {
    for (final a in all) {
      if (a.packageName == packageName) return a;
    }
    return null;
  }

  /// The package names the native listener filters with: the built-ins the
  /// user left on, plus the ones they added (FR-04-19, FR-04-20).
  static List<String> effectivePackages(WatchedApps watched) => [
        for (final a in all)
          if (!watched.disabled.contains(a.packageName)) a.packageName,
        for (final p in watched.extra.keys)
          if (byPackage(p) == null) p,
      ];

  /// The app to read [packageName] as, or null when it is not watched. A
  /// built-in the user switched off is not watched; an app they added is read
  /// as a UPI app under the label the phone gave it (FR-04-19, FR-04-20).
  static PaymentApp? resolve(String packageName, WatchedApps watched) {
    final built = byPackage(packageName);
    if (built != null) {
      return watched.disabled.contains(packageName) ? null : built;
    }
    final label = watched.extra[packageName];
    if (label == null) return null;
    return PaymentApp(packageName, label, isUpiApp: true);
  }

  /// Distinct display names of the built-in apps.
  static List<String> get displayNames =>
      {for (final a in all) a.displayName}.toList();
}
