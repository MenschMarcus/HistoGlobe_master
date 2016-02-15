window.HG ?= {}

class HG.AreaController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onAddArea"

    defaultConfig =
      JSONPaths: undefined,

    @_config = $.extend {}, defaultConfig, config

    # area handling
    @_areas = []          # set of all HG areas (id, geometry, ...)

    for file in @_config.JSONPaths
      $.getJSON file, (areas) =>
        for area in areas.features
          area.geometry = @_geometryFromGeoJSONToLeaflet area.geometry
          names = {
            'commonName': area.properties.name
            'pos': @_calcNamePos area.geometry
          }
          newArea = new HG.Area area.id, area.geometry, names
          @_areas.push newArea
          @notifyAll "onAddArea", newArea


  # ============================================================================
  hgInit: (@_hgInstance) ->
    @_hgInstance.areaController = @


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # transform geometry from geojson into leaflet layer
  _geometryFromGeoJSONToLeaflet: (inCoords) ->
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
  _calcNamePos: (geom) ->

    minLat = 180.0
    minLng = 90.0
    maxLat = -180.0
    maxLng = -90.0

    # only take largest subpart of the area into account
    maxIndex = 0
    for area, i in geom
      if area.length > geom[maxIndex].length
        maxIndex = i

    # find smallest and largest lat and long coordinates of all points in largest subpart
    if  geom[maxIndex].length > 0
      for coords in geom[maxIndex]
        if coords.lat < minLat then minLat = coords.lat
        if coords.lat > maxLat then maxLat = coords.lat
        if coords.lng < minLng then minLng = coords.lng
        if coords.lng > maxLng then maxLng = coords.lng

    return {
      'lat': (minLat+maxLat)/2,
      'lng': (minLng+maxLng)/2
    }

  # ============================================================================
  # find area/label
  # TODO: get better algorithm
  _getAreaById: (id) ->
    if id?
      for area in @_areas
        if area.getId() is id
          return area
    undefined
