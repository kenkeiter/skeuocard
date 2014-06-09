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
    @el.addClass('cc-field')
    @el.delegate "input", "keypress", @_handleGroupKeyPress.bind(@)
    @el.delegate "input", "keydown",  @_handleGroupKeyDown.bind(@)
    @el.delegate "input", "keyup",    @_handleGroupKeyUp.bind(@)
    @el.delegate "input", "paste",    @_handleGroupPaste.bind(@)
    @el.delegate "input", "change",   @_handleGroupChange.bind(@)
    @el.delegate "input", "focus", (e)=>
      @el.addClass('focus')
    @el.delegate "input", "blur", (e)=>
      @el.removeClass('focus')

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
    
      
    if @_state.selectingAll and 
      (e.which in @_specialKeys) and 
      e.which isnt @_keys.command and
      e.which isnt @_keys.alt
        @_endSelectAll()

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

  setGroupings: (groupings, dontFocus)->
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
    _currentField = @_focusFieldForValue([_caretPosition, _caretPosition], dontFocus)
    if _currentField? and _currentField[0].selectionEnd is _currentField[0].maxLength
      @_focusField(_currentField.next(), 'start')

  _focusFieldForValue: (place, dontFocus)->
    value = @getValue()
    if place is 'start'
      field = @el.find('input').first()
      @_focusField(field, place) unless dontFocus
    else if place is 'end'
      field = @el.find('input').last()
      @_focusField(field, place) unless dontFocus
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
        @_focusField(field, [fieldPosition, fieldPosition]) unless dontFocus
      else
        @_focusField(@el.find('input'), 'end') unless dontFocus
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
