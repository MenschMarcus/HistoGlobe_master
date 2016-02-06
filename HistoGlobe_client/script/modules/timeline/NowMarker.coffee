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
    @_nowMarker = document.createElement 'div'
    @_nowMarker.id = 'nowMarker'
    # hack to disable text select on timeline
    @_nowMarker.classList.add "no-text-select"

    @_parent.appendChild @_nowMarker

    # create date field
    @_dateField = document.createElement 'div'
    @_dateField.id = 'nowDateField'
    # hack to disable text select on timeline
    @_dateField.classList.add "no-text-select"

    @_parent.appendChild @_dateField

  # ============================================================================
  upDate: (date) ->
    @_dateField.innerHTML = date.toLocaleDateString DATE_LOCALE, DATE_OPTIONS

  resetPos: (pos) ->
    @_nowMarker.style.left = pos
    @_dateField.style.left = pos

  ##############################################################################
  #                            STATIC CONSTANTS                                #
  ##############################################################################

  DATE_LOCALE = 'de-DE'
  DATE_OPTIONS = {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }