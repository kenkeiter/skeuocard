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
        hiddenFaceFillPrompt: "<strong>Click here</strong> to <br />fill in the other side."
        hiddenFaceErrorWarning: "There's a problem on the other side."
        hiddenFaceSwitchPrompt: "Forget something?<br /> Flip the card over."
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
      value = $(e.target).val()
      @_setUnderlyingValue('name', value)
      @_updateValidation('name', value)

    @_inputViews.cvc.bind "keyup valueChanged", (e, input)=>
      value = $(e.target).val()
      @_setUnderlyingValue('cvc', value)
      @_updateValidation('cvc', value)

    @el.container.delegate "input", "keyup keydown", @_handleFieldTab.bind(@)

    @_tabViews.front.el.click => @flip()
    @_tabViews.back.el.click => @flip()

  _handleFieldTab: (e)->
    if e.which is 9
      currentFieldEl = $(e.currentTarget)
      _oppositeFace = if @visibleFace is 'front' then 'back' else 'front'
      _currentFace = if @visibleFace is 'front' then 'front' else 'back'
      backFieldEls = @el[_oppositeFace].find('input')
      frontFieldEls = @el[_currentFace].find('input')
      if @visibleFace is 'front' and
        @isFaceFilled('front') and
        backFieldEls.length > 0 and
        frontFieldEls.index(currentFieldEl) is -1
          @flip()
          backFieldEls.first().focus()
      if @visibleFace is 'back' and e.shiftKey
        @flip()
        frontFieldEls.last().focus()

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
      @trigger "fieldValidationStateWillChange.skeuocard", [@, fieldName, isFilled]
      @_inputViews[fieldName].el.toggleClass 'valid', isValid
      @_inputViews[fieldName].el.toggleClass 'invalid', not isValid
      @_state["#{fieldName}Valid"] = isValid
      @trigger "fieldValidationStateDidChange.skeuocard", [@, fieldName, isFilled]

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
                                     [@options.genericPlaceholder.length])
    if product?
      # reconfigure the expiration input groupings
      @_inputViews.exp.reconfigure
        pattern: product?.attrs.expirationFormat || "MM/YY"
      # reconfigure the CVC
      @_inputViews.cvc.attr
        maxlength: product.attrs.cvcLength
        placeholder: new Array(product.attrs.cvcLength + 1).join(@options.cardNumberPlaceholderChar)
    
    # set visibility and layout of fields
    @_inputViewsByFace = {front: [], back: []}
    for fieldName, view of @_inputViews
      destFace = product?.attrs.layout[fieldName] || null
      if destFace?
        if not @el[destFace].has(view.el)
          viewEl = view.el.detach()
          viewEl.appendTo(@el.container[destFace])
        @_inputViewsByFace[destFace].push view
        view.show()
      else if fieldName isnt 'number' # never hide number
        view.hide()

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
    @render()
    @el.cardBody.toggleClass('flip')
    surfaceName = if @visibleFace is 'front' then 'front' else 'back'
    @el[surfaceName].find('input').first().focus()
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

###
Skeuocard::FlipTabView
Handles rendering of the "flip button" control and its various warning and 
prompt states.

TODO: Rebuild this so that it observes events and contains its own logic.
###
class Skeuocard::FlipTabView
  constructor: (sc, face, opts = {})->
    @card = sc
    @face = face
    @el = $("<div class=\"flip-tab #{face}\"><p></p></div>")
    @options = opts
    @_state = {}
    @card.bind 'faceFillStateWillChange.skeuocard', 
               @_faceStateChanged.bind(@)
    @card.bind 'faceValidationStateWillChange.skeuocard', 
               @_faceValidationChanged.bind(@)
    @card.bind 'productWillChange.skeuocard', (e, card, prevProduct, newProduct)=>
      @hide() unless newProduct?

  _faceStateChanged: (e, card, face, isFilled)->
    @show() if isFilled is true
    @_state.opposingFaceFilled = isFilled if face isnt @face
    
    unless @_state.opposingFaceFilled is true
      @warn @options.strings.hiddenFaceFillPrompt, true

  _faceValidationChanged: (e, card, face, isValid)->
    @_state.opposingFaceValid = isValid if face isnt @face

    if @_state.opposingFaceValid
      @prompt @options.strings.hiddenFaceSwitchPrompt, true
    else
      if @_state.opposingFaceFilled
        @warn @options.strings.hiddenFaceErrorWarning, true 
      else
        @warn @options.strings.hiddenFaceFillPrompt, true

  _setText: (text)->
    @el.find('p').html(text)

  warn: (message, withAnimation = false)->
    @_resetClasses()
    @el.addClass('warn')
    @_setText(message)
    if withAnimation
      @el.removeClass('warn-anim')
      @el.addClass('warn-anim')

  prompt: (message, withAnimation = false)->
    @_resetClasses()
    @el.addClass('prompt')
    @_setText(message)
    if withAnimation
      @el.removeClass('valid-anim')
      @el.addClass('valid-anim')

  _resetClasses: ->
    @el.removeClass('valid-anim')
    @el.removeClass('warn-anim')
    @el.removeClass('warn')
    @el.removeClass('prompt')

  show: ->
    @el.show()

  hide: ->
    @el.hide()

