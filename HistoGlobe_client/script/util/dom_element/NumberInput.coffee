window.HG ?= {}

# ============================================================================
# <input type='checkbox'>

class HG.NumberInput extends HG.DOMElement

  # ============================================================================
  constructor: (@_hgInstance, id=null, classes=[]) ->

    # add to HG instance
    @_hgInstance.inputs = {} unless @_hgInstance.inputs?
    @_hgInstance.inputs[id] = @

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onChange'

    # construct object of subclass with superclass
    super 'input', id, classes, [['type', 'number'], ['name', id]]

    # change
    $(@_elem).on 'keyup mouseup', (e) =>
      # tell everyone the new value
      @notifyAll 'onChange', e.currentTarget.value