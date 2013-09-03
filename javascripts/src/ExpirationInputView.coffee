###
Skeuocard::ExpirationInputView
###
class Skeuocard::ExpirationInputView
  constructor: (opts = {})->
    # setup option defaults
    opts.pattern ||= "MM/YY"
    
    @options = opts
    # setup default values
    @date = null
    # create dom container
    @el = $("<fieldset>")
    @el.addClass('cc-field')
    @el.delegate "input", "keydown", (e)=> @_onKeyDown(e)
    @el.delegate "input", "keyup", (e)=> @_onKeyUp(e)
    @el.delegate "input", "focus", (e)=> @el.addClass('focus')
    @el.delegate "input", "blur", (e)=> @el.removeClass('focus')

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

  _zeroPadNumber: (num, places)->
    zero = places - num.toString().length + 1
    return Array(zero).join("0") + num

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

  show: ->
    @el.show()

  hide: ->
    @el.hide()