###
Skeuocard::TextInputView
###
class Skeuocard::TextInputView

  bind: (args...)->
    @el.bind(args...)

  trigger: (args...)->
    @el.trigger(args...)

  _getFieldCaretPosition: (el)->
    input = el.get(0)
    if input.selectionEnd?
      return input.selectionEnd
    else if document.selection
      input.focus()
      sel = document.selection.createRange()
      selLength = document.selection.createRange().text.length
      sel.moveStart('character', -input.value.length)
      return selLength

  _setFieldCaretPosition: (el, pos)->
    input = el.get(0)
    if input.createTextRange?
      range = input.createTextRange()
      range.move "character", pos
      range.select()
    else if input.selectionStart?
      input.focus()
      input.setSelectionRange(pos, pos)

  show: ->
    @el.show()

  hide: ->
    @el.hide()

  addClass: (args...)->
    @el.addClass(args...)

  removeClass: (args...)->
    @el.removeClass(args...)

  _zeroPadNumber: (num, places)->
    zero = places - num.toString().length + 1
    return Array(zero).join("0") + num

###
# Skeuocard::SegmentedCardNumberInputView
# Provides a reconfigurable segmented input view for credit card numbers.
###
class Skeuocard::SegmentedCardNumberInputView
  
  _digits: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
  
  _keys:
    backspace: 8
    tab: 9
    enter: 13
    del: 46
    arrowLeft: 37
    arrowUp: 38
    arrowRight: 39
    arrowDown: 40
    arrows: [37..40]
    command: 16
    alt: 17

  _specialKeys: [8, 9, 13, 46, 37, 38, 39, 40, 16, 17]

  constructor: (opts = {})->
    @optDefaults = 
      value: ""
      groupings: [19]
      placeholderChar: "X"
    @options = $.extend({}, @optDefaults, opts)
    @_state =
      selectingAll: false     # indicates whether the field is in "select all"
    @_buildDOM()
    @setGroupings(@options.groupings)

  _buildDOM: ->
    @el = $('<fieldset>')
    @el.delegate "input", "keypress", @_handleGroupKeyPress.bind(@)
    @el.delegate "input", "keydown",  @_handleGroupKeyDown.bind(@)
    @el.delegate "input", "keyup",    @_handleGroupKeyUp.bind(@)
    @el.delegate "input", "paste",    @_handleGroupPaste.bind(@)
    @el.delegate "input", "change",   @_handleGroupChange.bind(@)

  _handleGroupKeyDown: (e)->
    # If this is called with the control or meta key, defer to another handler
    return @_handleModifiedKeyDown(e) if e.ctrlKey or e.metaKey

    inputGroupEl = $(e.currentTarget)
    currentTarget = e.currentTarget # get rid of that e.
    cursorStart = currentTarget.selectionStart
    cursorEnd = currentTarget.selectionEnd
    inputMaxLength = currentTarget.maxLength

    prevInputEl = inputGroupEl.prevAll('input')
    nextInputEl = inputGroupEl.nextAll('input')

    switch e.which
      # handle backspace
      when @_keys.backspace
        if prevInputEl.length > 0 and cursorEnd is 0
          @_focusField(prevInputEl.first(), 'end')
      # handle up arrow
      when @_keys.arrowUp
        if cursorEnd is inputMaxLength
          @_focusField(inputGroupEl, 'start')
        else
          @_focusField(inputGroupEl.prev(), 'end')
        e.preventDefault()
      # handle down arrow
      when @_keys.arrowDown
        if cursorEnd is inputMaxLength
          @_focusField(inputGroupEl.next(), 'start')
        else
          @_focusField(inputGroupEl, 'end')
        e.preventDefault()
      # handle left arrow
      when @_keys.arrowLeft
        if cursorEnd is 0
          @_focusField(inputGroupEl.prev(), 'end')
          e.preventDefault()
      # handle right arrow
      when @_keys.arrowRight
        if cursorEnd is inputMaxLength
          @_focusField(inputGroupEl.next(), 'start')
          e.preventDefault()
      else
        if not (e.which in @_specialKeys) and 
          (cursorStart is inputMaxLength and cursorEnd is inputMaxLength) and
          nextInputEl.length isnt 0
            @_focusField(nextInputEl.first(), 'start')
    
    # Allow the event to propagate, and otherwise be happy
    return true

  _handleGroupKeyPress: (e)->
    inputGroupEl = $(e.currentTarget)
    isDigit = (String.fromCharCode(e.which) in @_digits)
    
    return true if e.ctrlKey or e.metaKey
    return true if e.which is 0

    if (not e.shiftKey and (e.which in @_specialKeys)) or isDigit
      return true
    
    e.preventDefault()
    return false

  _handleGroupKeyUp: (e)->
    inputGroupEl = $(e.currentTarget)
    currentTarget = e.currentTarget # get rid of that e.
    inputMaxLength = currentTarget.maxLength

    cursorStart = currentTarget.selectionStart
    cursorEnd = currentTarget.selectionEnd
    
    nextInputEl = inputGroupEl.nextAll('input')

    return true if e.ctrlKey or e.metaKey # ignore control keys
    
    if @_state.selectingAll
      @_endSelectAll() if (e.which in @_specialKeys)

    if not (e.which in @_specialKeys) and 
      not (e.shiftKey and e.which is @_keys.tab) and
      (cursorStart is inputMaxLength and cursorEnd is inputMaxLength) and 
      nextInputEl.length isnt 0
        @_focusField(nextInputEl.first(), 'start')

    unless e.shiftKey and (e.which in @_specialKeys)
      @trigger('change', [@])

    return true

  _handleModifiedKeyDown: (e)->
    char = String.fromCharCode(e.which)
    switch char
      when 'a', 'A'
        @_beginSelectAll()
        e.preventDefault()

  _handleGroupPaste: (e)->
    # clean and re-split the value
    setTimeout =>
      newValue = @getValue().replace(/[^0-9]+/g, '')
      @_endSelectAll() if @_state.selectingAll
      @setValue(newValue)
      @trigger('change', [@])
    , 50
  
  _handleGroupChange: (e)->
    e.stopPropagation()

  _getFocusedField: ->
    @el.find("input:focus")

  _beginSelectAll: ->
    unless @el.hasClass('selecting-all')
      @_state.lastGrouping = @options.groupings
      @_state.lastLength = @getValue().length
      @setGroupings(@optDefaults.groupings)
      @el.addClass('selecting-all')
      fieldEl = @el.find("input")
      fieldEl[0].setSelectionRange(0, fieldEl.val().length)
      @_state.selectingAll = true
    else
      fieldEl = @el.find("input")
      fieldEl[0].setSelectionRange(0, fieldEl.val().length)

  _endSelectAll: ->
    if @el.hasClass('selecting-all')
      # if the value hasn't been changed while selecting all, restore grouping
      @_state.selectingAll = false
      # restore groupings if length is the same
      if @_state.lastLength is @getValue().length
        @setGroupings(@_state.lastGrouping)
      @el.removeClass('selecting-all')

  # figure out what position in the overall value we're at given a selection
  _indexInValueAtFieldSelection: (field)->
    groupingIndex = @el.find('input').index(field)
    offset = 0
    offset += len for len, i in @options.groupings when i < groupingIndex
    return offset + field[0].selectionEnd

  setGroupings: (groupings)->
    # store the value and current caret position so we can reapply it
    _currentField = @_getFocusedField()
    _value = @getValue()
    _caretPosition = 0
    if _currentField.length > 0
      _caretPosition = @_indexInValueAtFieldSelection(_currentField)
    # remove any existing input elements
    @el.empty() # remove all existing inputs
    for groupLength in groupings
      groupEl = $("<input>").attr
        type: 'text'
        pattern: '[0-9]*'
        size: groupLength
        maxlength: groupLength
        class: "group#{groupLength}"
        placeholder: new Array(groupLength+1).join(@options.placeholderChar)
      @el.append(groupEl)
    @options.groupings = groupings
    @setValue(_value)
    _currentField = @_focusFieldForValue([_caretPosition, _caretPosition])
    if _currentField? and _currentField[0].selectionEnd is _currentField[0].maxLength
      @_focusField(_currentField.next(), 'start')

  _focusFieldForValue: (place)->
    value = @getValue()
    if place is 'start'
      field = @el.find('input').first()
      @_focusField(field, place)
    else if place is 'end'
      field = @el.find('input').last()
      @_focusField(field, place)
    else
      field = null
      fieldOffset = null
      _lastStartPos = 0
      for groupLength, groupIndex in @options.groupings
        if place[1] > _lastStartPos and place[1] <= _lastStartPos + groupLength
          field = $(@el.find('input')[groupIndex])
          fieldPosition = place[1] - _lastStartPos
        _lastStartPos += groupLength
      if field? and fieldPosition?
        @_focusField(field, [fieldPosition, fieldPosition])
      else
        @_focusField(@el.find('input'), 'end')
    return field

  _focusField: (field, place)->
    if field.length isnt 0
      field[0].focus()
      if $(field[0]).is(':visible') and field[0] is document.activeElement
        if place is 'start'
          field[0].setSelectionRange(0, 0)
        else if place is 'end'
          fieldLen = field[0].maxLength
          field[0].setSelectionRange(fieldLen, fieldLen)
        else # array of start, end
          field[0].setSelectionRange(place[0], place[1])

  setValue: (newValue)->
    _lastStartPos = 0
    for groupLength, groupIndex in @options.groupings
      el = $(@el.find('input').get(groupIndex))
      groupVal = newValue.substr(_lastStartPos, groupLength)
      el.val(groupVal)
      _lastStartPos += groupLength

  getValue: ->
    buffer = ""
    buffer += $(el).val() for el in @el.find('input')
    return buffer

  maxLength: ->
    @options.groupings.reduce((a,b)->(a+b))

  bind: (args...)->
    @el.bind(args...)

  trigger: (args...)->
    @el.trigger(args...)

  show: ->
    @el.show()

  hide: ->
    @el.hide()

  addClass: (args...)->
    @el.addClass(args...)

  removeClass: (args...)->
    @el.removeClass(args...)


