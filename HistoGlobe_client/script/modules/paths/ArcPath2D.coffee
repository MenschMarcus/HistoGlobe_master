window.HG ?= {}

class HG.ArcPath2D extends HG.Path

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (startHiventHandle, endHiventHandle, category, map, color, movingMarker, startMarker, endMarker, curvature=0.5) ->

    HG.Path.call @, startHiventHandle, endHiventHandle, category, color, movingMarker, startMarker, endMarker

    @_map = map
    @_arc = undefined

    @_p1 = new HG.Vector @_startHiventHandle.getHivent().long, @_startHiventHandle.getHivent().lat
    @_p2 = new HG.Vector @_endHiventHandle.getHivent().long, @_endHiventHandle.getHivent().lat

    p3_x = (@_p2.at(0) + @_p1.at(0)) / 2
    p3_y = (@_p2.at(1) + @_p1.at(1)) / 2 + curvature*Math.abs(@_p2.at(1) - @_p1.at(1))
    @_p3 = new HG.Vector p3_x, p3_y

    @_initParabolaParameters @_p1, @_p2, @_p3

  # ============================================================================
  show: (date) ->
    unless @_isVisible
      @_initArc()
      @_updateArc date
      @_updateAnimation date

  # ============================================================================
  hide: () ->
    if @_isVisible
      @_destroy()

  # ============================================================================
  getMarkerPos: (date) ->
    long = @_getLongFromDate date
    lat = @_getLatFromLong long

    {long:long, lat:lat}

  # ============================================================================
  setDate: (date) ->
    # mimic base class
    @_updateAnimation date

    if @_arc?
      @_updateArc date

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # calculates parameters a, b, c of equation y= a * x^2 + b * x + c for three
  # given points
  _initParabolaParameters: (p1, p2, p3) ->
    denom = (p1.at(0) - p2.at(0)) * (p1.at(0) - p3.at(0)) * (p2.at(0) - p3.at(0))

    @_param = {a:0, b:0, c:p3.at(1)}

    if denom isnt 0.0
      a = (p3.at(0) * (p2.at(1) - p1.at(1)) + p2.at(0) * (p1.at(1) - p3.at(1)) + p1.at(0) * (p3.at(1) - p2.at(1))) / denom
      b = (p3.at(0) * p3.at(0) * (p1.at(1) - p2.at(1)) + p2.at(0) * p2.at(0) * (p3.at(1) - p1.at(1)) + p1.at(0) * p1.at(0) * (p2.at(1) - p3.at(1))) / denom
      c = (p2.at(0) * p3.at(0) * (p2.at(0) - p3.at(0)) * p1.at(1) + p3.at(0) * p1.at(0) * (p3.at(0) - p1.at(0)) * p2.at(1) + p1.at(0) * p2.at(0) * (p1.at(0) - p2.at(0)) * p3.at(1)) / denom

      @_param = {a:a, b:b, c:c}

  # ============================================================================
  _getLatFromLong: (long) ->
    long*long * @_param.a + long * @_param.b + @_param.c

  # ============================================================================
  _getLongFromDate: (date) ->
    start = @_startHiventHandle.getHivent().endDate.getTime()
    end   = @_endHiventHandle.getHivent().startDate.getTime()
    now   = date.getTime()

    if start is end
      if now <= start
        long = @_startHiventHandle.getHivent().long
      else
        long = @_endHiventHandle.getHivent().long
    else
      delta = (now - start)/(end - start)
      long = @_startHiventHandle.getHivent().long + delta*(@_endHiventHandle.getHivent().long - @_startHiventHandle.getHivent().long)

  # ============================================================================
  _updateArc: (date) ->

    points = []

    if date > @_startHiventHandle.getHivent().endDate

      curLong = @_p1.at(0)
      endLong = @_p2.at(0)

      if date < @_endHiventHandle.getHivent().startDate
        endLong = @_getLongFromDate date

      dir = 1.0

      if curLong > endLong
        dir = -1.0

      while dir*(endLong - curLong) > 0.0
        lat = @_getLatFromLong curLong
        points.push {lng: curLong, lat: lat}
        curLong += dir/RESOLUTION

      lat = @_getLatFromLong endLong
      points.push {lng: endLong, lat: lat}

    @_arc.setLatLngs points

  # ============================================================================
  _initArc: () ->

    @_arc = new L.polyline [], {
      color: @_color
      lineCap: "butt"
      weight: "3.0"
      opacity: "0.6"
      dashArray: "6, 3"
    }

    @_map.addLayer @_arc
    @_isVisible = true

  # ============================================================================
  _destroy: () ->
    @_isVisible = false
    @_markerVisible = false
    @_map.removeLayer @_arc
    @_map.removeLayer @_marker
    @_arc = null

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

  RESOLUTION = 10 #segments per degree












