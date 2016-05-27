window.HG ?= {}

# ==============================================================================
# MODEL class
# contains data about a specific SEC AreaChange
#
# ------------------------------------------------------------------------------
# operation             area change terr change name change
# id    name            old -> new  old -> new  old -> new
# ------------------------------------------------------------------------------
# SEC - Secession       1   -> 1+   1   -> 1    -
# ==============================================================================


class HG.AreaChange.SEC extends HG.AreaChange

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ----------------------------------------------------------------------------
  constructor: (id, preserveArea, oldTerritory, newAreas) ->

    # create member variables in base class constructor
    super(id)

    ## establish double links

    # AreaChange <-> preserveArea
    @updateArea = preserveArea
    preserveArea.updateChanges.push @

    # AreaChange <-> oldTerritory
    @oldAreaTerritories[0] = oldTerritory
    oldTerritory.endChange = @

    # AreaChange <-> newTerritory
    newTerritory = preserveArea.territory
    @newAreaTerritories[0] = newTerritory
    newTerritory.startChange = @

    # AreaChange <-> newAreas
    for newArea in newAreas

      @newAreas.push newArea
      newArea.startChange = @

      @newAreaNames.push newArea.name
      newArea.name.startChange = @

      @newAreaTerritories.push newArea.territory
      newArea.territory.startChange = @

    ## establish historical relationships
    for newArea in newAreas
      newArea.predecessors.push preserveArea
      preserveArea.successors.push newArea

  # ----------------------------------------------------------------------------
  destroy: () ->

    ## remove historical relationships
    preserveArea = @updateArea
    for newArea in @newAreas
      succIdx = newArea.predecessors.indexOf preserveArea
      newArea.predecessors.splice succIdx,1
      predIdx = preserveArea.successors.indexOf newArea
      preserveArea.successors.splice predIdx,1

    ## remove double-links

    # AreaChange <-> preserveArea
    updIdx = preserveArea.updateChanges.indexOf @
    preserveArea.updateChanges.splice updIdx,1

    # AreaChange <-> newAreas
    for newArea in @newAreas
      newArea.startChange =               null
      newArea.name.startChange =          null
      newArea.territory.startChange =     null

    # AreaChange <-> oldTerritory
    @oldAreaTerritories[0].endChange =    null

    # AreaChange <-> newTerritory
    @newAreaTerritories[0].startChange =  null