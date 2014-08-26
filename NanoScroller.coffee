`"use strict"`
goog.provide 'NanoScroll'

goog.require 'goog.dom'
goog.require 'goog.style'
goog.require 'goog.events'

# Default settings
defaults =
	'paneClass': 'nano-pane'
	'sliderClass': 'nano-slider'
	'contentClass': 'nano-content'
	'iOSNativeScrolling': false
	'preventPageScrolling': false
	'disableResize': false
	'alwaysVisible': false
	'flashDelay': 1500
	'sliderMinHeight': 50
	'sliderMaxHeight': null
	'documentContext': null
	'windowContext': null

# Constants
SCROLLBAR = 'scrollbar'
SCROLL = 'scroll'
MOUSEDOWN = 'mousedown'
MOUSEENTER = 'mouseenter'
MOUSEMOVE = 'mousemove'
MOUSEWHEEL = 'mousewheel'
MOUSEUP = 'mouseup'
RESIZE = 'resize'
DRAG = 'drag'
ENTER = 'enter'
UP = 'up'
PANEDOWN = 'panedown'
DOMSCROLL  = 'DOMMouseScroll'
DOWN = 'down'
WHEEL = 'wheel'
KEYDOWN    = 'keydown'
KEYUP = 'keyup'
TOUCHMOVE = 'touchmove'
BROWSER_IS_IE7 = navigator.appName is 'Microsoft Internet Explorer' and (/msie 7./i).test(navigator.appVersion) and window.ActiveXObject
BROWSER_SCROLLBAR_WIDTH = null


# this transform stuff is from iScroll.
# all credit goes to @cubiq
_elementStyle = (goog.dom.createElement 'div').style

##test it
_vendor = do ->
	vendors = ['t', 'webkitT', 'MozT', 'msT', 'OT']
	for vendor, i in vendors
		transform = vendors[i] + 'ransform' #-
		if transform of _elementStyle
			return vendors[i].substr(0, vendors[i].length - 1)
	return false

_prefixStyle = (style) ->
	return false if _vendor is false
	return style if _vendor is ''
	return _vendor + style.charAt(0).toUpperCase() + style.substr(1)

transform = _prefixStyle('transform')

hasTransform = transform isnt false

###*
	Returns browser's native scrollbar width
###
getBrowserScrollbarWidth = ->
	outer = goog.dom.createElement 'div'
	goog.style.setStyle outer, 'position', 'absolute'
	goog.style.setStyle outer, 'width', '100px'
	goog.style.setStyle outer, 'height', '100px'
	goog.style.setStyle outer, 'overflow', SCROLL
	goog.style.setStyle outer, 'top', '-9999px'

	goog.dom.appendChild document.body, outer
	scrollbarWidth = outer.offsetWidth - outer.clientWidth
	goog.dom.removeNode outer
	scrollbarWidth

isFFWithBuggyScrollbar = ->
	ua = window.navigator.userAgent
	isOSXFF = /(?=.+Mac OS X)(?=.+Firefox)/.test(ua)
	return false if not isOSXFF
	version = /Firefox\/\d{2}\./.exec(ua)
	version = version[0].replace(/\D+/g, '') if version
	return isOSXFF and +version > 23


#Util functions that are missed in pure js starts here

###*
###
hackPercentMargin = (elem, marginValue) ->
	return marginValue if marginValue.indexOf("%") is -1
	originalWidth = elem.style.width

	# get measure by setting it on elem's width
	elem.style.width = marginValue
	ret = goog.style.getStyle elem, 'width'
	elem.style.width = originalWidth
	ret

