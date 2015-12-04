window.HG ?= {}

class HG.MinLayoutButton

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

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onRemoveGUI"
    @addCallback "onOpenGUI"

    hgInstance.minGUIButton = @

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
        icon: "fa-sort-desc"
        tooltip: "Oberfläche vereinfachen"
        callback: () =>
          $(hgInstance._config.container).addClass 'minGUI'
          @notifyAll "onRemoveGUI"
          return state_b

      state_b =
        icon: "fa-sort-asc"
        tooltip: "Mehr Optionen anzeigen"
        callback: () =>
          $(hgInstance._config.container).removeClass 'minGUI'
          @notifyAll "onOpenGUI"
          return state_a

      hgInstance.control_button_area.addButton state_a

    else
      console.error "Failed to add zoom buttons: ControlButtons module not found!"
