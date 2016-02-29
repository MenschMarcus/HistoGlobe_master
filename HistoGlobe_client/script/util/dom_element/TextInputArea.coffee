window.HG ?= {}

# ============================================================================
# <input type='text' name='id'>

class HG.TextInputArea extends HG.DOMElement

  # ============================================================================
  constructor: (@_hgInstance, id=null, classes=[], dimensions=[]) ->

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
    super 'textarea', id, classes, [['rows', dimensions[0]], ['cols', dimensions[1]], ['name', id]]

    # change
    $(@_elem).on 'keyup mouseup', (e) =>
      # tell everyone the new value
      @notifyAll 'onChange', e.currentTarget.value

    # focus
    $(@_elem).on 'focus', (e) =>
      $(@_elem).addClass 'hg-input-focus'
    $(@_elem).on 'focusout', (e) =>
      $(@_elem).removeClass 'hg-input-focus'

  # ============================================================================
  setPlaceholder: (text) ->
    $(@_elem).attr 'placeholder', text