###*
###
getHeight = (elem, isOuter) ->
	# Start with offset property
	val = elem.offsetHeight
	paddingA = parseFloat(goog.style.getStyle(elem, "padding-top")) or 0
	paddingB = parseFloat(goog.style.getStyle(elem, "padding-bottom")) or 0
	borderA = parseFloat(goog.style.getStyle(elem, "border-top-width")) or 0
	borderB = parseFloat(goog.style.getStyle(elem, "border-bottom-width")) or 0
	computedMarginA = goog.style.getStyle(elem, "margin-top")
	computedMarginB = goog.style.getStyle(elem, "margin-bottom")

	unless computedMarginA != '1%'
		computedMarginA = hackPercentMargin(elem, computedMarginA)
		computedMarginB = hackPercentMargin(elem, computedMarginB)
	marginA = parseFloat(computedMarginA) or 0
	marginB = parseFloat(computedMarginB) or 0
	if val > 0
		if isOuter
			# outerWidth, outerHeight, add margin
			val += marginA + marginB
		else
			# like getting width() or height(), no padding or border
			val -= paddingA + paddingB + borderA + borderB
	else
		# Fall back to computed then uncomputed css if necessary
		val = goog.style.getStyle(elem, 'height')
		val = goog.style.getStyle(elem, 'height') or 0  if val < 0 or val is null

		# Normalize "", auto, and prepare for extra
		val = parseFloat(val) or 0

		# Add padding, border, margin
		val += paddingA + paddingB + marginA + marginB + borderA + borderB  if isOuter
	val

offset = (elem) ->
	box =
		top: 0
		left: 0

	doc = elem and elem.ownerDocument
	return unless doc
	docElem = doc.documentElement

	# Make sure it's not a disconnected DOM node
	return box unless goog.dom.contains(docElem, elem)

	# If we don't have gBCR, just use 0,0 rather than error
	# BlackBerry 5, iOS 3 (original iPhone)
	box = elem.getBoundingClientRect()  if typeof elem.getBoundingClientRect isnt "undefined"
	win = getWindow(doc)
	top: box.top + (win.pageYOffset or docElem.scrollTop) - (docElem.clientTop or 0)
	left: box.left + (win.pageXOffset or docElem.scrollLeft) - (docElem.clientLeft or 0)

getWindow = (elem) ->
	if elem.nodeType is 9
		ret = elem.defaultView or elem.parentWindow
	else
		ret = false
	elem isnt null and elem is elem.window ? elem : ret

###
	@param element {Element}
	@param to {int}
###
scrollToInt = (element, to) ->
	element.scrollTop = to

###*
	Wrap an HTMLElement around each element in an HTMLElement array.
###
wrap = (parent, elms) ->
	# Convert `elms` to an array, if necessary.
	elms = [elms] unless elms.length

	# Loops backwards to prevent having to clone the wrapper on the
	# first element (see `child` below).
	i = elms.length - 1

	while i >= 0
		child = (if (i > 0) then parent.cloneNode(true) else parent)
		el = elms[i]

		# Cache the current parent and sibling.
		parent = el.parentNode
		sibling = el.nextSibling

		# Wrap the element (is automatically removed from its current
		# parent).
		child.appendChild el

		# If the element had a sibling, insert the wrapper before
		# the sibling to maintain the HTML structure; otherwise, just
		# append it to the parent.
		if sibling
			parent.insertBefore child, sibling
		else
			parent.appendChild child
		i--
	return








###*
	@class NanoScroll
	@param el {HTMLElement|Node} the main element
	@param options {Object} nanoScroller's options
	@constructor
