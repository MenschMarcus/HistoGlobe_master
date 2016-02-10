window.HG ?= {}

# ============================================================================
# <input type='checkbox'> element, its DOM element and its object counterpart inside code
# arguments:
#   hgInstance
#   id        'id' in dom
#   classes   ['className1', 'className2', ...] (if many)
#   hidden    true (optional, if not stated, not hidden)

class HG.NumberInput extends HG.DOMElement

  # ============================================================================
  constructor: (@_hgInstance, id=null, classes=[], hidden=false) ->

    # add to HG instance
    @_hgInstance.inputs = {} unless @_hgInstance.inputs?
    @_hgInstance.inputs[id] = @

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onChange'

    # construct object of subclass with superclass
    super 'input', id, classes, [['type', 'number'], ['name', id]], hidden

    # change
    @_jq.on 'keyup mouseup', (e) =>
      # tell everyone the new value
      @notifyAll 'onChange', e.currentTarget.value