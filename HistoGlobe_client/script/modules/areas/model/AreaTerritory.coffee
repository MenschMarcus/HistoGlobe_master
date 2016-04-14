window.HG ?= {}

# ============================================================================
# MODEL class
# contains data about an AreaName associated to an Area
# DTO => no functionality
# ============================================================================

class HG.AreaTerritory

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (data) ->

    @id                   = data.id
    @geometry             = data.geometry
    @representativePoint  = data.representativePoint

    @area                 = null    # HG.Area

    @startChange          = null    # HG.AreaChange
    @endChange            = null    # HG.AreaChange


    # to reset representativePoint: @geometry.getCenter()