###
class NanoScroll
	###*
		Wraps element with nano div and execute script
		@param element {HTMLElement|Node} element to wrap
		@param options {Object} nanoScroller's options
	###
	@wrap: (element, options = null) ->
		element.classList.add 'nano-content'
		wrapper = goog.dom.createDom 'div', 'class':'nano'
		wrap wrapper, element
		new NanoScroll wrapper, options

	constructor: (@el, @options = null) ->
		@options = defaults if @options is null
		BROWSER_SCROLLBAR_WIDTH or= do getBrowserScrollbarWidth
		@doc = @options['documentContext'] or document
		@win = @options['windowContext'] or window
		@body = document.body
		@content = goog.dom.getElementByClass @options['contentClass'], @el
		return if @content is null
		@content.setAttribute 'tabindex', @options['tabIndex'] or 0

		@previousPosition = 0

		if @options['iOSNativeScrolling'] && (goog.style.getStyle @el, '-webkit-overflow-scrolling')? #-
			do @nativeScrolling
		else
			do @generate
		do @createEvents
		do @addEvents
		do @reset

	###*
		Prevents the rest of the page being scrolled
		when user scrolls the `.nano-content` element.
		@param e {Event}
		@param direction {String} Scroll direction (up or down)
	###
	preventScrolling: (e, direction) ->
		return unless @isActive
		if e.type is DOMSCROLL # Gecko
			if direction is DOWN and e.detail > 0 or direction is UP and e.detail < 0
				do e.preventDefault
		else if e.type is MOUSEWHEEL # WebKit, Trident and Presto
			return if not e.or not e.wheelDelta
			if direction is DOWN and e.wheelDelta < 0 or direction is UP and e.wheelDelta > 0
				do e.preventDefault
		return

	###*
		Enable iOS native scrolling
	####
	nativeScrolling: ->
		# simply enable container
		goog.style.setStyle @content, '-webkit-overflow-scrolling', 'touch'
		@iOSNativeScrolling = true
		# we are always active
		@isActive = true
		return

	###*
		Updates those nanoScroller properties that
		are related to current scrollbar position.
	###
	updateScrollValues: ->
		# Formula/ratio
		# `scrollTop / maxScrollTop = sliderTop / maxSliderTop`
		@maxScrollTop = @content.scrollHeight - @content.clientHeight
		@prevScrollTop = @contentScrollTop or 0
		@contentScrollTop = @content.scrollTop

		direction = if @contentScrollTop > @previousPosition
			"down"
		else
			if @contentScrollTop < @previousPosition
				"up"
			else
				"same"
		@previousPosition = @contentScrollTop

		##test
		trigger(@el, 'update', { 'position': @contentScrollTop, 'maximum': @maxScrollTop, 'direction': direction}) unless direction == 'same' ##test

		if not @iOSNativeScrolling
			@maxSliderTop = @paneHeight - @sliderHeight
			# `sliderTop = scrollTop / maxScrollTop * maxSliderTop
			@sliderTop = if @maxScrollTop is 0 then 0 else @contentScrollTop * @maxSliderTop / @maxScrollTop
		return

	###*
		Updates CSS styles for current scroll position.
		Uses CSS 2d transfroms and `window.requestAnimationFrame` if available.
	###
	setOnScrollStyles: ->
		return if @lastSliderTop and @lastSliderTop.toFixed(2) is @sliderTop.toFixed(2)
		@lastSliderTop = @sliderTop

		if hasTransform
			cssValue = {transform: "translate(0, #{@sliderTop}px)"}
		else
			cssValue = {top: "#{@sliderTop}px"}

		if window.requestAnimationFrame
			window.cancelAnimationFrame(@scrollRAF) if window.cancelAnimationFrame and @scrollRAF
			@scrollRAF = window.requestAnimationFrame =>
				@scrollRAF = null
				goog.style.setStyle @slider, cssValue
		else
			goog.style.setStyle @slider, cssValue
		return

	###*
		Creates event related methods
	###
	createEvents: ->
		@events =
			'domchanged': =>
				do @reset

			###*
				@param e {Event}
			###
			'down': (e) =>
				@isBeingDragged  = true
				@offsetY = (Math.max 0, e.clientY) - offset(@slider)['top'] ##test it
				@offsetY = 0 unless e.target is @slider ##test it
				@pane.classList.add 'active'
				goog.dom.getElement('body').classList.add 'non-selectable'
				goog.events.listen @doc, MOUSEMOVE, @events[DRAG]
				goog.events.listen @doc, MOUSEUP, @events[UP]
				false

			###*
				@param e {Event}
			###
			'drag': (e) =>
				@sliderY = (Math.max 0, e.clientY) - offset(@content)['top'] - @paneTop - (@offsetY or @sliderHeight * 0.5)
				do @scroll
				if @contentScrollTop >= @maxScrollTop and @prevScrollTop isnt @maxScrollTop
					trigger @el, 'scrollend', null
				else if @contentScrollTop is 0 and @prevScrollTop isnt 0
					trigger @el, 'scrolltop', null
				false

			'up': =>
				@isBeingDragged = false
				@pane.classList.remove 'active'
				goog.dom.getElement('body').classList.remove 'non-selectable'
				goog.events.unlisten @doc, MOUSEMOVE, @events[DRAG]
				goog.events.unlisten @doc, MOUSEUP, @events[UP]
				false

			'resize': =>
				do @reset

			###*
				@param e {Event}
			###
			'panedown': (e) =>
				return if e.target is @slider
				@sliderY = (e.offsetY or e.layerY) - (@sliderHeight * 0.5)
				do @scroll
				@events[DOWN] e
				false

			###*
				@param e {Event}
			###
			'scroll': (e) =>
				do @updateScrollValues
				# Don't operate if there is a dragging mechanism going on.
				# This is invoked when a user presses and moves the slider or pane
				return if @isBeingDragged
				if not @iOSNativeScrolling
					# update the slider position
					@sliderY = @sliderTop
					do @setOnScrollStyles

				# the succeeding code should be ignored if @events.scroll() wasn't
				# invoked by a DOM event. (refer to @reset)
				return unless e?
				# if it reaches the maximum and minimum scrolling point,
				# we dispatch an event.
				if @contentScrollTop >= @maxScrollTop
					@preventScrolling(e, DOWN) if @options['preventPageScrolling']
					trigger @el, 'scrollend', null if @prevScrollTop isnt @maxScrollTop
				else if @contentScrollTop is 0
					@preventScrolling(e, UP) if @options['preventPageScrolling']
					trigger @el, 'scrolltop', null if @prevScrollTop isnt 0
				return

			###*
				@param e {Event}
			###
			'enter': (e) =>
				return unless @isBeingDragged
				@events[UP] arguments... if (e.buttons or e.which) isnt 1

		return

	###*
		Adds event listeners
	###
	addEvents: ->
		do @removeEvents
		if not @options['disableResize']
			goog.events.listen @win, RESIZE, @events[RESIZE] #-
		if not @iOSNativeScrolling
			goog.events.listen @slider, MOUSEDOWN, @events[DOWN] #-
			goog.events.listen @pane, MOUSEDOWN, @events[PANEDOWN] #-
		goog.events.listen @content, [SCROLL, MOUSEWHEEL, DOMSCROLL, TOUCHMOVE], @events[SCROLL] #-
		goog.events.listen @content, ['DOMNodeInserted', 'DOMNodeRemoved'], @events['domchanged']
		return

	###*
		Removes event listeners
	###
	removeEvents: ->
		events = @events
		goog.events.unlisten @win, RESIZE, events[RESIZE] #-
		if not @iOSNativeScrolling
			goog.events.removeAll @slider #-
			goog.events.removeAll @pane #-
		goog.events.unlisten @content, [SCROLL, MOUSEWHEEL, DOMSCROLL, TOUCHMOVE], events[SCROLL] #-
		return
