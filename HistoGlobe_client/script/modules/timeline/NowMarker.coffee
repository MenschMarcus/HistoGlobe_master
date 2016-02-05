window.HG ?= {}

##############################################################################
# nowMarker shows the current date above the timeline

class HG.NowMarker

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_parent) ->
    # make now marker
    @_nowMarker = document.createElement 'div'
    @_nowMarker.id = "now_marker_arrow_bottom"
    # hack to disable text select on timeline
    @_nowMarker.classList.add "no-text-select"

    @_parent.appendChild @_nowMarker

    # make date field
    @_dateField = document.createElement 'div'
    @_dateField.id = "now_date_field"
    # hack to disable text select on timeline
    @_dateField.classList.add "no-text-select"

    @_parent.appendChild @_dateField

  setDate: (date) ->
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