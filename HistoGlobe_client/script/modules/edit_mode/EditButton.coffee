window.HG ?= {}

class HG.EditButton

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      help: undefined

    @_operations =
      [
        {
          "name":     "ADD",
          "icon":     "fa-plus",
          "tooltip":  "add new country"
        },
        {
          "name":     "UNI",
          "icon":     "fa-venus-mars",
          "tooltip":  "unite countries"
        },
        {
          "name":     "SEP",
          "icon":     "fa-bolt",
          "tooltip":  "separate country"
        },
        {
          "name":     "CHB",
          "icon":     "fa-arrows-h",
          "tooltip":  "change borders between countries"
        },
        {
          "name":     "CHN",
          "icon":     "fa-amazon",
          "tooltip":  "change name of country"
        },
        {
          "name":     "DEL",
          "icon":     "fa-ban",
          "tooltip":  "delete country"
        },
      ]

    @_config = $.extend {}, defaultConfig, config

  # ============================================================================
  hgInit: (hgInstance) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onEnterEditMode"
    @addCallback "onLeaveEditMode"

    hgInstance.edit_button = @

    if hgInstance.help?
      hgInstance.help.addHelp
        image : "config/common/help/help01.png"
        anchorX : "left"
        anchorY : "top"
        offsetX: 30
        offsetY: 170
        width: "70%"

    # main
    if hgInstance.edit_button_area?
      state_a = {}  # browsing mode
      state_b = {}  # edit mode

      state_a =
        icon: "fa-pencil"
        tooltip: "Enter Edit Mode"
        callback: () =>
          # add all buttons for historical operations
          # TODO how to access object with operations?
          hgInstance.edit_button_area.addButtonGroup @_operations

          @notifyAll "onEnterEditMode"
          return state_b

      state_b =
        icon: "fa-pencil"
        tooltip: "Leave Edit Mode"
        callback: () =>
          elem = document.body

          @notifyAll "onLeaveEditMode"
          return state_a

      hgInstance.edit_button_area.addButton state_a

    else
      console.error "Failed to add zoom buttons: EditButtons module not found!"


  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################
