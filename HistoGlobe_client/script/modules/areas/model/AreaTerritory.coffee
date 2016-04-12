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
    # to reset representativePoint: @geometry.getCenter()

    @startHivent          = null    # HG.HiventHandle
    @endHivent            = null    # HG.HiventHandle