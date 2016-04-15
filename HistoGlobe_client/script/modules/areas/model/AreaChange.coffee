window.HG ?= {}

# ==============================================================================
# MODEL class
# contains data about a specific AreaChange for one specific area
# and can execute it
#   old area            -> new area
#   old area name       -> new area name
#   old area territory  -> new area territory
#
# ------------------------------------------------------------------------------
# operations:
#   ADD) add new area:         -> A
#   DEL) delete old area:    A ->
#   NCH) name change:        A -> A
#   TCH) territory change:   A -> A
# ==============================================================================


class HG.AreaChange

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (data) ->

    @id               = data.id
    @historicalChange = data.historicalChange # HG.HistoricalChange

    @operation        = data.operation        # 'ADD', 'DEL', 'TCH' or 'NCH'

    @area             = data.area             # HG.Area
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
          @area.handle.show()

        # backward => hide new area
        else
          @newAreaName.area.name            = null
          @newAreaTerritory.area.territory  = null
          @area.handle.hide()

      # ------------------------------------------------------------------------
      when 'DEL'    # delete area

        # forward => hide old area
        if direction is 1
          @oldAreaName.area.name            = null
          @oldAreaTerritory.area.territory  = null
          @area.handle.hide()

        # backward => show old area
        else
          @oldAreaName.area.name            = @oldAreaName
          @oldAreaTerritory.area.territory  = @oldAreaTerritory
          @area.handle.show()

      # ------------------------------------------------------------------------
      when 'TCH'    # change area territory

        # forward => update with new territory
        if direction is 1
          @oldAreaTerritory.area.territory  = @newAreaTerritory
          @area.handle.updateTerritory()

        # backward => update with old territory
        else
          @oldAreaTerritory.area.territory  = @oldAreaTerritory
          @area.handle.updateTerritory()

      # ------------------------------------------------------------------------
      when 'NCH'    # change area name

        # forward => update with new name
        if direction is 1
          @oldAreaName.area.name  = @newAreaName
          @area.handle.updateName()

        # backward => update with old name
        else
          @oldAreaName.area.name  = @oldAreaName
          @area.handle.updateName()

