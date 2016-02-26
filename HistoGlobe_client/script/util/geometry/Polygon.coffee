window.HG ?= {}

# ============================================================================
#

class HG.Polygon extends HG.Geometry

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (inCoordinates) ->

    @_type = 'Polygon'
    @_isValid = yes
    @_polylines = []

    for polyline in inCoordinates
      newPolyline = new HG.Polyline polyline
      @_isValid = no if not newPolyline.isValid()
      @_polylines.push newPolyline

    ## hole restructuring
    # goal: create the correct structure of holes in the geometry

    super @_polylines


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################