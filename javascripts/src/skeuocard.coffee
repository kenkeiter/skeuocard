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

class Skeuocard
  
  constructor: (el, opts = {})->
    @el = {container: $(el), underlyingFields: {}}
    @_inputViews = {}
    @_tabViews = {}
    @product = undefined
    @productShortname = undefined
    @issuerShortname = undefined
    @_cardProductNeedsLayout = true
    @acceptedCardProducts = {}
    @visibleFace = 'front'
    @_initialValidationState = {}
    @_validationState = {number: false, exp: false, name: false, cvc: false}
    @_faceFillState = {front: false, back: false}
    
    # configure default opts
    optDefaults = 
      debug: false
      acceptedCardProducts: []
      cardNumberPlaceholderChar: 'X'
      genericPlaceholder: "XXXX XXXX XXXX XXXX"
      typeInputSelector: '[name="cc_type"]'
      numberInputSelector: '[name="cc_number"]'
      expInputSelector: '[name="cc_exp"]'
      nameInputSelector: '[name="cc_name"]'
      cvcInputSelector: '[name="cc_cvc"]'
      currentDate: new Date()
      initialValues: {}
      validationState: {}
      strings:
        hiddenFaceFillPrompt: "Click here to<br /> fill in the other side."
        hiddenFaceErrorWarning: "There's a problem on the other side."
        hiddenFaceSwitchPrompt: "Back to the other side..."
    @options = $.extend(optDefaults, opts)
    
    # initialize the card
    @_conformDOM()   # conform the DOM to match our styling requirements
    @_setAcceptedCardProducts() # determine which card products to accept
    @_createInputs() # create reconfigurable input views
    @_updateProductIfNeeded()
    @_flipToInvalidSide()


  # Transform the elements within the container, conforming the DOM so that it 
  # becomes styleable, and that the underlying inputs are hidden.
  _conformDOM: ->
    # for CSS determination that this is an enhanced input, add 'js' class to 
    # the container
    @el.container.removeClass('no-js')
    @el.container.addClass("skeuocard js")
    # remove anything that's not an underlying form field
    @el.container.find("> :not(input,select,textarea)").remove()
    @el.container.find("> input,select,textarea").hide()
    # attach underlying form elements
    @el.underlyingFields =
      type: @el.container.find(@options.typeInputSelector)
      number: @el.container.find(@options.numberInputSelector)
      exp: @el.container.find(@options.expInputSelector)
      name: @el.container.find(@options.nameInputSelector)
      cvc: @el.container.find(@options.cvcInputSelector)
    # sync initial values, with constructor options taking precedence
    for fieldName, fieldValue of @options.initialValues
      @el.underlyingFields[fieldName].val(fieldValue)
    for fieldName, el of @el.underlyingFields
      @options.initialValues[fieldName] = el.val()
    # sync initial validation state, with constructor options taking precedence
    # we use the underlying form values to track state
    for fieldName, el of @el.underlyingFields
      if @options.validationState[fieldName] is false or el.hasClass('invalid')
        @_initialValidationState[fieldName] = false
        unless el.hasClass('invalid')
          el.addClass('invalid')
    # bind change handlers to render
    @el.underlyingFields.number.bind "change", (e)=> 
      @_inputViews.number.setValue @_getUnderlyingValue('number')
      @render()
    @el.underlyingFields.exp.bind "change", (e)=> 
      @_inputViews.exp.setValue @_getUnderlyingValue('exp')
      @render()
    @el.underlyingFields.name.bind "change", (e)=> 
      @_inputViews.exp.setValue @_getUnderlyingValue('name')
      @render()
    @el.underlyingFields.cvc.bind "change", (e)=> 
      @_inputViews.exp.setValue @_getUnderlyingValue('cvc')
      @render()
    # construct the necessary card elements
    @el.surfaceFront = $("<div>").attr(class: "face front")
    @el.surfaceBack = $("<div>").attr(class: "face back")
    @el.cardBody = $("<div>").attr(class: "card-body")
    # add elements to the DOM
    @el.surfaceFront.appendTo(@el.cardBody)
    @el.surfaceBack.appendTo(@el.cardBody)
    @el.cardBody.appendTo(@el.container)
    # create the validation indicator (flip tab), and attach them.
    @_tabViews.front = new @FlipTabView('front')
    @_tabViews.back = new @FlipTabView('back')
    @el.surfaceFront.prepend(@_tabViews.front.el)
    @el.surfaceBack.prepend(@_tabViews.back.el)
    @_tabViews.front.hide()
    @_tabViews.back.hide()

    @_tabViews.front.el.click =>
      @flip()
    @_tabViews.back.el.click =>
      @flip()

    return @el.container

  _setAcceptedCardProducts: ->
    # build the set of accepted card products
    if @options.acceptedCardProducts.length is 0
      @el.underlyingFields.type.find('option').each (i, _el)=>
        el = $(_el)
        cardProductShortname = el.attr('data-card-product-shortname') || el.attr('value')
        @options.acceptedCardProducts.push cardProductShortname
    # find all matching card products by shortname, and add them to the 
    # list of @acceptedCardProducts
    for matcher, product of CCProducts
      if product.companyShortname in @options.acceptedCardProducts
        @acceptedCardProducts[matcher] = product
    return @acceptedCardProducts

  _updateProductIfNeeded: ->
    # determine if product changed; if so, change it globally, and 
    # call render() to render the changes.
    number = @_getUnderlyingValue('number')
    matchedProduct = @getProductForNumber(number)
    matchedProductIdentifier = matchedProduct?.companyShortname || ''
    matchedIssuerIdentifier = matchedProduct?.issuerShortname || ''

    if (@productShortname isnt matchedProductIdentifier) or 
       (@issuerShortname isnt matchedIssuerIdentifier)
        @productShortname = matchedProductIdentifier
        @issuerShortname = matchedIssuerIdentifier
        @product = matchedProduct
        @_cardProductNeedsLayout = true
        @trigger 'productWillChange.skeuocard', 
          [@, @productShortname, matchedProductIdentifier]
        @_log("Triggering render because product changed.")
        @render()
        @trigger('productDidChange.skeuocard', [@, @productShortname, matchedProductIdentifier])

  # Create the new inputs, and attach them to their appropriate card face els.
  _createInputs: ->
    @_inputViews.number = new @SegmentedCardNumberInputView()
    @_inputViews.exp = new @ExpirationInputView(currentDate: @options.currentDate)
    @_inputViews.name = new @TextInputView(
      class: "cc-name", placeholder: "YOUR NAME")
    @_inputViews.cvc = new @TextInputView(
      class: "cc-cvc", placeholder: "XXX", requireMaxLength: true)

    # style and attach the number view to the DOM
    @_inputViews.number.el.addClass('cc-number')
    @_inputViews.number.el.appendTo(@el.surfaceFront)
    # attach name input
    @_inputViews.name.el.appendTo(@el.surfaceFront)
    # style and attach the exp view to the DOM
    @_inputViews.exp.el.addClass('cc-exp')
    @_inputViews.exp.el.appendTo(@el.surfaceFront)
    # attach cvc field to the DOM
    @_inputViews.cvc.el.appendTo(@el.surfaceBack)

    # bind change events to their underlying form elements
    @_inputViews.number.bind "keyup", (e, input)=>
      @_setUnderlyingValue('number', input.value)
      @_updateValidationStateForInputView('number')
      @_updateProductIfNeeded()
    @_inputViews.exp.bind "keyup", (e, input)=>
      @_setUnderlyingValue('exp', input.value)
      @_updateValidationStateForInputView('exp')
    @_inputViews.name.bind "keyup", (e)=>
      @_setUnderlyingValue('name', $(e.target).val())
      @_updateValidationStateForInputView('name')
    @_inputViews.cvc.bind "keyup", (e)=>
      @_setUnderlyingValue('cvc', $(e.target).val())
      @_updateValidationStateForInputView('cvc')

    # setup default values; when render is called, these will be picked up
    @_inputViews.number.setValue @_getUnderlyingValue('number')
    @_inputViews.exp.setValue @_getUnderlyingValue('exp')
    @_inputViews.name.el.val @_getUnderlyingValue('name')
    @_inputViews.cvc.el.val @_getUnderlyingValue('cvc')

  # Debugging helper; if debug is set to true at instantiation, messages will 
  # be printed to the console.
  _log: (msg...)->
    if console?.log and !!@options.debug
      console.log("[skeuocard]", msg...) if @options.debug?

  _flipToInvalidSide: ->
    if Object.keys(@_initialValidationState).length > 0
      _oppositeFace = if @visibleFace is 'front' then 'back' else 'front'
      # if the back face has errors, and the front does not, flip there.
      _errorCounts = {front: 0, back: 0}
      for fieldName, state of @_initialValidationState
        _errorCounts[@product?.layout[fieldName]]++
      if _errorCounts[@visibleFace] == 0 and _errorCounts[_oppositeFace] > 0
        @flip()

  # Update the card's visual representation to reflect internal state.
  render: ->
    @_log("*** start rendering ***")

    # Render card product layout changes.
    if @_cardProductNeedsLayout is true
      # Update product-specific details
      if @product isnt undefined
        # change the design and layout of the card to match the matched prod.
        @_log("[render]", "Activating product", @product)
        @el.container.removeClass (index, css)=>
          (css.match(/\b(product|issuer)-\S+/g) || []).join(' ')
        @el.container.addClass("product-#{@product.companyShortname}")
        if @product.issuerShortname?
          @el.container.addClass("issuer-#{@product.issuerShortname}")
        # Adjust underlying card type to match detected type
        @_setUnderlyingCardType(@product.companyShortname)
        # Reconfigure input to match product
        @_inputViews.number.reconfigure 
          groupings: @product.cardNumberGrouping
          placeholderChar: @options.cardNumberPlaceholderChar
        @_inputViews.exp.show()
        @_inputViews.name.show()
        @_inputViews.exp.reconfigure 
          pattern: @product.expirationFormat
        @_inputViews.cvc.show()
        @_inputViews.cvc.attr
          maxlength: @product.cvcLength
          placeholder: new Array(@product.cvcLength + 1).join(@options.cardNumberPlaceholderChar)
        for fieldName, surfaceName of @product.layout
          sel = if surfaceName is 'front' then 'surfaceFront' else 'surfaceBack'
          container = @el[sel]
          inputEl = @_inputViews[fieldName].el
          unless container.has(inputEl).length > 0
            @_log("Moving", inputEl, "=>", container)
            el = @_inputViews[fieldName].el.detach()
            $(el).appendTo(@el[sel])
      else
        @_log("[render]", "Becoming generic.")
        # Reset to generic input
        @_inputViews.exp.clear()
        @_inputViews.cvc.clear()
        @_inputViews.exp.hide()
        @_inputViews.name.hide()
        @_inputViews.cvc.hide()
        @_inputViews.number.reconfigure
          groupings: [@options.genericPlaceholder.length],
          placeholder: @options.genericPlaceholder
        @el.container.removeClass (index, css)=>
          (css.match(/\bproduct-\S+/g) || []).join(' ')
        @el.container.removeClass (index, css)=>
          (css.match(/\bissuer-\S+/g) || []).join(' ')
      @_cardProductNeedsLayout = false

    @_log("Validation state:", @_validationState)

    # Render validation changes
    @showInitialValidationErrors()

    # If the current face is filled, and there are validation errors, show 'em
    _oppositeFace = if @visibleFace is 'front' then 'back' else 'front'
    _visibleFaceFilled = @_faceFillState[@visibleFace]
    _visibleFaceValid = @isFaceValid(@visibleFace)
    _hiddenFaceFilled = @_faceFillState[_oppositeFace]
    _hiddenFaceValid = @isFaceValid(_oppositeFace)

    if _visibleFaceFilled and not _visibleFaceValid
      @_log("Visible face is filled, but invalid; showing validation errors.")
      @showValidationErrors()
    else if not _visibleFaceFilled
      @_log("Visible face hasn't been filled; hiding validation errors.")
      @hideValidationErrors()
    else
      @_log("Visible face has been filled, and is valid.")
      @hideValidationErrors()

    if @visibleFace is 'front' and @fieldsForFace('back').length > 0
      if _visibleFaceFilled and _visibleFaceValid and not _hiddenFaceFilled
        @_tabViews.front.prompt(@options.strings.hiddenFaceFillPrompt, true)
      else if _hiddenFaceFilled and not _hiddenFaceValid
        @_tabViews.front.warn(@options.strings.hiddenFaceErrorWarning, true)
      else if _hiddenFaceFilled and _hiddenFaceValid
        @_tabViews.front.prompt(@options.strings.hiddenFaceSwitchPrompt, true)
      else
        @_tabViews.front.hide()
    else
      if _hiddenFaceValid
        @_tabViews.back.prompt(@options.strings.hiddenFaceSwitchPrompt, true)
      else
        @_tabViews.back.warn(@options.strings.hiddenFaceErrorWarning, true)

    # Update the validity indicator for the whole card body
    if not @isValid()
      @el.container.removeClass('valid')
      @el.container.addClass('invalid')
    else
      @el.container.addClass('valid')
      @el.container.removeClass('invalid')
    
    @_log("*** rendering complete ***")

  # We should *always* show initial validation errors; they shouldn't show and 
  # hide with the rest of the errors unless their value has been changed.
  showInitialValidationErrors: ->
    for fieldName, state of @_initialValidationState
      if state is false and @_validationState[fieldName] is false
        # if the error hasn't been rectified
        @_inputViews[fieldName].addClass('invalid')
      else
        @_inputViews[fieldName].removeClass('invalid')

  showValidationErrors: ->
    for fieldName, state of @_validationState
      if state is true
        @_inputViews[fieldName].removeClass('invalid')
      else
        @_inputViews[fieldName].addClass('invalid')

  hideValidationErrors: ->
    for fieldName, state of @_validationState
      if (@_initialValidationState[fieldName] is false and state is true) or 
        (not @_initialValidationState[fieldName]?)
          @_inputViews[fieldName].el.removeClass('invalid')

  setFieldValidationState: (fieldName, valid)->
    if valid
      @el.underlyingFields[fieldName].removeClass('invalid')
    else
      @el.underlyingFields[fieldName].addClass('invalid')
    @_validationState[fieldName] = valid

  isFaceFilled: (faceName)->
    fields = @fieldsForFace(faceName)
    filled = (name for name in fields when @_inputViews[name].isFilled())
    if fields.length > 0
      return filled.length is fields.length
    else
      return false

  fieldsForFace: (faceName)->
    if @product?.layout
      return (fn for fn, face of @product.layout when face is faceName)
    return []

  _updateValidationStateForInputView: (fieldName)->
    field = @_inputViews[fieldName]
    fieldValid = field.isValid() and
      not (@_initialValidationState[fieldName] is false and
           field.getValue() is @options.initialValues[fieldName])
    # trigger a change event if the field has changed
    if fieldValid isnt @_validationState[fieldName]
      @setFieldValidationState(fieldName, fieldValid)
      # Update the fill state
      @_faceFillState.front = @isFaceFilled('front')
      @_faceFillState.back = @isFaceFilled('back')
      @trigger('validationStateDidChange.skeuocard', [@, @_validationState])
      @_log("Change in validation for #{fieldName} triggers re-render.")
      @render()

  isFaceValid: (faceName)->
    valid = true
    for fieldName in @fieldsForFace(faceName)
      valid &= @_validationState[fieldName]
    return !!valid

  isValid: ->
    @_validationState.number and 
      @_validationState.exp and 
      @_validationState.name and 
      @_validationState.cvc

  # Get a value from the underlying form.
  _getUnderlyingValue: (field)->
    @el.underlyingFields[field].val()

  # Set a value in the underlying form.
  _setUnderlyingValue: (field, newValue)->
    @trigger('change.skeuocard', [@]) # changing the underlying value triggers a change.
    @el.underlyingFields[field].val(newValue)

  # Flip the card over.
  flip: ->
    targetFace = if @visibleFace is 'front' then 'back' else 'front'
    @trigger('faceWillBecomeVisible.skeuocard', [@, targetFace])
    @visibleFace = targetFace
    @render()
    @el.cardBody.toggleClass('flip')
    @trigger('faceDidBecomeVisible.skeuocard', [@, targetFace])

  getProductForNumber: (num)->
    for m, d of @acceptedCardProducts
      parts = m.split('/')
      matcher = new RegExp(parts[1], parts[2])
      if matcher.test(num)
        issuer = @getIssuerForNumber(num) || {}
        return $.extend({}, d, issuer)
    return undefined

  getIssuerForNumber: (num)->
    for m, d of CCIssuers
      parts = m.split('/')
      matcher = new RegExp(parts[1], parts[2])
      if matcher.test(num)
        return d
    return undefined

  _setUnderlyingCardType: (shortname)->
    @el.underlyingFields.type.find('option').each (i, _el)=>
      el = $(_el)
      if shortname is (el.attr('data-card-product-shortname') || el.attr('value'))
        el.val(el.attr('value')) # change which option is selected

  trigger: (args...)->
    @el.container.trigger(args...)

  bind: (args...)->
    @el.container.trigger(args...)

