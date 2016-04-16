window.HG ?= {}

# ==============================================================================
# Step 2 in Edit Operation Workflow: Newly create geometry(ies)
# ==============================================================================

class HG.EditOperationStep.CreateNewTerritories extends HG.EditOperationStep


  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, direction) ->

    # inherit functionality from base class
    super @_hgInstance, direction

    # includes
    @_geometryOperator = new HG.GeometryOperator


    ### PREPARE AREA CHANGE ###

    if direction is 1 # forward
      @_hgInstance.editMode.enterAreaEditMode()

      # update area change
      for areaChange in @_historicalChange.areaChanges
        switch areaChange.operation

          # hide all areas that are to be deleted
          when 'DEL'
            areaChange.area.handle.deselect()
            areaChange.area.handle.hide()
            areaChange.oldAreaTerritory = areaChange.area.territory
            areaChange.area.territory = null

          # start editing all areas whose territory is to be changed now
          when 'TCH'
            areaChange.area.handle.startEdit()
            areaChange.oldAreaTerritory = areaChange.area.territory
            areaChange.area.territory = null



    ### AUTOMATIC PROCESSING ###

    switch @_historicalChange.operation

      # ------------------------------------------------------------------------
      when 'UNI', 'INC'                                ## unification operation

        if direction is 1 # forward

          # delete all selected areas
          oldTerritories = []
          for areaChange in @_historicalChange.areaChanges
            if areaChange.operation is 'DEL'
              oldTerritories.push areaChange.oldAreaTerritory.geometry

          # unify old areas to new area
          unifiedGeometry = @_geometryOperator.union oldTerritories

          # create AreaChange
          newChange = new HG.AreaChange @_hgInstance.editOperation.getRandomId()
          newChange.operation = 'ADD'

          # create Area
          newArea = new HG.Area @_hgInstance.editOperation.getRandomId()

          # create AreaTerritory
          newTerritory = new HG.AreaTerritory {
              id:                   @_hgInstance.editOperation.getRandomId()
              geometry:             unifiedGeometry
              representativePoint:  unifiedGeometry.getCenter()
            }

          # link AreaChange <-> HistoricalChange
          newChange.historicalChange = @_historicalChange
          @_historicalChange.areaChanges.push newChange

          # link Area <-> AreaTerritory
          newArea.territory = newTerritory
          newTerritory.area = newArea

          # link AreaChange <-> Area
          newChange.area = newArea
          newArea.startChange = newChange

          # link AreaChange <-> AreaTerritory
          newChange.newAreaTerritory = newTerritory
          newTerritory.startChange = newChange

          # create AreaHandle <-> Area
          newHandle = new HG.AreaHandle @_hgInstance, newArea
          newArea.handle = newHandle

          # show area via areaHandle
          @_hgInstance.areaController.addAreaHandle newHandle
          newHandle.startEdit()
          newHandle.select()
          newHandle.show()

          # go to next step
          @_makeTransition 1


        else # backward operation => do reverse

          # find responsible AreaChange
          for areaChange, idx in @_historicalChange.areaChanges
            if areaChange.operation is 'ADD'
              newChange = areaChange

              # destroy AreaHandle => appearance of Area in system
              newChange.area.handle.destroy()

              # unlink AreaChange from HistoricalChange
              @_historicalChange.areaChanges.splice idx, 1

              # delete AreaChange
              newChange = null

              # => all links AreaChange <-> Area <-> AreaTerritory destroyed
              # objects will be garbage collected
              break


      # ------------------------------------------------------------------------
      when 'NCH'                                      ## name change operation

        # each operation changes areas, even if they have the same geometry
        # => A copy area to have completely new area that can be renamed in next step
        # => new identity
        if direction is 1 # forward
          # deactivate old area
          oldAreaId = @_stepData.inData.selectedAreas[0]
          oldArea = @_hgInstance.areaController.getActiveArea oldAreaId
          @_stepData.tempAreas[0] = oldAreaId
          @notifyEditMode 'onEndEditArea', oldAreaId
          @notifyEditMode 'onDeselectArea', oldAreaId
          @notifyEditMode 'onDeactivateArea', oldAreaId

          # create and activate new area
          newAreaId = "NEW_NAME_" + oldAreaId
          @notifyEditMode 'onCreateArea', newAreaId, oldArea.getGeometry()
          @notifyEditMode 'onAddAreaName', newAreaId, oldArea.getShortName(), oldArea.getFormalName()
          @notifyEditMode 'onUpdateAreaRepresentativePoint', newAreaId, oldArea.getRepresentativePoint()

          @_stepData.outData.createdAreas[0] = newAreaId

        else
          # remove new area
          newAreaId = @_stepData.outData.createdAreas[0]
          @notifyEditMode 'onRemoveArea', newAreaId

          # reactivate old area
          oldAreaId = @_stepData.tempAreas[0]
          @notifyEditMode 'onActivateArea', oldAreaId
          @notifyEditMode 'onSelectArea', oldAreaId
          @notifyEditMode 'onStartEditArea', oldAreaId
          @_stepData.inData.selectedAreas[0] = oldAreaId

        return @finish() # no user input


      # ------------------------------------------------------------------------
      when 'DES'                                        ## destruction operation

        if direction is 1 # forward
          for id in @_stepData.inData.selectedAreas
            area = @_hgInstance.areaController.getActiveArea id
            # save in temporary areas to restore them later
            @_stepData.tempAreas.push id
            @notifyEditMode 'onDeactivateArea', id

        else # backward
          for id in @_stepData.tempAreas
            @notifyEditMode 'onActivateArea', id

        return @finish() # no user input


    # --------------------------------------------------------------------------
    ### SETUP OPERATION ###
    @_finish = no

    if direction is 1 # forward
      @_areaIdx = -1
      @_makeNewTerritory direction   # direction: positive

    else # backward
      @_areaIdx = @_stepData.outData.createdAreas.length
      @_makeNewTerritory direction  # direction: negative



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _makeNewTerritory: (direction) ->

    # error handling: finish criterion successful => finish
    #                 first geometry -> backward  => abort
    return @finish() if @_finish
    return @abort()  if (@_areaIdx is 0) and (direction is -1)

    # go to next/previous area
    @_areaIdx += direction

    # set up NewTerritoryTool to define geometry of an area interactively
    newTerritoryTool = new HG.NewTerritoryTool @_hgInstance, @_areaIdx is 0


    ### LISTEN TO USER INPUT ###
    newTerritoryTool.onSubmit @, (clipGeometry) =>  # incoming geometry: clipGeometry

      # ------------------------------------------------------------------------
      ## add new area operation
      if @_historicalChange.operation is 'CRE'

        # TODO: check for bug: adding two areas after each other -> what happens?

        # clip new geometry to existing geometries
        # check for intersection with each active area on the map
        # TODO: make more efficient later (Quadtree?)

        # manual loop, because some areas might be deleted on the way
        existingAreas = @_hgInstance.areaController.getActiveAreas()
        loopIdx = existingAreas.length-1
        while loopIdx >= 0
          existingAreaId =      existingAreas[loopIdx].getId()
          existingGeometry =    existingAreas[loopIdx].getGeometry()
          existingShortName =   existingAreas[loopIdx].getShortName()
          existingFormalName =  existingAreas[loopIdx].getFormalName()
          existingReprPoint =   existingAreas[loopIdx].getRepresentativePoint()

          # if new geometry intersects with an existing geometry
          intersectionGeometry = @_geometryOperator.intersection clipGeometry, existingGeometry
          if intersectionGeometry.isValid()

            # => clip the existing geometry to the new geometry and update its area
            newGeometry = @_geometryOperator.difference existingGeometry, clipGeometry
            @_stepData.tempAreas.push {
              'id':           existingAreaId
              'clip':         clipGeometry
              'removed':      not newGeometry.isValid()  # was the area 0removed in the process?
              'geometry':     existingGeometry
              'shortName':    existingShortName
              'formalName':   existingFormalName
              'reprPoint':    existingReprPoint
            }
            if newGeometry.isValid()
              @notifyEditMode 'onUpdateAreaGeometry', existingAreaId, newGeometry
              @notifyEditMode 'onUpdateAreaRepresentativePoint', existingAreaId, null
            else # area is gone
              @notifyEditMode 'onDeactivateArea', existingAreaId

          loopIdx--

        # insert new geometry into new area and add it
        addAreaId = 'NEW_AREA'
        @_stepData.outData.createdAreas.push addAreaId
        @notifyEditMode 'onCreateArea', addAreaId, clipGeometry

        # finish criterion: only one step necessary
        @_finish = yes

        # make action reversible
        @_undoManager.add {
          undo: =>
            # cleanup
            @_hgInstance.newTerritoryTool?.destroy()
            @_hgInstance.newTerritoryTool = null

            # delete created area
            newId = @_stepData.outData.createdAreas.pop()
            @notifyEditMode 'onRemoveArea', newId

            # restore old areas
            while @_stepData.tempAreas.length > 0
              area = @_stepData.tempAreas.pop()
              if area.removed # removed in forward => recreate in backward
                @notifyEditMode 'onActivateArea', area.id
              else # updated in forward => update in backward
                @notifyEditMode 'onUpdateAreaGeometry', area.id, area.geometry
                @notifyEditMode 'onUpdateAreaRepresentativePoint', area.id, area.reprPoint

            # go to previous area
            @_finish = no
            @_makeNewTerritory -1
        }


      # ------------------------------------------------------------------------
      ## separate areas operation
      else if @_historicalChange.operation is 'SEP'
        existingArea = @_hgInstance.areaController.getActiveArea @_stepData.inData.selectedAreas[0]

        existingAreaId =      existingArea.getId()
        existingGeometry =    existingArea.getGeometry()
        existingShortName =   existingArea.getShortName()
        existingFormalName =  existingArea.getFormalName()
        existingReprPoint =   existingArea.getRepresentativePoint()

        # clip incoming geometry (= clipGeometry) to selected geometry
        # -> create new area
        newGeometry = @_geometryOperator.intersection existingGeometry, clipGeometry
        newId = 'SEP_AREA_' + @_stepData.outData.createdAreas.length
        @notifyEditMode 'onCreateArea', newId, newGeometry
        @_stepData.outData.createdAreas.push newId

        # update existing areas (or remove when fully separated)
        updatedGeometry = @_geometryOperator.difference existingGeometry, clipGeometry
        @notifyEditMode 'onDeselectArea', existingAreaId # why?
        if updatedGeometry.isValid()
          @notifyEditMode 'onUpdateAreaGeometry', existingAreaId, updatedGeometry
          @notifyEditMode 'onUpdateAreaRepresentativePoint', existingAreaId, null
        else
          @notifyEditMode 'onDeactivateArea', existingAreaId

        # finish criterion: existing area is completely split up
        @_finish = yes  if not updatedGeometry.isValid()

        @_stepData.tempAreas.push {
          'id':           existingAreaId
          'clip':         clipGeometry
          'removed':      not updatedGeometry.isValid()  # was the area rremoved in the process?
          'geometry':     existingGeometry
          'shortName':    existingShortName
          'formalName':   existingFormalName
          'reprPoint':    existingReprPoint
          'usedRest':     @_finish    # bool: has user just clicked on rest?
        }

        # make action reversible
        @_undoManager.add {
          undo: =>
            # cleanup
            @_hgInstance.newTerritoryTool?.destroy()
            @_hgInstance.newTerritoryTool = null

            # reset finish criterion
            @_finish = no

            # restore last area
            updatedArea = @_stepData.tempAreas.pop()
            if updatedArea.removed
              @notifyEditMode 'onActivateArea', updatedArea.id
            else # update
              @notifyEditMode 'onUpdateAreaGeometry', updatedArea.id, updatedArea.geometry
              @notifyEditMode 'onUpdateAreaRepresentativePoint', updatedArea.id, updatedArea.reprPoint
            @notifyEditMode 'onSelectArea', updatedArea.id

            # delete newly created area
            newArea = @_stepData.outData.createdAreas.pop()
            @notifyEditMode 'onRemoveArea', newArea

            # go to previous area
            @_makeNewTerritory -1
        }


