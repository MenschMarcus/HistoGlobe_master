window.HG ?= {}

# ==============================================================================
# MODEL class
# contains data about a specific AreaChange for one specific area
# and can execute it
#   old area            -> new area
#   old area name       -> new area name
#   old area territory  -> new area territory
# ==============================================================================


class HG.AreaChange

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (data) ->

    @id               = data.id
    @hivent           = data.hivent           # HG.Hivent

    @operation        = data.operation        # 'ADD', 'DEL', 'TCH' or 'NCH'

    @areaHandle       = data.areaHandle       # HG.AreaHandle
    @oldAreaName      = data.oldAreaName      # HG.AreaName
    @newAreaName      = data.newAreaName      # HG.AreaName
    @oldAreaTerritory = data.oldAreaTerritory # HG.AreaTerritory
    @newAreaTerritory = data.newAreaTerritory # HG.AreaTerritory


  # ============================================================================
  # execute the change: update model and view based on the change direction
  # ============================================================================

  execute: (direction) ->
    # +1: execute change forward
    # -1: execute change backward

    switch @operation

      # ------------------------------------------------------------------------
      when 'ADD'    # add area

        # forward => show new area
        if direction is 1
          @newAreaName.area.name            = @newAreaName
          @newAreaTerritory.area.territory  = @newAreaTerritory
          @areaHandle.show()

        # backward => hide new area
        else
          @newAreaName.area.name            = null
          @newAreaTerritory.area.territory  = null
          @areaHandle.hide()

      # ------------------------------------------------------------------------
      when 'DEL'    # delete area

        # forward => hide old area
        if direction is 1
          @oldAreaName.area.name            = null
          @oldAreaTerritory.area.territory  = null
          @areaHandle.hide()

        # backward => show old area
        else
          @oldAreaName.area.name            = @oldAreaName
          @oldAreaTerritory.area.territory  = @oldAreaTerritory
          @areaHandle.show()

      # ------------------------------------------------------------------------
      when 'TCH'    # change area territory

        # forward => update with new territory
        if direction is 1
          @oldAreaTerritory.area.territory  = @newAreaTerritory
          @areaHandle.updateTerritory()

        # backward => update with old territory
        else
          @oldAreaTerritory.area.territory  = @oldAreaTerritory
          @areaHandle.updateTerritory()

      # ------------------------------------------------------------------------
      when 'NCH'    # change area name

        # forward => update with new name
        if direction is 1
          @oldAreaName.area.name  = @newAreaName
          @areaHandle.updateName()

        # backward => update with old name
        else
          @oldAreaName.area.name  = @oldAreaName
          @areaHandle.updateName()

