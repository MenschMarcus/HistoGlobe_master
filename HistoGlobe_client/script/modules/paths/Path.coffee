window.HG ?= {}

class HG.Path

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (startHiventHandle, endHiventHandle, category, color, movingMarker, startMarker, endMarker) ->

    if startHiventHandle.getHivent().endDate < endHiventHandle.getHivent().startDate
      @_startHiventHandle = startHiventHandle
      @_endHiventHandle   = endHiventHandle
    else
      @_startHiventHandle = endHiventHandle
      @_endHiventHandle   = startHiventHandle

    @category = category
    @_color = color

    @_movingMarker = movingMarker
    @_startMarker = startMarker
    @_endMarker = endMarker

    @_isVisible = false
    @_initMarker()

  # ============================================================================
  isVisible: () ->
    @_isVisible

  # ============================================================================
  # overide this in derived classes!
  getMarkerPos: (date) ->
    {long:0, lat:0}

  # ============================================================================
  setDate: (date) ->
    @_updateAnimation date

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _initMarker: () ->
    icon = new L.DivIcon {className: "path_marker_2D_#{@_startHiventHandle.getHivent().category}", iconSize: null}
    @_marker = new L.Marker [@_startHiventHandle.getHivent().lat, @_startHiventHandle.getHivent().long], {icon: icon}
    @_markerVisible = false

  # ============================================================================
  _updateAnimation: (date) ->
    if @_isMarkerVisible date
      if @_isVisible and not @_markerVisible
        @_marker.addTo @_map
        @_markerVisible = true

      if @_isMarkerMoving date
        pos = @getMarkerPos date
        @_marker.setLatLng([pos.lat, pos.long])

      else if date < @_startHiventHandle.getHivent().endDate
        hivent = @_startHiventHandle.getHivent()
        @_marker.setLatLng([hivent.lat, hivent.long])

      else
        hivent = @_endHiventHandle.getHivent()
        @_marker.setLatLng([hivent.lat, hivent.long])

    else if @_markerVisible
      @_map.removeLayer @_marker
      @_markerVisible = false

  # ============================================================================
  _isMarkerVisible: (date) ->

    if @_startMarker and @_endMarker
      date > @_startHiventHandle.getHivent().startDate and date < @_endHiventHandle.getHivent().endDate
    else if @_startMarker
      date > @_startHiventHandle.getHivent().startDate and date < @_endHiventHandle.getHivent().startDate
    else if @_endMarker
      date > @_startHiventHandle.getHivent().endDate and date < @_endHiventHandle.getHivent().endDate
    else
      date > @_startHiventHandle.getHivent().endDate and date < @_endHiventHandle.getHivent().startDate


  # ============================================================================
  _isMarkerMoving: (date) ->

    date > @_startHiventHandle.getHivent().endDate and date < @_endHiventHandle.getHivent().startDate

