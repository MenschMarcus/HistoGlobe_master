window.HG ?= {}

# ============================================================================
# MODEL class (DTO)
# contains data about each Area in the system
# geom = geojson object
# names = {
#   'commonName': string,
#   'pos':        {'lat': float, 'lng': float}
# }

class HG.Area

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_id, geom=null, @_names={}) ->
    @_geom = @_jsonToArray geom   # assumes input is leaflet layer
    @_calcNamePos()
    @_focused = no    # is area currently in focus (hovered)?
    @_selected = no   # is area currently selected?
    @_treated = no    # for edit mode: area has already been treated?

  # ============================================================================
  getId: () ->            @_id

  # ============================================================================
  setGeometry: (geom) ->  @_geom = geom
  setGeom: (geom) ->      @_geom = geom
  getGeometry: () ->      @_geom
  getGeom: () ->          @_geom
  getCenter: () ->        @_center

  # ============================================================================
  setNames: (names) ->    @_names = names
  getNames: () ->         @_names

  # ============================================================================
  deselect: () ->         @_selected = no
  select: () ->           @_selected = yes
  isSelected: () ->       @_selected

  # ============================================================================
  unfocus: () ->          @_focused = no
  focus: () ->            @_focused = yes
  isFocused: () ->        @_focused

  # ============================================================================
  treat: () ->            @_treated = yes
  untreat: () ->          @_treated = no
  isTreated: () ->        @_treated


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # ensure that each geometry put into an HG.Area is valid for Leaflet
  # -> transform geometry from geojson into leaflet layer
  _jsonToArray: (inCoords) ->
    geom = []

    # error handling: empty layer because of non-existing geometry
    if inCoords.coordinates.length is 0
      geom = [[]]

    else
      data = L.GeoJSON.geometryToLayer inCoords
      if inCoords.type is "Polygon" or inCoords.type is "LineString"
        geom.push data._latlngs
      else if inCoords.type is "MultiPolygon" or inCoords.type is "MultiLineString"
        for id, layer of data._layers
          geom.push layer._latlngs

    geom


  # ============================================================================
  _calcNamePos: () ->

    minLat = 180.0
    minLng = 90.0
    maxLat = -180.0
    maxLng = -90.0

    # only take largest subpart of the area into account
    maxIndex = 0
    for area, i in @_geom
      if area.length > @_geom[maxIndex].length
        maxIndex = i

    # find smallest and largest lat and long coordinates of all points in largest subpart
    if  @_geom[maxIndex].length > 0
      for coords in @_geom[maxIndex]
        if coords.lat < minLat then minLat = coords.lat
        if coords.lat > maxLat then maxLat = coords.lat
        if coords.lng < minLng then minLng = coords.lng
        if coords.lng > maxLng then maxLng = coords.lng

    @_center = {
      'lat': (minLat+maxLat)/2,
      'lng': (minLng+maxLng)/2
    }
