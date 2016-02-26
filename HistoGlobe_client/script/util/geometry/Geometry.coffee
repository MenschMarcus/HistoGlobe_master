window.HG ?= {}

# ============================================================================
# represents a polypolygon geometry in various different formats
# support for:
#     polyline        LineString
#     polygon         Polygon
#     polypolygon     MultiPolygon

# ============================================================================
#   GeoJSON object -> json(PtArr?=no)
#     -> returns only geometry object; to use in existing JSON object:
#         {'type': 'feature', 'geometry': myGeometry.json(), 'properties': ...}
#     -> if ptArr=yes, the output coordinates will be in an array [lat, lng]
#     -> if ptArr=no*, the output coordinates will be in an object {'lat': float, 'lng': float}
#   geometry array -> array(PtArr?=no)
#     -> if ptArr=yes, the output coordinates will be in an array [lat, lng]
#     -> if ptArr=no*, the output coordinates will be in an object {'lat': float, 'lng': float}
#   leaflet layer  -> new L.multiPolygon myGeometry.array(), options
#   WKT string     -> .wkt()
#   JSTS object    -> .jsts()
#     -> to be used in JSTS library: http://bjornharrtell.github.io/jsts/

# ============================================================================
# The internal strucutre of each geometry array is:
# 'type': 'MultiPolygon' or 'Polygon' or 'LineString'
# 'coordinates':
#   [           1. array: polypolygon       [n]
#     [         2. array: polygon           [1: no holes, 2+: holes]
#       [       3. array: polyline (closed) [m]
#         {     4. object: point            [2]
#           'lat': float, 'lng': float    -> point object (PtObj)
#         }
#     OR: [  lng, lat  ]                  -> point array  (PtArr)
#       ]
#     ]
#   ]
# N.B. each polygon can contain inner and outer rings
# => polygon usually contains only one polyline

class HG.Geometry

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_geometries) ->

    @_json = {
      'type':         @type()
      'coordinates':  @coordinates()
    }


  ### GETTER ###
  # ============================================================================
  type: () ->             @_type

  # ----------------------------------------------------------------------------
  json: () ->             @_json

  # ----------------------------------------------------------------------------
  coordinates: () ->      @_getCoordinates()
  array: ()->             @_getCoordinates()
  get: ()->               @_getCoordinates()

  # ----------------------------------------------------------------------------
  wkt: () ->              @_toWkt @_json

  # ----------------------------------------------------------------------------
  jsts: () ->             @_toJsts @_toWkt @_json

  # ----------------------------------------------------------------------------
  isValid: () ->          @_isValid

  # ----------------------------------------------------------------------------
  # bounding box structure: minLng, maxLng, minLat, maxLat
  getBoundingBox: () ->   @_calcBoundingBox()
  getCenter: () ->        @_calcCenter()

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _getCoordinates: () ->
    coordinates = []
    coordinates.push geometry.coordinates() for geometry in @_geometries
    coordinates

  # ============================================================================
  _toWkt: (json) ->
    # error handling
    return "MULTIPOLYGON EMPTY" if json.coordinates is null

    # wicket can not read array, only json
    wicket = new Wkt.Wkt
    wicket.fromJson json
    wicket.write()

  # ----------------------------------------------------------------------------
  _toJsts: (wkt) ->
    # WKTReader for jsts can not read pure array, only wkt or json
    # create jsts object
    wktReader = new jsts.io.WKTReader
    wktReader.read wkt


  # ============================================================================

  # ----------------------------------------------------------------------------
  _calcBoundingBox: () ->
    # approach: get bounding box of level underneath and
    # calculate this levels' bounding box based on them
    # what a great idea :)

    thisBbox = @_geometries[0].getBoundingBox()

    for lowerGeom in @_geometries
      lowerBbox = lowerGeom.getBoundingBox()
      thisBbox[0] = Math.min thisBbox[0], lowerBbox[0]    # minLng
      thisBbox[1] = Math.max thisBbox[1], lowerBbox[1]    # maxLng
      thisBbox[2] = Math.min thisBbox[2], lowerBbox[2]    # minLat
      thisBbox[3] = Math.max thisBbox[3], lowerBbox[3]    # maxLat

    # special case: points have no structure underneath, take their coordinates
    thisBbox


  # ----------------------------------------------------------------------------
  _calcCenter: () ->
    # approach: get bounding box of largest geometry underneath and take its center
    # TODO: is that actually a good approach? Does that actually matter?
    # -> I'm going to redefine it later anyways...

    center = [0,0]

    # find largest sub-part
    maxSize = 0
    for lowerGeom in @_geometries
      bbox = lowerGeom.getBoundingBox()
      size = (Math.abs bbox[1]-bbox[0])*(Math.abs bbox[3]-bbox[2])
      # new largest sub-part found!
      if size > maxSize
        maxSize = size
        # update center
        center[0] = ((bbox[0]+bbox[1])/2)
        center[1] = ((bbox[2]+bbox[3])/2)

    center