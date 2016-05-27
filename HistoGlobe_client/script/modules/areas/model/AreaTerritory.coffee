window.HG ?= {}

# ============================================================================
# MODEL class
# contains data about an AreaName associated to an Area
# ============================================================================

class HG.AreaTerritory

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (data) ->

    @id                   = data.id

    # superordinate: Area
    @area                 = null                      # HG.Area

    # superordinate: AreaChange (historical context)
    @startChange          = null                      # HG.AreaChange
    @endChange            = null                      # HG.AreaChange

    # properties
    @geometry             = data.geometry             # HG.Geometry
    @representativePoint  = data.representativePoint  # HG.Point


  # ============================================================================
  resetRepresentativePoint: () ->
    @representativePoint = @geometry.getCenter()