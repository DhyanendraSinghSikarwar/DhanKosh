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

/// The 19-app allow-list, 20 packages (FR-04-01).
abstract final class PaymentApps {
  /// Every allowed package.
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

  /// Allow-list package names, pushed to the native listener.
  static List<String> get packages => [for (final a in all) a.packageName];

  /// The app for [packageName], or null when not allow-listed.
  static PaymentApp? byPackage(String packageName) {
    for (final a in all) {
      if (a.packageName == packageName) return a;
    }
    return null;
  }

  /// Distinct display names for the "watched apps" list.
  static List<String> get displayNames =>
      {for (final a in all) a.displayName}.toList();
}
