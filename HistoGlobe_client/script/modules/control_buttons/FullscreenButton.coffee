window.HG ?= {}

class HG.FullscreenButton

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

    @addCallback "onEnterFullscreen"
    @addCallback "onLeaveFullscreen"

    hgInstance.fullscreen_button = @

    helpYOffset = 170 #130
    if hgInstance.sdwTitle?
      helpYOffset = 210 #170

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
        icon: "fa-expand"
        tooltip: "Vollbildmodus"
        callback: () =>

          elem = document.body
          if (elem.requestFullscreen)
            elem.requestFullscreen()
          else if (elem.msRequestFullscreen)
            elem.msRequestFullscreen()
          else if (elem.mozRequestFullScreen)
            elem.mozRequestFullScreen()
          else if (elem.webkitRequestFullscreen)
            elem.webkitRequestFullscreen()

          @notifyAll "onEnterFullscreen"

          return state_b

      state_b =
        icon: "fa-compress"
        tooltip: "Vollbildmodus verlassen"
        callback: () =>
          elem = document.body
          if (elem.requestFullscreen)
            document.cancelFullScreen()
          else if (elem.msRequestFullscreen)
            document.msExitFullscreen()
          else if (elem.mozRequestFullScreen)
            document.mozCancelFullScreen()
          else if (elem.webkitRequestFullscreen)
            document.webkitCancelFullScreen()
          @notifyAll "onLeaveFullscreen"
          return state_a

      hgInstance.control_button_area.addButton state_a

    else
      console.error "Failed to add zoom buttons: ControlButtons module not found!"



