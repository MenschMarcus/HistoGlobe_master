window.HG ?= {}

# ==============================================================================
# MODEL class
# contains data about a specific INC AreaChange
#
# ------------------------------------------------------------------------------
# operation             area change terr change name change
# id    name            old -> new  old -> new  old -> new
# ------------------------------------------------------------------------------
# INC - Incorporation   1+  -> 1    1   -> 1    -
# ==============================================================================


class HG.AreaChange.INC extends HG.AreaChange

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ----------------------------------------------------------------------------
  constructor: (id, preserveArea, oldTerritory, oldAreas) ->

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

    # AreaChange <-> oldAreas
    for oldArea in oldAreas

      @oldAreas.push oldArea
      oldArea.endChange = @

      @oldAreaNames.push oldArea.name
      oldArea.name.endChange = @

      @oldAreaTerritories.push oldArea.territory
      oldArea.territory.endChange = @

    ## establish historical relationships
    for oldArea in oldAreas
      oldArea.successors.push preserveArea
      preserveArea.predecessors.push oldArea

  # ----------------------------------------------------------------------------
  destroy: () ->

    ## remove historical relationships
    preserveArea = @updateArea
    for oldArea in @oldAreas
      succIdx = oldArea.successors.indexOf preserveArea
      oldArea.successors.splice succIdx,1
      predIdx = preserveArea.predecessors.indexOf oldArea
      preserveArea.predecessors.splice predIdx,1

    ## remove double-links

    # AreaChange <-> preserveArea
    updIdx = preserveArea.updateChanges.indexOf @
    preserveArea.updateChanges.splice updIdx,1

    # AreaChange <-> oldAreas
    for oldArea in @oldAreas
      oldArea.endChange =                 null
      oldArea.name.endChange =            null
      oldArea.territory.endChange =       null

    # AreaChange <-> oldTerritory
    @oldAreaTerritories[0].endChange =    null

    # AreaChange <-> newTerritory
    @newAreaTerritories[0].startChange =  null