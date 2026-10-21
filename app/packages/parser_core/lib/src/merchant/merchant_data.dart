// Generated from the Kotlin MerchantDirectory by tools in the port; the data
// is the parity baseline, edit with care.

import 'package:parser_core/src/model/model.dart';

/// One directory row: identifying keys, display name, category.
class _E {
  const _E(this.keys, this.name, this.category);
  final List<String> keys;
  final String name;
  final Category category;
}

/// A known merchant resolved from the directory.
class DirectoryEntry {
  /// Creates an entry.
  const DirectoryEntry(this.name, this.category);

  /// Display name.
  final String name;

  /// Category.
  final Category category;
}

/// Directory rows in priority order (first token match wins).
final List<(List<String>, DirectoryEntry)> directoryRows = [
  for (final e in _entries) (e.keys, DirectoryEntry(e.name, e.category)),
];

/// Generic words that give away the category of an unknown merchant.
const List<(Category, List<String>)> keywordRows = [
  (
    Category.food,
    [
      'RESTAURANT',
      'CAFE',
      'PIZZA',
      'BURGER',
      'BIRYANI',
      'BAKERY',
      'FOODS',
      'KITCHEN',
      'DHABA',
      'SWEETS',
    ]
  ),
  (
    Category.groceries,
    ['SUPERMARKET', 'GROCERY', 'GROCERIES', 'MART', 'KIRANA', 'FRESH']
  ),
  (Category.fuel, ['PETROL', 'FUEL', 'FUELS', 'PETROLEUM']),
  (Category.transport, ['CAB', 'CABS', 'TAXI', 'PARKING', 'TOLL']),
  (
    Category.health,
    [
      'HOSPITAL',
      'CLINIC',
      'PHARMACY',
      'MEDICAL',
      'MEDICALS',
      'CHEMIST',
      'DIAGNOSTICS',
      'LAB',
      'LABS',
    ]
  ),
  (
    Category.education,
    ['SCHOOL', 'COLLEGE', 'UNIVERSITY', 'ACADEMY', 'TUITION', 'FEES']
  ),
  (
    Category.bills,
    [
      'ELECTRICITY',
      'RECHARGE',
      'BROADBAND',
      'BILL',
      'BILLDESK',
      'GAS',
      'WATER',
      'DTH',
    ]
  ),
  (
    Category.travel,
    ['HOTEL', 'HOTELS', 'AIRLINES', 'AIRWAYS', 'TRAVELS', 'TOURS', 'RAILWAY']
  ),
  (Category.insurance, ['INSURANCE', 'PREMIUM']),
  (Category.emiLoan, ['EMI', 'LOAN', 'FINANCE']),
  (Category.rent, ['RENT']),
  (
    Category.investment,
    ['MUTUAL', 'SIP', 'MF', 'SECURITIES', 'BROKING', 'CAPITAL']
  ),
  (Category.entertainment, ['MOVIES', 'CINEMA', 'CINEMAS', 'GAMING']),
];

