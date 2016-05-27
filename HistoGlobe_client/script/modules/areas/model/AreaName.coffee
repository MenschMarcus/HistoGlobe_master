window.HG ?= {}

# ============================================================================
# MODEL class
# contains data about an AreaName associated to an Area
# ============================================================================

class HG.AreaName

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (data) ->

    @id           = data.id

    # superordinate: Area
    @area         = null                # HG.Area

    # superordinate: AreaChange (historical context)
    @startChange  = null                # HG.AreaChange
    @endChange    = null                # HG.AreaChange

    # properties
    @shortName    = data.shortName      # String
    @formalName   = data.formalName     # String