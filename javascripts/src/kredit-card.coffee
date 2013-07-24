class KreditCardInput

  constructor: (sel, options={}) ->
    @options = options
    @product = undefined
    @issuer = undefined
    
    # set up container
    @containerEl = $(sel)
    @containerEl.addClass('js-enabled') # hide unnecessary elements
    @cardSurfaceEl = @containerEl.find('.card')
    @faceFrontEl = @containerEl.find('.face.front')
    @faceBackEl = @containerEl.find('.face.back')
    
    # attach fields
    @fieldEls =
      number: @containerEl.find('.cc-number.value')
      exp: @containerEl.find('.cc-exp.value')
      name: @containerEl.find('.cc-name.value')
      cvc: @containerEl.find('.cc-cvc.value')

    # If a valid type or card number was supplied.
    if shortName = @containerEl.find('#cc-type-choice :selected').attr('value')
      prod = getProductByShortname(shortName)
      @setProduct(prod)
    else if initialCardNumber = @fieldEls.number.val()
      prod = getProductByNumber(initialCardNumber)
      @setProduct(prod)
    else
      @setProduct()

    @fieldEls.number.bind 'keyup', =>
      @setNumber(@fieldEls.number.val())

  flip: ->
    @cardSurfaceEl.toggleClass('flip')

  # Set the card number; may cause a re-layout.
  setNumber: (num)->
    # if matched product has changed, go ahead and change update the layout
    @fieldEls.number.val(num)

    matchedProduct = @getProductByNumber(num)
    if matchedProduct isnt @product
      @setProduct(matchedProduct)

    matchedIssuer = @getIssuerByNumber(num)
    if matchedIssuer isnt @issuer
      @setIssuer(matchedIssuer || {})

  setIssuer: (issuer)->
    @containerEl.removeClass (index, css)=>
      (css.match(/\bissuer-\S+/g) || []).join(' ')

    if issuer.issuerShortname?
      @containerEl.addClass("issuer-#{issuer.issuerShortname}")

    @issuer = issuer

  ###
  Set the product. Ensures visibility of generic fields if product is 
  undefined -- otherwise, hides generic fields and replaces them with product-
  specific ones. The product-specific fields update the underlying generic 
  fields as they are changed, ensuring smooth form submission.
  ###
  setProduct: (prod)->
    @containerEl.removeClass (index, css)=>
      (css.match(/\bproduct-\S+/g) || []).join(' ')

    # If we should show generic fields only...
    unless prod?
      @containerEl.addClass('product-generic')
      @containerEl.find('.product-specific').remove() # TODO: change to fade out
      @product = prod
      @fieldEls.number.caretToEnd()
      return

    # Otherwise, render product-specific fields, set to update the underlying 
    # generic fields.
    @containerEl.addClass("product-#{prod.companyShortname}")
    
    # generate CC number input fieldset
    @fieldNumberEl = $('<fieldset>').addClass('field cc-number product-specific')
    
    start_i = 0
    last_group = null
    for length, i in prod.cardNumberGrouping
      input = $('<input>').attr
        type: 'text'
        placeholder: new Array(length+1).join('X')
        maxlength: length
        size: length
        name: 'cc_number_segment'
        class: 'cc-number-group'
      # copy over any digits from the generic field
      unless @fieldEls.number.val().length < start_i
        input.attr('value', @fieldEls.number.val().substr(start_i, start_i + length))
        last_group = input
      start_i += length
      # append the element to the fieldset
      @fieldNumberEl.append(input)

    numberGroups = @fieldNumberEl.find('input')
    numberGroups.autotab_magic().autotab_filter('numeric')
    numberGroups.bind 'keyup', (e)=>
      value = ""
      @fieldNumberEl.find('input').each (i, ele)->
        value += $(ele).val()
      @setNumber(value)
    @faceFrontEl.prepend(@fieldNumberEl) # TODO: change to fade in
    last_group.caretToEnd();

    # generate CC expiration input
    @fieldExpEl = $('<fieldset>').addClass('field cc-exp product-specific')
    currentLength = 0
    formatParticles = prod.expirationFormat.split('')
    charWhitelist = ['M', 'D', 'Y']
    for char, i in formatParticles
      currentLength++
      
      if formatParticles[i+1] != char
        if char in charWhitelist
          # finish the input
          input = $('<input>').attr
            type: 'text'
            placeholder: new Array(currentLength+1).join(char)
            maxlength: currentLength
            size: currentLength
            name: 'cc_exp_' + char.toLowerCase()
            class: 'cc-exp-group'
          @fieldExpEl.append(input)
        else
          # add a separator
          sep = $('<span class="separator">' + char + '</span>')
          @fieldExpEl.append(sep)
        
        currentLength = 0 # reset length count

    expGroups = @fieldExpEl.find('input')
    expGroups.autotab_magic().autotab_filter('numeric')
    expGroups.bind 'keyup', (e)=>
      value = ""
      @fieldExpEl.find('input').each (i, ele)->
        value += $(ele).val()
    @faceFrontEl.prepend(@fieldExpEl)

    # update the current product
    @product = prod

  getProductByNumber: (num)->
    for m, d of CCProducts
      parts = m.split('/')
      matcher = new RegExp(parts[1], parts[2])
      if matcher.test(num)
        return d
    return undefined
  
  getIssuerByNumber: (num)->
    for m, d of CCIssuers
      parts = m.split('/')
      matcher = new RegExp(parts[1], parts[2])
      if matcher.test(num)
        return d
    return undefined

  getProductByShortname: (name)->
    console.log("Not yet implemented.")

  isValidLuhn: (identifier)->
    sum = 0
    alt = false
    for i in [identifier.length - 1..0] by -1
      num = parseInt identifier.charAt(i), 10
      return false if isNaN(num)
      if alt
        num *= 2
        num = (num % 10) + 1 if num > 9
      alt = !alt
      sum += num
    sum % 10 is 0

  ###
  Check if the information on the front of the card is valid
  * validate the credit card number against the Luhn algo
  * validate the date
  * validate the name
  # optionally validate the CVC if it's on the front
  ###
  isFrontValid: ->
    valid = true
    valid &= @isValidLuhn(@fieldEls.number.val())
    valid &= @fieldEls.exp.val().length > 0
    valid &= @fieldEls.name.val().length > 0
    return valid


window.KreditCardInput = KreditCardInput