const List<_E> _entries = [
  _E(['SWIGGY INSTAMART', 'INSTAMART'], 'Swiggy Instamart', Category.groceries),
  _E(['SWIGGY', 'BUNDL'], 'Swiggy', Category.food),
  _E(['ZOMATO'], 'Zomato', Category.food),
  _E(['EATSURE', 'FAASOS'], 'EatSure', Category.food),
  _E(['DOMINOS', 'JUBILANT'], "Domino's", Category.food),
  _E(['MCDONALDS', 'MCDONALD'], "McDonald's", Category.food),
  _E(['KFC'], 'KFC', Category.food),
  _E(['STARBUCKS'], 'Starbucks', Category.food),
  _E(['HALDIRAM', 'HALDIRAMS'], "Haldiram's", Category.food),
  _E(
    ['BIGBASKET', 'BIG BASKET', 'INNOVATIVE RETAIL'],
    'BigBasket',
    Category.groceries,
  ),
  _E(['BLINKIT', 'GROFERS'], 'Blinkit', Category.groceries),
  _E(['ZEPTO', 'KIRANAKART'], 'Zepto', Category.groceries),
  _E(['DMART', 'AVENUE SUPERMARTS'], 'DMart', Category.groceries),
  _E(['JIOMART'], 'JioMart', Category.groceries),
  _E(['UBER', 'UBERIND', 'UBER INDIA'], 'Uber', Category.transport),
  _E(
    ['OLA', 'OLACABS', 'OLAMONEY', 'ANI TECHNOLOGIES'],
    'Ola',
    Category.transport,
  ),
  _E(['RAPIDO', 'ROPPEN'], 'Rapido', Category.transport),
  _E(['BLUSMART', 'BLU SMART'], 'BluSmart', Category.transport),
  _E(['NAMMA YATRI', 'NAMMAYATRI'], 'Namma Yatri', Category.transport),
  _E(['MERU'], 'Meru', Category.transport),
  _E(['FASTAG'], 'FASTag', Category.transport),
  _E(['METRO', 'DMRC', 'BMRCL'], 'Metro', Category.transport),
  _E(['HPCL', 'HINDUSTAN PETROLEUM'], 'HPCL', Category.fuel),
  _E(['BPCL', 'BHARAT PETROLEUM'], 'BPCL', Category.fuel),
  _E(['IOCL', 'INDIAN OIL'], 'Indian Oil', Category.fuel),
  _E(['AMAZON', 'AMZN'], 'Amazon', Category.shopping),
  _E(['FLIPKART'], 'Flipkart', Category.shopping),
  _E(['MYNTRA'], 'Myntra', Category.shopping),
  _E(['AJIO'], 'AJIO', Category.shopping),
  _E(['MEESHO'], 'Meesho', Category.shopping),
  _E(['NYKAA'], 'Nykaa', Category.shopping),
  _E(['CROMA'], 'Croma', Category.shopping),
  _E(['DECATHLON'], 'Decathlon', Category.shopping),
  _E(['IKEA'], 'IKEA', Category.shopping),
  _E(['AIRTEL', 'BHARTI AIRTEL'], 'Airtel', Category.bills),
  _E(['JIO', 'RELIANCE JIO'], 'Jio', Category.bills),
  _E(['VODAFONE', 'VODAFONE IDEA'], 'Vi', Category.bills),
  _E(['BSNL'], 'BSNL', Category.bills),
  _E(
    ['BESCOM', 'TATA POWER', 'ADANI ELECTRICITY', 'MSEDCL', 'TNEB'],
    'Electricity',
    Category.bills,
  ),
  _E(['TATA PLAY', 'TATASKY'], 'Tata Play', Category.bills),
  _E(['NETFLIX'], 'Netflix', Category.entertainment),
  _E(['SPOTIFY'], 'Spotify', Category.entertainment),
  _E(
    ['HOTSTAR', 'JIOHOTSTAR', 'NOVI DIGITAL'],
    'JioHotstar',
    Category.entertainment,
  ),
  _E(['PRIME VIDEO'], 'Prime Video', Category.entertainment),
  _E(['BOOKMYSHOW', 'BIGTREE'], 'BookMyShow', Category.entertainment),
  _E(['PVR', 'INOX'], 'PVR INOX', Category.entertainment),
  _E(['YOUTUBE'], 'YouTube', Category.entertainment),
  _E(['IRCTC'], 'IRCTC', Category.travel),
  _E(['MAKEMYTRIP', 'MMT'], 'MakeMyTrip', Category.travel),
  _E(['GOIBIBO'], 'Goibibo', Category.travel),
  _E(['CLEARTRIP'], 'Cleartrip', Category.travel),
  _E(['INDIGO', 'INTERGLOBE'], 'IndiGo', Category.travel),
  _E(['AIR INDIA'], 'Air India', Category.travel),
  _E(['REDBUS'], 'redBus', Category.travel),
  _E(['OYO'], 'OYO', Category.travel),
  _E(['IXIGO'], 'ixigo', Category.travel),
  _E(['APOLLO'], 'Apollo', Category.health),
  _E(['PHARMEASY'], 'PharmEasy', Category.health),
  _E(['1MG', 'TATA 1MG'], 'Tata 1mg', Category.health),
  _E(['NETMEDS'], 'Netmeds', Category.health),
  _E(['MEDPLUS'], 'MedPlus', Category.health),
  _E(['CULTFIT', 'CULT FIT', 'CUREFIT'], 'cult.fit', Category.health),
  _E(['UDEMY'], 'Udemy', Category.education),
  _E(['COURSERA'], 'Coursera', Category.education),
  _E(['UNACADEMY'], 'Unacademy', Category.education),
  _E(['ZERODHA'], 'Zerodha', Category.investment),
  _E(['GROWW'], 'Groww', Category.investment),
  _E(['UPSTOX'], 'Upstox', Category.investment),
  _E(['KUVERA'], 'Kuvera', Category.investment),
  _E(['ICCL', 'INDIAN CLEARING'], 'ICCL', Category.investment),
  _E(['SMALLCASE'], 'smallcase', Category.investment),
  _E(['LIC', 'LIFE INSURANCE CORPORATION'], 'LIC', Category.insurance),
  _E(['POLICYBAZAAR'], 'Policybazaar', Category.insurance),
  _E(['ACKO'], 'Acko', Category.insurance),
  _E(['HDFC ERGO', 'HDFCERGO'], 'HDFC ERGO', Category.insurance),
  _E(['ICICI LOMBARD', 'ICICILOMBARD'], 'ICICI Lombard', Category.insurance),
  _E(['STAR HEALTH', 'STARHEALTH'], 'Star Health', Category.insurance),
  _E(['NIVA BUPA', 'NIVABUPA', 'MAX BUPA'], 'Niva Bupa', Category.insurance),
  _E(
    ['CARE HEALTH', 'CAREHEALTH', 'RELIGARE HEALTH'],
    'Care Health',
    Category.insurance,
  ),
  _E(
    ['ADITYA BIRLA HEALTH', 'ABHICL'],
    'Aditya Birla Health',
    Category.insurance,
  ),
  _E(['MANIPAL CIGNA', 'MANIPALCIGNA'], 'ManipalCigna', Category.insurance),
  _E(['TATA AIG', 'TATAAIG'], 'Tata AIG', Category.insurance),
  _E(['BAJAJ ALLIANZ', 'BAJAJALLIANZ'], 'Bajaj Allianz', Category.insurance),
  _E(
    ['GO DIGIT', 'GODIGIT', 'DIGIT INSURANCE'],
    'Digit Insurance',
    Category.insurance,
  ),
  _E(['RELIANCE GENERAL'], 'Reliance General', Category.insurance),
  _E(['NEW INDIA ASSURANCE'], 'New India Assurance', Category.insurance),
  _E(
    ['MAX LIFE', 'MAXLIFE', 'AXIS MAX LIFE'],
    'Axis Max Life',
    Category.insurance,
  ),
  _E(['HDFC LIFE', 'HDFCLIFE'], 'HDFC Life', Category.insurance),
  _E(['SBI LIFE', 'SBILIFE'], 'SBI Life', Category.insurance),
  _E(
    ['ICICI PRU', 'ICICIPRU', 'ICICI PRUDENTIAL LIFE'],
    'ICICI Prudential Life',
    Category.insurance,
  ),
  _E(['TATA AIA', 'TATAAIA'], 'Tata AIA', Category.insurance),
  _E(['KOTAK LIFE'], 'Kotak Life', Category.insurance),
  _E(
    ['BAJAJ FINANCE', 'BAJAJ FINSERV', 'BAJAJFINANCE', 'BAJAJFIN'],
    'Bajaj Finance',
    Category.emiLoan,
  ),
  _E(['PROPELLD'], 'Propelld', Category.emiLoan),
  _E(
    [
      'ADITYA BIRLA FINANCE',
      'ADITYA BIRLA CAPITAL',
      'ADITYA BIRLA HOUSING',
      'ADITYABIRLA',
      'ADITYA BIRLA',
      'ABFL',
      'ABHFL',
    ],
    'Aditya Birla Capital',
    Category.emiLoan,
  ),
  _E(
    ['ADITYA BIRLA SUN LIFE INSURANCE', 'ABSLI'],
    'Aditya Birla Sun Life Insurance',
    Category.insurance,
  ),
  _E(
    ['ADITYA BIRLA SUN LIFE', 'ABSLMF', 'ABSLAMC'],
    'Aditya Birla Sun Life MF',
    Category.investment,
  ),
  _E(['ADITYA BIRLA FASHION'], 'Aditya Birla Fashion', Category.shopping),
  _E(['TATA CAPITAL', 'TATACAPITAL'], 'Tata Capital', Category.emiLoan),
  _E(
    ['TATA CAPITAL SECURITIES', 'TATA SECURITIES'],
    'Tata Securities',
    Category.investment,
  ),
  _E(
    [
      'TATA MUTUAL FUND',
      'TATA MF',
      'TATAMF',
      'TATA ASSET MANAGEMENT',
      'TATA AMC',
      'TATA SMALL CAP',
      'TATA DIGITAL INDIA',
      'TATA NIFTY',
      'TATA ELSS',
      'TATA BANKING',
      'TATA FLEXI',
      'TATA LARGE',
      'TATA MID',
      'TATA ARBITRAGE',
      'TATA LIQUID',
      'TATA MONEY MARKET',
      'TATA BALANCED',
      'TATA HYBRID',
      'TATA EQUITY',
      'TATA INDEX',
    ],
    'Tata Mutual Fund',
    Category.investment,
  ),
  _E(['CREDILA', 'HDFC CREDILA'], 'HDFC Credila', Category.emiLoan),
  _E(['AVANSE'], 'Avanse', Category.emiLoan),
  _E(['INCRED'], 'InCred', Category.emiLoan),
  _E(['SMFG', 'FULLERTON'], 'SMFG India Credit', Category.emiLoan),
  _E(['HOME CREDIT', 'HOMECREDIT'], 'Home Credit', Category.emiLoan),
  _E(['KREDITBEE', 'KRAZYBEE'], 'KreditBee', Category.emiLoan),
  _E(
    ['NAVI FINSERV', 'NAVIFINSERV', 'NAVI TECHNOLOGIES'],
    'Navi',
    Category.emiLoan,
  ),
  _E(['POONAWALLA'], 'Poonawalla Fincorp', Category.emiLoan),
  _E(['HDB FINANCIAL', 'HDBFS', 'HDBFSL'], 'HDB Financial', Category.emiLoan),
  _E(['L&T FINANCE', 'LTFS', 'LNT FINANCE'], 'L&T Finance', Category.emiLoan),
  _E(['HERO FINCORP', 'HEROFINCORP'], 'Hero FinCorp', Category.emiLoan),
  _E(
    ['CHOLAMANDALAM INVESTMENT', 'CHOLAMANDALAM FINANCE', 'CHOLA FINANCE'],
    'Cholamandalam Finance',
    Category.emiLoan,
  ),
  _E(
    ['MAHINDRA FINANCE', 'MAHINDRA AND MAHINDRA FIN', 'MMFSL'],
    'Mahindra Finance',
    Category.emiLoan,
  ),
  _E(['NOBROKER'], 'NoBroker', Category.rent),
];
