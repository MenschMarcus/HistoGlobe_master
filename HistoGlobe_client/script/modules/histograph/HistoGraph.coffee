window.HG ?= {}

##############################################################################
# MODULE
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
    @_initHistory = no
    @_graphVisible = no

    # 2 modi: single-selection -> 1 country can be selected => show its history
    #         multiple-selection -> n countries can be selected => added to operation
    @_multipleSelection = no
    @_selectedCountries = []

  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add HistoGraph to HG instance
    @_hgInstance.histoGraph = @

    # create wrapper (put above timeline, hidden)
    @_wrapper = new HG.Div 'histograph-wrapper', null
    @_wrapper.j().hide()
    @_hgInstance.timeline.getParentDiv().appendChild @_wrapper

    # create transparent center line
    @_line = new HG.Div 'histograph-line', null
    @_line.j().hide()
    @_wrapper.appendChild @_line

    # create canvas itself
    @_canvas = d3.select @_wrapper.dom()
      .append 'svg'
      .attr 'id', 'histograph-canvas'

    ### LISTENER ###
    @_hgInstance.onAllModulesLoaded @, () =>

      # for test purpose: activate multiple selections (2)
      # @_hgInstance.buttons.zoomOut.onClick @, () =>
      #   @_multipleSelection = yes
      #   @_hgInstance.areasOnMap.enableMultipleSelection 3

      # @_hgInstance.buttons.zoomIn.onClick @, () =>
      #   @_multipleSelection = no
      #   @_hgInstance.areasOnMap.disableMultipleSelection()

      @_hgInstance.areasOnMap.onActivateArea @, (country) =>
        @show()
        @showHistory country

      # no active country => no graph
      @_hgInstance.areasOnMap.onDeactivateArea @, (country) =>
        @hide()


  # ============================================================================
  show: () ->
    if not @_graphVisible
      @_wrapper.j().show()
      @_line.j().show()
      @notifyAll 'onShow', @_wrapper.j()
      @_graphVisible = yes

  hide: () ->
    if @_graphVisible
      @_wrapper.j().hide()
      @_line.j().hide()
      @notifyAll 'onHide', @_wrapper.j()
      @_graphVisible = no

  # ============================================================================
  showHistory: (area) ->

    # data for each country
    countryData = [
      {
        'name':   area.getCommName()
        'start':  new Date 1981, 1, 1
        'end':    new Date 1994, 1, 1
      }
    ]

    # a line and a text (label for the line) for each country
    if not @_initHistory
      @_initLines countryData
      @_initLabels countryData
      @_initHistory = yes
    else
      @_updateLines countryData
      @_updateLabels countryData


  # ============================================================================
  addToSelection: (area) ->
    # TODO "add " + area.getCommName()

  removeFromSelection: (area) ->
    # TODO "remove " + area.getCommName()


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _initLines: (d) ->
    @_canvas.selectAll 'line'
      .data d
      .enter()
      .append 'line'
      .classed 'graph-country-line', true
      .attr 'x1', 0
      .attr 'x2', $(window).width()
      .attr 'y1', @_wrapper.j().height()/2
      .attr 'y2', @_wrapper.j().height()/2
      .on 'mouseover', () -> d3.select(@).style 'stroke', HGConfig.color_highlight.val
      .on 'mouseout', () -> d3.select(@).style 'stroke', HGConfig.color_white.val
      .on 'click', () -> d3.select(@).style 'stroke', HGConfig.color_active.val

  _initLabels: (d) ->
    @_canvas.selectAll 'text'
      .data d
      .enter()
      .append 'text'
      .classed 'graph-country-label', true
      .attr 'x', 15
      .attr 'y', @_wrapper.j().height()/2 - 5
      .text (d) -> d.name

  _updateLines: (d) ->
    @_canvas.selectAll 'line'

  _updateLabels: (d) ->
    @_canvas.selectAll 'text'
      .data d
      .transition()
      .duration 200
      .text (d) -> d.name


    # _initCircles
    # put in event the center assuming history of country is "infinite"
    # @_canvas.append 'circle'
    #   .classed 'graph-hivent', true
    #   .attr 'r', 10
    #   .attr 'cx', @_wrapper.j().width()/2
    #   .attr 'cy', @_wrapper.j().height()/2
    #   .on 'mouseover', () -> d3.select(@).style 'fill', HGConfig.color_highlight.val
    #   .on 'mouseout', () -> d3.select(@).style 'fill', HGConfig.color_white.val
    #   .on 'click', () -> d3.select(@).style 'fill', HGConfig.color_active.val


  # ============================================================================
  _highlight: (elem, col) ->
    d3.select(elem).transition()
      .style 'fill', col
