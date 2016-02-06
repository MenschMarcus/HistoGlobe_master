window.HG ?= {}

##############################################################################
# graph above the timeline that shows the history of countries
# very d3 intensive


class HG.HistoGraph

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onShow"
    @addCallback "onHide"

    # handle config
    defaultConfig =
      depth: 1

    @_config = $.extend {}, defaultConfig, config

    # init variables
    @_visible = no


  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add graph to HG instance
    @_hgInstance.histoGraph = @

    # create canvas (put above timeline, hidden)
    canvas = document.createElement 'div'
    canvas.id = 'histograph'
    @_hgInstance.timeline?.getParentDiv().appendChild canvas
    @_canvas = $(canvas)
    @_canvas.hide()

    ### LISTENER ###
    @_hgInstance.onAllModulesLoaded @, () =>
      # open on click of area
      @_hgInstance.areasOnMap.onClickArea @, (area) =>
        @show()
      # closes on click on anything else in the display
      @_hgInstance.display2D.onClick @, () =>
        @hide()

  # ============================================================================
  show: () ->
    if not @_visible
      @_canvas.show()
      @notifyAll "onShow", @_canvas
      @_visible = yes

  hide: () ->
    if @_visible
      @_canvas.hide()
      @notifyAll "onHide", @_canvas
      @_visible = no

  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################

  # ============================================================================