###
Skeuocard::FlipTabView
Handles rendering of the "flip button" control and its various warning and 
prompt states.
###
class Skeuocard::FlipTabView
  constructor: (face, opts = {})->
    @el = $("<div class=\"flip-tab #{face}\"><p></p></div>")
    @options = opts

  _setText: (text)->
    @el.find('p').html(text)

  warn: (message, withAnimation = false)->
    @_resetClasses()
    @el.addClass('warn')
    @_setText(message)
    @show()
    if withAnimation
      @el.removeClass('warn-anim')
      @el.addClass('warn-anim')

  prompt: (message, withAnimation = false)->
    @_resetClasses()
    @el.addClass('prompt')
    @_setText(message)
    @show()
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

class Skeuocard::SegmentedCardNumberInputView extends Skeuocard::TextInputView
  constructor: (opts = {})->
    # Setup option defaults
    opts.value           ||= ""
    opts.groupings       ||= [19]
    opts.placeholderChar ||= "X"
    @options = opts
    # everythIng else
    @value = @options.value
    @el = $("<fieldset>")
    @el.delegate "input", "keydown", (e)=> @_onGroupKeyDown(e)
    @el.delegate "input", "keyup", (e)=> @_onGroupKeyUp(e)
    @groupEls = $()

  _onGroupKeyDown: (e)->
    e.stopPropagation()
    groupEl = $(e.currentTarget)

    arrowKeys = [37, 38, 39, 40]
    groupEl = $(e.currentTarget)
    groupMaxLength = parseInt(groupEl.attr('maxlength'))
    groupCaretPos = @_getFieldCaretPosition(groupEl)

    if e.which is 8 and groupCaretPos is 0 and not $.isEmptyObject(groupEl.prev())
      groupEl.prev().focus()

    if e.which in arrowKeys
      switch e.which
        when 37 # left
          if groupCaretPos is 0 and not $.isEmptyObject(groupEl.prev())
            groupEl.prev().focus()
        when 39 # right
          if groupCaretPos is groupMaxLength and not $.isEmptyObject(groupEl.next())
            groupEl.next().focus()
        when 38 # up
          if not $.isEmptyObject(groupEl.prev())
            groupEl.prev().focus()
        when 40 # down
          if not $.isEmptyObject(groupEl.next())
            groupEl.next().focus()
  
  _onGroupKeyUp: (e)->
    e.stopPropagation() # prevent event from bubbling up

    specialKeys = [8, 9, 16, 17, 18, 19, 20, 27, 33, 34, 35, 36,
                   37, 38, 39, 40, 45, 46, 91, 93, 144, 145, 224]
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

    if e.which not in specialKeys and 
      groupEl.val().length is groupMaxLength and 
      not $.isEmptyObject(groupEl.next()) and
      @_getFieldCaretPosition(groupEl) is groupMaxLength
        groupEl.next().focus()    

    # update the value
    newValue = ""
    @groupEls.each -> newValue += $(@).val()
    @value = newValue
    @trigger("keyup", [@])
    return false

  setGroupings: (groupings)->
    caretPos = @_caretPosition()
    @el.empty() # remove all inputs
    _startLength = 0
    for groupLength in groupings
      groupEl = $("<input>").attr
        type: 'text'
        size: groupLength
        maxlength: groupLength
        class: "group#{groupLength}"
      # restore value, if necessary
      if @value.length > _startLength
        groupEl.val(@value.substr(_startLength, groupLength))
        _startLength += groupLength
      @el.append(groupEl)
    @options.groupings = groupings
    @groupEls = @el.find("input")
    # restore to previous settings
    @_caretTo(caretPos)
    if @options.placeholderChar isnt undefined
      @setPlaceholderChar(@options.placeholderChar)
    if @options.placeholder isnt undefined
      @setPlaceholder(@options.placeholder)

  setPlaceholderChar: (ch)->
    @groupEls.each ->
      el = $(@)
      el.attr 'placeholder', new Array(parseInt(el.attr('maxlength'))+1).join(ch)
    @options.placeholder = undefined
    @options.placeholderChar = ch

  setPlaceholder: (str)->
    @groupEls.each ->
      $(@).attr 'placeholder', str
    @options.placeholderChar = undefined
    @options.placeholder = str

  setValue: (newValue)->
    lastPos = 0
    @groupEls.each ->
      el = $(@)
      len = parseInt(el.attr('maxlength'))
      el.val(newValue.substr(lastPos, len))
      lastPos += len
    @value = newValue

  getValue: ->
    @value

  reconfigure: (changes = {})->
    if changes.groupings?
      @setGroupings(changes.groupings)
    if changes.placeholderChar?
      @setPlaceholderChar(changes.placeholderChar)
    if changes.placeholder?
      @setPlaceholder(changes.placeholder)
    if changes.value?
      @setValue(changes.value)

  _caretTo: (index)->
    pos = 0
    inputEl = undefined
    inputElIndex = 0
    # figure out which group we're in
    @groupEls.each (i, e)=>
      el = $(e)
      elLength = parseInt(el.attr('maxlength'))
      if index <= elLength + pos and index >= pos
        inputEl = el
        inputElIndex = index - pos
      pos += elLength
    # move the caret there
    @_setFieldCaretPosition(inputEl, inputElIndex)

  _caretPosition: ->
    iPos = 0
    finalPos = 0
    @groupEls.each (i, e)=>
      el = $(e)
      if el.is(':focus')
        finalPos = iPos + @_getFieldCaretPosition(el)
      iPos += parseInt(el.attr('maxlength'))
    return finalPos

  maxLength: ->
    @options.groupings.reduce((a,b)->(a+b))

  isFilled: ->
    @value.length == @maxLength()

  isValid: ->
    @isFilled() and @isValidLuhn(@value)

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
Skeuocard::ExpirationInputView
###
class Skeuocard::ExpirationInputView extends Skeuocard::TextInputView
  constructor: (opts = {})->
    # setup option defaults
    opts.dateFormatter ||= (date)->
      date.getDate() + "-" + (date.getMonth()+1) + "-" + date.getFullYear()
    opts.dateParser ||= (value)->
      dateParts = value.split('-')
      new Date(dateParts[2], dateParts[1]-1, dateParts[0])
    opts.currentDate ||= new Date()
    opts.pattern ||= "MM/YY"
    
    @options = opts
    # setup default values
    @date = undefined
    @value = undefined
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

  setDate: (newDate)->
    @date = newDate
    @value = @options.dateFormatter(newDate)
    @_updateFieldValues()

  setValue: (newValue)->
    @value = newValue
    @date = @options.dateParser(newValue)
    @_updateFieldValues()

  getDate: ->
    @date

  getValue: ->
    @value

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
    day = parseInt(@el.find('.cc-exp-field-d').val()) || 1
    month = parseInt(@el.find('.cc-exp-field-m').val())
    year = parseInt(@el.find('.cc-exp-field-y').val())
    if month is 0 or year is 0
      @value = ""
      @date = null
    else
      year += 2000 if year < 2000
      dateObj = new Date(year, month-1, day)
      @value = @options.dateFormatter(dateObj)
      @date = dateObj
    @trigger("keyup", [@])
    return false

  _inputGroupEls: ->
    @el.find("input")

  isFilled: ->
    for inputEl in @groupEls
      el = $(inputEl)
      return false if el.val().length != parseInt(el.attr('maxlength'))
    return true

  isValid: ->
    @isFilled() and
      ((@date.getFullYear() == @options.currentDate.getFullYear() and
        @date.getMonth() >= @options.currentDate.getMonth()) or
        @date.getFullYear() > @options.currentDate.getFullYear())


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

  isFilled: ->
    return @el.val().length > 0

  isValid: ->
    if @options.requireMaxLength 
      return @el.val().length is parseInt(@el.attr('maxlength'))
    else
      return @isFilled()

  getValue: ->
    @el.val()

# Export the object.
window.Skeuocard = Skeuocard

###
# Card Definitions
###

# List of credit card products by matching prefix.
CCProducts = {}

CCProducts[/^30[0-5][0-9]/] =
  companyName: "Diners Club"
  companyShortname: "dinersclubintl"
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
    cvc: 'front'

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
