###
Skeuocard::FlipTabView
Handles rendering of the "flip button" control and its various warning and 
prompt states.
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
    oppositeFace = if face is 'front' then 'back' else 'front'
    @show() if isFilled is true and @card._inputViewsByFace[oppositeFace].length > 0
    @_state.opposingFaceFilled = isFilled if face isnt @face
    
    unless @_state.opposingFaceFilled is true
      @warn @options.strings.hiddenFaceFillPrompt, true

  _faceValidationChanged: (e, card, face, isValid)->
    @_state.opposingFaceValid = isValid if face isnt @face

    if @_state.opposingFaceValid
      @prompt @options.strings.hiddenFaceSwitchPrompt
    else
      if @_state.opposingFaceFilled
        @warn @options.strings.hiddenFaceErrorWarning 
      else
        @warn @options.strings.hiddenFaceFillPrompt

  _setText: (text)->
    @el.find('p').first().html(text)

  warn: (message)->
    @_resetClasses()
    @_setText(message)
    @el.addClass('warn')

  prompt: (message)->
    @_resetClasses()
    @_setText(message)
    @el.addClass('prompt')

  _resetClasses: ->
    @el.removeClass('warn')
    @el.removeClass('prompt')

  show: ->
    @el.show()

  hide: ->
    @el.hide()