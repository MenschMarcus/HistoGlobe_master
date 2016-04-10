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

    @territory    = null    # HG.AreaTerritory
    @name         = null    # HG.AreaName

    @startHivent  = null    # HG.HiventHandle
    @endHivent    = null    # HG.HiventHandle
    @predecessors = []      # HG.AreaHandle
    @successors   = []      # HG.AreaHandle
    @sovereign    = null    # HG.AreaHandle
    @dependencies = []      # HG.AreaHandle