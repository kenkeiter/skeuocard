# Skeuocard

_Skeuocard_ is a re-think of the way we handle credit card input on the web. It progressively enhances credit card input forms so that the card inputs become skeuomorphic, facilitating accurate and fast card entry, and removing barriers to purchase.

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

Or you can link the necessary style sheets and scripts, and make sure any asset dependenceis are at the right paths.

```html
<head>
  <!-- ... your CSS includes ... -->
  <link rel="stylesheet" href="styles/skeuocard.reset.css" />
  <link rel="stylesheet" href="styles/skeuocard.css" />
  <script src="/javascripts/vendor/css_browser_selector.js"></script>
  <script src="/javascripts/skeuocard.js"></script>
  <!-- ... -->
</head>
```

Make sure your credit card inputs are within their own containing element (most likely a `<div>`). In the example below, the `name` attribute of the inputs is significant because Skeuocard needs to determine which inputs should remain intact and be used to store the underlying card values.

Side note: If you'd like to use different input `name`s or selectors, you can specify those at instantiation.

```html
<div class="credit-card-input no-js" id="skeuocard">
  <label for="cc_type">Card Type</label>
  <select name="cc_type">
    <option value="">...</option>
    <option value="visa">Visa</option>
    <option value="discover">Discover</option>
    <option value="mastercard">MasterCard</option>
    <option value="amex">American Express</option>
    <option value="dinersclubintl">Diners Club</option>
  </select>
  <label for="cc_number">Card Number</label>
  <input type="text" name="cc_number" placeholder="XXXX XXXX XXXX XXXX" maxlength="19" size="19">
  <label for="cc_exp">Expiration Date (mm/yy)</label>
  <input type="text" name="cc_exp" placeholder="00/00">
  <label for="cc_name">Cardholder's Name</label>
  <input type="text" name="cc_name" placeholder="John Doe">
  <label for="cc_cvc">Card Validation Code</label>
  <input type="text" name="cc_cvc" placeholder="XXX" maxlength="3" size="3">
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

#### Providing Initial Values

Sometimes you'll need to pre-fill credit card information when you load the page. To do so, you can simply provide a `value` attribute for your form fields (or `<option selected ...>`, in the case of a `<select>`), and Skeuocard will pick up your initial values when instantiated.

Alternately, you can instantiate your Skeuocard instance with an `initialValues` object, which will override any existing values provided in the form, like so:

```javascript
new Skeuocard($("#skeuocard"), {
  initialValues: {
    number: "4111111111111111",
    exp: "01-03-2016",
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
* `expInputSelector: [name="cc_exp"]`
* `nameInputSelector: [name="cc_name"]`
* `cvcInputSelector: [name="cc_cvc"]`

Providing any of those options with different values at instantiation will cause Skeuocard to use your supplied selector, instead! For example, if our credit card number field had a `name` of `credit_card_number` (instead of the default `cc_number`), we could change it at instantiation like so:

```javascript
new Skeuocard($("#skeuocard"), {
  numberInputSelector: '[name="credit_card_number"]'
});
```

#### Using the Server's Current Date

If you're smart, you probably won't want to use the client's local `Date` to validate against when checking expiration. You can specify a `Date` to check against at instantiation by providing the `currentDate` option, like so:

```javascript
new Skeuocard($("#skeuocard"), {
  currentDate: new Date(day, month, year)
});
```

#### Specifying Accepted Card Products

Only accept Visa and AmEx? No worries. Skeuocard has you covered. You can specify accepted card types with an options argument, or in the underlying form itself.

To limit your accepted card products, simply add or remove `<option>`s from your type `<select>` where either the `value` attribute matches the shortname of the product (see the example below), or the `data-card-product-shortname` attribute is set to the shortname of the product (if your value needs to be different for legacy purposes).

```html
<select class="field cc-type" name="cc_type">
  <option value="">...</option>
  <option value="visa">Visa</option>
  <option value="discover">Discover</option>
  <option value="mastercard">MasterCard</option>
  <option value="american_express" data-card-product-shortname="amex">American Express</option>
</select>
```

You can also optionally override this list by providing an array of accepted card product shortnames at instantiation, like so:

```javascript
new Skeuocard($("#skeuocard"), {
  acceptedCardProducts: ['visa', 'amex']
});
```

#### Progressive Enhancement

Progressive enhancement was really important to me when creating this plugin. I wanted to make sure that a potential purchase opportunity would never be denied by a failure in Skeuocard, so I chose to take an approach which would leave the users with a functional, styled form in the event that Skeuocard fails.

You can style your un-enhanced form elements in whichever way you wish. When Skeuocard is instantiated, it will automatically add both the `.skeuocard` and `.js` classes to the container, which will match the selectors necessary to style the card input properly.

#### Checking Validity

At some point or another, you're going to want your user to submit your purchase form -- so how do you determine if the credit card input they provided is valid? There are two ways of doing this with Skeuocard: first off, you can check to see if the card has the `.invalid` class applied to it, like so:

```javascript
$('#myform').on('submit', function(){
  if($('#skeuocard').has('.invalid')){
    return false; // not a valid card; don't allow submission
  }else{
    return true; // looks good!
  }
})
```

Alternately, you can bind an event handler to the container element, and watch for `validationStateDidChange.skeuocard` events, like so:

```javascript
$('#skeuocard').bind('validationStateDidChange.skeuocard', function(evt, card, validationState){
  console.log("Validation state just changed to:", validationState.number && validationState.exp && validationState.name && validationState.cvc)
});
```

#### Specifying Validity at Instantiation

Sometimes you'll want to indicate a problem with the card to the user at instantiation -- for example, if the card number (after having been submitted to your payment processor) is determined to be incorrect. You can do this one of two ways: by adding the `invalid` class to your underlying `number` form field at instantiation, or by passing an initial `validationState` argument with your options.

Applying the `invalid` class to the invalid field:

```html
<input class="cc-cvc invalid" type="text" name="cc_cvc" placeholder="XXX" maxlength="3" size="3">
```

Providing a list of invalid fields at instantiation:

```javascript
new Skeuocard($("#skeuocard"), {
  validationState: {
    number: true,
    exp: true,
    name: true,
    cvc: false
  }
});
```

Note that, if the CVC is on the back of the card for the matching card product, the card will automatically flip to show the invalid field.

#### Registering Custom Card Layouts

You may wish to add a custom layout to support a card (BIN) specific to your locale, or for promotional reasons. You can do so easily.

You'll need to create a set of transparent PNG file containing any elements you wish to appear on the card faces. For an example, see any of the images in the `images/products/` folder. If you have Adobe Fireworks installed, the editable images are also included in `images/src/`.

Skeuocard accepts an `issuers` option upon instantion. The `issuers` option should be an object whose keys are regexes which match the BIN, and whose value is an object describing the issuer and layout features. When the issuer's regex matches the entered card number, a css class is added to the container in the format `issuer-<issuerShortname>`, which you will use to match and style the container to match your issuer.

```javascript
var myIssuers = {}
myIssuers[/^414720/] = {
  issuingAuthority: "Chase",
  issuerName: "Chase Sapphire Card",
  issuerShortname: "chase-sapphire",
  layout: {
    number: 'front',
    exp: 'back',
    name: 'front',
    cvc: 'back'
  }
}

new Skeuocard($("#skeuocard"), {
  issuers: myIssuers
});
```

For an example of how to style a card, see `styles/_cards.scss`.

#### Design Customization

You might not like the way Skeuocard looks. That's easy to fix; CSS is used to style and position most elements in Skeuocard, with the exception of the card faces.

## Browser Compatibility

Skeuocard aims to gain better compatibility with older browsers, but for the time being, it looks good and works well in the following browsers:

* Chrome (Mac, Win)
* Safari (Mac)
* Firefox > 18 (Mac, Win)
* Mobile Safari (iOS)
* IE 10+ (Win)

It's recommended that you selectively disable Skeuocard based upon browser version, to retain maximum compatibility. If you have an odd or obscure browser, and wish to submit a patch, that's always appreciated!

## Integration

* The [skeuocard-rails](https://github.com/rougecardinal/skeuocard-rails) gem provides integration with the Rails asset pipeline.

## Development

Contributing to Skeuocard is pretty simple. Simply fork the project, make your changes in a branch, and submit a pull request.

I'll do my best to keep an eye out for pull requests and triage any submitted issues.

#### Compiling SCSS and CoffeeScript

We use SCSS and CoffeeScript to keep things short and easy. You should include compiled CSS and Javascript files in any pull requests you send. If you have [foreman](https://github.com/ddollar/foreman), [sass](http://sass-lang.com/), and [CoffeeScript](http://coffeescript.org/) installed, you can simply run

    foreman start

from within your Skeuocard working directory, and it'll watch for changes and automatically re-compile the files.

#### New Card Layouts & Graphics

I've done my best to include layouts for all major card products (Visa, MasterCard, Amex, etc.) in the project. It is entirely possible that I've missed some products, and that the addition of a product is justified; however, I'm not accepting issuer-specific layouts (for things like Visa-branded products) at this time. There are literally thousands of them, and doing so could be seen as discriminatory. 

For the time being, the only reason I'll make an exception is for cards like the Chase Sapphire, which is a Visa product, but has been granted an allowance by Visa to drastically alter the appearance and field layout of the card.

All of that said, I'm working on a standardized method of distributing issuer-specific layouts for users who wish to cater to popular cards in their locale, etc.

## Licensing

Skeuocard is licensed under the [MIT license](http://opensource.org/licenses/MIT). Share and enjoy :)

* The [*OCR-A font*](http://ansuz.sooke.bc.ca/page/fonts#ocra) included with this project was converted and released for free commercial and non-commercial use by [Matthew Skala](http://ansuz.sooke.bc.ca/page/about).
* *css_browser_selector.js* by [Rafael Lima](http://rafael.adm.br) is included under a [Creative Commons license](http://creativecommons.org/licenses/by/2.5/).
* [*jQuery*](http://jquery.com/) 2.0.3 is included under its [MIT license](https://github.com/jquery/jquery/blob/master/MIT-LICENSE.txt).

The trademarks and branding assets of the credit card products used in this project have not been used with express consent of their owners; this project is intended for use only by those whom have the proper authorization to do so. The trademarks and branding included in this project are property of their respective owners.

Any complaints should be sent to me at: ken+skeuocard-complaints@kenkeiter.com and I will address them promptly.

### Special Thanks

I owe a special thanks to my guinea-pig users, and to the designers I met in coffee shops who took the time to critique this work.
