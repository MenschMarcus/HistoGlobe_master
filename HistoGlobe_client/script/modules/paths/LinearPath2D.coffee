window.HG ?= {}

class HG.LinearPath2D extends HG.Path

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (startHiventHandle, endHiventHandle, category, map, color) ->

    HG.Path.call @, startHiventHandle, endHiventHandle, category, color

    @_map = map
    @_arc = undefined

    p1 = new HG.Vector @_startHiventHandle.getHivent().long, @_startHiventHandle.getHivent().lat
    p2 = new HG.Vector @_endHiventHandle.getHivent().long, @_endHiventHandle.getHivent().lat

    @_initArc p1, p2

  # ============================================================================
  getMarkerPos: (date) ->
    start = @_startHiventHandle.getHivent().endDate.getTime()
    end   = @_endHiventHandle.getHivent().startDate.getTime()
    now   = date.getTime()

    delta = (now - start)/(end - start)

    long = @_startHiventHandle.getHivent().long + delta*(@_endHiventHandle.getHivent().long - @_startHiventHandle.getHivent().long)
    lat = @_startHiventHandle.getHivent().lat + delta*(@_endHiventHandle.getHivent().lat - @_startHiventHandle.getHivent().lat)

    {long:long, lat:lat}

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _initArc: (p1, p2) ->

    points = []
    points.push {lng: p1.at(0), lat: p1.at(1)}
    points.push {lng: p2.at(0), lat: p2.at(1)}

    @_arc = new L.polyline points, {
      color: @_color
      lineCap: "butt"
      weight: "2"
      opacity: "0.8"
      dashArray: "5, 2"
    }

    @_map.addLayer @_arc

  # ============================================================================
  _destroy: () ->
    @_map.removeLayer @_arc
    @_arc = null













