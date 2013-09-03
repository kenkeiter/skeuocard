###
Skeuocard::CardProduct
###

class Skeuocard::CardProduct
  @_registry: [] # registry of stored CardProduct instances

  # Create and register a new CardProduct instance.
  @create: (opts)->
    @_registry.push new Skeuocard::CardProduct(opts)

  @firstMatchingShortname: (shortname)->
    for card in @_registry
      return card if card.attrs.companyShortname is shortname
    return null

  @firstMatchingNumber: (number)->
    for card in @_registry
      if card.pattern.test(number)
        if (variation = card.firstVariationMatchingNumber(number))
          combinedOptions = $.extend({}, card.attrs, variation)
          return new Skeuocard::CardProduct(combinedOptions)
        return new Skeuocard::CardProduct(card.attrs)
    return null

  constructor: (attrs)->
    @attrs = $.extend({}, attrs)
    @pattern = @attrs.pattern
    @_variances = []
    # syntactic sugar ;)
    @name =
      isFilled: @_isCardNameFilled.bind(@)
      isValid: @_isCardNameValid.bind(@)
    @number =
      isFilled: @_isCardNumberFilled.bind(@)
      isValid: @_isCardNumberValid.bind(@)
    @exp =
      isFilled: @_isCardExpirationFilled.bind(@)
      isValid: @_isCardExpirationValid.bind(@)
    @cvc =
      isFilled: @_isCardCVCFilled.bind(@)
      isValid: @_isCardCVCValid.bind(@)

  createVariation: (attrs)->
    @_variances.push attrs

  firstVariationMatchingNumber: (number)->
    for variance in @_variances
      return variance if variance.pattern.test(number)
    return null

  fieldsForLayoutFace: (faceName)->
    (fieldName for fieldName, face of @attrs.layout when face is faceName)

  _id: ->
    ident = @attrs.companyShortname
    if @attrs.issuerShortname?
      ident += @attrs.issuerShortname
    return ident

  eql: (otherCardProduct)->
    otherCardProduct?._id() is @_id()

  _daysInMonth: (m, y)->
    return switch m
      when 1 then (if (y % 4 is 0 and y % 100) or y % 400 is 0 then 29 else 28)
      when 3, 5, 8, 10 then 30
      else 31

  _isCardNumberFilled: (number)->
    return (number.length in @attrs.cardNumberLength) if @attrs.cardNumberLength?

  _isCardExpirationFilled: (exp)->
    currentDate = Skeuocard.currentDate
    return false unless exp? and exp.getMonth? and exp.getFullYear?
    day = exp.getDate()
    month = exp.getMonth()
    year = exp.getFullYear()
    return (day > 0 and day <= @_daysInMonth(month, year)) and
           (month >= 0 and month <= 11) and
           (year >= 1900 and year <= currentDate.getFullYear() + 10)

  _isCardCVCFilled: (cvc)->
    cvc.length is @attrs.cvcLength

  _isCardNameFilled: (name)->
    name.length > 0

  _isCardNumberValid: (number)->
    /^\d+$/.test(number) and
    (@attrs.validateLuhn is false or @_isValidLuhn(number)) and
    @_isCardNumberFilled(number)

  _isCardExpirationValid: (exp)->
    return false unless exp? and exp.getMonth? and exp.getFullYear?
    currentDate = Skeuocard.currentDate
    day = exp.getDate()
    month = exp.getMonth()
    year = exp.getFullYear()
    isDateInFuture = (year == currentDate.getFullYear() and
                      month >= currentDate.getMonth()) or
                      year > currentDate.getFullYear()
    return isDateInFuture and @_isCardExpirationFilled(exp)

  _isCardCVCValid: (cvc)->
    @_isCardCVCFilled(cvc)

  _isCardNameValid: (name)->
    @_isCardNameFilled(name)

  _isValidLuhn: (number)->
    sum = 0
    alt = false
    for i in [number.length - 1..0] by -1
      num = parseInt number.charAt(i), 10
      return false if isNaN(num)
      if alt
        num *= 2
        num = (num % 10) + 1 if num > 9
      alt = !alt
      sum += num
    sum % 10 is 0


###
# Seed CardProducts.
###
Skeuocard::CardProduct.create
  pattern: /^(36|38|30[0-5])/
  companyName: "Diners Club"
  companyShortname: "dinersclubintl"
  cardNumberGrouping: [4,6,4]
  cardNumberLength: [14]
  expirationFormat: "MM/YY"
  cvcLength: 3
  validateLuhn: true
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

Skeuocard::CardProduct.create 
  pattern: /^35/
  companyName: "JCB"
  companyShortname: "jcb"
  cardNumberGrouping: [4,4,4,4]
  cardNumberLength: [16]
  expirationFormat: "MM/'YY"
  cvcLength: 3
  validateLuhn: true
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

Skeuocard::CardProduct.create 
  pattern: /^3[47]/
  companyName: "American Express"
  companyShortname: "amex"
  cardNumberGrouping: [4,6,5]
  cardNumberLength: [15]
  expirationFormat: "MM/YY"
  cvcLength: 4
  validateLuhn: true
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'front'

Skeuocard::CardProduct.create 
  pattern: /^(6706|6771|6709)/
  companyName: "Laser Card Services Ltd."
  companyShortname: "laser"
  cardNumberGrouping: [4,4,4,4]
  cardNumberLength: [16..19]
  expirationFormat: "MM/YY"
  validateLuhn: true
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

Skeuocard::CardProduct.create 
  pattern: /^4/
  companyName: "Visa"
  companyShortname: "visa"
  cardNumberGrouping: [4,4,4,4]
  cardNumberLength: [13..16]
  expirationFormat: "MM/YY"
  validateLuhn: true
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

Skeuocard::CardProduct.create 
  pattern: /^(62|88)/
  companyName: "China UnionPay"
  companyShortname: "unionpay"
  cardNumberGrouping: [19]
  cardNumberLength: [16..19]
  expirationFormat: "MM/YY"
  validateLuhn: false
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

Skeuocard::CardProduct.create 
  pattern: /^5[1-5]/
  companyName: "Mastercard"
  companyShortname: "mastercard"
  cardNumberGrouping: [4,4,4,4]
  cardNumberLength: [16]
  expirationFormat: "MM/YY"
  validateLuhn: true
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

Skeuocard::CardProduct.create 
  pattern: /^(5018|5020|5038|6304|6759|676[1-3])/
  companyName: "Maestro (MasterCard)"
  companyShortname: "maestro"
  cardNumberGrouping: [4,4,4,4]
  cardNumberLength: [12..19]
  expirationFormat: "MM/YY"
  validateLuhn: true
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

Skeuocard::CardProduct.create 
  pattern: /^(6011|65|64[4-9]|622)/
  companyName: "Discover"
  companyShortname: "discover"
  cardNumberGrouping: [4,4,4,4]
  cardNumberLength: [16]
  expirationFormat: "MM/YY"
  validateLuhn: true
  cvcLength: 3
  layout:
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'back'

# Variation of Visa layout specific to Chase Sapphire Card.
visaProduct = Skeuocard::CardProduct.firstMatchingShortname 'visa'
visaProduct.createVariation
  pattern: /^414720/
  issuingAuthority: "Chase"
  issuerName: "Chase Sapphire Card"
  issuerShortname: "chase-sapphire"
  layout:
    name: 'front'
    number: 'front'
    exp: 'front'
    cvc: 'front'
