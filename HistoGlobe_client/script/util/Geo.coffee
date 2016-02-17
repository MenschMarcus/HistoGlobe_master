window.HG ?= {}

# ============================================================================
# GeoObject representing the geometry for any MultiPolygon used in HistoGlobe
# receives (input): leaflet layer, geoJSON, wkt
# sends (output):   geoJSON, wkt

class HG.Geo

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (inGeo) ->
    @_wkt = null
    @_geojson = null
    if @_checkLeaflet inGeo
      @_wkt = @_leaflet2wkt inGeo
      @_geojson = @_wkt2json @_wkt
    else if @_checkGeoJson inGeo
      @_geojson = @_geoJson2wkt
      @_wkt = @_json2wkt
    else
      console.error "The date you entered seems to be neither GeoJSON nor WKT :("


  # ============================================================================
  getWKT: () ->       @_wkt
  getGeoJSON: () ->   @_geojson


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _checkLeaflet: (inObj) ->
    if inObj instanceof L.Marker or
       inObj instanceof L.Polyline or
       inObj instanceof L.MultiPolyline or
       inObj instanceof L.Polygon or
       inObj instanceof L.MultiPolygon
      true
    else
      false

  _leaflet2wkt: (inLayer) ->
    # credits: Bryan McBride - thank you!
    # https://gist.github.com/bmcbride/4248238
    # -> extended to deal with MultiPolylines and MultiPolygons as well
    # => returns array of wkt strings

    lng = undefined
    lat = undefined
    inLayers = [inLayer]
    wktStrings = []
    # preparation: transform MultiPolygons to multiple polygon layers *haha*
    if inLayer instanceof L.MultiPolygon or layer instanceof L.MultiPolyline
      for id, layer of inLayer._layers
        inLayers.push layer
    # create wkt string for each layer
    for layer in inLayers
      coords = []
      if layer instanceof L.Polygon or layer instanceof L.Polyline
        latlngs = layer.getLatLngs()
        i = 0
        while i < latlngs.length
          latlngs[i]
          coords.push latlngs[i].lng + ' ' + latlngs[i].lat
          if i == 0
            lng = latlngs[i].lng
            lat = latlngs[i].lat
          i++
        if layer instanceof L.Polygon
          wktStrings.push 'POLYGON((' + coords.join(',') + ',' + lng + ' ' + lat + '))'
        else if layer instanceof L.Polyline
          wktStrings.push 'LINESTRING(' + coords.join(',') + ')'
      else if layer instanceof L.Marker
        wktStrings.push 'POINT(' + layer.getLatLng().lng + ' ' + layer.getLatLng().lat + ')'
    wktStrings

  # ============================================================================
  _checkGeoJson: (inObj) ->
    isJson = true
    try
      json = $.parseJSON inObj
    catch e
      isJson = false
    isJson

  _geoJson2wkt: (inJson) ->
