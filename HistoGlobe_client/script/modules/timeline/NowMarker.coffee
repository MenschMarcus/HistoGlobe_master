window.HG ?= {}

##############################################################################
# nowMarker shows the current date above the timeline

class HG.NowMarker

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_parent) ->

    # create now marker
    @_nowMarker = new HG.Div 'nowMarker', 'no-text-select'
    @_parent.append @_nowMarker

  # ============================================================================
  upDate: (date) ->
    $(@_nowMarker.elem()).html date.toLocaleDateString DATE_LOCALE, DATE_OPTIONS

  resetPos: (pos) ->
    @_nowMarker.elem().style.left = pos

  ##############################################################################
  #                            STATIC CONSTANTS                                #
  ##############################################################################

  DATE_LOCALE = 'de-DE'
  DATE_OPTIONS = {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }