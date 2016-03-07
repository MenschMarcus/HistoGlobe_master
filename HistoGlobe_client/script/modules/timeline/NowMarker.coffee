window.HG ?= {}

##############################################################################
# nowMarker shows the current date above the timeline

class HG.NowMarker

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->


  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add module to HG instance
    @_hgInstance.nowMarker = @

    @_hgContainer = @_hgInstance.getContainer()

    # create now marker
    @_nowMarker = new HG.Div 'nowMarker', 'no-text-select'
    @_hgContainer.appendChild @_nowMarker.dom()

    # initialize position and content
    @_resetPosition()
    @_upDate @_hgInstance.timeline.getNowDate()

    ### INTERACTION ###

    # window: update position on resize
    $(window).resize =>
      @_resetPosition()

    # timeline: update date
    @_hgInstance.timeline.onNowChanged @, (date) =>
      @_upDate date


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _upDate: (date) ->
    @_nowMarker.j().html date.toLocaleDateString DATE_LOCALE, DATE_OPTIONS


  # ============================================================================
  _resetPosition: (pos) ->
    @_nowMarker.dom().style.left = (window.innerWidth / 2) + "px"


  ##############################################################################
  #                            STATIC CONSTANTS                                #
  ##############################################################################

  DATE_LOCALE = 'de-DE'
  DATE_OPTIONS = {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }