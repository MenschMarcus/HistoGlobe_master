window.HG ?= {}

# ==============================================================================
# MODEL class
# contains data about each Area (territory + name + attributes)
# DTO => no functionality
# ==============================================================================

class HG.Area

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@id) ->

    @territory      = null    # HG.AreaTerritory
    @name           = null    # HG.AreaName

    @startChange    = null    # HG.AreaChange
    @updateChanges  = []      # HG.AreaChange
    @endChange      = null    # HG.AreaChange

    @predecessors   = []      # HG.AreaHandle
    @successors     = []      # HG.AreaHandle
    @sovereignt     = null    # HG.AreaHandle
    @dependencies   = []      # HG.AreaHandle