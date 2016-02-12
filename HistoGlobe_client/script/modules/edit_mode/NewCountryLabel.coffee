window.HG ?= {}

# ============================================================================
# maybe needed later...

class HG.NewCountryLabel

  # ============================================================================
  constructor: (@_hgInstance, pos) ->

    # add to HG instance
    @_hgInstance.newCountryLabel = @

    # handle callbacks
    H.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onChangeName'





    # change
    $(@_elem).on 'keyup mouseup', (e) =>
      # tell everyone the new value
      @notifyAll 'onChangeName', e.currentTarget.value