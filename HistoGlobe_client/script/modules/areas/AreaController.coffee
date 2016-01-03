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
          newArea = new HG.Area area
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
  # find area/label -> get better algorithm
  _getAreaById: (id) ->
    if id?
      for area in @_areas
        if area.getId() is id
          return area
    undefined
