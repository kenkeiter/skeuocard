###
Skeuocard::TextInputView
###
class Skeuocard::TextInputView
  constructor: (opts)->
    @el = $('<div>')
    @inputEl = $("<input>").attr
      type: 'text'
      placeholder: opts.placeholder
      class: opts.class
    @el.append @inputEl
    @el.addClass 'cc-field'
    @options = opts
    @el.delegate "input", "focus", (e)=> @el.addClass('focus')
    @el.delegate "input", "blur", (e)=> @el.removeClass('focus')
    @el.delegate "input", "keyup", (e)=>
      e.stopPropagation()
      @trigger('keyup', [@])

  clear: ->
    @inputEl.val("")

  attr: (args...)->
    @inputEl.attr(args...)

  setValue: (newValue)->
    @inputEl.val(newValue)

  getValue: ->
    @inputEl.val()

  bind: (args...)->
    @el.bind(args...)

  trigger: (args...)->
    @el.trigger(args...)
  
  show: ->
    @el.show()

  hide: ->
    @el.hide()