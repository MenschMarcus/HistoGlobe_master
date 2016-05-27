window.HG ?= {}

# ==============================================================================
# MODEL class
# contains data about a specific SEC AreaChange
#
# ------------------------------------------------------------------------------
# operation             area change terr change name change
# id    name            old -> new  old -> new  old -> new
# ------------------------------------------------------------------------------
# UNI - Unification     1+  -> 1    -           -
# ==============================================================================


class HG.AreaChange.UNI extends HG.AreaChange

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ----------------------------------------------------------------------------
  constructor: (id, oldAreas, newArea) ->

    # create member variables in base class constructor
    super(id)

    ## establish double links

    # AreaChange <-> newArea
    @newAreas[0] = newArea
    newArea.startChange = @

    @newAreaNames[0] = newArea.name
    newArea.name.startChange = @

    @newAreaTerritories[0] = newArea.territory
    newArea.territory.startChange = @

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
      oldArea.successors.push newArea
      newArea.predecessor.push oldArea


  # ----------------------------------------------------------------------------
  destroy: () ->

    ## remove historical relationships
    newArea = @newAreas[0]
    for oldArea in @oldAreas
      succIdx = oldArea.successors.indexOf newArea
      oldArea.successors.splice succIdx,1
      predIdx = newArea.predecessor.indexOf oldArea
      newArea.predecessor.splice predIdx,1

    ## remove double-links

    # AreaChange <-> newArea
    newArea.startChange =             null
    newArea.name.startChange =        null
    newArea.territory.startChange =   null

    # AreaChange <-> oldAreas
    for oldArea in @oldAreas
      oldArea.endChange =             null
      oldArea.name.endChange =        null
      oldArea.territory.endChange =   null