# List of credit card products by matching prefix.
CCProducts = {}

CCProducts[/^30[0-5][0-9]/] =
  companyName: "Diners Club"
  companyShortname: "dinersclub"
  cardNumberGrouping: [4,6,4]
  expirationFormat: "MM/YY"
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

CCProducts[/^3095/] =
  companyName: "Diners Club International"
  companyShortname: "dinersclubintl"
  cardNumberGrouping: [4,6,4]
  expirationFormat: "MM/YY"
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

CCProducts[/^35\d{2}/] =
  companyName: "JCB"
  companyShortname: "jcb"
  cardNumberGrouping: [4,4,4,4]
  expirationFormat: "MM/YY"
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

CCProducts[/^36\d{2}/] =
  companyName: "Diners Club International"
  companyShortname: "dinersclubintl"
  cardNumberGrouping: [4,6,4]
  expirationFormat: "MM/YY"
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

CCProducts[/^37/] =
  companyName: "American Express"
  companyShortname: "amex"
  cardNumberGrouping: [4,6,5]
  expirationFormat: "MM/YY"
  cvcLength: 4
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

CCProducts[/^38/] =
  companyName: "Hipercard"
  companyShortname: "hipercard"
  cardNumberGrouping: [4,4,4,4]
  expirationFormat: "MM/YY"
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

CCProducts[/^4[0-9]\d{2}/] =
  companyName: "Visa"
  companyShortname: "visa"
  cardNumberGrouping: [4,4,4,4]
  expirationFormat: "MM/YY"
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

CCProducts[/^5[0-8]\d{2}/] =
  companyName: "Mastercard"
  companyShortname: "mastercard"
  cardNumberGrouping: [4,4,4,4]
  expirationFormat: "MM/YY"
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

CCProducts[/^6011/] =
  companyName: "Discover"
  companyShortname: "discover"
  cardNumberGrouping: [4,4,4,4]
  expirationFormat: "MM/YY"
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

CCIssuers = {}

###
# Example issuer customizations
# AmEx Issuers
CCIssuers[/^377411/] =
  issuingAuthority: "American Express"
  issuerName: "Black Card"
  issuerShortname: "blackcard"
# Visa Issuers
CCIssuers[/^481171/] =
  issuingAuthority: "Simple Finance Technology Corporation"
  issuerName: "Simple Debit Card"
  issuerShortname: "simple"
###

CCIssuers = {}

###
Hack fixes the Chase Sapphire card's stupid (nice?) layout non-conformity.
###
CCIssuers[/^414720/] =
  issuingAuthority: "Chase"
  issuerName: "Chase Sapphire Card"
  issuerShortname: "chase-sapphire"
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'front'

window.CCIssuers = CCIssuers
window.CCProducts = CCProducts
