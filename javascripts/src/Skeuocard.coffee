###
"Skeuocard" -- A Skeuomorphic Credit-Card Input Enhancement
@description Skeuocard is a skeuomorphic credit card input plugin, supporting 
             progressive enhancement. It renders a credit-card input which 
             behaves similarly to a physical credit card.
@author Ken Keiter <ken@kenkeiter.com>
@updated 2013-07-25
@website http://kenkeiter.com/
@exports [window.Skeuocard]
###

$ = jQuery

class Skeuocard

  @currentDate: new Date()
  
  constructor: (el, opts = {})->
    @el = container: $(el), underlyingFields: {}
    @_inputViews = {}
    @_inputViewsByFace = {front: [], back: []}
    @_tabViews = {}
    @_state = {}
    @product = null
    @visibleFace = 'front'
    
    # configure default opts
    optDefaults = 
      debug: false
      dontFocus: false
      acceptedCardProducts: null
      cardNumberPlaceholderChar: 'X'
      genericPlaceholder: "XXXX XXXX XXXX XXXX"
      typeInputSelector: '[name="cc_type"]'
      numberInputSelector: '[name="cc_number"]'
      expMonthInputSelector: '[name="cc_exp_month"]'
      expYearInputSelector: '[name="cc_exp_year"]'
      nameInputSelector: '[name="cc_name"]'
      cvcInputSelector: '[name="cc_cvc"]'
      initialValues: {}
      validationState: {}
      strings:
        hiddenFaceFillPrompt: "<strong>Click here</strong> to <br>fill in the other side."
        hiddenFaceErrorWarning: "There's a problem on the other side."
        hiddenFaceSwitchPrompt: "Forget something?<br> Flip the card over."
    @options = $.extend(optDefaults, opts)
    
    # initialize the card
    @_conformDOM()            # conform the DOM, add our elements
    @_bindInputEvents()       # bind input and interaction events
    @_importImplicitOptions() # import init options from DOM element attrs
    @render()                 # perform initial render

  # Debugging helper; if debug is set to true at instantiation, messages will 
  # be printed to the console.
  _log: (msg...)->
    if console?.log and !!@options.debug
      console.log("[skeuocard]", msg...) if @options.debug?

  # Trigger an event on a Skeuocard instance (jQuery's #trigger signature).
  trigger: (args...)->
    @el.container.trigger(args...)

  # Bind an event handler on a Skeuocard instance (jQuery's #trigger signature).
  bind: (args...)->
    @el.container.bind(args...)

  ###
  Transform the elements within the container, conforming the DOM so that it 
  becomes styleable, and that the underlying inputs are hidden.
  ###
  _conformDOM: ->
    @el.container.removeClass('no-js')
    @el.container.addClass("skeuocard js")
    # remove anything that's not an underlying form field
    @el.container.find("> :not(input,select,textarea)").remove()
    @el.container.find("> input,select,textarea").hide()
    # Attach underlying form fields.
    @el.underlyingFields =
      type: @el.container.find(@options.typeInputSelector)
      number: @el.container.find(@options.numberInputSelector)
      expMonth: @el.container.find(@options.expMonthInputSelector)
      expYear: @el.container.find(@options.expYearInputSelector)
      name: @el.container.find(@options.nameInputSelector)
      cvc: @el.container.find(@options.cvcInputSelector)
    # construct the necessary card elements
    @el.front    = $("<div>").attr(class: "face front")
    @el.back     = $("<div>").attr(class: "face back")
    @el.cardBody = $("<div>").attr(class: "card-body")
    # add elements to the DOM
    @el.front.appendTo(@el.cardBody)
    @el.back.appendTo(@el.cardBody)
    @el.cardBody.appendTo(@el.container)
    # create the validation indicator (flip tab), and attach them.
    @_tabViews.front = new Skeuocard::FlipTabView(@, 'front', strings: @options.strings)
    @_tabViews.back  = new Skeuocard::FlipTabView(@, 'back', strings: @options.strings)
    @el.front.prepend(@_tabViews.front.el)
    @el.back.prepend(@_tabViews.back.el)
    @_tabViews.front.hide()
    @_tabViews.back.hide()
    # Create new input views, attach them to the appropriate surfaces
    @_inputViews =
      number: new @SegmentedCardNumberInputView()
      exp:    new @ExpirationInputView(currentDate: @options.currentDate)
      name:   new @TextInputView(class: "cc-name", placeholder: "YOUR NAME")
      cvc:    new @TextInputView(class: "cc-cvc", placeholder: "XXX", requireMaxLength: true)
    # style and attach the number view to the DOM
    @_inputViews.number.el.addClass('cc-number')
    @_inputViews.number.el.appendTo(@el.front)
    # attach name input
    @_inputViews.name.el.appendTo(@el.front)
    # style and attach the exp view to the DOM
    @_inputViews.exp.el.addClass('cc-exp')
    @_inputViews.exp.el.appendTo(@el.front)
    # attach cvc field to the DOM
    @_inputViews.cvc.el.appendTo(@el.back)

    return @el.container

  ###
  Import implicit initialization options from the DOM. Brings in things like 
  the accepted card type, initial validation state, existing values, etc.
  ###
  _importImplicitOptions: ->
    
    for fieldName, fieldEl of @el.underlyingFields
      # import initial values, with constructor options taking precedence
      unless @options.initialValues[fieldName]?
        @options.initialValues[fieldName] = fieldEl.val()
      else # update underlying field value so that it is canonical.
        @options.initialValues[fieldName] = @options.initialValues[fieldName].toString()
        @_setUnderlyingValue(fieldName, @options.initialValues[fieldName])
      # set a flag if any fields were initially filled
      if @options.initialValues[fieldName].length > 0
        @_state['initiallyFilled'] = true
      # import initial validation state
      unless @options.validationState[fieldName]?
        @options.validationState[fieldName] = not fieldEl.hasClass('invalid')
            
    # If no explicit acceptedCardProducts were specified, determine accepted 
    # card products using the underlying type select field.
    unless @options.acceptedCardProducts?
      @options.acceptedCardProducts = []
      @el.underlyingFields.type.find('option').each (i, _el)=>
        el = $(_el)
        shortname = el.attr('data-sc-type') || el.attr('value')
        @options.acceptedCardProducts.push shortname

    # setup default values; when render is called, these will be picked up
    if @options.initialValues.number.length > 0
      @set 'number', @options.initialValues.number
    
    if @options.initialValues.name.length > 0
      @set 'name', @options.initialValues.name

    if @options.initialValues.cvc.length > 0
      @set 'cvc', @options.initialValues.cvc

    if @options.initialValues.expYear.length > 0 and
      @options.initialValues.expMonth.length > 0
        _initialExp = new Date parseInt(@options.initialValues.expYear),
                               parseInt(@options.initialValues.expMonth) - 1, 1
        @set 'exp', _initialExp

    @_updateValidationForFace('front')
    @_updateValidationForFace('back')

  set: (field, newValue)->
    @_inputViews[field].setValue(newValue)
    @_inputViews[field].trigger('valueChanged', @_inputViews[field])

  ###
  Bind interaction events to their appropriate handlers.
  ###
  _bindInputEvents: ->
    # bind change handlers to render
    @el.underlyingFields.number.bind "change", (e)=> 
      @_inputViews.number.setValue @_getUnderlyingValue('number')
      @render()

    _expirationChange = (e)=>
      month = parseInt @_getUnderlyingValue('expMonth')
      year  = parseInt @_getUnderlyingValue('expYear')
      @_inputViews.exp.setValue new Date(year, month - 1)
      @render()

    @el.underlyingFields.expMonth.bind "change", _expirationChange
    @el.underlyingFields.expYear.bind "change", _expirationChange

    @el.underlyingFields.name.bind "change", (e)=> 
      @_inputViews.exp.setValue @_getUnderlyingValue('name')
      @render()

    @el.underlyingFields.cvc.bind "change", (e)=> 
      @_inputViews.exp.setValue @_getUnderlyingValue('cvc')
      @render()

    # bind change events to their underlying form elements
    @_inputViews.number.bind "change valueChanged", (e, input)=>
      cardNumber = input.getValue()
      @_setUnderlyingValue 'number', cardNumber
      @_updateValidation 'number', cardNumber
      # update the product if needed.
      number = @_getUnderlyingValue('number')
      matchedProduct = Skeuocard::CardProduct.firstMatchingNumber(number)
      # check if the product is accepted
      if not @product?.eql(matchedProduct)
        @_log("Product will change:", @product, "=>", matchedProduct)
        if matchedProduct?.attrs.companyShortname in @options.acceptedCardProducts
          @trigger 'productWillChange.skeuocard', [@, @product, matchedProduct]
          previousProduct = @product
          @el.container.removeClass('unaccepted')
          @_renderProduct(matchedProduct)
          @product = matchedProduct
        else if matchedProduct?
          @trigger 'productWillChange.skeuocard', [@, @product, null]
          @el.container.addClass('unaccepted')
          @_renderProduct(null)
          @product = null
        else
          @trigger 'productWillChange.skeuocard', [@, @product, null]
          @el.container.removeClass('unaccepted')
          @_renderProduct(null)
          @product = null
        @trigger 'productDidChange.skeuocard', [@, previousProduct, @product]
    
    @_inputViews.exp.bind "keyup valueChanged", (e, input)=>
      newDate = input.getValue()
      @_updateValidation('exp', newDate)
      if newDate?
        @_setUnderlyingValue('expMonth', newDate.getMonth() + 1)
        @_setUnderlyingValue('expYear',  newDate.getFullYear())

    @_inputViews.name.bind "keyup valueChanged", (e, input)=>
      value = input.getValue()
      @_setUnderlyingValue('name', value)
      @_updateValidation('name', value)

    @_inputViews.cvc.bind "keyup valueChanged", (e, input)=>
      value = input.getValue()
      @_setUnderlyingValue('cvc', value)
      @_updateValidation('cvc', value)

    @el.container.delegate "input", "keyup keydown", @_handleFieldTab.bind(@)

    @_tabViews.front.el.click => @flip()
    @_tabViews.back.el.click => @flip()

  _handleFieldTab: (e)->
    if e.which is 9 # tab
      currentFieldEl = $(e.currentTarget)
      _oppositeFace = if @visibleFace is 'front' then 'back' else 'front'
      _currentFace = if @visibleFace is 'front' then 'front' else 'back'
      backFieldEls = @el[_oppositeFace].find('input')
      frontFieldEls = @el[_currentFace].find('input')

      if @visibleFace is 'front' and
        @el.front.hasClass('filled') and
        backFieldEls.length > 0 and
        frontFieldEls.index(currentFieldEl) is frontFieldEls.length-1 and
        not e.shiftKey
          @flip()
          backFieldEls.first().focus()
          e.preventDefault()
      if @visibleFace is 'back' and e.shiftKey
        @flip()
        backFieldEls.last().focus() # other side, now...
        e.preventDefault()
    return true

  _updateValidation: (fieldName, newValue)->
    return false unless @product?

    # Check against the current product to determine if the field is filled
    isFilled = @product[fieldName].isFilled(newValue)
    # If an initial value was supplied and marked as invalid, ensure that it 
    # has been changed to a new value.
    needsFix = @options.validationState[fieldName]? is false
    isFixed = @options.initialValues[fieldName]? and
               newValue isnt @options.initialValues[fieldName]
    # Check validity of value, asserting fixes have occurred if necessary.
    isValid  = @product[fieldName].isValid(newValue) and ((needsFix and isFixed) or true)

    # Determine if state changed
    fillStateChanged = @_state["#{fieldName}Filled"] isnt isFilled
    validationStateChanged = @_state["#{fieldName}Valid"] isnt isValid

    # If the fill state has changed, trigger events, and make styling changes.
    if fillStateChanged
      @trigger "fieldFillStateWillChange.skeuocard", [@, fieldName, isFilled]
      @_inputViews[fieldName].el.toggleClass 'filled', isFilled
      @_state["#{fieldName}Filled"] = isFilled
      @trigger "fieldFillStateDidChange.skeuocard", [@, fieldName, isFilled]
    
    # If the valid state has changed, trigger events, and make styling changes.
    if validationStateChanged
      @trigger "fieldValidationStateWillChange.skeuocard", [@, fieldName, isValid]
      @_inputViews[fieldName].el.toggleClass 'valid', isValid
      @_inputViews[fieldName].el.toggleClass 'invalid', not isValid
      @_state["#{fieldName}Valid"] = isValid
      @trigger "fieldValidationStateDidChange.skeuocard", [@, fieldName, isValid]

    @_updateValidationForFace(@visibleFace)

  _updateValidationForFace: (face)->
    fieldsFilled = (iv.el.hasClass('filled') for iv in @_inputViewsByFace[face]).every(Boolean)
    fieldsValid  = (iv.el.hasClass('valid') for iv in @_inputViewsByFace[face]).every(Boolean)

    isFilled = (fieldsFilled and @product?) or (@_state['initiallyFilled'] or false)
    isValid  = fieldsValid and @product?

    fillStateChanged = @_state["#{face}Filled"] isnt isFilled
    validationStateChanged = @_state["#{face}Valid"] isnt isValid

    if fillStateChanged
      @trigger "faceFillStateWillChange.skeuocard", [@, face, isFilled]
      @el[face].toggleClass 'filled', isFilled
      @_state["#{face}Filled"] = isFilled
      @trigger "faceFillStateDidChange.skeuocard", [@, face, isFilled]

    if validationStateChanged
      @trigger "faceValidationStateWillChange.skeuocard", [@, face, isValid]
      @el[face].toggleClass 'valid', isValid
      @el[face].toggleClass 'invalid', not isValid
      @_state["#{face}Valid"] = isValid
      @trigger "faceValidationStateDidChange.skeuocard", [@, face, isValid]

  ###
  Assert rendering changes necessary for the current product. Passing a null 
  value instead of a product will revert the card to a generic state.
  ###
  _renderProduct: (product)->
    @_log("[_renderProduct]", "Rendering product:", product)

    # remove existing product and issuer classes (destyling product)
    @el.container.removeClass (index, css)=>
      (css.match(/\b(product|issuer)-\S+/g) || []).join(' ')
    # add classes necessary to identify new product
    if product?.attrs.companyShortname?
      @el.container.addClass("product-#{product.attrs.companyShortname}")
    if product?.attrs.issuerShortname?
      @el.container.addClass("issuer-#{product.attrs.issuerShortname}")
    # update the underlying card type field
    @_setUnderlyingValue('type', product?.attrs.companyShortname || null)
    # reconfigure the number input groupings
    @_inputViews.number.setGroupings(product?.attrs.cardNumberGrouping || 
                                     [@options.genericPlaceholder.length], @options.dontFocus)
    delete @options.dontFocus
    if product?
      # reconfigure the expiration input groupings
      @_inputViews.exp.reconfigure
        pattern: product?.attrs.expirationFormat || "MM/YY"
      # reconfigure the CVC
      @_inputViews.cvc.attr
        maxlength: product.attrs.cvcLength
        placeholder: new Array(product.attrs.cvcLength + 1).join(@options.cardNumberPlaceholderChar)
    
      # set visibility and re-layout fields
      @_inputViewsByFace = {front: [], back: []}
      focused = $('input:focus') # allow restoration of focus upon re-attachment
      for fieldName, destFace of product.attrs.layout
        @_log("Moving", fieldName, "to", destFace)
        viewEl = @_inputViews[fieldName].el.detach()
        viewEl.appendTo(@el[destFace])
        @_inputViewsByFace[destFace].push @_inputViews[fieldName]
        @_inputViews[fieldName].show()
      # Restore focus. Use setTimeout to resolve IE10 issue.
      setTimeout =>
        if (fieldEl = focused.first())?
          fieldLength = fieldEl[0].maxLength
          fieldEl.focus()
          fieldEl[0].setSelectionRange(fieldLength, fieldLength)
      , 10
    else
      for fieldName, view of @_inputViews
        view.hide() if fieldName isnt 'number'

    return product

  _renderValidation: ->
    # update the validation state of all fields
    for fieldName, fieldView of @_inputViews
      @_updateValidation(fieldName, fieldView.getValue())

  # Update the card's visual representation to reflect internal state.
  render: ->
    @_renderProduct(@product)
    @_renderValidation()
    # @_flipToInvalidSide()

  # Flip the card over.
  flip: ->
    targetFace = if @visibleFace is 'front' then 'back' else 'front'
    @trigger('faceWillBecomeVisible.skeuocard', [@, targetFace])
    @visibleFace = targetFace
    @el.cardBody.toggleClass('flip')
    surfaceName = if @visibleFace is 'front' then 'front' else 'back'
    @el[surfaceName].find('.cc-field').not('.filled').find('input').first().focus()
    @trigger('faceDidBecomeVisible.skeuocard', [@, targetFace])

  # Set a value in the underlying form.
  _setUnderlyingValue: (field, newValue)->
    fieldEl = @el.underlyingFields[field]
    _newValue = (newValue || "").toString()
    throw "Set underlying value of unknown field: #{field}." unless fieldEl?
    
    @trigger('change.skeuocard', [@])
    unless fieldEl.is('select')
      @el.underlyingFields[field].val(_newValue)
    else
      remapAttrKey = "data-sc-" + field.toLowerCase()
      fieldEl.find('option').each (i, _el)=>
        optionEl = $(_el)
        if _newValue is (optionEl.attr(remapAttrKey) || optionEl.attr('value'))
          @el.underlyingFields[field].val optionEl.attr('value')

  # Get a value from the underlying form.
  _getUnderlyingValue: (field)->
    @el.underlyingFields[field]?.val()

  isValid: ->
    not @el.front.hasClass('invalid') and not @el.back.hasClass('invalid')


# Export the object.
window.Skeuocard = Skeuocard
