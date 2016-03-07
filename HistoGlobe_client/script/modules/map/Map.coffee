window.HG ?= {}

class HG.Map extends HG.Display

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->
    HG.Display.call @

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @


  # ============================================================================
  hgInit: (@_hgInstance) ->
    super @_hgInstance

    unless @_hgInstance.browserDetector
      return console.error "Failed to initialize Map: Module BrowserDetector not detected!"


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################