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
    @_currArea =      @_stepData.inData.areas[@_areaIdx]
    @_currName =      @_stepData.inData.areaNames[@_areaIdx]
    @_currTerritory = @_stepData.inData.areaTerritories[@_areaIdx]

    # original names of areas from 1st step (HG.AreaName)
    @_origNames = @_hgInstance.editOperation.operation.steps[1].outData.areaNames

    # initial values for NewNameTool
    tempData = {
      nameSuggestions:    []
      name:               null
      oldPoint:           @_currTerritory.representativePoint
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
    if @_currArea.name
      @_currArea.name = null
      @_currArea.handle.update()


    # get initial data for NewNameTool
    allowNameChange = yes     # is the user allowed to change the name?
    switch @_operationId

      # for NCH/ICH: set the current name of the area as default value
      # to work immediately on it or just use it
      when 'NCH', 'ICH'
        tempData.name = {
          shortName:  @_currName.shortName
          formalName: @_currName.formalName
        }

      # for TCH/BCH: set the current name of the area as default value
      # that can not be changed (only name position can be changed)
      when 'TCH', 'BCH'
        tempData.name = {
          shortName:  @_currName.shortName
          formalName: @_currName.formalName
        }
        allowNameChange = no


    # backward into this step => reverse last operation
    if direction is -1
      switch @_operationId
        when 'CRE'        then @_CRE_reverse()
        when 'UNI', 'INC'
          @_UNI_reverse()
          console.log @_operationId
          console.log "in area ", @_stepData.inData.areas[0]
          console.log "in name ", @_stepData.inData.areaNames[0]
          console.log "in terr ", @_stepData.inData.areaTerritories[0]
          console.log "out area", @_stepData.outData.areas[0]
          console.log "out name", @_stepData.outData.areaNames[0]
          console.log "out terr", @_stepData.outData.areaTerritories[0]

        when 'SEP', 'SEC' then @_SEP_reverse()
        when 'TCH', 'BCH' then @_TCH_reverse()
        when 'NCH', 'ICH' then @_NCH_reverse()


    # set up NewNameTool to set name and position of area interactively
    newNameTool = new HG.NewNameTool @_hgInstance, tempData, allowNameChange


    # --------------------------------------------------------------------------
    ### LISTEN TO USER INPUT ###

    newNameTool.onSubmit @, (newData) =>

      # temporarily save new data so it can be restores on undo
      @_stepData.tempData[@_areaIdx] = newData

      # get data for appling changes
      shortName =   newData.name.shortName
      formalName =  newData.name.formalName
      newPoint =    newData.newPoint

      # handle different operations
      switch @_operationId

        # ----------------------------------------------------------------------
        when 'CRE'
          @_CRE shortName, formalName, newPoint

          # only one step necessary => finish
          return @finish()

        # ----------------------------------------------------------------------
        when 'UNI', 'INC'
          @_UNI shortName, formalName, newPoint

          console.log @_operationId
          console.log "in area ", @_stepData.inData.areas[0]
          console.log "in name ", @_stepData.inData.areaNames[0]
          console.log "in terr ", @_stepData.inData.areaTerritories[0]
          console.log "out area", @_stepData.outData.areas[0]
          console.log "out name", @_stepData.outData.areaNames[0]
          console.log "out terr", @_stepData.outData.areaTerritories[0]

          # only one step necessary => finish
          return @finish()

        # ----------------------------------------------------------------------
        when 'SEP', 'SEC'
          complete = @_SEP shortName, formalName, newPoint

          # finish when old area was separated completely
          if complete
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
                else
                  @abort()
            }

        # ----------------------------------------------------------------------
        when 'TCH', 'BCH'
          @_TCH shortName, formalName, newPoint

          # only one step necessary => finish
          return @finish()


        # ----------------------------------------------------------------------
        when 'NCH', 'ICH'
          @_NCH shortName, formalName, newPoint

          # only one step necessary => finish
          return @finish()


        # ----------------------------------------------------------------------
        # nothing to do for 'DES' operation



  ##############################################################################
  #                     DEFINITION OF ACTUAL OPERATIONS                        #
  ##############################################################################

  # ============================================================================
  # CRE = create new area
  # ============================================================================

  _CRE: (newShortName, newFormalName, newPoint) ->

    # create new AreaName
    newName = new HG.AreaName {
      id:         @_getId()
      shortName:  newShortName
      formalName: newFormalName
    }

    # link Area and AreaName
    @_currArea.name = newName
    newName.area = @_currArea

    # update representative point
    @_currTerritory.representativePoint = newPoint

    # update view
    @_currArea.handle.update()

    # add to operation workflow
    @_stepData.outData.areas[0] =           @_currArea
    @_stepData.outData.areaNames[0] =       newName
    @_stepData.outData.areaTerritories[0] = @_currTerritory


  # ============================================================================
  _CRE_reverse: () ->

    # restore old area
    oldArea =       @_stepData.inData.areas[0]
    oldName =       @_stepData.inData.areaNames[0]
    oldTerritory =  @_stepData.inData.areaTerritories[0]

    # reset old properties
    oldArea.name = oldName
    oldTerritory.representativePoint = @_stepData.tempData[0].oldPoint

    # update view
    oldArea.handle.update()


  # ============================================================================
  # UNI = unify selected areas to a new area
  # INC = incorporate selected areas into another selected area
  # ============================================================================

  _UNI: (newShortName, newFormalName, newPoint) ->

    # find out if new area continues the identity of one of the old areas
    # -> check if formal name equals
    sameFormalName = null
    for oldName in @_origNames
      if oldName.formalName.localeCompare(newFormalName) is 0
        sameFormalName = oldName

    # change of formal name => new identity => same as CRE operation
    if not sameFormalName
      @_operationId = 'UNI'
      @_CRE newShortName, newFormalName, newPoint

    # no change in formal name => continue this areas identity
    else
      # change operation id to incorporation
      @_operationId = 'INC'

      # restore original Area to continue its identity
      origArea = sameFormalName.area

      # attach new territory to it and update its representative point
      origArea.territory = @_currArea.territory
      origArea.territory.representativePoint = newPoint

      # find out if short name has changed -> need for new AreaName?
      if sameFormalName.shortName.localeCompare(newShortName) is 0
        # also same short name => reuse old AreaName
        sameFormalName.area = origArea
        origArea.name = sameFormalName

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
      # and mark it for deletion in last step unless it is not to be restored
      # and restore (show) the updated area of this step
      @_currArea.handle.deselect()
      @_currArea.handle.endEdit()
      @_currArea.handle.hide()
      @_stepData.tempData.handleToBeDestroyed = @_currArea.handle
      origArea.handle.show()
      origArea.handle.startEdit()
      origArea.handle.select()

      # add to operation workflow
      @_stepData.outData.areas[0] =           origArea
      @_stepData.outData.areaNames[0] =       origArea.name
      @_stepData.outData.areaTerritories[0] = origArea.territory


  # ============================================================================
  _UNI_reverse: () ->

    # TODO: fix this

    # action in UNI was the same than action in CRE => reverse is the same
    if @_operationId is 'UNI'
      @_CRE_reverse()

    else # 'INC'

      # get old and new data
      newArea =       @_stepData.outData.areas[0]
      newName =       @_stepData.outData.areaNames[0]
      newTerritory =  @_stepData.outData.areaTerritories[0]

      oldArea =       @_stepData.inData.areas[0]
      oldName =       @_stepData.inData.areaNames[0]
      oldTerritory =  @_stepData.inData.areaTerritories[0]

      # reset old representative point
      oldTerritory.representativePoint = @_stepData.tempData[@_areaIdx].oldPoint
      newTerritory.representativePoint = @_stepData.tempData[@_areaIdx].oldPoint

      # reset name
      oldArea.name = oldName
      oldName.area = oldArea
      newArea.name = null

      # reset territory
      oldArea.territory = oldTerritory
      oldTerritory.area = oldArea
      newArea.territory = null

      # update view
      newArea.handle.deselect()
      newArea.handle.endEdit()
      newArea.handle.hide()
      oldArea.handle.show()
      oldArea.handle.startEdit()
      oldArea.handle.select()


      # unmark handle for deletion
      @_stepData.tempData.handleToBeDestroyed = null


  # ============================================================================
  # SEP = separate selected area into multiple areas (multiple iterations)
  # SEC = seize multiple areas from one area
  # ============================================================================

  _SEP: (newShortName, newFormalName, newPoint) ->


  # ============================================================================
  _SEP_reverse: () ->



  # ============================================================================
  # TCH = change territory of one area
  # BCH = change the border between two territories
  # ============================================================================

  _TCH: (newShortName, newFormalName, newPoint) ->


  # ============================================================================
  _TCH_reverse: () ->


  # ============================================================================
  # NCH = change the name of an area
  # ICH = identity change
  # ============================================================================

  _NCH: (newShortName, newFormalName, newPoint) ->


  # ============================================================================
  _NCH_reverse: () ->




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
      if not @_currArea.name
        @_currArea.name = @_currName
        @_currArea.handle.update()
