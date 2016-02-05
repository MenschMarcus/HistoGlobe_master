window.HG ?= {}

##############################################################################
# graph above the timeline that shows the history of countries
# very d3 intensive
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

    # @addCallback ""

    # init variables


  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add graph to HG instance
    @_hgInstance.histoGraph = @
    console.log "MUH"

    # init canvas
    canvas = document.createElement 'div'
    canvas.id = 'histograph'
    @_hgInstance._top_area.appendChild canvas
    @_canvas = $(canvas)

  # ============================================================================
  show: () ->   @_canvas.show()
  hide: () ->   @_canvas.hide()

  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################

  # ============================================================================
