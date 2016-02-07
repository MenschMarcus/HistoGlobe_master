+window.HG ?= {}

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

    # create wrapper (put above timeline, hidden)
    @_wrapper = new HG.Div 'histograph-wrapper', null, true
    @_hgInstance.timeline.getParentDiv().append @_wrapper

    # create transparent center line
    @_line = new HG.Div 'histograph-line', null, true
    @_wrapper.append @_line

    # canvas itself
    @_canvas = d3.select @_wrapper.obj()
      .append 'svg'
      .attr 'id', 'histograph-canvas'

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
      @_wrapper.dom().show()
      @_line.dom().show()
      @notifyAll 'onShow', @_wrapper.dom()
      @_visible = yes
      @_showHistory area

  hide: () ->
    if @_visible
      @_wrapper.dom().hide()
      @_line.dom().hide()
      @notifyAll 'onHide', @_wrapper.dom()
      @_visible = no

  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################

  # ============================================================================
  _showHistory: (area) ->
    @_canvas.append 'circle'
      .style 'stroke', 'gray'
      .style 'fill', 'white'
      .attr 'r', 25
      .attr 'cx', @_wrapper.dom().width()/2
      .attr 'cy', @_wrapper.dom().height()/2
      .on 'mouseover', -> d3.select(@).style 'fill', 'red'
      .on 'mouseout', ->  d3.select(@).style 'fill', 'white'