window.HG ?= {}

class HG.GraphButton

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################
  # ============================================================================
  constructor: () ->
    @_button_div = null
    @_parent_div = null

  # ============================================================================
  hgInit: (hgInstance) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onShowGraph"
    @addCallback "onHideGraph"

    hgInstance.graph_button = @

    if hgInstance.control_button_area?
      state_a = {}
      state_b = {}

      state_a =
        icon: "fa-share-alt"
        tooltip: "Allianzen zeigen"
        callback: () =>
          @notifyAll "onShowGraph"
          return state_b

      state_b =
        icon: "fa-share-alt"
        tooltip: "Allianzen ausblenden"
        callback: () =>
          @notifyAll "onHideGraph"
          return state_a

      @_button_div = hgInstance.control_button_area.addButton state_a
      @_parent_div = @_button_div.parentNode

      @hide_button()

    else
      console.error "Failed to graph button: ControlButtons module not found!"

  # ============================================================================
  hide_button:() ->
    if @_button_div and @_parent_div
      @_parent_div.removeChild(@_button_div);

  # ============================================================================
  show_button:() ->
    if @_button_div and @_parent_div
      @_parent_div.appendChild(@_button_div);