###
Skeuocard::ExpirationInputView
###
class Skeuocard::ExpirationInputView extends Skeuocard::TextInputView
  constructor: (opts = {})->
    # setup option defaults
    opts.pattern ||= "MM/YY"
    
    @options = opts
    # setup default values
    @date = null
    # create dom container
    @el = $("<fieldset>")
    @el.delegate "input", "keydown", (e)=> @_onKeyDown(e)
    @el.delegate "input", "keyup", (e)=> @_onKeyUp(e)

  _getFieldCaretPosition: (el)->
    input = el.get(0)
    if input.selectionEnd?
      return input.selectionEnd
    else if document.selection
      input.focus()
      sel = document.selection.createRange()
      selLength = document.selection.createRange().text.length
      sel.moveStart('character', -input.value.length)
      return selLength

  _setFieldCaretPosition: (el, pos)->
    input = el.get(0)
    if input.createTextRange?
      range = input.createTextRange()
      range.move "character", pos
      range.select()
    else if input.selectionStart?
      input.focus()
      input.setSelectionRange(pos, pos)

  setPattern: (pattern)->
    groupings = []
    patternParts = pattern.split('')
    _currentLength = 0
    for char, i in patternParts
      _currentLength++
      if patternParts[i+1] != char
        groupings.push([_currentLength, char])
        _currentLength = 0
    @options.groupings = groupings
    @_setGroupings(@options.groupings)

  _setGroupings: (groupings)->
    fieldChars = ['D', 'M', 'Y']
    @el.empty()
    _startLength = 0
    for group in groupings
      groupLength = group[0]
      groupChar = group[1]
      if groupChar in fieldChars # this group is a field
        input = $('<input>').attr
          type: 'text'
          pattern: '[0-9]*'
          placeholder: new Array(groupLength+1).join(groupChar)
          maxlength: groupLength
          class: 'cc-exp-field-' + groupChar.toLowerCase() + 
                 ' group' + groupLength
        input.data('fieldtype', groupChar)
        @el.append(input)
      else # this group is a separator
        sep = $('<span>').attr
          class: 'separator'
        sep.html(new Array(groupLength + 1).join(groupChar))
        @el.append(sep)
    @groupEls = @el.find('input')
    @_updateFieldValues() if @date?

  _updateFieldValues: ->
    currentDate = @date
    unless @groupEls # they need to be created
      return @setPattern(@options.pattern)
    @groupEls.each (i,_el)=>
      el = $(_el)
      groupLength = parseInt(el.attr('maxlength'))
      switch el.data('fieldtype')
        when 'M'
          el.val @_zeroPadNumber(currentDate.getMonth() + 1, groupLength)
        when 'D'
          el.val @_zeroPadNumber(currentDate.getDate(), groupLength)
        when 'Y'
          year = if groupLength >= 4 then currentDate.getFullYear() else 
                 currentDate.getFullYear().toString().substr(2,4)
          el.val(year)

  clear: ->
    @value = ""
    @date = null
    @groupEls.each ->
      $(@).val('')

  setValue: (newDate)->
    @date = newDate
    @_updateFieldValues()

  getValue: ->
    @date

  reconfigure: (opts)->
    if opts.pattern?
      @setPattern(opts.pattern)
    if opts.value?
      @setValue(opts.value)

  _onKeyDown: (e)->
    e.stopPropagation()
    groupEl = $(e.currentTarget)

    groupEl = $(e.currentTarget)
    groupMaxLength = parseInt(groupEl.attr('maxlength'))
    groupCaretPos = @_getFieldCaretPosition(groupEl)

    prevInputEl = groupEl.prevAll('input').first()
    nextInputEl = groupEl.nextAll('input').first()

    # Handle delete key
    if e.which is 8 and groupCaretPos is 0 and 
      not $.isEmptyObject(prevInputEl)
        prevInputEl.focus()

    if e.which in [37, 38, 39, 40] # arrow keys
      switch e.which
        when 37 # left
          if groupCaretPos is 0 and not $.isEmptyObject(prevInputEl)
            prevInputEl.focus()
        when 39 # right
          if groupCaretPos is groupMaxLength and not $.isEmptyObject(nextInputEl)
            nextInputEl.focus()
        when 38 # up
          if not $.isEmptyObject(groupEl.prev('input'))
            prevInputEl.focus()
        when 40 # down
          if not $.isEmptyObject(groupEl.next('input'))
            nextInputEl.focus()

  getRawValue: (fieldType)->
    parseInt(@el.find(".cc-exp-field-" + fieldType).val())

  _onKeyUp: (e)->
    e.stopPropagation()
    
    specialKeys = [8, 9, 16, 17, 18, 19, 20, 27, 33, 34, 35, 36,
                   37, 38, 39, 40, 45, 46, 91, 93, 144, 145, 224]
    arrowKeys = [37, 38, 39, 40]
    groupEl = $(e.currentTarget)
    groupMaxLength = parseInt(groupEl.attr('maxlength'))
    groupCaretPos = @_getFieldCaretPosition(groupEl)
    
    if e.which not in specialKeys
      # intercept bad chars, returning user to the right char pos if need be
      groupValLength = groupEl.val().length
      pattern = new RegExp('[^0-9]+', 'g')
      groupEl.val(groupEl.val().replace(pattern, ''))
      if groupEl.val().length < groupValLength # we caught bad char
        @_setFieldCaretPosition(groupEl, groupCaretPos - 1)
      else
        @_setFieldCaretPosition(groupEl, groupCaretPos)

    nextInputEl = groupEl.nextAll('input').first()

    if e.which not in specialKeys and 
      groupEl.val().length is groupMaxLength and 
      not $.isEmptyObject(nextInputEl) and
      @_getFieldCaretPosition(groupEl) is groupMaxLength
        nextInputEl.focus()

    # get a date object representing what's been entered
    day = @getRawValue('d') || 1
    month = @getRawValue('m')
    year = @getRawValue('y')
    if month is 0 or year is 0
      @date = null
    else
      year += 2000 if year < 2000
      dateObj = new Date(year, month-1, day)
      @date = dateObj
    @trigger("keyup", [@])
    return false

  _inputGroupEls: ->
    @el.find("input")

###
Skeuocard::TextInputView
###
class Skeuocard::TextInputView extends Skeuocard::TextInputView
  constructor: (opts)->
    @el = $("<input>").attr
      type: 'text'
      placeholder: opts.placeholder
      class: opts.class
    @options = opts

  clear: ->
    @el.val("")

  attr: (args...)->
    @el.attr(args...)

  setValue: (newValue)->
    @el.val(newValue)

  getValue: ->
    @el.val()

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
    number: 'front'
    exp: 'front'
    name: 'front'
    cvc: 'front'
