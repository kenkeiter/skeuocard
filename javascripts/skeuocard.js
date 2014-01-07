/*
"Skeuocard" -- A Skeuomorphic Credit-Card Input Enhancement
@description Skeuocard is a skeuomorphic credit card input plugin, supporting 
             progressive enhancement. It renders a credit-card input which 
             behaves similarly to a physical credit card.
@author Ken Keiter <ken@kenkeiter.com>
@updated 2013-07-25
@website http://kenkeiter.com/
@exports [window.Skeuocard]
*/


(function() {
  var $, Skeuocard, visaProduct,
    __slice = [].slice,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  $ = jQuery;

  Skeuocard = (function() {
    Skeuocard.currentDate = new Date();

    function Skeuocard(el, opts) {
      var optDefaults;
      if (opts == null) {
        opts = {};
      }
      this.el = {
        container: $(el),
        underlyingFields: {}
      };
      this._inputViews = {};
      this._inputViewsByFace = {
        front: [],
        back: []
      };
      this._tabViews = {};
      this._state = {};
      this.product = null;
      this.visibleFace = 'front';
      optDefaults = {
        debug: false,
        dontFocus: false,
        acceptedCardProducts: null,
        cardNumberPlaceholderChar: 'X',
        genericPlaceholder: "XXXX XXXX XXXX XXXX",
        typeInputSelector: '[name="cc_type"]',
        numberInputSelector: '[name="cc_number"]',
        expMonthInputSelector: '[name="cc_exp_month"]',
        expYearInputSelector: '[name="cc_exp_year"]',
        nameInputSelector: '[name="cc_name"]',
        cvcInputSelector: '[name="cc_cvc"]',
        initialValues: {},
        validationState: {},
        strings: {
          hiddenFaceFillPrompt: "<strong>Click here</strong> to <br>fill in the other side.",
          hiddenFaceErrorWarning: "There's a problem on the other side.",
          hiddenFaceSwitchPrompt: "Forget something?<br> Flip the card over."
        }
      };
      this.options = $.extend(optDefaults, opts);
      this._conformDOM();
      this._bindInputEvents();
      this._importImplicitOptions();
      this.render();
    }

    Skeuocard.prototype._log = function() {
      var msg;
      msg = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      if ((typeof console !== "undefined" && console !== null ? console.log : void 0) && !!this.options.debug) {
        if (this.options.debug != null) {
          return console.log.apply(console, ["[skeuocard]"].concat(__slice.call(msg)));
        }
      }
    };

    Skeuocard.prototype.trigger = function() {
      var args, _ref;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return (_ref = this.el.container).trigger.apply(_ref, args);
    };

    Skeuocard.prototype.bind = function() {
      var args, _ref;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return (_ref = this.el.container).bind.apply(_ref, args);
    };

    /*
    Transform the elements within the container, conforming the DOM so that it 
    becomes styleable, and that the underlying inputs are hidden.
    */


    Skeuocard.prototype._conformDOM = function() {
      this.el.container.removeClass('no-js');
      this.el.container.addClass("skeuocard js");
      this.el.container.find("> :not(input,select,textarea)").remove();
      this.el.container.find("> input,select,textarea").hide();
      this.el.underlyingFields = {
        type: this.el.container.find(this.options.typeInputSelector),
        number: this.el.container.find(this.options.numberInputSelector),
        expMonth: this.el.container.find(this.options.expMonthInputSelector),
        expYear: this.el.container.find(this.options.expYearInputSelector),
        name: this.el.container.find(this.options.nameInputSelector),
        cvc: this.el.container.find(this.options.cvcInputSelector)
      };
      this.el.front = $("<div>").attr({
        "class": "face front"
      });
      this.el.back = $("<div>").attr({
        "class": "face back"
      });
      this.el.cardBody = $("<div>").attr({
        "class": "card-body"
      });
      this.el.front.appendTo(this.el.cardBody);
      this.el.back.appendTo(this.el.cardBody);
      this.el.cardBody.appendTo(this.el.container);
      this._tabViews.front = new Skeuocard.prototype.FlipTabView(this, 'front', {
        strings: this.options.strings
      });
      this._tabViews.back = new Skeuocard.prototype.FlipTabView(this, 'back', {
        strings: this.options.strings
      });
      this.el.front.prepend(this._tabViews.front.el);
      this.el.back.prepend(this._tabViews.back.el);
      this._tabViews.front.hide();
      this._tabViews.back.hide();
      this._inputViews = {
        number: new this.SegmentedCardNumberInputView(),
        exp: new this.ExpirationInputView({
          currentDate: this.options.currentDate
        }),
        name: new this.TextInputView({
          "class": "cc-name",
          placeholder: "YOUR NAME"
        }),
        cvc: new this.TextInputView({
          "class": "cc-cvc",
          placeholder: "XXX",
          requireMaxLength: true
        })
      };
      this._inputViews.number.el.addClass('cc-number');
      this._inputViews.number.el.appendTo(this.el.front);
      this._inputViews.name.el.appendTo(this.el.front);
      this._inputViews.exp.el.addClass('cc-exp');
      this._inputViews.exp.el.appendTo(this.el.front);
      this._inputViews.cvc.el.appendTo(this.el.back);
      return this.el.container;
    };

    /*
    Import implicit initialization options from the DOM. Brings in things like 
    the accepted card type, initial validation state, existing values, etc.
    */


    Skeuocard.prototype._importImplicitOptions = function() {
      var fieldEl, fieldName, _initialExp, _ref,
        _this = this;
      _ref = this.el.underlyingFields;
      for (fieldName in _ref) {
        fieldEl = _ref[fieldName];
        if (this.options.initialValues[fieldName] == null) {
          this.options.initialValues[fieldName] = fieldEl.val();
        } else {
          this.options.initialValues[fieldName] = this.options.initialValues[fieldName].toString();
          this._setUnderlyingValue(fieldName, this.options.initialValues[fieldName]);
        }
        if (this.options.initialValues[fieldName].length > 0) {
          this._state['initiallyFilled'] = true;
        }
        if (this.options.validationState[fieldName] == null) {
          this.options.validationState[fieldName] = !fieldEl.hasClass('invalid');
        }
      }
      if (this.options.acceptedCardProducts == null) {
        this.options.acceptedCardProducts = [];
        this.el.underlyingFields.type.find('option').each(function(i, _el) {
          var el, shortname;
          el = $(_el);
          shortname = el.attr('data-sc-type') || el.attr('value');
          return _this.options.acceptedCardProducts.push(shortname);
        });
      }
      if (this.options.initialValues.number.length > 0) {
        this.set('number', this.options.initialValues.number);
      }
      if (this.options.initialValues.name.length > 0) {
        this.set('name', this.options.initialValues.name);
      }
      if (this.options.initialValues.cvc.length > 0) {
        this.set('cvc', this.options.initialValues.cvc);
      }
      if (this.options.initialValues.expYear.length > 0 && this.options.initialValues.expMonth.length > 0) {
        _initialExp = new Date(parseInt(this.options.initialValues.expYear), parseInt(this.options.initialValues.expMonth) - 1, 1);
        this.set('exp', _initialExp);
      }
      this._updateValidationForFace('front');
      return this._updateValidationForFace('back');
    };

    Skeuocard.prototype.set = function(field, newValue) {
      this._inputViews[field].setValue(newValue);
      return this._inputViews[field].trigger('valueChanged', this._inputViews[field]);
    };

    /*
    Bind interaction events to their appropriate handlers.
    */


    Skeuocard.prototype._bindInputEvents = function() {
      var _expirationChange,
        _this = this;
      this.el.underlyingFields.number.bind("change", function(e) {
        _this._inputViews.number.setValue(_this._getUnderlyingValue('number'));
        return _this.render();
      });
      _expirationChange = function(e) {
        var month, year;
        month = parseInt(_this._getUnderlyingValue('expMonth'));
        year = parseInt(_this._getUnderlyingValue('expYear'));
        _this._inputViews.exp.setValue(new Date(year, month - 1));
        return _this.render();
      };
      this.el.underlyingFields.expMonth.bind("change", _expirationChange);
      this.el.underlyingFields.expYear.bind("change", _expirationChange);
      this.el.underlyingFields.name.bind("change", function(e) {
        _this._inputViews.exp.setValue(_this._getUnderlyingValue('name'));
        return _this.render();
      });
      this.el.underlyingFields.cvc.bind("change", function(e) {
        _this._inputViews.exp.setValue(_this._getUnderlyingValue('cvc'));
        return _this.render();
      });
      this._inputViews.number.bind("change valueChanged", function(e, input) {
        var cardNumber, matchedProduct, number, previousProduct, _ref, _ref1;
        cardNumber = input.getValue();
        _this._setUnderlyingValue('number', cardNumber);
        _this._updateValidation('number', cardNumber);
        number = _this._getUnderlyingValue('number');
        matchedProduct = Skeuocard.prototype.CardProduct.firstMatchingNumber(number);
        if (!((_ref = _this.product) != null ? _ref.eql(matchedProduct) : void 0)) {
          _this._log("Product will change:", _this.product, "=>", matchedProduct);
          if (_ref1 = matchedProduct != null ? matchedProduct.attrs.companyShortname : void 0, __indexOf.call(_this.options.acceptedCardProducts, _ref1) >= 0) {
            _this.trigger('productWillChange.skeuocard', [_this, _this.product, matchedProduct]);
            previousProduct = _this.product;
            _this.el.container.removeClass('unaccepted');
            _this._renderProduct(matchedProduct);
            _this.product = matchedProduct;
          } else if (matchedProduct != null) {
            _this.trigger('productWillChange.skeuocard', [_this, _this.product, null]);
            _this.el.container.addClass('unaccepted');
            _this._renderProduct(null);
            _this.product = null;
          } else {
            _this.trigger('productWillChange.skeuocard', [_this, _this.product, null]);
            _this.el.container.removeClass('unaccepted');
            _this._renderProduct(null);
            _this.product = null;
          }
          return _this.trigger('productDidChange.skeuocard', [_this, previousProduct, _this.product]);
        }
      });
      this._inputViews.exp.bind("keyup valueChanged", function(e, input) {
        var newDate;
        newDate = input.getValue();
        _this._updateValidation('exp', newDate);
        if (newDate != null) {
          _this._setUnderlyingValue('expMonth', newDate.getMonth() + 1);
          return _this._setUnderlyingValue('expYear', newDate.getFullYear());
        }
      });
      this._inputViews.name.bind("keyup valueChanged", function(e, input) {
        var value;
        value = input.getValue();
        _this._setUnderlyingValue('name', value);
        return _this._updateValidation('name', value);
      });
      this._inputViews.cvc.bind("keyup valueChanged", function(e, input) {
        var value;
        value = input.getValue();
        _this._setUnderlyingValue('cvc', value);
        return _this._updateValidation('cvc', value);
      });
      this.el.container.delegate("input", "keyup keydown", this._handleFieldTab.bind(this));
      this._tabViews.front.el.click(function() {
        return _this.flip();
      });
      return this._tabViews.back.el.click(function() {
        return _this.flip();
      });
    };

    Skeuocard.prototype._handleFieldTab = function(e) {
      var backFieldEls, currentFieldEl, frontFieldEls, _currentFace, _oppositeFace;
      if (e.which === 9) {
        currentFieldEl = $(e.currentTarget);
        _oppositeFace = this.visibleFace === 'front' ? 'back' : 'front';
        _currentFace = this.visibleFace === 'front' ? 'front' : 'back';
        backFieldEls = this.el[_oppositeFace].find('input');
        frontFieldEls = this.el[_currentFace].find('input');
        if (this.visibleFace === 'front' && this.el.front.hasClass('filled') && backFieldEls.length > 0 && frontFieldEls.index(currentFieldEl) === frontFieldEls.length - 1 && !e.shiftKey) {
          this.flip();
          backFieldEls.first().focus();
          e.preventDefault();
        }
        if (this.visibleFace === 'back' && e.shiftKey) {
          this.flip();
          backFieldEls.last().focus();
          e.preventDefault();
        }
      }
      return true;
    };

    Skeuocard.prototype._updateValidation = function(fieldName, newValue) {
      var fillStateChanged, isFilled, isFixed, isValid, needsFix, validationStateChanged;
      if (this.product == null) {
        return false;
      }
      isFilled = this.product[fieldName].isFilled(newValue);
      needsFix = (this.options.validationState[fieldName] != null) === false;
      isFixed = (this.options.initialValues[fieldName] != null) && newValue !== this.options.initialValues[fieldName];
      isValid = this.product[fieldName].isValid(newValue) && ((needsFix && isFixed) || true);
      fillStateChanged = this._state["" + fieldName + "Filled"] !== isFilled;
      validationStateChanged = this._state["" + fieldName + "Valid"] !== isValid;
      if (fillStateChanged) {
        this.trigger("fieldFillStateWillChange.skeuocard", [this, fieldName, isFilled]);
        this._inputViews[fieldName].el.toggleClass('filled', isFilled);
        this._state["" + fieldName + "Filled"] = isFilled;
        this.trigger("fieldFillStateDidChange.skeuocard", [this, fieldName, isFilled]);
      }
      if (validationStateChanged) {
        this.trigger("fieldValidationStateWillChange.skeuocard", [this, fieldName, isValid]);
        this._inputViews[fieldName].el.toggleClass('valid', isValid);
        this._inputViews[fieldName].el.toggleClass('invalid', !isValid);
        this._state["" + fieldName + "Valid"] = isValid;
        this.trigger("fieldValidationStateDidChange.skeuocard", [this, fieldName, isValid]);
      }
      return this._updateValidationForFace(this.visibleFace);
    };

    Skeuocard.prototype._updateValidationForFace = function(face) {
      var fieldsFilled, fieldsValid, fillStateChanged, isFilled, isValid, iv, validationStateChanged;
      fieldsFilled = ((function() {
        var _i, _len, _ref, _results;
        _ref = this._inputViewsByFace[face];
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          iv = _ref[_i];
          _results.push(iv.el.hasClass('filled'));
        }
        return _results;
      }).call(this)).every(Boolean);
      fieldsValid = ((function() {
        var _i, _len, _ref, _results;
        _ref = this._inputViewsByFace[face];
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          iv = _ref[_i];
          _results.push(iv.el.hasClass('valid'));
        }
        return _results;
      }).call(this)).every(Boolean);
      isFilled = (fieldsFilled && (this.product != null)) || (this._state['initiallyFilled'] || false);
      isValid = fieldsValid && (this.product != null);
      fillStateChanged = this._state["" + face + "Filled"] !== isFilled;
      validationStateChanged = this._state["" + face + "Valid"] !== isValid;
      if (fillStateChanged) {
        this.trigger("faceFillStateWillChange.skeuocard", [this, face, isFilled]);
        this.el[face].toggleClass('filled', isFilled);
        this._state["" + face + "Filled"] = isFilled;
        this.trigger("faceFillStateDidChange.skeuocard", [this, face, isFilled]);
      }
      if (validationStateChanged) {
        this.trigger("faceValidationStateWillChange.skeuocard", [this, face, isValid]);
        this.el[face].toggleClass('valid', isValid);
        this.el[face].toggleClass('invalid', !isValid);
        this._state["" + face + "Valid"] = isValid;
        return this.trigger("faceValidationStateDidChange.skeuocard", [this, face, isValid]);
      }
    };

    /*
    Assert rendering changes necessary for the current product. Passing a null 
    value instead of a product will revert the card to a generic state.
    */


    Skeuocard.prototype._renderProduct = function(product) {
      var destFace, fieldName, focused, view, viewEl, _ref, _ref1,
        _this = this;
      this._log("[_renderProduct]", "Rendering product:", product);
      this.el.container.removeClass(function(index, css) {
        return (css.match(/\b(product|issuer)-\S+/g) || []).join(' ');
      });
      if ((product != null ? product.attrs.companyShortname : void 0) != null) {
        this.el.container.addClass("product-" + product.attrs.companyShortname);
      }
      if ((product != null ? product.attrs.issuerShortname : void 0) != null) {
        this.el.container.addClass("issuer-" + product.attrs.issuerShortname);
      }
      this._setUnderlyingValue('type', (product != null ? product.attrs.companyShortname : void 0) || null);
      this._inputViews.number.setGroupings((product != null ? product.attrs.cardNumberGrouping : void 0) || [this.options.genericPlaceholder.length], this.options.dontFocus);
      delete this.options.dontFocus;
      if (product != null) {
        this._inputViews.exp.reconfigure({
          pattern: (product != null ? product.attrs.expirationFormat : void 0) || "MM/YY"
        });
        this._inputViews.cvc.attr({
          maxlength: product.attrs.cvcLength,
          placeholder: new Array(product.attrs.cvcLength + 1).join(this.options.cardNumberPlaceholderChar)
        });
        this._inputViewsByFace = {
          front: [],
          back: []
        };
        focused = $('input:focus');
        _ref = product.attrs.layout;
        for (fieldName in _ref) {
          destFace = _ref[fieldName];
          this._log("Moving", fieldName, "to", destFace);
          viewEl = this._inputViews[fieldName].el.detach();
          viewEl.appendTo(this.el[destFace]);
          this._inputViewsByFace[destFace].push(this._inputViews[fieldName]);
          this._inputViews[fieldName].show();
        }
        setTimeout(function() {
          var fieldEl, fieldLength;
          if ((fieldEl = focused.first()) != null) {
            fieldLength = fieldEl[0].maxLength;
            fieldEl.focus();
            return fieldEl[0].setSelectionRange(fieldLength, fieldLength);
          }
        }, 10);
      } else {
        _ref1 = this._inputViews;
        for (fieldName in _ref1) {
          view = _ref1[fieldName];
          if (fieldName !== 'number') {
            view.hide();
          }
        }
      }
      return product;
    };

    Skeuocard.prototype._renderValidation = function() {
      var fieldName, fieldView, _ref, _results;
      _ref = this._inputViews;
      _results = [];
      for (fieldName in _ref) {
        fieldView = _ref[fieldName];
        _results.push(this._updateValidation(fieldName, fieldView.getValue()));
      }
      return _results;
    };

    Skeuocard.prototype.render = function() {
      this._renderProduct(this.product);
      return this._renderValidation();
    };

    Skeuocard.prototype.flip = function() {
      var surfaceName, targetFace;
      targetFace = this.visibleFace === 'front' ? 'back' : 'front';
      this.trigger('faceWillBecomeVisible.skeuocard', [this, targetFace]);
      this.visibleFace = targetFace;
      this.el.cardBody.toggleClass('flip');
      surfaceName = this.visibleFace === 'front' ? 'front' : 'back';
      this.el[surfaceName].find('.cc-field').not('.filled').find('input').first().focus();
      return this.trigger('faceDidBecomeVisible.skeuocard', [this, targetFace]);
    };

    Skeuocard.prototype._setUnderlyingValue = function(field, newValue) {
      var fieldEl, remapAttrKey, _newValue,
        _this = this;
      fieldEl = this.el.underlyingFields[field];
      _newValue = (newValue || "").toString();
      if (fieldEl == null) {
        throw "Set underlying value of unknown field: " + field + ".";
      }
      this.trigger('change.skeuocard', [this]);
      if (!fieldEl.is('select')) {
        return this.el.underlyingFields[field].val(_newValue);
      } else {
        remapAttrKey = "data-sc-" + field.toLowerCase();
        return fieldEl.find('option').each(function(i, _el) {
          var optionEl;
          optionEl = $(_el);
          if (_newValue === (optionEl.attr(remapAttrKey) || optionEl.attr('value'))) {
            return _this.el.underlyingFields[field].val(optionEl.attr('value'));
          }
        });
      }
    };

    Skeuocard.prototype._getUnderlyingValue = function(field) {
      var _ref;
      return (_ref = this.el.underlyingFields[field]) != null ? _ref.val() : void 0;
    };

    Skeuocard.prototype.isValid = function() {
      return !this.el.front.hasClass('invalid') && !this.el.back.hasClass('invalid');
    };

    return Skeuocard;

  })();

  window.Skeuocard = Skeuocard;

  /*
  Skeuocard::FlipTabView
  Handles rendering of the "flip button" control and its various warning and 
  prompt states.
  */


  Skeuocard.prototype.FlipTabView = (function() {
    function FlipTabView(sc, face, opts) {
      var _this = this;
      if (opts == null) {
        opts = {};
      }
      this.card = sc;
      this.face = face;
      this.el = $("<div class=\"flip-tab " + face + "\"><p></p></div>");
      this.options = opts;
      this._state = {};
      this.card.bind('faceFillStateWillChange.skeuocard', this._faceStateChanged.bind(this));
      this.card.bind('faceValidationStateWillChange.skeuocard', this._faceValidationChanged.bind(this));
      this.card.bind('productWillChange.skeuocard', function(e, card, prevProduct, newProduct) {
        if (newProduct == null) {
          return _this.hide();
        }
      });
    }

    FlipTabView.prototype._faceStateChanged = function(e, card, face, isFilled) {
      var oppositeFace;
      oppositeFace = face === 'front' ? 'back' : 'front';
      if (isFilled === true && this.card._inputViewsByFace[oppositeFace].length > 0) {
        this.show();
      }
      if (face !== this.face) {
        this._state.opposingFaceFilled = isFilled;
      }
      if (this._state.opposingFaceFilled !== true) {
        return this.warn(this.options.strings.hiddenFaceFillPrompt, true);
      }
    };

    FlipTabView.prototype._faceValidationChanged = function(e, card, face, isValid) {
      if (face !== this.face) {
        this._state.opposingFaceValid = isValid;
      }
      if (this._state.opposingFaceValid) {
        return this.prompt(this.options.strings.hiddenFaceSwitchPrompt);
      } else {
        if (this._state.opposingFaceFilled) {
          return this.warn(this.options.strings.hiddenFaceErrorWarning);
        } else {
          return this.warn(this.options.strings.hiddenFaceFillPrompt);
        }
      }
    };

    FlipTabView.prototype._setText = function(text) {
      return this.el.find('p').first().html(text);
    };

    FlipTabView.prototype.warn = function(message) {
      this._resetClasses();
      this._setText(message);
      return this.el.addClass('warn');
    };

    FlipTabView.prototype.prompt = function(message) {
      this._resetClasses();
      this._setText(message);
      return this.el.addClass('prompt');
    };

    FlipTabView.prototype._resetClasses = function() {
      this.el.removeClass('warn');
      return this.el.removeClass('prompt');
    };

    FlipTabView.prototype.show = function() {
      return this.el.show();
    };

    FlipTabView.prototype.hide = function() {
      return this.el.hide();
    };

    return FlipTabView;

  })();

  /*
  # Skeuocard::SegmentedCardNumberInputView
  # Provides a reconfigurable segmented input view for credit card numbers.
  */


  Skeuocard.prototype.SegmentedCardNumberInputView = (function() {
    SegmentedCardNumberInputView.prototype._digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    SegmentedCardNumberInputView.prototype._keys = {
      backspace: 8,
      tab: 9,
      enter: 13,
      del: 46,
      arrowLeft: 37,
      arrowUp: 38,
      arrowRight: 39,
      arrowDown: 40,
      arrows: [37, 38, 39, 40],
      command: 16,
      alt: 17
    };

    SegmentedCardNumberInputView.prototype._specialKeys = [8, 9, 13, 46, 37, 38, 39, 40, 16, 17];

    function SegmentedCardNumberInputView(opts) {
      if (opts == null) {
        opts = {};
      }
      this.optDefaults = {
        value: "",
        groupings: [19],
        placeholderChar: "X"
      };
      this.options = $.extend({}, this.optDefaults, opts);
      this._state = {
        selectingAll: false
      };
      this._buildDOM();
      this.setGroupings(this.options.groupings);
    }

    SegmentedCardNumberInputView.prototype._buildDOM = function() {
      var _this = this;
      this.el = $('<fieldset>');
      this.el.addClass('cc-field');
      this.el.delegate("input", "keypress", this._handleGroupKeyPress.bind(this));
      this.el.delegate("input", "keydown", this._handleGroupKeyDown.bind(this));
      this.el.delegate("input", "keyup", this._handleGroupKeyUp.bind(this));
      this.el.delegate("input", "paste", this._handleGroupPaste.bind(this));
      this.el.delegate("input", "change", this._handleGroupChange.bind(this));
      this.el.delegate("input", "focus", function(e) {
        return _this.el.addClass('focus');
      });
      return this.el.delegate("input", "blur", function(e) {
        return _this.el.removeClass('focus');
      });
    };

    SegmentedCardNumberInputView.prototype._handleGroupKeyDown = function(e) {
      var currentTarget, cursorEnd, cursorStart, inputGroupEl, inputMaxLength, nextInputEl, prevInputEl, _ref;
      if (e.ctrlKey || e.metaKey) {
        return this._handleModifiedKeyDown(e);
      }
      inputGroupEl = $(e.currentTarget);
      currentTarget = e.currentTarget;
      cursorStart = currentTarget.selectionStart;
      cursorEnd = currentTarget.selectionEnd;
      inputMaxLength = currentTarget.maxLength;
      prevInputEl = inputGroupEl.prevAll('input');
      nextInputEl = inputGroupEl.nextAll('input');
      switch (e.which) {
        case this._keys.backspace:
          if (prevInputEl.length > 0 && cursorEnd === 0) {
            this._focusField(prevInputEl.first(), 'end');
          }
          break;
        case this._keys.arrowUp:
          if (cursorEnd === inputMaxLength) {
            this._focusField(inputGroupEl, 'start');
          } else {
            this._focusField(inputGroupEl.prev(), 'end');
          }
          e.preventDefault();
          break;
        case this._keys.arrowDown:
          if (cursorEnd === inputMaxLength) {
            this._focusField(inputGroupEl.next(), 'start');
          } else {
            this._focusField(inputGroupEl, 'end');
          }
          e.preventDefault();
          break;
        case this._keys.arrowLeft:
          if (cursorEnd === 0) {
            this._focusField(inputGroupEl.prev(), 'end');
            e.preventDefault();
          }
          break;
        case this._keys.arrowRight:
          if (cursorEnd === inputMaxLength) {
            this._focusField(inputGroupEl.next(), 'start');
            e.preventDefault();
          }
          break;
        default:
          if (!(_ref = e.which, __indexOf.call(this._specialKeys, _ref) >= 0) && (cursorStart === inputMaxLength && cursorEnd === inputMaxLength) && nextInputEl.length !== 0) {
            this._focusField(nextInputEl.first(), 'start');
          }
      }
      return true;
    };

    SegmentedCardNumberInputView.prototype._handleGroupKeyPress = function(e) {
      var inputGroupEl, isDigit, _ref, _ref1;
      inputGroupEl = $(e.currentTarget);
      isDigit = (_ref = String.fromCharCode(e.which), __indexOf.call(this._digits, _ref) >= 0);
      if (e.ctrlKey || e.metaKey) {
        return true;
      }
      if (e.which === 0) {
        return true;
      }
      if ((!e.shiftKey && (_ref1 = e.which, __indexOf.call(this._specialKeys, _ref1) >= 0)) || isDigit) {
        return true;
      }
      e.preventDefault();
      return false;
    };

    SegmentedCardNumberInputView.prototype._handleGroupKeyUp = function(e) {
      var currentTarget, cursorEnd, cursorStart, inputGroupEl, inputMaxLength, nextInputEl, _ref, _ref1, _ref2;
      inputGroupEl = $(e.currentTarget);
      currentTarget = e.currentTarget;
      inputMaxLength = currentTarget.maxLength;
      cursorStart = currentTarget.selectionStart;
      cursorEnd = currentTarget.selectionEnd;
      nextInputEl = inputGroupEl.nextAll('input');
      if (e.ctrlKey || e.metaKey) {
        return true;
      }
      if (this._state.selectingAll && (_ref = e.which, __indexOf.call(this._specialKeys, _ref) >= 0) && e.which !== this._keys.command && e.which !== this._keys.alt) {
        this._endSelectAll();
      }
      if (!(_ref1 = e.which, __indexOf.call(this._specialKeys, _ref1) >= 0) && !(e.shiftKey && e.which === this._keys.tab) && (cursorStart === inputMaxLength && cursorEnd === inputMaxLength) && nextInputEl.length !== 0) {
        this._focusField(nextInputEl.first(), 'start');
      }
      if (!(e.shiftKey && (_ref2 = e.which, __indexOf.call(this._specialKeys, _ref2) >= 0))) {
        this.trigger('change', [this]);
      }
      return true;
    };

    SegmentedCardNumberInputView.prototype._handleModifiedKeyDown = function(e) {
      var char;
      char = String.fromCharCode(e.which);
      switch (char) {
        case 'a':
        case 'A':
          this._beginSelectAll();
          return e.preventDefault();
      }
    };

    SegmentedCardNumberInputView.prototype._handleGroupPaste = function(e) {
      var _this = this;
      return setTimeout(function() {
        var newValue;
        newValue = _this.getValue().replace(/[^0-9]+/g, '');
        if (_this._state.selectingAll) {
          _this._endSelectAll();
        }
        _this.setValue(newValue);
        return _this.trigger('change', [_this]);
      }, 50);
    };

    SegmentedCardNumberInputView.prototype._handleGroupChange = function(e) {
      return e.stopPropagation();
    };

    SegmentedCardNumberInputView.prototype._getFocusedField = function() {
      return this.el.find("input:focus");
    };

    SegmentedCardNumberInputView.prototype._beginSelectAll = function() {
      var fieldEl;
      if (!this.el.hasClass('selecting-all')) {
        this._state.lastGrouping = this.options.groupings;
        this._state.lastLength = this.getValue().length;
        this.setGroupings(this.optDefaults.groupings);
        this.el.addClass('selecting-all');
        fieldEl = this.el.find("input");
        fieldEl[0].setSelectionRange(0, fieldEl.val().length);
        return this._state.selectingAll = true;
      } else {
        fieldEl = this.el.find("input");
        return fieldEl[0].setSelectionRange(0, fieldEl.val().length);
      }
    };

    SegmentedCardNumberInputView.prototype._endSelectAll = function() {
      if (this.el.hasClass('selecting-all')) {
        this._state.selectingAll = false;
        if (this._state.lastLength === this.getValue().length) {
          this.setGroupings(this._state.lastGrouping);
        }
        return this.el.removeClass('selecting-all');
      }
    };

    SegmentedCardNumberInputView.prototype._indexInValueAtFieldSelection = function(field) {
      var groupingIndex, i, len, offset, _i, _len, _ref;
      groupingIndex = this.el.find('input').index(field);
      offset = 0;
      _ref = this.options.groupings;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        len = _ref[i];
        if (i < groupingIndex) {
          offset += len;
        }
      }
      return offset + field[0].selectionEnd;
    };

    SegmentedCardNumberInputView.prototype.setGroupings = function(groupings, dontFocus) {
      var groupEl, groupLength, _caretPosition, _currentField, _i, _len, _value;
      _currentField = this._getFocusedField();
      _value = this.getValue();
      _caretPosition = 0;
      if (_currentField.length > 0) {
        _caretPosition = this._indexInValueAtFieldSelection(_currentField);
      }
      this.el.empty();
      for (_i = 0, _len = groupings.length; _i < _len; _i++) {
        groupLength = groupings[_i];
        groupEl = $("<input>").attr({
          type: 'text',
          pattern: '[0-9]*',
          size: groupLength,
          maxlength: groupLength,
          "class": "group" + groupLength,
          placeholder: new Array(groupLength + 1).join(this.options.placeholderChar)
        });
        this.el.append(groupEl);
      }
      this.options.groupings = groupings;
      this.setValue(_value);
      _currentField = this._focusFieldForValue([_caretPosition, _caretPosition], dontFocus);
      if ((_currentField != null) && _currentField[0].selectionEnd === _currentField[0].maxLength) {
        return this._focusField(_currentField.next(), 'start');
      }
    };

    SegmentedCardNumberInputView.prototype._focusFieldForValue = function(place, dontFocus) {
      var field, fieldOffset, fieldPosition, groupIndex, groupLength, value, _i, _lastStartPos, _len, _ref;
      value = this.getValue();
      if (place === 'start') {
        field = this.el.find('input').first();
        if (!dontFocus) {
          this._focusField(field, place);
        }
      } else if (place === 'end') {
        field = this.el.find('input').last();
        if (!dontFocus) {
          this._focusField(field, place);
        }
      } else {
        field = null;
        fieldOffset = null;
        _lastStartPos = 0;
        _ref = this.options.groupings;
        for (groupIndex = _i = 0, _len = _ref.length; _i < _len; groupIndex = ++_i) {
          groupLength = _ref[groupIndex];
          if (place[1] > _lastStartPos && place[1] <= _lastStartPos + groupLength) {
            field = $(this.el.find('input')[groupIndex]);
            fieldPosition = place[1] - _lastStartPos;
          }
          _lastStartPos += groupLength;
        }
        if ((field != null) && (fieldPosition != null)) {
          if (!dontFocus) {
            this._focusField(field, [fieldPosition, fieldPosition]);
          }
        } else {
          if (!dontFocus) {
            this._focusField(this.el.find('input'), 'end');
          }
        }
      }
      return field;
    };

    SegmentedCardNumberInputView.prototype._focusField = function(field, place) {
      var fieldLen;
      if (field.length !== 0) {
        field[0].focus();
        if ($(field[0]).is(':visible') && field[0] === document.activeElement) {
          if (place === 'start') {
            return field[0].setSelectionRange(0, 0);
          } else if (place === 'end') {
            fieldLen = field[0].maxLength;
            return field[0].setSelectionRange(fieldLen, fieldLen);
          } else {
            return field[0].setSelectionRange(place[0], place[1]);
          }
        }
      }
    };

    SegmentedCardNumberInputView.prototype.setValue = function(newValue) {
      var el, groupIndex, groupLength, groupVal, _i, _lastStartPos, _len, _ref, _results;
      _lastStartPos = 0;
      _ref = this.options.groupings;
      _results = [];
      for (groupIndex = _i = 0, _len = _ref.length; _i < _len; groupIndex = ++_i) {
        groupLength = _ref[groupIndex];
        el = $(this.el.find('input').get(groupIndex));
        groupVal = newValue.substr(_lastStartPos, groupLength);
        el.val(groupVal);
        _results.push(_lastStartPos += groupLength);
      }
      return _results;
    };

    SegmentedCardNumberInputView.prototype.getValue = function() {
      var buffer, el, _i, _len, _ref;
      buffer = "";
      _ref = this.el.find('input');
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        el = _ref[_i];
        buffer += $(el).val();
      }
      return buffer;
    };

    SegmentedCardNumberInputView.prototype.maxLength = function() {
      return this.options.groupings.reduce(function(a, b) {
        return a + b;
      });
    };

    SegmentedCardNumberInputView.prototype.bind = function() {
      var args, _ref;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return (_ref = this.el).bind.apply(_ref, args);
    };

    SegmentedCardNumberInputView.prototype.trigger = function() {
      var args, _ref;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return (_ref = this.el).trigger.apply(_ref, args);
    };

    SegmentedCardNumberInputView.prototype.show = function() {
      return this.el.show();
    };

    SegmentedCardNumberInputView.prototype.hide = function() {
      return this.el.hide();
    };

    SegmentedCardNumberInputView.prototype.addClass = function() {
      var args, _ref;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return (_ref = this.el).addClass.apply(_ref, args);
    };

    SegmentedCardNumberInputView.prototype.removeClass = function() {
      var args, _ref;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return (_ref = this.el).removeClass.apply(_ref, args);
    };

    return SegmentedCardNumberInputView;

  })();

  /*
  Skeuocard::ExpirationInputView
  */


  Skeuocard.prototype.ExpirationInputView = (function() {
    function ExpirationInputView(opts) {
      var _this = this;
      if (opts == null) {
        opts = {};
      }
      opts.pattern || (opts.pattern = "MM/YY");
      this.options = opts;
      this.date = null;
      this.el = $("<fieldset>");
      this.el.addClass('cc-field');
      this.el.delegate("input", "keydown", function(e) {
        return _this._onKeyDown(e);
      });
      this.el.delegate("input", "keyup", function(e) {
        return _this._onKeyUp(e);
      });
      this.el.delegate("input", "focus", function(e) {
        return _this.el.addClass('focus');
      });
      this.el.delegate("input", "blur", function(e) {
        return _this.el.removeClass('focus');
      });
    }

    ExpirationInputView.prototype.bind = function() {
      var args, _ref;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return (_ref = this.el).bind.apply(_ref, args);
    };

    ExpirationInputView.prototype.trigger = function() {
      var args, _ref;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return (_ref = this.el).trigger.apply(_ref, args);
    };

    ExpirationInputView.prototype._getFieldCaretPosition = function(el) {
      var input, sel, selLength;
      input = el.get(0);
      if (input.selectionEnd != null) {
        return input.selectionEnd;
      } else if (document.selection) {
        input.focus();
        sel = document.selection.createRange();
        selLength = document.selection.createRange().text.length;
        sel.moveStart('character', -input.value.length);
        return selLength;
      }
    };

    ExpirationInputView.prototype._setFieldCaretPosition = function(el, pos) {
      var input, range;
      input = el.get(0);
      if (input.createTextRange != null) {
        range = input.createTextRange();
        range.move("character", pos);
        return range.select();
      } else if (input.selectionStart != null) {
        input.focus();
        return input.setSelectionRange(pos, pos);
      }
    };

    ExpirationInputView.prototype.setPattern = function(pattern) {
      var char, groupings, i, patternParts, _currentLength, _i, _len;
      groupings = [];
      patternParts = pattern.split('');
      _currentLength = 0;
      for (i = _i = 0, _len = patternParts.length; _i < _len; i = ++_i) {
        char = patternParts[i];
        _currentLength++;
        if (patternParts[i + 1] !== char) {
          groupings.push([_currentLength, char]);
          _currentLength = 0;
        }
      }
      this.options.groupings = groupings;
      return this._setGroupings(this.options.groupings);
    };

    ExpirationInputView.prototype._setGroupings = function(groupings) {
      var fieldChars, group, groupChar, groupLength, input, sep, _i, _len, _startLength;
      fieldChars = ['D', 'M', 'Y'];
      this.el.empty();
      _startLength = 0;
      for (_i = 0, _len = groupings.length; _i < _len; _i++) {
        group = groupings[_i];
        groupLength = group[0];
        groupChar = group[1];
        if (__indexOf.call(fieldChars, groupChar) >= 0) {
          input = $('<input>').attr({
            type: 'text',
            pattern: '[0-9]*',
            placeholder: new Array(groupLength + 1).join(groupChar),
            maxlength: groupLength,
            "class": 'cc-exp-field-' + groupChar.toLowerCase() + ' group' + groupLength
          });
          input.data('fieldtype', groupChar);
          this.el.append(input);
        } else {
          sep = $('<span>').attr({
            "class": 'separator'
          });
          sep.html(new Array(groupLength + 1).join(groupChar));
          this.el.append(sep);
        }
      }
      this.groupEls = this.el.find('input');
      if (this.date != null) {
        return this._updateFieldValues();
      }
    };

    ExpirationInputView.prototype._zeroPadNumber = function(num, places) {
      var zero;
      zero = places - num.toString().length + 1;
      return Array(zero).join("0") + num;
    };

    ExpirationInputView.prototype._updateFieldValues = function() {
      var currentDate,
        _this = this;
      currentDate = this.date;
      if (!this.groupEls) {
        return this.setPattern(this.options.pattern);
      }
      return this.groupEls.each(function(i, _el) {
        var el, groupLength, year;
        el = $(_el);
        groupLength = parseInt(el.attr('maxlength'));
        switch (el.data('fieldtype')) {
          case 'M':
            return el.val(_this._zeroPadNumber(currentDate.getMonth() + 1, groupLength));
          case 'D':
            return el.val(_this._zeroPadNumber(currentDate.getDate(), groupLength));
          case 'Y':
            year = groupLength >= 4 ? currentDate.getFullYear() : currentDate.getFullYear().toString().substr(2, 4);
            return el.val(year);
        }
      });
    };

    ExpirationInputView.prototype.clear = function() {
      this.value = "";
      this.date = null;
      return this.groupEls.each(function() {
        return $(this).val('');
      });
    };

    ExpirationInputView.prototype.setValue = function(newDate) {
      this.date = newDate;
      return this._updateFieldValues();
    };

    ExpirationInputView.prototype.getValue = function() {
      return this.date;
    };

    ExpirationInputView.prototype.reconfigure = function(opts) {
      if (opts.pattern != null) {
        this.setPattern(opts.pattern);
      }
      if (opts.value != null) {
        return this.setValue(opts.value);
      }
    };

    ExpirationInputView.prototype._onKeyDown = function(e) {
      var groupCaretPos, groupEl, groupMaxLength, nextInputEl, prevInputEl, _ref;
      e.stopPropagation();
      groupEl = $(e.currentTarget);
      groupEl = $(e.currentTarget);
      groupMaxLength = parseInt(groupEl.attr('maxlength'));
      groupCaretPos = this._getFieldCaretPosition(groupEl);
      prevInputEl = groupEl.prevAll('input').first();
      nextInputEl = groupEl.nextAll('input').first();
      if (e.which === 8 && groupCaretPos === 0 && !$.isEmptyObject(prevInputEl)) {
        prevInputEl.focus();
      }
      if ((_ref = e.which) === 37 || _ref === 38 || _ref === 39 || _ref === 40) {
        switch (e.which) {
          case 37:
            if (groupCaretPos === 0 && !$.isEmptyObject(prevInputEl)) {
              return prevInputEl.focus();
            }
            break;
          case 39:
            if (groupCaretPos === groupMaxLength && !$.isEmptyObject(nextInputEl)) {
              return nextInputEl.focus();
            }
            break;
          case 38:
            if (!$.isEmptyObject(groupEl.prev('input'))) {
              return prevInputEl.focus();
            }
            break;
          case 40:
            if (!$.isEmptyObject(groupEl.next('input'))) {
              return nextInputEl.focus();
            }
        }
      }
    };

    ExpirationInputView.prototype.getRawValue = function(fieldType) {
      return parseInt(this.el.find(".cc-exp-field-" + fieldType).val());
    };

    ExpirationInputView.prototype._onKeyUp = function(e) {
      var arrowKeys, dateObj, day, groupCaretPos, groupEl, groupMaxLength, groupValLength, month, nextInputEl, pattern, specialKeys, year, _ref, _ref1;
      e.stopPropagation();
      specialKeys = [8, 9, 16, 17, 18, 19, 20, 27, 33, 34, 35, 36, 37, 38, 39, 40, 45, 46, 91, 93, 144, 145, 224];
      arrowKeys = [37, 38, 39, 40];
      groupEl = $(e.currentTarget);
      groupMaxLength = parseInt(groupEl.attr('maxlength'));
      groupCaretPos = this._getFieldCaretPosition(groupEl);
      if (_ref = e.which, __indexOf.call(specialKeys, _ref) < 0) {
        groupValLength = groupEl.val().length;
        pattern = new RegExp('[^0-9]+', 'g');
        groupEl.val(groupEl.val().replace(pattern, ''));
        if (groupEl.val().length < groupValLength) {
          this._setFieldCaretPosition(groupEl, groupCaretPos - 1);
        } else {
          this._setFieldCaretPosition(groupEl, groupCaretPos);
        }
      }
      nextInputEl = groupEl.nextAll('input').first();
      if ((_ref1 = e.which, __indexOf.call(specialKeys, _ref1) < 0) && groupEl.val().length === groupMaxLength && !$.isEmptyObject(nextInputEl) && this._getFieldCaretPosition(groupEl) === groupMaxLength) {
        nextInputEl.focus();
      }
      day = this.getRawValue('d') || 1;
      month = this.getRawValue('m');
      year = this.getRawValue('y');
      if (month === 0 || year === 0) {
        this.date = null;
      } else {
        if (year < 2000) {
          year += 2000;
        }
        dateObj = new Date(year, month - 1, day);
        this.date = dateObj;
      }
      this.trigger("keyup", [this]);
      return false;
    };

    ExpirationInputView.prototype._inputGroupEls = function() {
      return this.el.find("input");
    };

    ExpirationInputView.prototype.show = function() {
      return this.el.show();
    };

    ExpirationInputView.prototype.hide = function() {
      return this.el.hide();
    };

    return ExpirationInputView;

  })();

  /*
  Skeuocard::TextInputView
  */


  Skeuocard.prototype.TextInputView = (function() {
    function TextInputView(opts) {
      var _this = this;
      this.el = $('<div>');
      this.inputEl = $("<input>").attr({
        type: 'text',
        placeholder: opts.placeholder,
        "class": opts["class"]
      });
      this.el.append(this.inputEl);
      this.el.addClass('cc-field');
      this.options = opts;
      this.el.delegate("input", "focus", function(e) {
        return _this.el.addClass('focus');
      });
      this.el.delegate("input", "blur", function(e) {
        return _this.el.removeClass('focus');
      });
      this.el.delegate("input", "keyup", function(e) {
        e.stopPropagation();
        return _this.trigger('keyup', [_this]);
      });
    }

    TextInputView.prototype.clear = function() {
      return this.inputEl.val("");
    };

    TextInputView.prototype.attr = function() {
      var args, _ref;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return (_ref = this.inputEl).attr.apply(_ref, args);
    };

    TextInputView.prototype.setValue = function(newValue) {
      return this.inputEl.val(newValue);
    };

    TextInputView.prototype.getValue = function() {
      return this.inputEl.val();
    };

    TextInputView.prototype.bind = function() {
      var args, _ref;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return (_ref = this.el).bind.apply(_ref, args);
    };

    TextInputView.prototype.trigger = function() {
      var args, _ref;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return (_ref = this.el).trigger.apply(_ref, args);
    };

    TextInputView.prototype.show = function() {
      return this.el.show();
    };

    TextInputView.prototype.hide = function() {
      return this.el.hide();
    };

    return TextInputView;

  })();

  /*
  Skeuocard::CardProduct
  */


  Skeuocard.prototype.CardProduct = (function() {
    CardProduct._registry = [];

    CardProduct.create = function(opts) {
      return this._registry.push(new Skeuocard.prototype.CardProduct(opts));
    };

    CardProduct.firstMatchingShortname = function(shortname) {
      var card, _i, _len, _ref;
      _ref = this._registry;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        card = _ref[_i];
        if (card.attrs.companyShortname === shortname) {
          return card;
        }
      }
      return null;
    };

    CardProduct.firstMatchingNumber = function(number) {
      var card, combinedOptions, variation, _i, _len, _ref;
      _ref = this._registry;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        card = _ref[_i];
        if (card.pattern.test(number)) {
          if ((variation = card.firstVariationMatchingNumber(number))) {
            combinedOptions = $.extend({}, card.attrs, variation);
            return new Skeuocard.prototype.CardProduct(combinedOptions);
          }
          return new Skeuocard.prototype.CardProduct(card.attrs);
        }
      }
      return null;
    };

    function CardProduct(attrs) {
      this.attrs = $.extend({}, attrs);
      this.pattern = this.attrs.pattern;
      this._variances = [];
      this.name = {
        isFilled: this._isCardNameFilled.bind(this),
        isValid: this._isCardNameValid.bind(this)
      };
      this.number = {
        isFilled: this._isCardNumberFilled.bind(this),
        isValid: this._isCardNumberValid.bind(this)
      };
      this.exp = {
        isFilled: this._isCardExpirationFilled.bind(this),
        isValid: this._isCardExpirationValid.bind(this)
      };
      this.cvc = {
        isFilled: this._isCardCVCFilled.bind(this),
        isValid: this._isCardCVCValid.bind(this)
      };
    }

    CardProduct.prototype.createVariation = function(attrs) {
      return this._variances.push(attrs);
    };

    CardProduct.prototype.firstVariationMatchingNumber = function(number) {
      var variance, _i, _len, _ref;
      _ref = this._variances;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        variance = _ref[_i];
        if (variance.pattern.test(number)) {
          return variance;
        }
      }
      return null;
    };

    CardProduct.prototype.fieldsForLayoutFace = function(faceName) {
      var face, fieldName, _ref, _results;
      _ref = this.attrs.layout;
      _results = [];
      for (fieldName in _ref) {
        face = _ref[fieldName];
        if (face === faceName) {
          _results.push(fieldName);
        }
      }
      return _results;
    };

    CardProduct.prototype._id = function() {
      var ident;
      ident = this.attrs.companyShortname;
      if (this.attrs.issuerShortname != null) {
        ident += this.attrs.issuerShortname;
      }
      return ident;
    };

    CardProduct.prototype.eql = function(otherCardProduct) {
      return (otherCardProduct != null ? otherCardProduct._id() : void 0) === this._id();
    };

    CardProduct.prototype._daysInMonth = function(m, y) {
      switch (m) {
        case 1:
          if ((y % 4 === 0 && y % 100) || y % 400 === 0) {
            return 29;
          } else {
            return 28;
          }
        case 3:
        case 5:
        case 8:
        case 10:
          return 30;
        default:
          return 31;
      }
    };

    CardProduct.prototype._isCardNumberFilled = function(number) {
      var _ref;
      if (this.attrs.cardNumberLength != null) {
        return (_ref = number.length, __indexOf.call(this.attrs.cardNumberLength, _ref) >= 0);
      }
    };

    CardProduct.prototype._isCardExpirationFilled = function(exp) {
      var currentDate, day, month, year;
      currentDate = Skeuocard.currentDate;
      if (!((exp != null) && (exp.getMonth != null) && (exp.getFullYear != null))) {
        return false;
      }
      day = exp.getDate();
      month = exp.getMonth();
      year = exp.getFullYear();
      return (day > 0 && day <= this._daysInMonth(month, year)) && (month >= 0 && month <= 11) && (year >= 1900 && year <= currentDate.getFullYear() + 10);
    };

    CardProduct.prototype._isCardCVCFilled = function(cvc) {
      return cvc.length === this.attrs.cvcLength;
    };

    CardProduct.prototype._isCardNameFilled = function(name) {
      return name.length > 0;
    };

    CardProduct.prototype._isCardNumberValid = function(number) {
      return /^\d+$/.test(number) && (this.attrs.validateLuhn === false || this._isValidLuhn(number)) && this._isCardNumberFilled(number);
    };

    CardProduct.prototype._isCardExpirationValid = function(exp) {
      var currentDate, day, isDateInFuture, month, year;
      if (!((exp != null) && (exp.getMonth != null) && (exp.getFullYear != null))) {
        return false;
      }
      currentDate = Skeuocard.currentDate;
      day = exp.getDate();
      month = exp.getMonth();
      year = exp.getFullYear();
      isDateInFuture = (year === currentDate.getFullYear() && month >= currentDate.getMonth()) || year > currentDate.getFullYear();
      return isDateInFuture && this._isCardExpirationFilled(exp);
    };

    CardProduct.prototype._isCardCVCValid = function(cvc) {
      return this._isCardCVCFilled(cvc);
    };

    CardProduct.prototype._isCardNameValid = function(name) {
      return this._isCardNameFilled(name);
    };

    CardProduct.prototype._isValidLuhn = function(number) {
      var alt, i, num, sum, _i, _ref;
      sum = 0;
      alt = false;
      for (i = _i = _ref = number.length - 1; _i >= 0; i = _i += -1) {
        num = parseInt(number.charAt(i), 10);
        if (isNaN(num)) {
          return false;
        }
        if (alt) {
          num *= 2;
          if (num > 9) {
            num = (num % 10) + 1;
          }
        }
        alt = !alt;
        sum += num;
      }
      return sum % 10 === 0;
    };

    return CardProduct;

  })();

  /*
  # Seed CardProducts.
  */


  Skeuocard.prototype.CardProduct.create({
    pattern: /^(36|38|30[0-5])/,
    companyName: "Diners Club",
    companyShortname: "dinersclubintl",
    cardNumberGrouping: [4, 6, 4],
    cardNumberLength: [14],
    expirationFormat: "MM/YY",
    cvcLength: 3,
    validateLuhn: true,
    layout: {
      number: 'front',
      exp: 'front',
      name: 'front',
      cvc: 'back'
    }
  });

  Skeuocard.prototype.CardProduct.create({
    pattern: /^35/,
    companyName: "JCB",
    companyShortname: "jcb",
    cardNumberGrouping: [4, 4, 4, 4],
    cardNumberLength: [16],
    expirationFormat: "MM/'YY",
    cvcLength: 3,
    validateLuhn: true,
    layout: {
      number: 'front',
      exp: 'front',
      name: 'front',
      cvc: 'back'
    }
  });

  Skeuocard.prototype.CardProduct.create({
    pattern: /^3[47]/,
    companyName: "American Express",
    companyShortname: "amex",
    cardNumberGrouping: [4, 6, 5],
    cardNumberLength: [15],
    expirationFormat: "MM/YY",
    cvcLength: 4,
    validateLuhn: true,
    layout: {
      number: 'front',
      exp: 'front',
      name: 'front',
      cvc: 'front'
    }
  });

  Skeuocard.prototype.CardProduct.create({
    pattern: /^(6706|6771|6709)/,
    companyName: "Laser Card Services Ltd.",
    companyShortname: "laser",
    cardNumberGrouping: [4, 4, 4, 4],
    cardNumberLength: [16, 17, 18, 19],
    expirationFormat: "MM/YY",
    validateLuhn: true,
    cvcLength: 3,
    layout: {
      number: 'front',
      exp: 'front',
      name: 'front',
      cvc: 'back'
    }
  });

  Skeuocard.prototype.CardProduct.create({
    pattern: /^4/,
    companyName: "Visa",
    companyShortname: "visa",
    cardNumberGrouping: [4, 4, 4, 4],
    cardNumberLength: [13, 14, 15, 16],
    expirationFormat: "MM/YY",
    validateLuhn: true,
    cvcLength: 3,
    layout: {
      number: 'front',
      exp: 'front',
      name: 'front',
      cvc: 'back'
    }
  });

  Skeuocard.prototype.CardProduct.create({
    pattern: /^(62|88)/,
    companyName: "China UnionPay",
    companyShortname: "unionpay",
    cardNumberGrouping: [19],
    cardNumberLength: [16, 17, 18, 19],
    expirationFormat: "MM/YY",
    validateLuhn: false,
    cvcLength: 3,
    layout: {
      number: 'front',
      exp: 'front',
      name: 'front',
      cvc: 'back'
    }
  });

  Skeuocard.prototype.CardProduct.create({
    pattern: /^5[1-5]/,
    companyName: "Mastercard",
    companyShortname: "mastercard",
    cardNumberGrouping: [4, 4, 4, 4],
    cardNumberLength: [16],
    expirationFormat: "MM/YY",
    validateLuhn: true,
    cvcLength: 3,
    layout: {
      number: 'front',
      exp: 'front',
      name: 'front',
      cvc: 'back'
    }
  });

  Skeuocard.prototype.CardProduct.create({
    pattern: /^(5018|5020|5038|6304|6759|676[1-3])/,
    companyName: "Maestro (MasterCard)",
    companyShortname: "maestro",
    cardNumberGrouping: [4, 4, 4, 4],
    cardNumberLength: [12, 13, 14, 15, 16, 17, 18, 19],
    expirationFormat: "MM/YY",
    validateLuhn: true,
    cvcLength: 3,
    layout: {
      number: 'front',
      exp: 'front',
      name: 'front',
      cvc: 'back'
    }
  });

  Skeuocard.prototype.CardProduct.create({
    pattern: /^(6011|65|64[4-9]|622)/,
    companyName: "Discover",
    companyShortname: "discover",
    cardNumberGrouping: [4, 4, 4, 4],
    cardNumberLength: [16],
    expirationFormat: "MM/YY",
    validateLuhn: true,
    cvcLength: 3,
    layout: {
      number: 'front',
      exp: 'front',
      name: 'front',
      cvc: 'back'
    }
  });

  visaProduct = Skeuocard.prototype.CardProduct.firstMatchingShortname('visa');

  visaProduct.createVariation({
    pattern: /^414720/,
    issuingAuthority: "Chase",
    issuerName: "Chase Sapphire Card",
    issuerShortname: "chase-sapphire",
    layout: {
      name: 'front',
      number: 'front',
      exp: 'front',
      cvc: 'front'
    }
  });

}).call(this);
