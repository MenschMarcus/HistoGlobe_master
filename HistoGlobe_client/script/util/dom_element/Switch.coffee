window.HG ?= {}

# ============================================================================
# <div> element representing an on/off switch (default: on)
# its DOM element and its object counterpart inside code
# arguments:
#   hgInstance
#   id        'id' in dom
#   classes   ['className1', 'className2', ...] (if many)
#   hidden    true (optional, if not stated, not hidden)

class HG.Switch extends HG.DOMElement

  # ============================================================================
  constructor: (@_hgInstance, id=null, classes=[], hidden=false) ->

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
    super 'div', id, classes, [], hidden

    # toggle
    @_jq.click () =>

      # switch off
      if state is on
        @_jq.removeClass 'switch-on'
        @_jq.addClass 'switch-off'
        state = off
        @notifyAll 'onSwitchOff'

      # switch on
      else # state is off
        @_jq.removeClass 'switch-off'
        @_jq.addClass 'switch-on'
        state = on
        @notifyAll 'onSwitchOn'