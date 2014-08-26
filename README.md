Google-Closure-NanoScroller
===========================

NanoScroller without using jquery, works fine with google closure compiler, writed in CoffeeScript.

Original version by http://jamesflorentino.github.io/nanoScrollerJS/

This version by Artyom Suchkov (fanasew@gmail.com), Wikidi.

Scroller.css and NanoScroll.js are automatically generated from less and coffee, so they can be really dirty

Style your page with scroller.css `<link rel="stylesheet" type="text/css" href="scroller.css">`

Import class with `goog.require 'NanoScroll'`

Wrap your content with `NanoScroll.wrap element, options` or `NanoScroll.wrap element, null`

Or, if you have element structure like
```
<div id="about" class="nano">
    <div class="nano-content"> ... content here ...  </div>
</div>
```
You can use `new NanoScroll element, options`
or `new NanoScroll element, null`
