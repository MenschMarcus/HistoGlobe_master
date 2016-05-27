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
  constructor: (data) ->

    @id             = data.id

    # superordinate: AreaChange (historical context)
    @startChange    = null            # HG.AreaChange
    @updateChanges  = []              # HG.AreaChange
    @endChange      = null            # HG.AreaChange

    # superordinate: AreaHandle
    @handle         = null            # HG.AreaHandle

    # properties (can change over time)
    @isUniverse     = data.universe   # bool
    @territory      = null            # HG.AreaTerritory
    @name           = null            # HG.AreaName

    # historical relations
    @predecessors   = []              # HG.Area
    @successors     = []              # HG.Area
