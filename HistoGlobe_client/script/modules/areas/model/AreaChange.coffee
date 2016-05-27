window.HG ?= {}

# ==============================================================================
# MODEL class
# contains data about a specific AreaChange for one specific area
# and can execute it
#
# AreaChange <-> HistoricalGeographicOperation
#
# ------------------------------------------------------------------------------
# operation             area change terr change name change
# id    name            old -> new  old -> new  old -> new
# ------------------------------------------------------------------------------
# UNI - Unification     1+  -> 1    -           -
# INC - Incorporation   1+  -> 1    1   -> 1    -
# SEP - Separation      1   -> 2+   -           -
# SEC - Secession       1   -> 1+   1   -> 1    -
# NCH - Name Change     -           -           1   -> 1
# ==============================================================================


class HG.AreaChange

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ----------------------------------------------------------------------------
  constructor: (@id) ->

    # init members
    @oldAreas = []                # Area
    @updateArea = null            # Area
    @newAreas = []                # Area
    @oldAreaNames = []            # AreaName
    @newAreaNames = []            # AreaName
    @oldAreaTerritories = []      # AreaTerritory
    @newAreaTerritories = []      # AreaTerritory

    # rest implemented in derived class

  # ----------------------------------------------------------------------------
  destroy: () ->
  # implemented in derived class

  # ----------------------------------------------------------------------------
  execute: () ->

    # forward change
    if direction is 1

      for newArea in @newAreas
        newArea.handle.show()

      for oldArea in @oldAreas
        oldArea.handle.hide()

      for newName in @newAreaNames
        newName.area.name = newName
        newName.area.handle.update()

      for newTerritory in @newAreaTerritories
        newTerritory.area.territory = newTerritory
        newTerritory.area.handle.update()


    # backward change
    else # direction is -1

      for newArea in @newAreas
        newArea.handle.hide()

      for oldArea in @oldAreas
        oldArea.handle.show()

      for oldName in @oldAreaNames
        oldName.area.name = oldName
        oldName.area.handle.update()

      for oldTerritory in @oldAreaTerritories
        oldTerritory.area.territory = oldTerritory
        oldTerritory.area.handle.update()