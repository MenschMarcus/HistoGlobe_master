window.HG ?= {}

# ============================================================================
#

class HG.Point extends HG.Geometry

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (inCoordinates) ->

    @_type = 'Point'
    @_lng = null
    @_lat = null

    if @_checkIfPointArr inCoordinates
      @_lng = inCoordinates[0]
      @_lat = inCoordinates[1]

    else if @_checkIfPointObj inCoordinates
      @_lng = inCoordinates.lng
      @_lat = inCoordinates.lat

    # both coordinates must be given and valid
    @_isValid = no if (not @_lng) or (not @_lat)
    @_isValid = no if (isNaN @_lng) or (isNaN @_lat)

    super null


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _getCoordinates: (flipped=no) ->
    if not flipped then [@_lng, @_lat] else [@_lat, @_lng]

  # ============================================================================
  _checkIfPointArr: (coordinates) ->
    (coordinates?) and
    (Array.isArray(coordinates)) and   # checks if array
    (coordinates.length is (2)) and
    (not isNaN(coordinates[0])) and (not isNaN(coordinates[1])) and
    (isFinite(coordinates[0])) and (isFinite(coordinates[1]))

  # ----------------------------------------------------------------------------
  _checkIfPointObj: (coordinates) ->
    (coordinates?) and
    (coordinates.constructor is Object) and
    (coordinates.hasOwnProperty('lat')) and
    (coordinates.hasOwnProperty('lng'))

  # ============================================================================
  # special calculation for bounding box and center -> it is the point itself
  _getBoundingBox: (flipped=no) ->
    if not flipped then [@_lng, @_lng, @_lat, @_lat] else  [@_lat, @_lat, @_lng, @_lng]

  _getCenter: (flipped=no) ->
    if not flipped then [@_lng, @_lat] else [@_lat, @_lng]
