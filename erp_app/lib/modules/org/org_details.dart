/// Full organization record fetched from the `organizations` table.
class OrgDetails {
  const OrgDetails({
    required this.id,
    required this.name,
    required this.currency,
    this.timezone,
    this.address,
    this.country,
    this.phone,
    this.email,
    this.website,
    this.taxId,
    this.logoUrl,
    this.rcNumber,
    this.rneNumber,
    this.bankName,
    this.bankRib,
    this.bankIban,
    this.bankBic,
    this.defaultPaymentTerms,
    this.enableFodec = false,
    this.enableTimbreFiscal = false,
    this.enableRetenuSource = false,
    this.paymentTermsOptions = const [],
    this.defaultQuoteNotes,
  });

  final String  id;
  final String  name;
  final String  currency;
  final String? timezone;
  final String? address;
  final String? country;
  final String? phone;
  final String? email;
  final String? website;
  final String? taxId;
  final String? logoUrl;
  // ── Legal identifiers (Tunisia-style, also usable elsewhere) ─────────────────
  final String? rcNumber;   // Registre de Commerce
  final String? rneNumber;  // RNE
  // ── Bank details, printed on quote/invoice payment section ───────────────────
  final String? bankName;
  final String? bankRib;
  final String? bankIban;
  final String? bankBic;
  final String? defaultPaymentTerms;
  // ── Quote / Invoice defaults ──────────────────────────────────────────────────
  final bool         enableFodec;
  final bool         enableTimbreFiscal;
  final bool         enableRetenuSource;
  final List<String> paymentTermsOptions;
  final String?      defaultQuoteNotes;

  factory OrgDetails.fromJson(Map<String, dynamic> json) => OrgDetails(
        id:       json['id']       as String,
        name:     json['name']     as String,
        currency: json['currency'] as String? ?? 'USD',
        timezone: json['timezone'] as String?,
        address:  json['address']  as String?,
        country:  json['country']  as String?,
        phone:    json['phone']    as String?,
        email:    json['email']    as String?,
        website:  json['website']  as String?,
        taxId:    json['tax_id']   as String?,
        logoUrl:  json['logo_url'] as String?,
        rcNumber:            json['rc_number']             as String?,
        rneNumber:           json['rne_number']            as String?,
        bankName:            json['bank_name']             as String?,
        bankRib:             json['bank_rib']               as String?,
        bankIban:            json['bank_iban']              as String?,
        bankBic:             json['bank_bic']                as String?,
        defaultPaymentTerms: json['default_payment_terms']  as String?,
        enableFodec:        json['enable_fodec']          as bool? ?? false,
        enableTimbreFiscal: json['enable_timbre_fiscal']  as bool? ?? false,
        enableRetenuSource: json['enable_retenu_source']  as bool? ?? false,
        paymentTermsOptions: (json['payment_terms_options'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ?? const [],
        defaultQuoteNotes:  json['default_quote_notes']   as String?,
      );

  Map<String, dynamic> toUpdateMap() => {
        'name':     name,
        'currency': currency,
        if (timezone != null) 'timezone': timezone,
        'address':  address,
        'country':  country,
        'phone':    phone,
        'email':    email,
        'website':  website,
        'tax_id':   taxId,
        'logo_url': logoUrl,
        'rc_number':             rcNumber,
        'rne_number':            rneNumber,
        'bank_name':             bankName,
        'bank_rib':              bankRib,
        'bank_iban':             bankIban,
        'bank_bic':              bankBic,
        'default_payment_terms': defaultPaymentTerms,
        'enable_fodec':          enableFodec,
        'enable_timbre_fiscal':  enableTimbreFiscal,
        'enable_retenu_source':  enableRetenuSource,
        'default_quote_notes':   defaultQuoteNotes,
      };
}
