window.HG ?= {}

##############################################################################
# VIEW MODULE
# graph above the timeline that shows the history of countries
# and historical events (hivents) that changed them
# visualisation based on d3 (?)
##############################################################################

class HG.HistoGraph

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle config
    defaultConfig =
      depth: 1

    @_config = $.extend {}, defaultConfig, config

    # include
    @_domElemCreator = new HG.DOMElementCreator

    # init variables
    @_numAreas = 0

  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add to HG instance
    @_hgInstance.histoGraph = @

    # DOM Elements
    @_bottomArea =  @_hgInstance.getBottomArea()
    @_tlSlider =    @_hgInstance.timeline.getSlider()
    @_tlMain =      $('#tl-main, #tl-wrapper')

    # create transparent center line
    # not inside HistoGraph, but centered on top of it
    # -> same level as NowMarker
    @_centerLine = @_domElemCreator.create 'div', 'histograph-centerline', ['no-text-select']
    @_bottomArea.appendChild @_centerLine

    # create canvas itself
    @_canvas = d3
      .select @_tlSlider
      .append 'svg'
      .attr 'id', 'histograph-canvas'

    # put an arbitrary circle on the graph
    # @_canvas
    #   .append 'circle'
    #   .attr 'cx', 9000
    #   .attr 'cy', 30
    #   .attr 'r', 20
    #   .style 'fill', "red"


  # ============================================================================
  updateHeight: (direction) ->
    @_numAreas += direction

    newHeightTl = HGConfig.timeline_height.val + @_numAreas*AREA_HEIGHT
    newHeightTl += INIT_HEIGHT if @_numAreas > 0
    @_tlMain.animate {height: newHeightTl}, HGConfig.slow_animation_time.val, () =>
      $(@_tlSlider).height newHeightTl
      $(@_bottomArea).height newHeightTl
      @_hgInstance.updateLayout()

    newHeightGraph = @_numAreas*AREA_HEIGHT
    newHeightGraph += INIT_HEIGHT if @_numAreas > 0
    $(@_centerLine).animate {height: newHeightGraph}, HGConfig.slow_animation_time.val, () =>
      $(@_canvas).height newHeightGraph


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  ##############################################################################
  #                            STATIC INTERFACE                               #
  ##############################################################################

  INIT_HEIGHT =  40    # px, for padding above and below
  AREA_HEIGHT =  60    # px
