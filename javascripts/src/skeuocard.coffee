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
    @el = {container: $(el)}
    @_underlyingFormEls = {}
    @_inputViews = {}
    @product = null
    @issuer = null
    @visibleFace = 'front'
    # configure default opts
    opts.debug ||= false
    opts.cardNumberPlaceholderChar ||= "X"
    opts.typeInputSelector   ||= '[name="cc_type"]'
    opts.numberInputSelector ||= '[name="cc_number"]'
    opts.expInputSelector    ||= '[name="cc_exp"]'
    opts.nameInputSelector   ||= '[name="cc_name"]'
    opts.cvcInputSelector    ||= '[name="cc_cvc"]'
    opts.frontFlipTabBody    ||= 'Click here to<br /> fill in the other side.'
    opts.backFlipTabBody     ||= "Forgot something?"
    opts.flipTabFrontEl      ||= $("<div class=\"flip-tab front\">" +
                                   "<p>#{opts.frontFlipTabBody}</p></div>")
    opts.flipTabBackEl       ||= $("<div class=\"flip-tab back\">" +
                                   "<p>#{opts.backFlipTabBody}</p></div>")
    opts.currentDate         ||= new Date()
    opts.genericPlaceholder  ||= "XXXX XXXX XXXX XXXX"
    @options = opts
    # configure initial values

    # initialize the card
    @_conformDOM()   # conform the DOM to match our styling requirements
    
    @options.initialValues = @_conformInitialValues(@options.initialValues || {})

    @_createInputs() # create reconfigurable input views
    @_bindEvents()   # bind custom events to the containers

    # call initial render to pick up existing values from non-enhanced inputs
    @render()

  _conformInitialValues: (supplied)->
    if supplied.number?
      @_setUnderlyingValue('number', supplied.number)
    if supplied.exp?
      @_setUnderlyingValue('exp', supplied.exp)
    if supplied.name?
      @_setUnderlyingValue('name', supplied.name)
    if supplied.cvc?
      @_setUnderlyingValue('cvc', supplied.cvc)
    return {
      number: @_getUnderlyingValue('number')
      exp: @_getUnderlyingValue('exp')
      cvc: @_getUnderlyingValue('cvc')
      name: @_getUnderlyingValue('name')
    }

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
    @_underlyingFormEls.number.bind "change", (e)=> 
      @_inputViews.number.setValue @_getUnderlyingValue('number')
      @render()
    @_underlyingFormEls.exp.bind "change", (e)=> 
      @_inputViews.exp.setValue @_getUnderlyingValue('exp')
      @render()
    @_underlyingFormEls.name.bind "change", (e)=> 
      @_inputViews.exp.setValue @_getUnderlyingValue('name')
      @render()
    @_underlyingFormEls.cvc.bind "change", (e)=> 
      @_inputViews.exp.setValue @_getUnderlyingValue('cvc')
      @render()
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
    @_inputViews.name = new @TextInputView(
      class: "cc-name", required: true, placeholder: "YOUR NAME")
    @_inputViews.cvc = new @TextInputView(
      class: "cc-cvc", required: true, placeholder: "XXX")

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
      @render()
    @_inputViews.exp.bind "keyup", (e, input)=>
      @_setUnderlyingValue('exp', input.value)
      @render()
    @_inputViews.name.bind "keyup", (e)=>
      @_setUnderlyingValue('name', $(e.target).val())
      @render()
    @_inputViews.cvc.bind "keyup", (e)=>
      @_setUnderlyingValue('cvc', $(e.target).val())
      @render()

    # setup default values; when render is called, these will be picked up
    @_inputViews.number.setValue @options.initialValues.number
    @_inputViews.exp.setValue @options.initialValues.exp
    @_inputViews.name.el.val @options.initialValues.name
    @_inputViews.cvc.el.val @options.initialValues.cvc

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
    if console?.log and !!@options.debug
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
        @_inputViews.exp.show()
        @_inputViews.name.show()
        @_inputViews.exp.reconfigure 
          pattern: matchedProduct.expirationFormat
      else
        # Reset to generic input
        @_inputViews.exp.clear()
        @_inputViews.cvc.clear()
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
    if @frontIsValid()
      @_log("Front face is now valid.")
      @el.flipTabFront.show()
      @el.flipTabFront.addClass('valid-anim')
    else
      @el.flipTabFront.hide()
      @el.flipTabFront.removeClass('valid-anim')

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
    # console.log("Card valid:", cardValid, "exp valid:", expValid, "name valid:", nameValid)
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

  # Flip the card over.
  flip: ->
    if @visibleFace == 'front'
      @el.cardBody.addClass('flip')
      @visibleFace = 'back'
    else
      @el.cardBody.removeClass('flip')
      @visibleFace = 'front'

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
    console.log('setting value', newValue)
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


class Skeuocard::ExpirationInputView extends Skeuocard::TextInputView
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
          required: true
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


class Skeuocard::TextInputView extends Skeuocard::TextInputView
  constructor: (opts)->
    @el = $("<input>").attr $.extend({type: 'text'}, opts)

  clear: ->
    @el.val("")

# Export the object.
window.Skeuocard = Skeuocard