window.HG ?= {}

# ============================================================================
# <input type='text' name='id'>

class HG.TextInput extends HG.DOMElement

  # ============================================================================
  constructor: (@_hgInstance, id=null, classes=[]) ->

    console.error "Please enter an id for the text input field, it is required" unless id?

    # add to HG instance
    @_hgInstance.inputs = {} unless @_hgInstance.inputs?
    @_hgInstance.inputs[id] = @

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onChange'

    # construct object of subclass with superclass
    classes.push 'hg-input'
    super 'input', id, classes, [['type', 'text'], ['name', id]]

    # change
    @_j.on 'keyup mouseup', (e) =>
      # tell everyone the new value
      @notifyAll 'onChange', e.currentTarget.value


  # ============================================================================
  setPlaceholder: (text) ->  @_j.attr 'placeholder', text

  # ----------------------------------------------------------------------------
  getValue: () ->            @_elem.value
  setValue: (text) ->        @_elem.value = text