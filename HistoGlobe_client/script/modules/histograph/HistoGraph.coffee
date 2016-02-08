window.HG ?= {}

##############################################################################
# graph above the timeline that shows the history of countries
# visualisation based on d3
##############################################################################

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
    # add HistoGraph to HG instance
    @_hgInstance.histoGraph = @

    # create wrapper (put above timeline, hidden)
    @_wrapper = new HG.Div 'histograph-wrapper', null, true
    @_hgInstance.timeline.getParentDiv().append @_wrapper

    # create transparent center line
    @_line = new HG.Div 'histograph-line', null, true
    @_wrapper.append @_line

    # create canvas itself
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
    @_showHistory area
    if not @_visible
      @_wrapper.dom().show()
      @_line.dom().show()
      @notifyAll 'onShow', @_wrapper.dom()
      @_visible = yes

  hide: () ->
    if @_visible
      @_wrapper.dom().hide()
      @_line.dom().hide()
      @notifyAll 'onHide', @_wrapper.dom()
      @_visible = no


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _showHistory: (area) ->

    # data for each country
    countryData = [
      {
        'name':   area.getCommName()
        'start':  new Date 1981, 1, 1
        'end':    new Date 1994, 1, 1
      }
    ]

    # a line and a text (label for the line) for each country
    if not @_visible
      @_countryLines = @_canvas.selectAll 'line'
      @_countryLabels = @_canvas.selectAll 'text'
      @_initLines countryData
      @_initLabels countryData
    else
      @_updateLines countryData
      @_updateLabels countryData


    # put in event the center assuming history of country is "infinite"
    @_canvas.append 'circle'
      .classed 'graph-hivent', true
      .attr 'r', 10
      .attr 'cx', @_wrapper.dom().width()/2
      .attr 'cy', @_wrapper.dom().height()/2
      .on 'mouseover', () -> d3.select(@).style 'fill', HGConfig.color_highlight.val
      .on 'mouseout', () -> d3.select(@).style 'fill', HGConfig.color_white.val
      .on 'click', () -> d3.select(@).style 'fill', HGConfig.color_active.val


  _initLines: (d) ->
    @_countryLines
      .data d
      .enter()
      .append 'line'
      .classed 'graph-country-line', true
      .attr 'x1', 0
      .attr 'x2', $(window).width()
      .attr 'y1', @_wrapper.dom().height()/2
      .attr 'y2', @_wrapper.dom().height()/2
      .on 'mouseover', () -> d3.select(@).style 'stroke', HGConfig.color_highlight.val
      .on 'mouseout', () -> d3.select(@).style 'stroke', HGConfig.color_white.val
      .on 'click', () -> d3.select(@).style 'stroke', HGConfig.color_active.val

  _initLabels: (d) ->
    @_countryLabels
      .data d
      .enter()
      .append 'text'
      .classed 'graph-country-label', true
      .attr 'x', 15
      .attr 'y', @_wrapper.dom().height()/2 - 5
      .text (d) -> d.name

  _updateLines: (d) ->

  _updateLabels: (d) ->
    @_canvas.selectAll 'text'
      .data d
      .transition()
      .duration 200
      .text (d) -> d.name




  # ============================================================================
  _highlight: (elem, col) ->
    d3.select(elem).transition()
      .style 'fill', col