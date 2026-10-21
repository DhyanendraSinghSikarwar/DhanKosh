// Generated from the Kotlin Subcategories catalogue; the data is the parity
// baseline, edit with care.

import 'package:parser_core/src/merchant/subcategories.dart';
import 'package:parser_core/src/model/model.dart';

/// Built-in sub-categories per category.
const Map<Category, List<SubcategoryDef>> subcategoryCatalog = {
  Category.food: [
    SubcategoryDef(
      'Food delivery',
      'delivery_dining',
      r'''swiggy|zomato|uber\s*eats|eatsure|box8|faasos|rebel\s*foods|magicpin''',
    ),
    SubcategoryDef(
      'Cafés & coffee',
      'local_cafe',
      r'''starbucks|\bcafe|caf[eé]\b|coffee|\bccd\b|chaayos|chai|third\s*wave|blue\s*tokai''',
    ),
    SubcategoryDef(
      'Fast food',
      'fastfood',
      r'''mcdonald|domino|\bkfc\b|pizza|burger|subway|wow\s*momo''',
    ),
    SubcategoryDef(
      'Bakery & desserts',
      'bakery_dining',
      r'''bakery|bakers|cake|ice\s*cream|baskin|theobroma|naturals\s*ice''',
    ),
    SubcategoryDef(
      'Bars & nightlife',
      'local_bar',
      r'''\bbar\b|\bpub\b|brew|liquor|wines?\b|beer''',
    ),
    SubcategoryDef(
      'Restaurants',
      'restaurant',
      '''restaurant|dhaba|bistro|kitchen|biryani|dining|eatery|hotel''',
    ),
  ],
  Category.groceries: [
    SubcategoryDef(
      'Quick commerce',
      'bolt',
      r'''blinkit|grofers|zepto|kiranakart|instamart|bb\s*now|dunzo''',
    ),
    SubcategoryDef(
      'Supermarket',
      'local_grocery_store',
      r'''d\s*-?mart|avenue\s*supermart|reliance\s*(fresh|smart|retail)|spencer|star\s*bazaar|more\s*retail|bigbasket|jiomart|nature'?s\s*basket''',
    ),
    SubcategoryDef(
      'Dairy',
      'egg',
      r'''milk|dairy|amul|mother\s*dairy|country\s*delight|milkbasket|nandini''',
    ),
    SubcategoryDef(
      'Fruits & vegetables',
      'eco',
      '''fruit|vegetable|sabzi|farm''',
    ),
    SubcategoryDef(
      'Kirana',
      'storefront',
      r'''kirana|general\s*store|provision|traders''',
    ),
  ],
  Category.transport: [
    SubcategoryDef(
      'Cabs & rides',
      'local_taxi',
      r'''\buber\b|\bola\b|olacabs|ani\s*technologies|rapido|roppen|blusmart|meru|namma\s*yatri''',
    ),
    SubcategoryDef(
      'Metro & bus',
      'directions_subway',
      r'''metro|dmrc|bmrcl|\bbest\b|bmtc|dtc|ksrtc|msrtc''',
    ),
    SubcategoryDef(
      'Parking & tolls',
      'local_parking',
      r'''parking|fastag|\btoll|netc''',
    ),
    SubcategoryDef(
      'Vehicle service',
      'car_repair',
      r'''service\s*cent|garage|tyre|car\s*wash|motors''',
    ),
  ],
  Category.fuel: [
    SubcategoryDef(
      'Petrol & diesel',
      'local_gas_station',
      r'''hpcl|bpcl|iocl|indian\s*oil|indianoil|bharat\s*petroleum|hindustan\s*petroleum|hp\s*pay|petrol|diesel|shell|nayara|fuel''',
    ),
    SubcategoryDef(
      'EV charging',
      'ev_station',
      r'''charging|ez\s*charge|statiq|chargezone|\bev\b''',
    ),
    SubcategoryDef(
      'CNG',
      'propane',
      r'''\bcng\b|indraprastha\s*gas|\bigl\b|mahanagar\s*gas''',
    ),
  ],
  Category.shopping: [
    SubcategoryDef(
      'Online shopping',
      'shopping_bag',
      '''amazon|amzn|flipkart|meesho|snapdeal|shopsy''',
    ),
    SubcategoryDef(
      'Fashion',
      'checkroom',
      r'''myntra|ajio|zara|h\s*&\s*m|\bmax\b|pantaloons|westside|lifestyle|uniqlo|bata|puma|nike|adidas|tata\s*cliq|trends''',
    ),
    SubcategoryDef(
      'Electronics',
      'devices',
      r'''croma|reliance\s*digital|vijay\s*sales|apple|samsung|\bmi\b|xiaomi|oneplus|boat''',
    ),
    SubcategoryDef(
      'Home & furniture',
      'chair',
      r'''ikea|pepperfry|urban\s*ladder|home\s*centre|wakefit''',
    ),
    SubcategoryDef(
      'Sports & fitness gear',
      'sports_cricket',
      '''decathlon|sports''',
    ),
    SubcategoryDef(
      'Books & stationery',
      'menu_book',
      '''book|stationery|crossword|sapna''',
    ),
  ],
  Category.bills: [
    SubcategoryDef(
      'Mobile recharge',
      'smartphone',
      r'''\bjio\b|airtel|\bvi\b|vodafone|idea|bsnl|recharge|prepaid|postpaid''',
    ),
    SubcategoryDef(
      'Electricity',
      'electric_bolt',
      r'''electric|bescom|tata\s*power|adani\s*electricity|msedcl|mahadiscom|bses|torrent\s*power|tneb|tangedco|cesc|power''',
    ),
    SubcategoryDef(
      'Broadband & DTH',
      'router',
      r'''broadband|fib(er|re)|act\s*fibernet|hathway|excitel|tata\s*play|dish\s*tv|d2h|xstream|sun\s*direct''',
    ),
    SubcategoryDef(
      'Gas cylinder',
      'propane_tank',
      r'''indane|hp\s*gas|bharat\s*gas|\blpg\b|gas\s*booking''',
    ),
    SubcategoryDef('Water', 'water_drop', r'''water|jal\s*board'''),
    SubcategoryDef(
      'Society maintenance',
      'apartment',
      '''maintenance|society|mygate|nobrokerhood|apartment''',
    ),
  ],
  Category.entertainment: [
    SubcategoryDef(
      'Movies',
      'movie',
      r'''\bpvr\b|\binox\b|bookmyshow|bigtree|cinepolis|cinema|movie''',
    ),
    SubcategoryDef(
      'Events & shows',
      'confirmation_number',
      '''event|concert|insider|district|ticket''',
    ),
    SubcategoryDef(
      'Gaming',
      'sports_esports',
      r'''steam|playstation|xbox|game|dream11|\bmpl\b|winzo''',
    ),
    SubcategoryDef(
      'Outings',
      'attractions',
      '''wonderla|imagica|park|museum|zoo|bowling|smaaash''',
    ),
  ],
  Category.travel: [
    SubcategoryDef(
      'Cabs',
      'local_taxi',
      r'''\buber\b|\bola\b|olacabs|ani\s*technologies|rapido|roppen|blusmart|meru|namma\s*yatri|savaari|outstation''',
    ),
    SubcategoryDef(
      'Flights',
      'flight',
      r'''indigo|interglobe|air\s*india|vistara|spicejet|akasa|airline|airways''',
    ),
    SubcategoryDef('Trains', 'train', r'''irctc|railway|\brail\b'''),
    SubcategoryDef(
      'Hotels & stays',
      'hotel',
      r'''\boyo\b|hotel|airbnb|treebo|fabhotel|\btaj\b|marriott|booking\.com|agoda|resort|zostel''',
    ),
    SubcategoryDef(
      'Bus',
      'directions_bus',
      '''redbus|abhibus|zingbus|volvo''',
    ),
    SubcategoryDef(
      'Travel booking',
      'luggage',
      r'''makemytrip|make\s*my\s*trip|goibibo|cleartrip|yatra|ixigo|easemytrip''',
    ),
  ],
  Category.health: [
    SubcategoryDef(
      'Medicines',
      'medication',
      r'''pharmeasy|netmeds|\b1mg\b|apollo\s*pharm|medplus|pharma|chemist|medical|druggist|wellness\s*forever''',
    ),
    SubcategoryDef(
      'Doctor & hospital',
      'local_hospital',
      r'''hospital|clinic|doctor|\bdr\.?\s|practo|fortis|manipal|max\s*health|narayana|aster|medanta|apollo''',
    ),
    SubcategoryDef(
      'Lab tests',
      'biotech',
      r'''\blab|diagnostic|thyrocare|lal\s*path|metropolis|redcliffe|healthians|orange\s*health''',
    ),
    SubcategoryDef(
      'Fitness',
      'fitness_center',
      '''cult|gym|fitness|yoga|healthify''',
    ),
    SubcategoryDef('Personal care', 'spa', r'''salon|spa\b|parlour|grooming'''),
    SubcategoryDef(
      'Eye care',
      'visibility',
      '''lenskart|optical|optician|eye''',
    ),
  ],
  Category.education: [
    SubcategoryDef(
      'Courses & coaching',
      'school',
      r'''udemy|coursera|byju|unacademy|upgrad|vedantu|physics\s*wallah|course|coaching|classes|academy''',
    ),
    SubcategoryDef(
      'School & college fees',
      'account_balance',
      '''school|college|university|institute|fees|tuition''',
    ),
    SubcategoryDef('Books', 'menu_book', '''book|kindle'''),
  ],
  Category.rent: [
    SubcategoryDef('House rent', 'home', '''rent|nobroker|housing|landlord'''),
    SubcategoryDef(
      'PG & hostel',
      'bed',
      r'''\bpg\b|hostel|co-?living|stanza|zolo|colive''',
    ),
  ],
  Category.insurance: [
    SubcategoryDef(
      'Life insurance',
      'favorite',
      r'''\blic\b|life|term|max\s*life|hdfc\s*life|icici\s*pru|sbi\s*life|tata\s*aia''',
    ),
    SubcategoryDef(
      'Health insurance',
      'health_and_safety',
      r'''health|star\s*health|care\s*health|niva\s*bupa|hdfc\s*ergo|aditya\s*birla\s*health''',
    ),
    SubcategoryDef(
      'Vehicle insurance',
      'directions_car',
      r'''motor|car\s*insurance|bike\s*insurance|two\s*wheeler|acko|go\s*digit|\bdigit\b''',
    ),
  ],
  Category.emiLoan: [
    SubcategoryDef('Home loan', 'home', r'''home\s*loan|housing\s*loan|hfc'''),
    SubcategoryDef(
      'Car loan',
      'directions_car',
      r'''car\s*loan|auto\s*loan|vehicle\s*loan''',
    ),
    SubcategoryDef('Education loan', 'school', r'''education\s*loan'''),
    SubcategoryDef('Card EMI', 'credit_card', r'''\bemi\b|card'''),
    SubcategoryDef(
      'Personal loan',
      'payments',
      r'''personal\s*loan|loan|bajaj\s*fin|navi|kreditbee|moneyview|slice''',
    ),
  ],
  Category.investment: [
    SubcategoryDef(
      'Mutual funds',
      'pie_chart',
      r'''mutual|\bsip\b|cams|kfin|kuvera|\bcoin\b|\bmf\b|amc''',
    ),
    SubcategoryDef(
      'Stocks',
      'show_chart',
      r'''zerodha|upstox|angel|dhan|groww|stock|\bnse\b|\bbse\b|indmoney|iccl|nsccl''',
    ),
    SubcategoryDef(
      'PPF, EPF & NPS',
      'savings',
      r'''\bppf\b|\bepf\b|\bnps\b|provident|pension''',
    ),
    SubcategoryDef(
      'FD & RD',
      'account_balance',
      r'''fixed\s*deposit|recurring\s*deposit|\bfd\b|\brd\b''',
    ),
    SubcategoryDef('Gold', 'diamond', r'''gold|\bsgb\b|safegold|augmont'''),
  ],
  Category.subscriptions: [
    SubcategoryDef(
      'Streaming',
      'live_tv',
      r'''netflix|prime\s*video|hotstar|jiocinema|sonyliv|zee5|youtube|aha|voot''',
    ),
    SubcategoryDef(
      'Music',
      'music_note',
      r'''spotify|gaana|saavn|apple\s*music|wynk''',
    ),
    SubcategoryDef(
      'Cloud & apps',
      'cloud',
      r'''google\s*(one|storage|play)|icloud|dropbox|microsoft|office|chatgpt|openai|adobe|notion|claude|anthropic|canva''',
    ),
    SubcategoryDef(
      'News & reading',
      'newspaper',
      r'''times|hindu|express|kindle\s*unlimited|audible|economist|newspaper''',
    ),
    SubcategoryDef(
      'Memberships',
      'card_membership',
      r'''prime|flipkart\s*plus|swiggy\s*one|zomato\s*gold|membership''',
    ),
  ],
  Category.personalCare: [
    SubcategoryDef(
      'Salon & spa',
      'content_cut',
      r'''salon|spa\b|parlour|urban\s*company|urbanclap|looks|naturals|lakme|jawed''',
    ),
    SubcategoryDef(
      'Cosmetics & skincare',
      'face',
      '''nykaa|purplle|mamaearth|sugar|cosmetic|beauty|minimalist''',
    ),
  ],
  Category.household: [
    SubcategoryDef(
      'Home services',
      'handyman',
      r'''urban\s*company|urbanclap|plumb|electrician|carpenter|pest|repair''',
    ),
    SubcategoryDef(
      'Domestic help',
      'cleaning_services',
      '''maid|cook|driver|help|cleaning''',
    ),
    SubcategoryDef(
      'Laundry',
      'local_laundry_service',
      r'''laundry|dry\s*clean|washing''',
    ),
    SubcategoryDef(
      'Home supplies',
      'kitchen',
      '''utensil|hardware|household''',
    ),
  ],
  Category.gifts: [
    SubcategoryDef(
      'Flowers & cakes',
      'local_florist',
      '''fnp|ferns|igp|flower|bloom''',
    ),
    SubcategoryDef('Gifts', 'redeem'),
  ],
  Category.donations: [
    SubcategoryDef(
      'Religious',
      'temple_hindu',
      '''temple|mandir|gurudwara|church|mosque|masjid|devasthan|trust''',
    ),
    SubcategoryDef('Charity', 'volunteer_activism'),
  ],
  Category.taxes: [
    SubcategoryDef(
      'Income tax',
      'receipt_long',
      r'''income\s*tax|\bitd\b|\btds\b|advance\s*tax|incometax''',
    ),
    SubcategoryDef('GST', 'request_quote', r'''\bgst\b'''),
    SubcategoryDef(
      'Property tax',
      'house',
      r'''property\s*tax|municipal|nagar\s*nigam|bbmp|mcgm''',
    ),
  ],
  Category.fees: [
    SubcategoryDef(
      'Interest & late fees',
      'warning',
      r'''late|penalty|interest|finance\s*charge|overdue''',
    ),
    SubcategoryDef(
      'Card fees',
      'credit_card',
      r'''annual\s*fee|joining\s*fee|card\s*fee|renewal''',
    ),
    SubcategoryDef('Bank charges', 'account_balance'),
  ],
  Category.cash: [
    SubcategoryDef('ATM withdrawal', 'atm'),
  ],
};
