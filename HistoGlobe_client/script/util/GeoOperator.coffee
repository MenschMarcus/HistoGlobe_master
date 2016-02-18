window.HG ?= {}

# ============================================================================
# this class can perform the necessary geo operations given a set of leaflet layers
#   union = cascaded union = dissolve
#   intersection = cascaded intersection
# ============================================================================

class HG.GeoOperator

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->
    @_wkt = new Wkt.Wkt

  # ============================================================================
  # credits: elrobis - thank you!
  # http://gis.stackexchange.com/questions/85229/looking-for-dissolve-algorithm-for-javascript
  # -> extended to perform cascaded union (unifies all (Multi)Polygons in array of wkt representations of (Multi)Polygons)
  union: (jsonObjs) ->
    wktStrings = @_json2wkt jsonObjs                          # INPUT
    wktGeoms = @_wkt2array wktStrings

    # TODO: could be more efficient with a tree, but I really do not care about this at this point :P
    unionGeom = wktGeoms[0]                                   # PROCESSING
    idx = 1 # = start at the second geometry
    while idx < wktGeoms.length
      unionGeom = unionGeom.union wktGeoms[idx]
      idx++

    wktOut = @_write2wkt unionGeom                            # OUTPUT
    @_wkt2json wktOut

  # ============================================================================
  intersection: (jsonObjs) ->
    wktStrings = @_json2wkt jsonObjs                          # INPUT
    wktGeoms = @_wkt2array wktStrings

    # TODO: could be more efficient with a tree, but I really do not care about this at this point :P
    intersectionGeom = wktGeoms[0]                            # PROCESSING
    idx = 1 # = start at the second geometry
    while idx < wktGeoms.length
      intersectionGeom = intersectionGeom.intersection wktGeoms[idx]
      idx++

    wktOut = @_write2wkt intersectionGeom                    # OUTPUT
    @_wkt2json wktOut


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  ## HELPER CONVERSION FUNCTIONS ##

  # ============================================================================
  _json2wkt: (jsonObjs) ->
    wkts = []
    for obj in jsonObjs
      @_wkt.fromObject obj
      wkts.push @_wkt.write()
    wkts

  # ============================================================================
  _wkt2json: (wktObj) ->
    @_wkt.read wktObj
    @_wkt.toJson()

  # ============================================================================
  # Instantiate JSTS WKTReader and get two JSTS geometry objects
  _wkt2array: (wktStrings) ->
    wktReader = new (jsts.io.WKTReader)
    geoms = []
    geoms.push wktReader.read wkt for wkt in wktStrings
    geoms

  # ============================================================================
  # Instantiate JSTS WKTWriter and get new geometry's WKT
  _write2wkt: (inGeom) ->
    wktWriter = new (jsts.io.WKTWriter)
    wktWriter.write inGeom