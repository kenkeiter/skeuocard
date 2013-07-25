class Skeuocard
  
  constructor: (el, opts = {})->
    @el = {container: $(el)}
    @_underlyingFormEls = {}
    @_inputViews = {}
    @product = null
    @issuer = null
    # configure default opts
    opts.debug ||= false
    opts.cardNumberPlaceholderChar ||= "X"
    opts.typeInputSelector   ||= '[name="cc_type"]'
    opts.numberInputSelector ||= '[name="cc_number"]'
    opts.expInputSelector    ||= '[name="cc_exp"]'
    opts.nameInputSelector   ||= '[name="cc_name"]'
    opts.cvcInputSelector    ||= '[name="cc_cvc"]'
    opts.frontFlipTabHeader  ||= 'Looks good.'
    opts.frontFlipTabBody    ||= 'Click here to fill in the back...'
    opts.backFlipTabHeader   ||= "Back"
    opts.backFlipTabBody     ||= "Forget to fill something in on the front? " +
                                 "Click here to turn the card over."
    opts.flipTabFrontEl      ||= $("<div class=\"flip-tab front\"><h1>" +
                                   "#{opts.frontFlipTabHeader}</h1>" +
                                   "<p>#{opts.frontFlipTabBody}</p></div>")
    opts.flipTabBackEl       ||= $("<div class=\"flip-tab back\"><h1>" +
                                   "#{opts.backFlipTabHeader}</h1>" +
                                   "<p>#{opts.backFlipTabBody}</p></div>")
    opts.currentDate         ||= new Date()
    opts.genericPlaceholder  ||= "XXXX XXXX XXXX XXXX"
    @options = opts
    # initialize the card
    @_conformDOM()   # conform the DOM to match our styling requirements
    @_createInputs() # create reconfigurable input views
    @_bindEvents()   # bind custom events to the container
    
    # call initial render to pick up existing values from non-enhanced inputs
    @render()

  # Transform the elements within the container, conforming the DOM so that it 
  # becomes styleable, and that the underlying inputs are hidden.
  _conformDOM: ->
    # for CSS determination that this is an enhanced input, add 'js' class to 
    # the container
    @el.container.addClass("js")
    # remove anything that's not an underlying form field
    @el.container.find("> :not(input,select,textarea)").remove()
    @el.container.find("> input,select,textarea").hide()
    # attach underlying form elements
    @_underlyingFormEls =
      type: @el.container.find(@options.typeInputSelector)
      number: @el.container.find(@options.numberInputSelector)
      exp: @el.container.find(@options.expInputSelector)
      name: @el.container.find(@options.nameInputSelector)
      cvc: @el.container.find(@options.cvcInputSelector)
    # bind change handlers to render
    @_underlyingFormEls.number.bind "change", (e)=> @render()
    @_underlyingFormEls.exp.bind "change", (e)=> @render()
    @_underlyingFormEls.name.bind "change", (e)=> @render()
    @_underlyingFormEls.cvc.bind "change", (e)=> @render()
    # construct the necessary card elements
    @el.surfaceFront = $("<div>").attr(class: "face front")
    @el.surfaceBack = $("<div>").attr(class: "face back")
    @el.cardBody = $("<div>").attr(class: "card-body")
    @el.container.addClass("skeuocard")
    # add elements to the DOM
    @el.surfaceFront.appendTo(@el.cardBody)
    @el.surfaceBack.appendTo(@el.cardBody)
    @el.cardBody.appendTo(@el.container)

    return @el.container

  # Create the new inputs, and attach them to their appropriate card face els.
  _createInputs: ->
    @_inputViews.number = new @SegmentedCardNumberInputView()
    @_inputViews.exp = new @ExpirationInputView()
    @_inputViews.name = new @TextInputView @el.surfaceFront, 
                                           class: "cc-name"
                                           required: true
                                           placeholder: "YOUR NAME"
    @_inputViews.cvc = new @TextInputView @el.surfaceBack, 
                                          class: "cc-cvc"
                                          required: true

    # style and attach the number view to the DOM
    @_inputViews.number.el.addClass('cc-number')
    @_inputViews.number.el.appendTo(@el.surfaceFront)
    # style and attach the exp view to the DOM
    @_inputViews.exp.el.addClass('cc-exp')
    @_inputViews.exp.el.appendTo(@el.surfaceFront)

    # bind change events to their underlying form elements
    @_inputViews.number.bind "keyup", (e, input)=>
      @_setUnderlyingValue 'number', input.value
    @_inputViews.exp.bind "keyup", (e, input)=>
      @_setUnderlyingValue('exp', input.value)
    @_inputViews.name.bind "keyup", (e)=>
      @_setUnderlyingValue('name', $(e.target).val())
    @_inputViews.cvc.bind "keyup", (e)=>
      @_setUnderlyingValue('cvc', $(e.target).val())

    # create the validation indicator (flip tab)
    @el.flipTabFront = @options.flipTabFrontEl
    @el.flipTabBack = @options.flipTabBackEl
    @el.surfaceFront.prepend(@el.flipTabFront)
    @el.surfaceBack.prepend(@el.flipTabBack)

    @el.flipTabFront.click =>
      @flip()
    @el.flipTabBack.click =>
      @flip()

  _bindEvents: ->
    @el.container.bind "productchanged", (e)=>
      @updateLayout()
    @el.container.bind "issuerchanged", (e)=>
      @updateLayout()

  # Debugging helper; if debug is set to true at instantiation, messages will 
  # be printed to the console.
  _log: (msg...)->
    if console?.log
      console.log("[skeuocard]", msg...) if @options.debug?

  # Render changes to the skeuocard; state-agnostic -- should transform content 
  # without clearing input.
  render: ->
    number = @_getUnderlyingValue('number')
    
    # rerender (if necessary) to deal with a change in product
    if @product isnt matchedProduct = @getProductForNumber(number)
      @_log("Changing product:", matchedProduct)
      @el.container.removeClass (index, css)=>
        (css.match(/\bproduct-\S+/g) || []).join(' ')
      if matchedProduct isnt undefined
        @el.container.addClass("product-#{matchedProduct.companyShortname}")
        # Reconfigure input to match product
        @_inputViews.number.reconfigure 
          groupings: matchedProduct.cardNumberGrouping
          placeholderChar: @options.cardNumberPlaceholderChar
          value: @_getUnderlyingValue('number')
        @_inputViews.exp.show()
        @_inputViews.name.show()
        @_inputViews.exp.reconfigure 
          pattern: matchedProduct.expirationFormat
          value: @_getUnderlyingValue('exp')
        @_inputViews.name.el.val(@_getUnderlyingValue('name'))
      else
        # Reset to generic input
        @_inputViews.exp.hide()
        @_inputViews.name.hide()
        @_inputViews.number.reconfigure
          groupings: [@options.genericPlaceholder.length],
          placeholder: @options.genericPlaceholder
      # change the current product for the card
      @product = matchedProduct
    
    # rerender (if necessary) to match change in issuer
    if @issuer isnt matchedIssuer = @getIssuerForNumber(number)
      @_log("Changing issuer:", matchedIssuer)
      @el.container.removeClass (index, css)=>
        (css.match(/\bissuer-\S+/g) || []).join(' ')
      if matchedIssuer isnt undefined
        @el.container.addClass("issuer-#{matchedIssuer.issuerShortname}")
      # change the current issuer for the card
      @issuer = matchedIssuer
    
    # If we're viewing the front, and the data is "valid", show the flip tab.
    @_log("Rendered...")
    if @frontIsValid()
      @_log("Front face is now valid.")
      @el.flipTabFront.show()
    else
      @el.flipTabFront.hide()

  frontIsValid: ->
    # validate card number
    cardValid = @isValidLuhn(@_inputViews.number.value) and 
      (@_inputViews.number.maxLength() == @_inputViews.number.value.length)
    # validate expiration
    expValid = @_inputViews.exp.date and
      ((@_inputViews.exp.date.getFullYear() == @options.currentDate.getFullYear() and
       @_inputViews.exp.date.getMonth() >= @options.currentDate.getMonth()) or
       @_inputViews.exp.date.getFullYear() > @options.currentDate.getFullYear())


    # validate name
    nameValid = @_inputViews.name.el.val().length > 0
    # combine
    console.log("Card valid:", cardValid, "exp valid:", expValid, "name valid:", nameValid)
    cardValid and expValid and nameValid

  isValid: ->
    valid = true
    for fieldName, view of @_inputViews
      valid &= view.isValid()
      console.log("#{fieldName} is valid?", view.isValid())
    return valid

  # Get a value from the underlying form.
  _getUnderlyingValue: (field)->
    @_underlyingFormEls[field].val()

  # Set a value in the underlying form.
  _setUnderlyingValue: (field, newValue)->
    @_underlyingFormEls[field].val(newValue)
    # we couple to the change event to influence renders in the interface
    @_underlyingFormEls[field].trigger('change')

  # Flip the card over.
  flip: ->
    @el.cardBody.toggleClass('flip')

  getProductForNumber: (num)->
    for m, d of CCProducts
      parts = m.split('/')
      matcher = new RegExp(parts[1], parts[2])
      if matcher.test(num)
        return d
    return undefined

  getIssuerForNumber: (num)->
    for m, d of CCIssuers
      parts = m.split('/')
      matcher = new RegExp(parts[1], parts[2])
      if matcher.test(num)
        return d
    return undefined

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


