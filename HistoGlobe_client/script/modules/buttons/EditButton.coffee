window.HG ?= {}

class HG.EditButton

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

    @addCallback "onEnterEditMode"
    @addCallback "onLeaveEditMode"

    hgInstance.edit_button = @

    # main
    if hgInstance.button_area?
      state_a = {}  # browsing mode
      state_b = {}  # edit mode

      state_a =
        icon: "fa-pencil"
        tooltip: "Enter Edit Mode"
        callback: () =>
          @notifyAll "onEnterEditMode"
          return state_b

      state_b =
        icon: "fa-pencil"
        tooltip: "Leave Edit Mode"
        callback: () =>
          @notifyAll "onLeaveEditMode"
          return state_a

      hgInstance.button_area.addButton state_a

    else
      console.error "Failed to add zoom buttons: EditButtons module not found!"


  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################
