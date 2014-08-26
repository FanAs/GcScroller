Google-Closure-NanoScroller
===========================

NanoScroller without using jquery, works fine with google closure compiler, writed in CoffeeScript.

Original version by http://jamesflorentino.github.io/nanoScrollerJS/

This version by Artyom Suchkov (fanasew@gmail.com), Wikidi.

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
