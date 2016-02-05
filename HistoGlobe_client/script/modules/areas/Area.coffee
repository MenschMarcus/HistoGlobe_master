window.HG ?= {}

class HG.Area

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (area) ->
    @_id = area.id

    @_geom = area.geometry
    bbox = @_calcBoundingBox()

    @_commName = area.properties.name
    # @_commName = area.properties.commName
    # @_fullName = area.properties.fullName

    @_labelName = area.properties.name
    @_labelPos = [
      (bbox[0]+bbox[2])/2,
      (bbox[1]+bbox[3])/2
    ]

    @

  # ============================================================================
  getId: () ->           @_id
  getGeometry: () ->     @_geom
  getLabelName: () ->    @_labelName
  getLabelPos: () ->     @_labelPos


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _calcBoundingBox: () ->

    minLat = 180
    minLng = 90
    maxLat = -180
    maxLng = -90

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

    [minLat, minLng, maxLat, maxLng]
