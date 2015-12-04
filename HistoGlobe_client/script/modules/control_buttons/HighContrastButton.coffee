window.HG ?= {}

class HG.HighContrastButton

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      help: undefined

    @_config = $.extend {}, defaultConfig, config

  # ============================================================================
  hgInit: (hgInstance) ->

    unless hgInstance.browserDetector.fullscreenSupported
      console.warn "Not adding fullscreen button due to missing fullScreenApi!"
      return

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onEnterHighContrast"
    @addCallback "onLeaveHighContrast"

    hgInstance.highcontrast_button = @

    helpYOffset = 170 #130

    if hgInstance.help?
      hgInstance.help.addHelp
        image : "config/common/help/help01.png"
        anchorX : "left"
        anchorY : "top"
        offsetX: 30
        offsetY: helpYOffset
        width: "70%"


    if hgInstance.control_button_area?
      state_a = {}
      state_b = {}

      state_a =
        icon: "fa-adjust"
        tooltip: "Hohen Kontrast einschalten"
        callback: () =>
          $(hgInstance._config.container).addClass 'highContrast'
          @notifyAll "onEnterHighContrast"
          return state_b

      state_b =
        icon: "fa-adjust"
        tooltip: "Hohen Kontrast ausschalten"
        callback: () =>
          $(hgInstance._config.container).removeClass 'highContrast'
          @notifyAll "onLeaveHighContrast"
          return state_a

      hgInstance.control_button_area.addButton state_a

    else
      console.error "Failed to add zoom buttons: ControlButtons module not found!"
