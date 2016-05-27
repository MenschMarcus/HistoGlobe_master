window.HG ?= {}

# ==============================================================================
# MODEL class
# contains data about a specific SEC AreaChange
#
# ------------------------------------------------------------------------------
# operation             area change terr change name change
# id    name            old -> new  old -> new  old -> new
# ------------------------------------------------------------------------------
# SEP - Separation      1   -> 2+   -           -
# ==============================================================================


class HG.AreaChange.SEP extends HG.AreaChange

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ----------------------------------------------------------------------------
  constructor: (id, oldArea, newAreas) ->

    # create member variables in base class constructor
    super(id)

    ## establish double links

    # AreaChange <-> oldArea
    @oldAreas[0] = oldArea
    oldArea.endChange = @

    @oldAreaNames[0] = oldArea.name
    oldArea.name.endChange = @

    @oldAreaTerritories[0] = oldArea.territory
    oldArea.territory.endChange = @

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
      newArea.predecessors.push oldArea
      oldArea.successors.push newArea


  # ----------------------------------------------------------------------------
  destroy: () ->

    ## remove historical relationships
    oldArea = @oldAreas[0]
    for newArea in @newAreas
      succIdx = newArea.predecessors.indexOf oldArea
      newArea.predecessors.splice succIdx,1
      predIdx = oldArea.successors.indexOf newArea
      oldArea.successors.splice predIdx,1

    ## remove double-links

    # AreaChange <-> oldArea
    oldArea.endChange =               null
    oldArea.name.endChange =          null
    oldArea.territory.endChange =     null

    # AreaChange <-> newAreas
    for newArea in @newAreas
      newArea.startChange =           null
      newArea.name.startChange =      null
      newArea.territory.startChange = null