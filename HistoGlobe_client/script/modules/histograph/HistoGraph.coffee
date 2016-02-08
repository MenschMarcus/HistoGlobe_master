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
  _highlight: (elem, col) ->
    d3.select(elem).transition()
      .style 'fill', col

  # ============================================================================
  _showHistory: (area) ->
    color_white = @_toHex HGConfig.color_white
    color_highlight = @_toHex HGConfig.color_highlight
    color_active = @_toHex HGConfig.color_active

    @_canvas.append 'circle'
      .style 'fill', color_white
      .attr 'r', 10
      .attr 'cx', @_wrapper.dom().width()/2
      .attr 'cy', @_wrapper.dom().height()/2
      .on 'mouseover', () -> d3.select(@).style 'fill', color_highlight
      .on 'mouseout', () -> d3.select(@).style 'fill', color_white
      .on 'click', () -> d3.select(@).style 'fill', color_active
      # these lines took 2 hours !!! this is for some reason the way to
      # hand in local variables into a callback function. I will never understand...

  # ============================================================================
  _toHex: (obj) ->
    r = obj.r.toString 16
    g = obj.g.toString 16
    b = obj.b.toString 16
    r = "0"+r if r.length is 1
    g = "0"+g if g.length is 1
    b = "0"+b if b.length is 1
    "#" + r + g + b
