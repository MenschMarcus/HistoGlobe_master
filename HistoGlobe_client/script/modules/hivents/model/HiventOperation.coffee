window.HG ?= {}

# ==============================================================================
# MODEL class
# contains data about a specific HiventOperation for one specific area
# and can execute it
#
# HiventOperation <-> HistoricalGeographicOperation
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
#
# ------------------------------------------------------------------------------
# structure of function parameters
# data = {
#   id              int
#   operation       'XXX'
#   oldAreas = [{
#     area          HG.Area
#     name          HG.AreaName
#     territory     HG.AreaTerritory
#   }]
#   newAreas =      ... same structure as oldAreas
#   updateArea = {
#     area          HG.Area
#     oldName       HG.AreaName
#     newName       HG.AreaName
#     oldTerritory  HG.AreaTerritory
#     newTerritory  HG.AreaTerritory
#   }
# }
# ==============================================================================


class HG.HiventOperation

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (data) ->

    ## init members

    @id           = data.id
    @operation  = data.operation
    @oldAreas     = data.oldAreas
    @newAreas     = data.newAreas
    @updateArea   = data.updateArea


    ## establish double-links

    # HiventOperation <- old Areas
    for oldArea in @oldAreas
      oldArea.area.endChange = @
      oldArea.name.endChange = @
      oldArea.territory.endChange = @

    # HiventOperation <- new Areas
    for newArea in @newAreas
      newArea.area.startChange = @
      newArea.name.startChange = @
      newArea.territory.startChange = @

    # HiventOperation <- update Area
    if @updateArea
      @updateArea.area.updateChanges.push @
      @updateArea.oldName?.endChange = @
      @updateArea.newName?.startChange = @
      @updateArea.oldTerritory?.endChange = @
      @updateArea.newTerritory?.startChange = @


    ## establish historical relationships

    switch @operation

      when 'UNI', 'SEP'
        for oldArea in @oldAreas
          for newArea in @newAreas
            oldArea.area.successors.push newArea.area
            newArea.area.predecessors.push oldArea.area

      when 'INC'
        for oldArea in @oldAreas
          oldArea.area.successors.push @updateArea.area
          @updateArea.area.predecessors.push oldArea.area

      when 'SEC'
        for newArea in @newAreas
          @updateArea.area.successors.push newArea.area
          newArea.area.predecessors.push @updateArea.area

  # ============================================================================
  destroy: () ->

    ## remove historical relationships

    switch @operation

      when 'UNI', 'SEP'
        for oldArea in @oldAreas
          for newArea in @newAreas
            succIdx = oldArea.area.successors.indexOf newArea.area
            oldArea.area.successors.splice succIdx, 1
            predIdx = newArea.area.predecessors.indexOf oldArea.area
            newArea.area.predecessors.splice predIdx, 1

      when 'INC'
        for oldArea in @oldAreas
          succIdx = oldArea.area.successors.indexOf @updateArea.area
          oldArea.area.successors.splice succIdx, 1
          predIdx = @updateArea.area.predecessors.indexOf oldArea.area
          @updateArea.area.predecessors.splice predIdx, 1

      when 'SEC'
        for newArea in @newAreas
          succIdx = @updateArea.area.successors.indexOf newArea.area
          @updateArea.area.successors.splice succIdx, 1
          predIdx = newArea.area.predecessors.indexOf @updateArea.area
          newArea.area.predecessors.splice predIdx, 1


    ## remove double-links

    # HiventOperation <- old Areas
    for oldArea in @oldAreas
      oldArea.area.endChange = null
      oldArea.name.endChange = null
      oldArea.territory.endChange = null

    # HiventOperation <- new Areas
    for newArea in @newAreas
      newArea.area.startChange = null
      newArea.name.startChange = null
      newArea.territory.startChange = null

    # HiventOperation <- update Area
    if @updateArea
      updIdx = @updateArea.area.updateChanges.indexOf @
      @updateArea.area.updateChanges.splice updIdx, 1
      @updateArea.oldName?.endChange = null
      @updateArea.newName?.startChange = null
      @updateArea.oldTerritory?.endChange = null
      @updateArea.newTerritory?.startChange = null

  # ============================================================================
  execute: (direction) ->

    # TODO: can lines 51/52 resp. 56/57 be omitted?
    # -> do name/territory reference has to be reset all the time
    # -> actually no, but what about the initial case?

    # forward change
    if direction is 1

      for newArea in @newAreas
        newArea.area.name =       newArea.name
        newArea.area.territory =  newArea.territory
        newArea.area.handle.show()

      for oldArea in @oldAreas
        oldArea.area.name =       null
        oldArea.area.territory =  null
        oldArea.handle.hide()

      if @updateArea
        if @updateArea.newName
          @updateArea.area.name =      @updateArea.newName
        if @updateArea.newTerritory
          @updateArea.area.territory = @updateArea.newTerritory
        @updateArea.area.handle.update()

    # backward change
    else # direction is -1

      for newArea in @newAreas
        newArea.area.name =       null
        newArea.area.territory =  null
        newArea.area.handle.hide()

      for oldArea in @oldAreas
        oldArea.area.name =       oldArea.name
        oldArea.area.territory =  oldArea.territory
        oldArea.handle.show()

      if @updateArea
        if @updateArea.oldName
          @updateArea.area.name =      @updateArea.oldName
        if @updateArea.oldTerritory
          @updateArea.area.territory = @updateArea.oldTerritory
        @updateArea.area.handle.update()
