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

    @addCallback 'onShow'
    @addCallback 'onHide'

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
    @_canvas = new HG.Div 'histograph', null, true
    @_hgInstance.timeline.getParentDiv().appendChild @_canvas.obj()

    # create transparent center line


    ### LISTENER ###
    @_hgInstance.onAllModulesLoaded @, () =>
      # open on click of area
      @_hgInstance.areasOnMap.onSelectArea @, (area) =>
        @show area
      # closes on click on anything else in the display
      @_hgInstance.areasOnMap.onDeselectArea @, () =>
        @hide()

  # ============================================================================
  show: (area) ->
    if not @_visible
      @_canvas.dom().show()
      @notifyAll 'onShow', @_canvas.dom()
      @_visible = yes
      # @_showArea area

  hide: () ->
    if @_visible
      @_canvas.dom().hide()
      @notifyAll 'onHide', @_canvas.dom()
      @_visible = no

  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################

  # ============================================================================
