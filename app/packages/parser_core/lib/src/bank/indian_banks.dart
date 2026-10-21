import 'package:parser_core/src/bank/base_bank_parser.dart';
import 'package:parser_core/src/parser_config.dart';

/// A bank, small finance bank, payments bank or co-operative bank with no
/// templates of its own. Its alerts follow the common "A/c XX1234
/// debited/credited by Rs. ... Avl Bal ..." shape, which the shared extractors
/// read; the entry supplies the display name and the sender codes (SMS
/// headers) and mail domains it writes from (FR-06-08).
///
/// Sender codes are the ones banks register for transactional SMS; a code
/// missing here still works when the bank's header ends in BK, BNK or BANK
/// (the generic parser), just under the raw header as its name.
class ListedBank {
  /// Creates a listed bank.
  const ListedBank(this.name, this.headers, [this.domains = const {}]);

  /// Display name.
  final String name;

  /// SMS headers.
  final Set<String> headers;

  /// Email domains.
  final Set<String> domains;
}

/// The 51 listed banks.
abstract final class IndianBanks {
  /// All listed banks in priority order.
  static const List<ListedBank> all = [
    ListedBank(
      'Central Bank of India',
      {'CENTBK', 'CBOIND', 'CBINBK', 'CENTRL', 'CBISMS'},
      {'centralbank.co.in', 'centralbankofindia.co.in'},
    ),
    ListedBank(
      'Bank of Maharashtra',
      {'MAHABK', 'BOMSMS', 'MAHBNK', 'BOMBNK', 'MAHABN'},
      {'bankofmaharashtra.in'},
    ),
    ListedBank(
      'Canara Bank',
      {'CANBNK', 'CANARA', 'CANBKS', 'CNRBNK', 'CANBSM'},
      {'canarabank.com', 'canarabank.in'},
    ),
    ListedBank(
      'Union Bank of India',
      {'UNIONB', 'UBINBK', 'UBISMS', 'UNIBNK'},
      {'unionbankofindia.co.in', 'unionbankofindia.bank.in'},
    ),
    ListedBank(
      'Bank of India',
      {'BOIIND', 'BOIBNK', 'BOISMS', 'BOIBKS'},
      {'bankofindia.co.in'},
    ),
    ListedBank(
      'Indian Bank',
      {'INDBNK', 'INDIAN', 'INDBKS', 'INDSMS'},
      {'indianbank.in', 'indianbank.co.in'},
    ),
    ListedBank(
      'Indian Overseas Bank',
      {'IOBCHN', 'IOBBNK', 'IOBSMS', 'IOBANK'},
      {'iob.in'},
    ),
    ListedBank(
      'UCO Bank',
      {'UCOBNK', 'UCOBKS', 'UCOSMS', 'UCOBAN'},
      {'ucobank.com'},
    ),
    ListedBank(
      'Punjab & Sind Bank',
      {'PSBANK', 'PSBIND', 'PSBSMS', 'PSBBNK'},
      {'psbindia.com'},
    ),
    ListedBank(
      'IDBI Bank',
      {'IDBIBK', 'IDBIIN', 'IDBISM'},
      {'idbibank.in', 'idbi.co.in'},
    ),
    ListedBank(
      'IndusInd Bank',
      {'INDUSB', 'INDUSL'},
      {'indusind.com', 'indusind.bank.in'},
    ),
    ListedBank(
      'Federal Bank',
      {'FEDBNK', 'FEDSMS', 'FEDBKS'},
      {'federalbank.co.in'},
    ),
    ListedBank(
      'South Indian Bank',
      {'SIBSMS', 'SIBBNK', 'SIBANK'},
      {'southindianbank.com'},
    ),
    ListedBank(
      'Karur Vysya Bank',
      {'KVBANK', 'KVBSMS', 'KVBBNK'},
      {'kvb.co.in'},
    ),
    ListedBank(
      'City Union Bank',
      {'CUBANK', 'CUBSMS', 'CUBBNK'},
      {'cityunionbank.com'},
    ),
    ListedBank('CSB Bank', {'CSBANK', 'CSBSMS', 'CSBBNK'}, {'csb.co.in'}),
    ListedBank('DCB Bank', {'DCBBNK', 'DCBSMS', 'DCBANK'}, {'dcbbank.com'}),
    ListedBank(
      'Tamilnad Mercantile Bank',
      {'TMBANK', 'TMBSMS', 'TMBBNK'},
      {'tmb.in'},
    ),
    ListedBank(
      'Jammu & Kashmir Bank',
      {'JKBANK', 'JKBSMS', 'JKBBNK'},
      {'jkbank.com'},
    ),
    ListedBank(
      'Dhanlaxmi Bank',
      {'DHANBK', 'DLXBNK', 'DHNLXM'},
      {'dhanbank.com'},
    ),
    ListedBank(
      'Nainital Bank',
      {'NTLBNK', 'NAINBK', 'NAINTL'},
      {'nainitalbank.co.in'},
    ),
    ListedBank(
      'Karnataka Bank',
      {'KTKBNK', 'KARBNK', 'KBLSMS'},
      {'karnatakabank.com'},
    ),
    ListedBank('RBL Bank', {'RBLBNK', 'RBLCRD', 'RBLSMS'}, {'rblbank.com'}),
    ListedBank(
      'Bandhan Bank',
      {'BANDHN', 'BDNBNK', 'BNDHAN'},
      {'bandhanbank.com'},
    ),
    ListedBank(
      'Equitas Small Finance Bank',
      {'EQUTAS', 'EQSFBL', 'EQUITS'},
      {'equitasbank.com'},
    ),
    ListedBank(
      'Ujjivan Small Finance Bank',
      {'UJJSFB', 'UJVNSB', 'UJJIVN'},
      {'ujjivansfb.in'},
    ),
    ListedBank(
      'Jana Small Finance Bank',
      {'JANASF', 'JANABK', 'JANASM'},
      {'janabank.com'},
    ),
    ListedBank(
      'Suryoday Small Finance Bank',
      {'SURYDY', 'SURYOD'},
      {'suryodaybank.com'},
    ),
    ListedBank(
      'Utkarsh Small Finance Bank',
      {'UTKSFB', 'UTKRSH'},
      {'utkarsh.bank'},
    ),
    ListedBank(
      'ESAF Small Finance Bank',
      {'ESAFSF', 'ESAFBK'},
      {'esafbank.com'},
    ),
    ListedBank(
      'Capital Small Finance Bank',
      {'CAPSFB', 'CAPITL'},
      {'capitalbank.co.in'},
    ),
    ListedBank('HSBC', {'HSBCIN', 'HSBCCC', 'HSBCBK'}, {'hsbc.co.in'}),
    ListedBank(
      'Standard Chartered',
      {'SCBNKS', 'STANCB', 'SCBANK'},
      {'sc.com'},
    ),
    ListedBank(
      'Citibank',
      {'CITIIN', 'CITIBK', 'CITIBN'},
      {'citibank.com', 'citi.com'},
    ),
    ListedBank('DBS Bank', {'DBSIND', 'DBSBNK'}, {'dbs.com'}),
    ListedBank(
      'Paytm Payments Bank',
      {'PYTMPB', 'PAYTMB', 'PAYTMP'},
      {'paytmbank.com'},
    ),
    ListedBank(
      'Airtel Payments Bank',
      {'AIRBNK', 'APBLTD', 'AIRPBL'},
      {'airtelbank.com'},
    ),
    ListedBank(
      'India Post Payments Bank',
      {'IPPBNK', 'IPPBSM', 'IPPBLT'},
      {'ippbonline.com'},
    ),
    ListedBank('Fino Payments Bank', {'FINOPB', 'FINOBK'}, {'finobank.com'}),
    ListedBank(
      'Jio Payments Bank',
      {'JIOPBL', 'JIOPAY'},
      {'jiopaymentsbank.com'},
    ),
    ListedBank('Nagrik Sahakari Bank', {
      'NAGRIK',
      'NAGRIKB',
      'NAGRKB',
      'NSBANK',
      'NSBLTD',
      'NSBGWL',
      'NSBMPL',
      'NSBIDR',
      'NSBAHM',
      'NGRKSB',
      'NAGSBK',
      'NSBSMS',
    }, {
      'nagriksahakaribank.com',
      'nagrikbank.com',
      'nagriksahkaribank.com',
    }),
    ListedBank(
      'Saraswat Bank',
      {'SARBNK', 'SARSWT', 'SRSWAT'},
      {'saraswatbank.com'},
    ),
    ListedBank(
      'Cosmos Bank',
      {'COSMOS', 'COSBNK', 'COSMBK'},
      {'cosmosbank.com'},
    ),
    ListedBank('SVC Bank', {'SVCBNK', 'SVCBAN'}, {'svcbank.com'}),
    ListedBank('Abhyudaya Bank', {'ABHYUD', 'ABHYBK'}, {'abhyudayabank.co.in'}),
    ListedBank('TJSB Sahakari Bank', {'TJSBNK', 'TJSBSM'}, {'tjsb.in'}),
    ListedBank(
      'Bharat Co-operative Bank',
      {'BCBLTD', 'BHARBK'},
      {'bharatbank.com'},
    ),
    ListedBank(
      'Kalupur Commercial Co-operative Bank',
      {'KALUPR', 'KALPUR'},
      {'kalupurbank.com'},
    ),
    ListedBank(
      'NKGSB Co-operative Bank',
      {'NKGSBK', 'NKGSBB'},
      {'nkgsb.co.in'},
    ),
    ListedBank(
      'Janata Sahakari Bank',
      {'JSBLTD', 'JANSBK'},
      {'janatabank.com'},
    ),
    ListedBank('Apna Sahakari Bank', {'APNABK', 'APNSBK'}, {'apnabank.co.in'}),
  ];
}

/// One [ListedBank] as a parser: no templates, so everything is read by the
/// shared extractors.
class ListedBankParser extends BaseBankParser {
  /// Creates the parser for [bank].
  ListedBankParser(this.bank, [super.config = const ParserConfig()]);

  /// The bank this parser stands for.
  final ListedBank bank;

  @override
  String get bankName => bank.name;

  @override
  Set<String> get smsHeaders => bank.headers;

  @override
  Set<String> get emailDomains => bank.domains;
}