# ------------------------------------------------------------------------------
      ## change border operation
      else if @_historicalChange.operation is 'TCH'

        # idea: both areas A and B get a new common border
        # => unify both areas and use the drawn geometry C as a clip polygon
        # A' = (A \/ B) /\ C    intersection (A u B) with C
        # B' = (A \/ B) - C     difference (A u B) with C

        A_old_id = @_stepData.inData.selectedAreas[0]
        B_old_id = @_stepData.inData.selectedAreas[1]
        A_area = @_hgInstance.areaController.getActiveArea A_old_id
        B_area = @_hgInstance.areaController.getActiveArea B_old_id

        A_shortName = A_area.getShortName()
        B_shortName = B_area.getShortName()
        A_formalName = A_area.getFormalName()
        B_formalName = B_area.getFormalName()
        A_reprPoint = A_area.getRepresentativePoint()
        B_reprPoint = B_area.getRepresentativePoint()

        A = A_area.getGeometry()
        B = B_area.getGeometry()
        C = clipGeometry

        # test: which country was covered in clip area?
        A_covered = @_geometryOperator.isWithin A, C

        AuB = @_geometryOperator.union [A, B]

        # 2 cases: A first and B first
        if A_covered
          A_new_geom = @_geometryOperator.intersection AuB, C
          B_new_geom = @_geometryOperator.difference AuB, C
        else  # B is covered
          B_new_geom = @_geometryOperator.intersection AuB, C
          A_new_geom = @_geometryOperator.difference AuB, C

        @_stepData.tempAreas[0] = {
          'id':           A_old_id
          'clip':         C
          'geometry':     A
          'shortName':    A_shortName
          'formalName':   A_formalName
          'reprPoint':    A_reprPoint
        }
        @_stepData.tempAreas[1] = {
          'id':           B_old_id
          'clip':         C
          'geometry':     B
          'shortName':    B_shortName
          'formalName':   B_formalName
          'reprPoint':    B_reprPoint
        }

        # deactivate old areas
        @notifyEditMode 'onEndEditArea', A_old_id
        @notifyEditMode 'onEndEditArea', B_old_id
        @notifyEditMode 'onDeselectArea', A_old_id
        @notifyEditMode 'onDeselectArea', B_old_id
        @notifyEditMode 'onDeactivateArea', A_old_id
        @notifyEditMode 'onDeactivateArea', B_old_id

        @_stepData.tempAreas[0] = A_old_id
        @_stepData.tempAreas[1] = B_old_id

        # create and activate new area
        A_new_id = "NEW_BORDER_" + A_old_id
        B_new_id = "NEW_BORDER_" + B_old_id
        @notifyEditMode 'onCreateArea', A_new_id, A_new_geom
        @notifyEditMode 'onCreateArea', B_new_id, B_new_geom
        @notifyEditMode 'onAddAreaName', A_new_id, A_shortName, A_formalName
        @notifyEditMode 'onAddAreaName', B_new_id, B_shortName, B_formalName
        @notifyEditMode 'onUpdateAreaRepresentativePoint', A_new_id, A_reprPoint
        @notifyEditMode 'onUpdateAreaRepresentativePoint', B_new_id, B_reprPoint

        @_stepData.outData.createdAreas[0] = A_new_id
        @_stepData.outData.createdAreas[1] = B_new_id

        # done!
        @_finish = yes

        # make action reversible
        # TODO: put clip area back and make it editable ;)
        # -> that would be truly inversible!
        @_undoManager.add {
          undo: =>
            # cleanup
            @_hgInstance.newTerritoryTool?.destroy()
            @_hgInstance.newTerritoryTool = null

            # remove new area
            A_new_id = @_stepData.outData.createdAreas[0]
            B_new_id = @_stepData.outData.createdAreas[1]
            @notifyEditMode 'onRemoveArea', A_new_id
            @notifyEditMode 'onRemoveArea', B_new_id

            # reactivate old area
            A_old_id = @_stepData.tempAreas[0]
            B_old_id = @_stepData.tempAreas[1]

            @notifyEditMode 'onActivateArea', A_old_id
            @notifyEditMode 'onActivateArea', B_old_id
            @notifyEditMode 'onSelectArea', A_old_id
            @notifyEditMode 'onSelectArea', B_old_id
            @notifyEditMode 'onStartEditArea', A_old_id
            @notifyEditMode 'onStartEditArea', B_old_id

            @_stepData.inData.selectedAreas[0] = A_old_id
            @_stepData.inData.selectedAreas[1] = B_old_id

            # go to previous area
            @_finish = no
            @_areaIdx = 0 # manual setting, because TCH step does two areas at once
            @_makeNewTerritory -1
        }


      # cleanup
      @_hgInstance.newTerritoryTool?.destroy()
      @_hgInstance.newTerritoryTool = null

      # go to next geometry
      @_makeNewTerritory 1


  # ============================================================================
  _cleanup: (direction) ->

    ### CLEANUP OPERATION ###

    @_hgInstance.newTerritoryTool?.destroy()
    @_hgInstance.newTerritoryTool = null


    ### RESTORE AREA CHANGE ###

    if direction is -1 # backward
      @_hgInstance.editMode.leaveAreaEditMode()

      # restore area change
      for areaChange in @_historicalChange.areaChanges
        switch areaChange.operation

          # hide all areas that are to be deleted
          when 'DEL'
            areaChange.area.territory = areaChange.oldAreaTerritory
            areaChange.oldAreaTerritory = null
            areaChange.area.handle.show()
            areaChange.area.handle.select()

          # start editing all areas whose territory was to be changed
          when 'TCH'
            areaChange.area.territory = areaChange.oldAreaTerritory
            areaChange.oldAreaTerritory = null
            areaChange.area.handle.endEdit()
