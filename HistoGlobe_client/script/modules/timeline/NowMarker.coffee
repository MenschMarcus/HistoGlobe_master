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

    # create date field
    @_dateField = new HG.Div 'nowDateField', 'no-text-select'
    @_parent.append @_dateField

  # ============================================================================
  upDate: (date) ->
    @_dateField.dom().html date.toLocaleDateString DATE_LOCALE, DATE_OPTIONS

  resetPos: (pos) ->
    @_nowMarker.obj().style.left = pos
    @_dateField.obj().style.left = pos

  ##############################################################################
  #                            STATIC CONSTANTS                                #
  ##############################################################################

  DATE_LOCALE = 'de-DE'
  DATE_OPTIONS = {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }