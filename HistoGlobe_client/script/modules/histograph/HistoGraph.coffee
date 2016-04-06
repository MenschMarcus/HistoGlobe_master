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
    @_initHistory = no
    @_graphVisible = no


  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add to HG instance
    @_hgInstance.histoGraph = @

    # create wrapper (put above timeline, hidden)
    @_wrapper = @_domElemCreator.create 'div', 'histograph-wrapper', null
    $(@_wrapper).hide()
    @_hgInstance.timeline.getTimelineArea().appendChild @_wrapper

    # create transparent center line
    @_line = @_domElemCreator.create 'div', 'histograph-line', null
    $(@_line).hide()
    @_wrapper.appendChild @_line

    # create canvas itself
    @_canvas = d3.select @_wrapper
      .append 'svg'
      .attr 'id', 'histograph-canvas'

  # ============================================================================
  show: () ->
    if not @_graphVisible
      $(@_wrapper).show()
      $(@_line).show()
      @_graphVisible = yes

  # ----------------------------------------------------------------------------
  hide: () ->
    if @_graphVisible
      $(@_wrapper).hide()
      $(@_line).hide()
      @_graphVisible = no

  # ============================================================================


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