class Skeuocard::SegmentedCardNumberInputView
  constructor: (opts = {})->
    # Setup option defaults
    opts.value           ||= ""
    opts.groupings       ||= [19]
    opts.placeholderChar ||= "X"
    @options = opts
    # everythIng else
    @value = @options.value
    @el = $("<fieldset>")
    @el.delegate "input", "keyup", (e)=> @_onGroupKeyUp(e)
    @groupEls = $()

  bind: (args...)->
    @el.bind(args...)

  trigger: (args...)->
    @el.trigger(args...)

  setGroupings: (groupings)->
    caretPos = @_caretPosition()
    @el.empty() # remove all inputs
    _startLength = 0
    for groupLength in groupings
      groupEl = $("<input>").attr
        type: 'text'
        size: groupLength
        maxlength: groupLength
        required: true
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
    # setup autotabbing between inputs
    @groupEls.autotab_magic().autotab_filter('numeric')

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

  _onGroupChange: (e)->
    e.preventDefault()

  _onGroupKeyUp: (e)->
    e.stopPropagation()
    # update the value
    newValue = ""
    @groupEls.each -> newValue += $(@).val()
    @value = newValue
    @trigger("keyup", [@])
    return false

  _caretTo: (index)->
    pos = 0
    inputEl = undefined
    inputElIndex = 0
    # figure out which group we're in
    @groupEls.each (i, e)=>
      el = $(e)
      elLength = parseInt(el.attr('maxlength'))
      if index <= elLength + pos and index >= pos
        inputEl = e
        inputElIndex = index - pos
      pos += elLength
    # move the caret there
    if inputEl.createTextRange?
      range = inputEl.createTextRange()
      range.move "character", inputElIndex
      range.select()
    else if inputEl.selectionStart?
      inputEl.focus()
      inputEl.setSelectionRange(inputElIndex, inputElIndex)

  _caretPosition: ->
    iPos = 0
    finalPos = 0
    @groupEls.each (i, e)=>
      el = $(e)
      if el.is(':focus') and e.selectionStart
        finalPos = iPos + e.selectionStart
      iPos += parseInt(el.attr('maxlength'))
    return finalPos

  maxLength: ->
    @options.groupings.reduce((a,b)->(a+b))


