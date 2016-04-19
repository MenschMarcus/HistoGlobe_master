window.HG ?= {}

# ==============================================================================
# Step 3 in Edit Operation Workflow: define name of newly created area
# TODO: set names in all languages
# ==============================================================================

class HG.EditOperationStep.CreateNewNames extends HG.EditOperationStep


  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, direction) ->

    # inherit functionality from base class
    super @_hgInstance, direction

    # skip operations without user input
    return @finish() if not @_stepData.userInput

    # include
    @_geometryOperator = new HG.GeometryOperator


    ### SETUP OPERATION ###

    # forward: start at the first area
    if direction is 1
      @_areaIdx = -1

    # backward: start at the last area
    else
      @_areaIdx = @_stepData.inData.areas.length

    @_makeNewName direction



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _makeNewName: (direction) ->

    # abort prev Step -> first name and backwards
    return @abort()   if (@_areaIdx is 0) and (direction is -1)

    # go to next/previous area
    @_areaIdx += direction

    # get current area to work with
    if direction is 1 # forward
      currArea =      @_stepData.inData.areas[@_areaIdx]
      currName =      @_stepData.inData.areaNames[@_areaIdx]
      currTerritory = @_stepData.inData.areaTerritories[@_areaIdx]
    else # backward
      currArea =      @_stepData.outData.areas[@_areaIdx]
      currName =      @_stepData.outData.areaNames[@_areaIdx]
      currTerritory = @_stepData.outData.areaTerritories[@_areaIdx]

    # original names of areas from 1st step (HG.AreaName)
    @_origNames = @_hgInstance.editOperation.operation.steps[1].outData.areaNames

    # initial values for NewNameTool
    tempData = {
      nameSuggestions:    []
      name:               null
      oldPoint:           currTerritory.representativePoint
      newPoint:           null
    }

    # do not hand the HG.AreaName into NewNameTool, but only the name strings
    # => used nameAuggestion will be determined later by string comparison
    for nameSuggestion in @_origNames
      tempData.nameSuggestions.push {
        shortName:  nameSuggestion.shortName
        formalName: nameSuggestion.formalName
      }

    # override with temporary data from last time, if it is available
    tempData = $.extend {}, tempData, @_stepData.tempData[@_areaIdx]

    # remove the name from the area
    if currArea.name
      currArea.name = null
      currArea.handle.update()


    # get initial data for NewNameTool
    allowNameChange = yes     # is the user allowed to change the name?
    switch @_getOperationId()

      # for NCH/ICH: set the current name of the area as default value
      # to work immediately on it or just use it
      when 'NCH', 'ICH'
        tempData.name = {
          shortName:  currName.shortName
          formalName: currName.formalName
        }

      # for TCH/BCH: set the current name of the area as default value
      # that can not be changed (only name position can be changed)
      when 'TCH', 'BCH'
        tempData.name = {
          shortName:  currName.shortName
          formalName: currName.formalName
        }
        allowNameChange = no


    # backward into this step => reverse last operation
    if direction is -1
      switch @_getOperationId()

        # ----------------------------------------------------------------------
        when 'CRE'
          @_updateAreaName_reverse()
          @_updateRepresentativePoint_reverse()

        # ----------------------------------------------------------------------
        when 'UNI'
          @_updateAreaName_reverse()
          @_updateRepresentativePoint_reverse()

        # ----------------------------------------------------------------------
        when 'INC'
          @_continueIdentity_reverse()

        # ----------------------------------------------------------------------
        when 'SEP', 'SEC'

          # reverse the step which continued the identity of the selected area
          if @_stepData.outData.handleToBeDeleted.area.id is @_stepData.inData.areas[0].id
            @_continueIdentity_reverse()
            @_setOperationId 'SEP'

          # reverse every other "normal" step that created a new AreaName
          else
            @_updateAreaName_reverse()
            @_updateRepresentativePoint_reverse()

        # ----------------------------------------------------------------------
        when 'TCH', 'BCH'
          @_updateRepresentativePoint_reverse()

        # ----------------------------------------------------------------------
        when 'NCH'
          @_updateAreaName_reverse()
          @_updateRepresentativePoint_reverse()

        # ----------------------------------------------------------------------
        when 'ICH'
          @_continueIdentity_reverse()


    # set up NewNameTool to set name and position of area interactively
    newNameTool = new HG.NewNameTool @_hgInstance, tempData, allowNameChange


    # ==========================================================================
    ### LISTEN TO USER INPUT ###

    newNameTool.onSubmit @, (newData) =>

      # temporarily save new data so it can be restores on undo
      @_stepData.tempData[@_areaIdx] = newData

      # get data for appling changes
      newShortName =   newData.name.shortName
      newFormalName =  newData.name.formalName
      newPoint =    newData.newPoint

      # handle different operations
      switch @_getOperationId()

        # ----------------------------------------------------------------------
        when 'CRE'
          @_updateAreaName newShortName, newFormalName
          @_updateRepresentativePoint newPoint

          # only one step necessary => finish
          return @finish()

        # ----------------------------------------------------------------------
        when 'UNI', 'INC'

          # find out if new area continues the identity of one of the old areas
          # -> check if formal name equals
          origAreaName = null
          for oldName in @_origNames
            if oldName.formalName.localeCompare(newFormalName) is 0
              origAreaName = oldName

          # change of formal name => new identity => same as CRE operation
          if not origAreaName
            @_setOperationId 'UNI'
            @_updateAreaName newShortName, newFormalName
            @_updateRepresentativePoint newPoint

          # no change in formal name => continue this areas identity
          else
            @_setOperationId 'INC'
            @_continueIdentity origAreaName, newShortName, newFormalName, newPoint

          # only one step necessary => finish
          return @finish()

        # ----------------------------------------------------------------------
        when 'SEP', 'SEC'

          # find out if new area continues the identity of one of the old areas
          # -> check if formal name equals
          origAreaName = null
          if @_origNames[0].formalName.localeCompare(newFormalName) is 0
            origAreaName = @_origNames[0]

          # problem: how to distinguish SEP <-> SEC?
          # -> as soon as one area continues the identity of the selected area => SEC
          # mark this AreaHandle for deletion in outData.handleToBeDeleted
          # => if this variable carries an AreaHandle <-> SEC
          # => if this variable is null               <-> SEP

          # change of formal name => new identity => same as CRE operation
          if not origAreaName
            @_setOperationId 'SEP' if not @_stepData.outData.handleToBeDeleted
            @_updateAreaName newShortName, newFormalName
            @_updateRepresentativePoint newPoint

          # no change in formal name => continue this areas identity
          else
            @_setOperationId 'SEC'
            @_continueIdentity origAreaName, newShortName, newFormalName newPoint


          # finish when old area was separated completely
          if @_areaIdx is @_stepData.inData.areas.length-1
            return @finish()

          # otherwise cleanup and continue with next area
          else
            @_hgInstance.newNameTool?.destroy()
            @_hgInstance.newNameTool = null
            @_makeNewName 1

          # make action reversible
          @_undoManager.add {
            undo: =>
              # cleanup
              @_hgInstance.newNameTool?.destroy()
              @_hgInstance.newNameTool = null

              # area left to restore => go back one step
              if @_areaIdx > 0
                @_makeNewName -1

              # no area left => first action => abort step and go backwards
              else @abort()
          }

        # ----------------------------------------------------------------------
        when 'TCH', 'BCH'
          @_updateRepresentativePoint newPoint

          # only one step necessary => finish
          return @finish()


        # ----------------------------------------------------------------------
        when 'NCH', 'ICH'

          # find out if new area continues the identity of the old area
          # -> check if formal name equals
          shortNameChanged =  @_origNames[0].shortName.localeCompare(newShortName) is 0
          formalNameChanged = @_origNames[0].formalName.localeCompare(newFormalName) is 0

          if formalNameChanged # => new identity
            @_setOperationId 'NCH'
            @_updateAreaName newShortName, newFormalName
            @_updateRepresentativePoint newPoint

          else  # formal name stayed the same
            @_setOperationId 'ICH'
            @_continueIdentity @_origNames[0], newShortName, newFormalName, newPoint

            if not shortNameChanged
              @_stepData.outData.emptyOperation = yes

          # only one step necessary => finish
          return @finish()



  # ============================================================================
  # create new AreaName, attach it to current Area and add it to the output
  # ============================================================================

  _updateAreaName: (newShortName, newFormalName) ->

    # get area to work with
    oldArea = @_stepData.inData.areas[@_areaIdx]

    # create new AreaName
    newName = new HG.AreaName {
      id:         @_getId()
      shortName:  newShortName
      formalName: newFormalName
    }

    # update model: link Area and AreaName
    oldArea.name = newName
    newName.area = oldArea

    # update view
    oldArea.handle.update()

    # add to operation workflow
    @_stepData.outData.areas[@_areaIdx] =           oldArea
    @_stepData.outData.areaNames[@_areaIdx] =       newName
    @_stepData.outData.areaTerritories[@_areaIdx] = oldArea.territory


  # ----------------------------------------------------------------------------
  _updateAreaName_reverse: (newShortName, newFormalName) ->

    # get old area and name
    oldArea =  @_stepData.inData.areas[@_areaIdx]
    oldName =  @_stepData.inData.areaNames[@_areaIdx]

    # update model: link Area and AreaName
    oldArea.name = oldName

    # update view
    oldArea.handle.update()


  # ============================================================================
  # update the representative point of the territory with the new point set
  # in NewNameTool
  # ============================================================================

  _continueIdentity: (origAreaName, newShortName, newFormalName, newPoint) ->

    # restore original Area to continue its identity
    origArea = origAreaName.area

    # attach new territory to it and update its representative point
    origArea.territory = oldArea.territory
    origArea.territory.representativePoint = newPoint

    # find out if short name has changed -> need for new AreaName?
    if origAreaName.shortName.localeCompare(newShortName) is 0
      # also same short name => reuse old AreaName
      origAreaName.area = origArea
      origArea.name = origAreaName

    else
      # different short name, but same formal name
      # => identitiy stays the same, but it still needs new AreaName
      newName = new HG.AreaName {
        id:         @_getId()
        shortName:  newShortName
        formalName: newFormalName
      }
      newName.area = origArea
      origArea.name = newName

    # update model and view:
    # hide the area that was created in the previous NewTerritory step
    # and restore (show) the updated area of this step
    oldArea.handle.deselect()
    oldArea.handle.endEdit()
    oldArea.handle.hide()
    origArea.handle.show()
    origArea.handle.startEdit()
    origArea.handle.select()

    # add to operation workflow
    @_stepData.outData.areas[@_areaIdx] =           origArea
    @_stepData.outData.areaNames[@_areaIdx] =       origArea.name
    @_stepData.outData.areaTerritories[@_areaIdx] = origArea.territory

    # mark hidden area handle for deletion in last step
    # do not destroy it know, because it might needs to be restored
    @_stepData.outData.handleToBeDeleted = oldArea.handle


  # ----------------------------------------------------------------------------
  _continueIdentity_reverse: () ->

    # get old and new data
    newArea =       @_stepData.outData.areas[@_areaIdx]
    newName =       @_stepData.outData.areaNames[@_areaIdx]
    newTerritory =  @_stepData.outData.areaTerritories[@_areaIdx]

    oldArea =       @_stepData.inData.areas[@_areaIdx]
    oldName =       @_stepData.inData.areaNames[@_areaIdx]
    oldTerritory =  @_stepData.inData.areaTerritories[@_areaIdx]

    # reset old representative point
    oldTerritory.representativePoint = @_stepData.tempData[@_areaIdx].oldPoint
    newTerritory.representativePoint = @_stepData.tempData[@_areaIdx].oldPoint

    # reset name
    oldArea.name = oldName
    newArea.name = null

    # reset territory
    oldArea.territory = oldTerritory
    newArea.territory = null

    # update view
    newArea.handle.deselect()
    newArea.handle.endEdit()
    newArea.handle.hide()
    oldArea.handle.show()
    oldArea.handle.startEdit()
    oldArea.handle.select()

    # unmark handle for deletion
    @_stepData.outData.handleToBeDeleted = null


  # ============================================================================
  # update the representative point of the territory with the new point set
  # in NewNameTool
  # ============================================================================

  _updateRepresentativePoint: (newPoint) ->

    # get area to work with
    oldArea = @_stepData.inData.areas[@_areaIdx]

    # update model
    oldArea.territory.representativePoint = newPoint

    # update view
    oldArea.handle.update()


  # ----------------------------------------------------------------------------
  _updateRepresentativePoint_reverse: (newPoint) ->

    # get area to work with
    oldArea =  @_stepData.inData.areas[@_areaIdx]

    # update model
    oldArea.territory.representativePoint = @_stepData.tempData[@_areaIdx].oldPoint

    # update view
    oldArea.handle.update()


  ##############################################################################

  # ============================================================================
  # end of operation
  # ============================================================================

  _cleanup: (direction) ->

    ### CLEANUP OPERATION ###
    @_hgInstance.newNameTool?.destroy()
    @_hgInstance.newNameTool = null

    # backwards step => restore name previously on the area
    if direction is -1
      oldArea = @_stepData.inData.areas[@_areaIdx]
      oldName = @_stepData.inData.areaNames[@_areaIdx]
      oldArea.name = oldName
      oldArea.handle.update()
