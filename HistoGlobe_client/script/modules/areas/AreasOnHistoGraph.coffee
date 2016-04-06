window.HG ?= {}

class HG.AreasOnHistoGraph

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add areasOnMap to HG instance
    @_hgInstance.areasOnHistoGraph = @

    # error handling
    if not @_hgInstance.areaController
      console.error "Unable to show areas on HistoGraph: AreaController module not detected in HistoGlobe instance!"

    # init variables
    @_selectedAreas = []

    # event handling
    @_hgInstance.onAllModulesLoaded @, () =>

      @_hgInstance.areaController.onSelect @, (area) =>
        @_selectedAreas.push area

      @_hgInstance.areaController.onDeselect @, (area) =>
        idx = @_selectedAreas.indexOf area
        @_selectedAreas.splice idx, 1



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _showOnGraph: (area) ->

    # data for each country
    # TODO: get real data
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
  _initLines: (d) ->
    @_canvas.selectAll 'line'
      .data d
      .enter()
      .append 'line'
      .classed 'graph-country-line', true
      .attr 'x1', 0
      .attr 'x2', $(window).width()
      .attr 'y1', $(@_wrapper).height()/2
      .attr 'y2', $(@_wrapper).height()/2
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
      .attr 'y', $(@_wrapper).height()/2 - 5
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
    #   .attr 'cx', $(@_wrapper).width()/2
    #   .attr 'cy', $(@_wrapper).height()/2
    #   .on 'mouseover', () -> d3.select(@).style 'fill', HGConfig.color_highlight.val
    #   .on 'mouseout', () -> d3.select(@).style 'fill', HGConfig.color_white.val
    #   .on 'click', () -> d3.select(@).style 'fill', HGConfig.color_active.val


  # ============================================================================
  _highlight: (elem, col) ->
    d3.select(elem).transition()
      .style 'fill', col