class Skeuocard::ExpirationInputView
  constructor: (opts = {})->
    # setup option defaults
    opts.dateFormatter ||= (date)->
      date.getDate() + "-" + (date.getMonth()+1) + "-" + date.getFullYear()
    opts.dateParser ||= (value)->
      dateParts = value.split('-')
      new Date(dateParts[2], dateParts[1]-1, dateParts[0])
    opts.pattern ||= "MM/YY"
    
    @options = opts
    # setup default values
    @date = undefined
    @value = undefined
    # create dom container
    @el = $("<fieldset>")
    @el.delegate "input", "keyup", (e)=> @_onKeyUp(e)

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
          required: true
          'data-fieldtype': groupChar
          class: 'cc-exp-field-' + groupChar.toLowerCase() + 
                 ' group' + groupLength
        @el.append(input)
      else # this group is a separator
        sep = $('<span>').attr
          class: 'separator'
        sep.html(new Array(groupLength + 1).join(groupChar))
        @el.append(sep)

    @groupEls = @el.find('input')
    @groupEls.autotab_magic().autotab_filter('numeric')
    @_updateFieldValues() if @date?

  _updateFieldValues: ->
    currentDate = @date
    @groupEls.each =>
      el = $(this)
      groupLength = parseInt(el.attr('maxlength'))
      switch el.attr('data-fieldtype')
        when 'M'
          el.val @_zeroPadNumber(currentDate.getMonth() + 1, groupLength)
        when 'D'
          el.val @_zeroPadNumber(currentDate.getDate(), groupLength)
        when 'Y'
          year = if groupLength >= 4 then currentDate.getFullYear() else 
                 currentDate.getFullYear().toString().substr(2,4)
          el.val(year)

  setDate: (newDate)->
    @date = newDate
    @_updateFieldValues()

  setValue: (newValue)->
    @setDate @options.dateParser(newValue)

  getDate: ->
    @date

  getValue: ->
    @value

  reconfigure: (opts)->
    if opts.pattern?
      @setPattern(opts.pattern)
    if opts.value?
      @setValue(opts.value)

  _onKeyUp: (e)->
    e.stopPropagation()
    # get a date object representing what's been entered
    day = parseInt(@el.find('.cc-exp-field-d').val()) || 1
    month = parseInt(@el.find('.cc-exp-field-m').val())
    year = parseInt(@el.find('.cc-exp-field-y').val())
    year += 2000 if year < 2000
    dateObj = new Date(year, month-1, day)
    @value = @options.dateFormatter(dateObj)
    @date = dateObj
    @trigger("keyup", [@])
    return false

  bind: (args...)->
    @el.bind(args...)

  trigger: (args...)->
    @el.trigger(args...)

  _inputGroupEls: ->
    @el.find("input")

  show: ->
    @el.show()

  hide: ->
    @el.hide()

  isValid: ->
    @el.find(':invalid').length == 0

  _zeroPadNumber: (num, places)->
    zero = places - num.toString().length + 1
    return Array(zero).join("0") + num


class Skeuocard::TextInputView
  constructor: (parentEl, opts)->
    @el = $("<input>").attr $.extend({type: 'text'}, opts)
    parentEl.append(@el)

  bind: (args...)->
    @el.bind(args...)

  trigger: (args...)->
    @el.trigger(args...)

  show: ->
    @el.show()

  hide: ->
    @el.hide()

  isValid: ->
    @el.is(':valid')


# Export the object.
window.Skeuocard = Skeuocard