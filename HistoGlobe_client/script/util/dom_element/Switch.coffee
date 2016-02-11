window.HG ?= {}

# ============================================================================
# <div> element representing an on/off switch (default: on)

class HG.Switch extends HG.DOMElement

  # ============================================================================
  constructor: (@_hgInstance, id=null, classes=[]) ->

    # add to switch object of HG instance
    @_hgInstance.switches = {} unless @_hgInstance.switches?
    @_hgInstance.switches[id] = @

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onSwitchOn'
    @addCallback 'onSwitchOff'

    # init state variables
    state = on

    # construct object of subclass with superclass
    classes.unshift 'toggle-on-off'
    classes.unshift 'switch-on'
    super 'div', id, classes, []

    # toggle
    $(@_elem).click () =>

      # switch off
      if state is on
        $(@_elem).removeClass 'switch-on'
        $(@_elem).addClass 'switch-off'
        state = off
        @notifyAll 'onSwitchOff'

      # switch on
      else # state is off
        $(@_elem).removeClass 'switch-off'
        $(@_elem).addClass 'switch-on'
        state = on
        @notifyAll 'onSwitchOn'