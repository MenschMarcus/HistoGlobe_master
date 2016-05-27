window.HG ?= {}

# ==============================================================================
# MODEL class
# contains data about a specific SEC AreaChange
#
# ------------------------------------------------------------------------------
# operation             area change terr change name change
# id    name            old -> new  old -> new  old -> new
# ------------------------------------------------------------------------------
# NCH - Name Change     -           -           1   -> 1
# ==============================================================================


class HG.AreaChange.NCH extends HG.AreaChange

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ----------------------------------------------------------------------------
  constructor: (id, updateArea, oldName) ->

    # create member variables in base class constructor
    super(id)

    ## establish double links

    # AreaChange <-> updateArea
    @updateArea = updateArea
    updateArea.updateChanges.push @

    # AreaChange <-> oldName
    @oldAreaNames[0] = oldName
    oldName.endChange = @

    # AreaChange <-> newName
    newName = updateArea.name
    @newAreaNames[0] = newName
    newName.startChange = @



  # ----------------------------------------------------------------------------
  destroy: () ->

    ## remove double-links

    # AreaChange <-> updateArea
    updIdx = @updateArea.updateChanges.indexOf @
    @updateArea.updateChanges.splice updIdx,1

    # AreaChange <-> oldName
    @oldAreaNames[0].endChange =    null

    # AreaChange <-> newName
    @newAreaNames[0].startChange =  null