##stopped here
	###*
		Generates nanoScroller's scrollbar and elements for it
	###
	generate: ->
		# For reference:
		# http://msdn.microsoft.com/en-us/library/windows/desktop/bb787527(v=vs.85).aspx#parts_of_scroll_bar
		paneClass = @options['paneClass']
		sliderClass = @options['sliderClass']
		contentClass = @options['contentClass']
		if not (pane = @el.getElementsByClassName paneClass).length and not pane.namedItem sliderClass #::? if not (pane = @$el.children(".#{paneClass}")).length and not pane.children(".#{sliderClass}").length
			div = goog.dom.createDom 'div', 'class':paneClass
			goog.dom.appendChild div, goog.dom.createDom('div', 'class':sliderClass)
			goog.dom.appendChild @el, div

		# pane is the name for the actual scrollbar.
		@pane = goog.dom.getElementByClass paneClass, @el #-

		# slider is the name for the  scrollbox or thumb of the scrollbar gadget
		@slider = goog.dom.getElementByClass sliderClass, @pane

		if BROWSER_SCROLLBAR_WIDTH is 0 and do isFFWithBuggyScrollbar
			currentPadding = window.getComputedStyle(@content,null).getPropertyValue('padding-right').replace(/\D+/g, '')
			cssRule =
				'right': '-14px'
				'padding-right': "#{+currentPadding + 14}px"
		else if BROWSER_SCROLLBAR_WIDTH
			cssRule =
				'right': "#{-BROWSER_SCROLLBAR_WIDTH}px" #::really dirty! fix asap
				'padding-right': '10px'
			@el.classList.add 'has-scrollbar' #-

		goog.style.setStyle @content, cssRule if cssRule? #-

		this

	restore: ->
		@stopped = false
		goog.style.setElementShown(@pane, true) if not @iOSNativeScrolling #-
		do @addEvents
		return

	###*
		Resets nanoScroller's scrollbar.
	###
	reset: ->
		if @iOSNativeScrolling
			@contentHeight = @content.scrollHeight
			return
		do @generate().stop if not goog.dom.getElementsByClass(@options['paneClass'], @el).length #-
		do @restore if @stopped
		contentStyleOverflowY = goog.style.getStyle @content, 'overflow-y' #-

		# try to detect IE7 and IE7 compatibility mode.
		# this sniffing is done to fix a IE7 related bug.
		goog.style.setStyle @content, 'height', @content.clientHeight if BROWSER_IS_IE7

		#goog.style.setStyle @content, 'width', "#{@el.clientWidth+(if BROWSER_SCROLLBAR_WIDTH is 0 then 14 else BROWSER_SCROLLBAR_WIDTH)}px"

		# set the scrollbar UI's height
		# the target content
		contentHeight = @content.scrollHeight + BROWSER_SCROLLBAR_WIDTH

		# Handle using max-height on the parent @el and not
		# setting the height explicitly
		parentMaxHeight = parseInt(goog.style.getStyle(@content, 'max-height'), 10) #-
		if parentMaxHeight > 0
			goog.style.setStyle @content, 'height', '' #-
			goog.style.setStyle @content, 'height', "#{(if @content.scrollHeight > parentMaxHeight then parentMaxHeight else @content.scrollHeight)}px" #-

		# set the pane's height.
		paneHeight = getHeight(@pane, true) #::not sure
		paneTop = parseInt(goog.style.getStyle(@pane, 'top'), 10) or 0
		paneBottom = parseInt(goog.style.getStyle(@pane, 'bottom'), 10) or 0
		paneOuterHeight = paneHeight + paneTop + paneBottom

		# set the slider's height
		sliderHeight = Math.round paneOuterHeight / contentHeight * paneOuterHeight
		if sliderHeight < @options['sliderMinHeight']
			sliderHeight = @options['sliderMinHeight'] # set min height
		else if @options['sliderMaxHeight']? and sliderHeight > @options['sliderMaxHeight']
			sliderHeight = @options['sliderMaxHeight'] # set max height
		sliderHeight += BROWSER_SCROLLBAR_WIDTH if contentStyleOverflowY is SCROLL and goog.style.getStyle(@content, 'overflow-x') isnt SCROLL

		# the maximum top value for the slider
		@maxSliderTop = paneOuterHeight - sliderHeight

		# set into properties for further use
		@contentHeight = contentHeight
		@paneHeight = paneHeight
		@paneOuterHeight = paneOuterHeight
		@sliderHeight = sliderHeight
		@paneTop = paneTop

		# set the values to the gadget
		goog.style.setStyle @slider, 'height', "#{sliderHeight}px" #-

		# scroll sets the position of the @slider
		do @events.scroll

		goog.style.setElementShown @pane, true
		@isActive = true

		if (@content.scrollHeight is @content.clientHeight) or (
			getHeight(@pane, true) >= @content.scrollHeight and contentStyleOverflowY isnt SCROLL) #::not sure
			goog.style.setElementShown @slider, false
			@isActive = false
		else if @content.clientHeight is @content.scrollHeight and contentStyleOverflowY is SCROLL
			goog.style.setElementShown @slider, false
		else
			goog.style.setElementShown @slider, true

		# allow the pane element to stay visible
		goog.style.setStyle @pane,
			opacity: (if @options['alwaysVisible'] then 1 else '')
			visibility: (if @options['alwaysVisible'] then 'visible' else '')

		contentPosition = goog.style.getStyle @content, 'position'

		if contentPosition is 'static' or contentPosition is 'relative'
			right = parseInt(goog.style.getStyle(@content, 'right'), 10)

			if right
				goog.style.setStyle @content, 'right', ''
				goog.style.setStyle @content, 'margin-right', "#{right}px"

		this

	scroll: ->
		return unless @isActive
		@sliderY = Math.max 0, @sliderY
		@sliderY = Math.min @maxSliderTop, @sliderY
		val = @maxScrollTop * @sliderY / @maxSliderTop
		#return if @sliderY <= @slider.clientHeight/2
		scrollToInt @content, val #::not the same as scrollTop i guess
		if not @iOSNativeScrolling
			do @updateScrollValues
			do @setOnScrollStyles
		this

	###*
		Scroll at the bottom with an offset value
		@param offsetY {Number}
	###
	scrollBottom: (offsetY) ->
		return unless @isActive
		scrollToInt @content, @contentHeight - @content.clientHeight - offsetY # Update scrollbar position by triggering one of the scroll events
		trigger @content, MOUSEWHEEL, null
		@stop().restore()
		this

	###*
		Scroll at the top with an offset value
		@param offsetY {Number}
	###
	scrollTop: (offsetY) ->
		return unless @isActive
		scrollToInt @content, offsetY
		trigger @content, MOUSEWHEEL, null # Update scrollbar position by triggering one of the scroll events #::?
		@stop().restore()
		this

	###*
		Scroll to an element
		@param node {Node} A node to scroll to.
	###
	scrollTo: (node) ->
		return unless @isActive
			el = goog.dom.getElement node
			@scrollTop el.offsetTop
		this

	###*
		To stop the operation.
		This option will tell the plugin to disable all event bindings and hide the gadget scrollbar from the UI.
	###
	stop: ->
		if window.cancelAnimationFrame and @scrollRAF
			window.cancelAnimationFrame(@scrollRAF)
			@scrollRAF = null
		@stopped = true
		do @removeEvents
		do goog.style.setElementShown(@pane, false) if not @iOSNativeScrolling
		this

	###*
		Destroys nanoScroller and restores browser's native scrollbar.
	###
	destroy: ->
		do @stop if not @stopped
		goog.dom.removeNode @pane if not @iOSNativeScrolling and @pane.length
		goog.style.setStyle(@content, 'height', '') if BROWSER_IS_IE7
		@content.removeAttribute 'tabindex' #::Is it ok?
		if @content.classList.contains 'has-scrollbar'
			@content.classList.remove 'has-scrollbar'
			goog.style.setStyle @content, 'right', ''
		this

	###*
		To flash the scrollbar gadget for an amount of time defined in plugin settings (defaults to 1,5s).
		Useful if you want to show the user (e.g. on pageload) that there is more content waiting for him.
	###
	flash: ->
		return if @iOSNativeScrolling
		return unless @isActive
		do @reset
		@pane.classList.add 'flashed'
		setTimeout =>
			@pane.classList.remove 'flashed'
			return
		, @options['flashDelay']
		this

###
	Triggers event
	@param el {Element}
	@param type {String}
	@param data {mixed}
###
trigger = (el, type, data) ->
	event = document.createEvent("HTMLEvents")
	event.initEvent type, true, true
	event.data = data or {}
	event.eventName = type
	el.dispatchEvent event
	true