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

      # for test purpose: activate multiple selections (2)
      # @_hgInstance.buttons.

      @_hgInstance.areasOnMap.onActivateArea @, (country) =>
        @show() unless @_graphVisible
        if not @_multipleSelection          # single-selection mode
          @_showHistory country
        else                                # multiple-selection mode
          @_selectedCountries.push country

      # no active country => no graph
      @_hgInstance.areasOnMap.onDeactivateArea @, (country) =>
        if not @_multipleSelection          # single-selection mode
          @hide()
        else                                # multiple-selection mode
          # @_selectedCountries.push country


  # ============================================================================
  show: () ->
    @_wrapper.dom().show()
    @_line.dom().show()
    @notifyAll 'onShow', @_wrapper.dom()
    @_graphVisible = yes

  hide: () ->
    @_wrapper.dom().hide()
    @_line.dom().hide()
    @notifyAll 'onHide', @_wrapper.dom()
    @_graphVisible = no


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
    if not @_initHistory
      @_initLines countryData
      @_initLabels countryData
      @_initHistory = yes
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
    @_canvas.selectAll 'line'
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
    @_canvas.selectAll 'text'
      .data d
      .enter()
      .append 'text'
      .classed 'graph-country-label', true
      .attr 'x', 15
      .attr 'y', @_wrapper.dom().height()/2 - 5
      .text (d) -> d.name

  _updateLines: (d) ->
    @_canvas.selectAll 'line'

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