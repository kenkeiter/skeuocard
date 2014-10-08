# Skeuocard (v1.0.3)

_Skeuocard_ is a re-think of the way we handle credit card input on the web. It progressively enhances credit card input forms so that the card inputs become skeuomorphic, facilitating accurate and fast card entry, and removing barriers to purchase.

You can try it out at [http://kenkeiter.com/skeuocard](http://kenkeiter.com/skeuocard).

For more on the theory behind Skeuocard, check out the blog post that started it all: [_"Redesigning Credit Card Inputs"_](http://kenkeiter.com/2013/07/21/redesigning-credit-card-inputs/) by [me (Ken Keiter)](http://kenkeiter.com/).

![Skeuocard at its finest.](https://raw.github.com/kenkeiter/skeuocard/master/screenshot.png)

## Usage

Skeuocard takes a standard credit card input form and partially transforms its DOM, removing non-essential elements, while leaving the underlying inputs alone. In order to use Skeuocard in your checkout page, you'll need to do one of two things.

### Bower

If you have [Bower](http://bower.io) then you can simply:

```bash
$ bower install skeuocard
```

### Manually

Or you can link the necessary style sheets and scripts, and make sure any asset dependencies are at the right paths.

```html
<head>
  <!-- ... your CSS includes ... -->
  <link rel="stylesheet" href="styles/skeuocard.reset.css" />
  <link rel="stylesheet" href="styles/skeuocard.css" />
  <link rel="stylesheet" href="styles/demo.css">
  <script src="javascripts/vendor/cssua.min.js"></script>
  <!-- ... -->
</head>
```

Make sure your credit card inputs are within their own containing element (most likely a `<div>`). In the example below, the `name` attribute of the inputs is significant because Skeuocard needs to determine which inputs should remain intact and be used to store the underlying card values.

Side note: If you'd like to use different input `name`s or selectors, you can specify those at instantiation. See the "Changing Underlying Value Selectors" section, below.

```html
<div class="credit-card-input no-js" id="skeuocard">
  <p class="no-support-warning">
    Either you have Javascript disabled, or you're using an unsupported browser, amigo! That's why you're seeing this old-school credit card input form instead of a fancy new Skeuocard. On the other hand, at least you know it gracefully degrades...
  </p>
  <label for="cc_type">Card Type</label>
  <select name="cc_type">
    <option value="">...</option>
    <option value="visa">Visa</option>
    <option value="discover">Discover</option>
    <option value="mastercard">MasterCard</option>
    <option value="maestro">Maestro</option>
    <option value="jcb">JCB</option>
    <option value="unionpay">China UnionPay</option>
    <option value="amex">American Express</option>
    <option value="dinersclubintl">Diners Club</option>
  </select>
  <label for="cc_number">Card Number</label>
  <input type="text" name="cc_number" id="cc_number" placeholder="XXXX XXXX XXXX XXXX" maxlength="19" size="19">
  <label for="cc_exp_month">Expiration Month</label>
  <input type="text" name="cc_exp_month" id="cc_exp_month" placeholder="00">
  <label for="cc_exp_year">Expiration Year</label>
  <input type="text" name="cc_exp_year" id="cc_exp_year" placeholder="00">
  <label for="cc_name">Cardholder's Name</label>
  <input type="text" name="cc_name" id="cc_name" placeholder="John Doe">
  <label for="cc_cvc">Card Validation Code</label>
  <input type="text" name="cc_cvc" id="cc_cvc" placeholder="123" maxlength="3" size="3">
</div>
```

When the Skeuocard is instantiated for the containing element above, all children of the containing element will be removed except for the underlying form fields.

Causing a Skeuocard to appear instead is as simple as:

```javascript
$(document).ready(function(){
  card = new Skeuocard($("#skeuocard"));
});
```

That's it! You've got a skeuomorphic credit card input, instead of your normal, confusing form.

### Beyond the Basics

#### Enabling Debugging Output

Skeuocard occasionally provides useful debugging output. By instantiating Skeuocard with the `debug` option set to true, those messages will be sent to `console.log` and prefixed with `[skeuocard]`.

```javascript
new Skeuocard($("#skeuocard"), {
  debug: true
});
```

#### Turn off Focusing the Input by Default

By default, when Skeuocard is initialized, the input field will be focused.  If you don't want this to happen (for example, if the skeuocard element is positioned below the fold and you want to prevent the browser from scrolling there), then pass `dontFocus: true` as an initialization option.

```javascript
new Skeuocard($("#skeuocard"), {
  dontFocus: true
});

```

#### Providing Initial Values

Sometimes you'll need to pre-fill credit card information when you load the page. To do so, you can simply provide a `value` attribute for your form fields (or `<option selected ...>`, in the case of a `<select>`), and Skeuocard will pick up your initial values when instantiated.

Alternately, you can instantiate your Skeuocard instance with an `initialValues` object, which will override any existing values provided in the form, like so:

```javascript
new Skeuocard($("#skeuocard"), {
  initialValues: {
    number: "4111111111111111",
    expMonth: "1",
    expYear: "2016",
    name: "James Doe",
    cvc: "123"
  }
});
```

#### Changing Values on the Fly

You can also change Skeuocard values manually by changing the underlying form element's value, and triggering a `change` event.

```javascript
$('[name="cc_number"]').val('4111111111111111').trigger('change')
```

#### Changing Placeholder Strings

You can change the character which Skeuocard uses as a placeholder for segmented card inputs, as well as the placeholder on the generic card view (visible when a card type has not been determined) by providing either of the following options at instantiation: `cardNumberPlaceholderChar` and `genericPlaceholder`.

`cardNumberPlaceholderChar` is used for filling only segmented inputs (i.e. "[XXXX] [XXXX] [XXXX] [XXXX]") and is by default set to `X`. The `genericPlaceholder` value is used when the card type has not yet been determined, and is by default set to `XXXX XXXX XXXX XXXX`.

```javascript
new Skeuocard($("#skeuocard"), {
  cardNumberPlaceholderChar: '*',
  genericPlaceholder: '**** **** **** ****'
});
```

#### Changing Underlying Value Selectors

When a Skeuocard is instantiated, it attaches itself to a container element and removes any unneeded children, before adding its own; *however,* Skeuocard stores its values in pre-existing input fields, which aren't selected for removal.

By default, Skeuocard sets the following default selectors to match the  underlying form fields within the container element, and use them to store values:

* `typeInputSelector: [name="cc_type"]`
* `numberInputSelector: [name="cc_number"]`
* `expMonthInputSelector: [name="cc_exp_month"]`
* `expYearInputSelector: [name="cc_exp_year"]`
* `nameInputSelector: [name="cc_name"]`
* `cvcInputSelector: [name="cc_cvc"]`

Providing any of those options with different values at instantiation will cause Skeuocard to use your supplied selector, instead! For example, if our credit card number field had a `name` of `credit_card_number` (instead of the default `cc_number`), we could change it at instantiation like so:

```javascript
new Skeuocard($("#skeuocard"), {
  numberInputSelector: '[name="credit_card_number"]'
});
```

#### Using the Server's Current Date

If you're smart, you probably won't want to use the client's local `Date` to validate against when checking expiration. You can specify a `Date` to check against at instantiation by setting `currentDate` on the Skeuocard class like so:

```javascript
Skeuocard.currentDate = new Date(year, month, day);
```

Note that month is an integer from 0 - 11.

By default, Skeuocard will automatically use the client's local Date.

#### Specifying Accepted Card Products

Only accept Visa and AmEx? No worries. Skeuocard has you covered. You can specify accepted card types with an options argument, or in the underlying form itself.

To limit your accepted card products, simply add or remove `<option>`s from your type `<select>` where either the `value` attribute matches the shortname of the product (see the example below), or the `data-sc-type` attribute is set to the shortname of the product (if your `value` needs to be different for legacy purposes).

```html
<select name="cc_type">
  <option value="">...</option>
  <option value="visa">Visa</option>
  <option value="mastercard">MasterCard</option>
  <option value="maestro">Maestro</option>
  <option value="amex">American Express</option>
  <option value="diners" data-sc-type="dinersclubintl">Diners Club</option>
</select>
```

You can also optionally override this list by providing an array of accepted card product shortnames at instantiation, like so:

```javascript
new Skeuocard($("#skeuocard"), {
  acceptedCardProducts: ['visa', 'amex']
});
```

#### jQuery's noConflict Mode

If you are using jQuery's `noConflict` mode, you'll need to instantiate your Skeuocard instance slightly differently than above:

```javascript
jQuery(document).ready(function(){
  card = new Skeuocard(jQuery("#skeuocard"));
});
```

#### Progressive Enhancement

Progressive enhancement was really important to me when creating this plugin. I wanted to make sure that a potential purchase opportunity would never be denied by a failure in Skeuocard, so I chose to take an approach which would leave the users with a functional, styled form in the event that Skeuocard fails.

You can style your un-enhanced form elements in whichever way you wish. When Skeuocard is instantiated, it will automatically add both the `skeuocard` and `js` classes to the container, which will match the selectors necessary to style the card input properly.

#### Checking Validity

At some point or another, you're going to want your user to submit your purchase form -- so how do you determine if the credit card input they provided is valid? While there are several ways of doing this, there's one recommended way:

```javascript
card.isValid() // => Boolean
```

#### Showing Errors at Instantiation

Sometimes you'll want to indicate a problem with the card to the user at instantiation -- for example, if the card number (after having been submitted to your payment processor) is determined to be incorrect. You can do this one of two ways: by adding the `invalid` class to your underlying `number` form field at instantiation, or by passing an initial `validationState` argument with your options.

Applying the `invalid` class to the invalid field:

```html
...
<input type="text" name="cc_number" id="cc_number" placeholder="XXXX XXXX XXXX XXXX" maxlength="19" size="19" class="invalid">
...
```

Providing a list of invalid fields at instantiation:

```javascript
new Skeuocard($("#skeuocard"), {
  validationState: {
    number: false,
    exp: true,
    name: true,
    cvc: true
  }
});
```

Note that, if the CVC is on the back of the card for the matching card product, the card will automatically flip to show the invalid field.

#### Registering Custom Card Layouts

You may wish to add a custom layout to support a card (BIN) specific to your locale, or for promotional reasons. You can do so easily.

You'll need to create a set of transparent PNG file containing any elements you wish to appear on the card faces. For an example, see any of the images in the `images/products/` folder. If you have Adobe Fireworks installed, the editable images are also included in `images/src/`.

For an example of how to style a card, see `styles/_cards.scss`.

Once you have created your images and the appropriate CSS styling, you will need to create a new CardProduct or variation of an existing card product. Lets say that we're matching a new type of gift card with a BIN (9123) that doesn't match any of the pre-defined credit card providers:

```javascript
// Create a new CardProduct instance, and register it with Skeuocard.
Skeuocard.CardProduct.create({
  pattern: /^9123/,                     // match all cards starting with 9123
  companyName: "Fancy Gift Card Inc.",
  companyShortname: "fancycard",        // this will be the card type
  cardNumberGrouping: [4,4,4,4],        // how the number input should group
  cardNumberLength: [14],               // array of valid card number lengths
  expirationFormat: "MM/YY",            // format of the date field
  cvcLength: 3,                         // the length of the CVC
  validateLuhn: true,                   // validate using the Luhn algorithm?
  layout: {
    number: 'front',
    exp: 'front',
    name: 'front',
    cvc: 'back'
  }
});
```

Now, lets say that we'd like to recognize and apply a layout for a Visa card with a specific BIN. First, we'd select the matching card product, and then add a variant, which will extend it:

```javascript
// find the existing Visa product
var visaProduct = Skeuocard.CardProduct.firstMatchingShortname('visa');
// register a new variation of the Visa product
visaProduct.createVariation({
  pattern: /^414720/,
  issuingAuthority: "Chase",
  issuerName: "Chase Sapphire Card",
  issuerShortname: "chase-sapphire",
  layout:
    number: 'front',
    exp: 'front',
    name: 'front',
    cvc: 'front'
});
```

#### Design Customization

You might not like the way Skeuocard looks. That's easy to fix; CSS is used to style and position most elements in Skeuocard, with the exception of the card faces.

## Browser Compatibility

Skeuocard aims to gain better compatibility with older browsers, but for the time being, it looks good and works well in the following browsers:

* Chrome (Mac, Win)
* Safari (Mac)
* Firefox > 18 (Mac, Win)
* Mobile Safari (iOS)
* Mobile Chrome (iOS/Android)
* IE 10+ (Win)

It's recommended that you selectively disable Skeuocard based upon browser version, to retain maximum compatibility. If you have an odd or obscure browser, and wish to submit a patch, that's always appreciated!

## Integration

* The [skeuocard-rails](https://github.com/rougecardinal/skeuocard-rails) gem provides integration with the Rails asset pipeline.

## Development

Contributing to Skeuocard is pretty simple. Simply fork the project, make your changes in a branch, and submit a pull request.

I'll do my best to keep an eye out for pull requests and triage any submitted issues. Please note that you MUST make changes on the src (.coffee, .scss) files, compile the changes with Grunt, and include any compiled changes in any pull requests you submit.

#### Getting Up and Running

Ensure that you have the following tools installed before continuing:
  
  * [NodeJS/NPM](http://nodejs.org/download/)
  * [SASS](http://sass-lang.com/)
  * [CoffeeScript](http://coffeescript.org/)

To begin working on Skeuocard, fork the repository to your Github account, and clone it to your machine. 

Once you have `cd`ed to your cloned `skeuocard` repository, you'll need to install the required Node packages:

    $ npm install

Once that's completed, simply run:

    $ grunt

Upon starting `grunt`, the following things will happen:

* a development server will be started on `0.0.0.0:8000`;
* `index.html` will be opened automatically in your browser;
* grunt will begin watching for changes to source files, and setup live-reload
* source files will be recompiled automatically when changes are made.

Simply make your changes to the necessary source files (typically under the `src` directory of each directory in the project), commit the changes (including the compiled changes), and submit a pull request! 

#### New Card Layouts & Graphics

I've done my best to include layouts for all major card products (Visa, MasterCard, Amex, etc.) in the project. It is entirely possible that I've missed some products, and that the addition of a product is justified; however, I'm not accepting issuer-specific layouts (for things like Visa-branded products) at this time. There are literally thousands of them, and doing so could be seen as discriminatory. 

For the time being, the only reason I'll make an exception is for cards like the Chase Sapphire, which is a Visa product, but has been granted an allowance by Visa to drastically alter the appearance and field layout of the card.

All of that said, I'm working on a standardized method of distributing issuer-specific layouts for users who wish to cater to popular cards in their locale, etc.

## Licensing

Skeuocard is licensed under the [MIT license](http://opensource.org/licenses/MIT). Share and enjoy :)

* The [*OCR-A font*](http://ansuz.sooke.bc.ca/page/fonts#ocra) included with this project was converted and released for free commercial and non-commercial use by [Matthew Skala](http://ansuz.sooke.bc.ca/page/about).
* [*CSS User Agent*](http://cssuseragent.org/) by [Stephen M. McKamey](http://stephen.mckamey.com/) is included under its [MIT license](https://bitbucket.org/mckamey/cssuseragent/raw/tip/LICENSE.txt).
* [*jQuery*](http://jquery.com/) 2.0.3 is included under its [MIT license](https://github.com/jquery/jquery/blob/master/MIT-LICENSE.txt).

The trademarks and branding assets of the credit card products used in this project have not been used with express consent of their owners; this project is intended for use only by those whom have the proper authorization to do so. The trademarks and branding included in this project are property of their respective owners.

Any complaints should be sent to me at: ken+skeuocard-complaints@kenkeiter.com and I will address them promptly.

### Special Thanks

I owe a special thanks to my guinea-pig users, and to the designers I met in coffee shops who took the time to critique this work.
