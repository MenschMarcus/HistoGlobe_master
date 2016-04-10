window.HG ?= {}

# ============================================================================
# MODEL class
# contains data about an AreaName associated to an Area
# DTO => no functionality
# ============================================================================

class HG.AreaName

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (data) ->

    @id           = data.id
    @shortName    = data.shortName
    @formalName   = data.formalName