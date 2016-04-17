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


    # ==========================================================================

    ### AUTOMATIC PROCESSING ###

    switch @_operationId

      # ------------------------------------------------------------------------
      when 'UNI'                                        ## unification operation
        if direction is 1   # forward
          @_UNI()
          return @finish()

        else                # backward
          @_UNI_reverse()
          return @abort()

      # ------------------------------------------------------------------------
      when 'DES'                                        ## destruction operation
        if direction is 1   # forward
          @_DES()
          return @finish()

        else                # backward
          @_DES_reverse()
          return @abort()


    # ==========================================================================

    ### SETUP OPERATION ###

    # make only edit areas focusable
    @_hgInstance.editMode.enterAreaEditMode() if direction is 1

    # backward into this step => reverse last operation
    if direction is -1
      switch @_operationId
        when 'CRE' then @_CRE_reverse()
        # when 'SEP' then @_SEP_reverse()
        # when 'TCH' then @_TCH_reverse()

    # start at first (forward) resp. last (backward) area
    if direction is 1 then  @_areaIdx = -1
    else                    @_areaIdx = @_stepData.inData.areas.length

    @_makeNewTerritory direction


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _makeNewTerritory: (direction) ->

    # for backward operation: restore previously drawn clip geometry in the tool
    restoreLayer = null
    restoreLayer = @_stepData.tempData.restoreLayers[@_areaIdx] if direction is -1

    # go to next/previous area
    @_areaIdx += direction

    # set up NewTerritoryTool to define geometry of an area interactively
    newTerritoryTool = new HG.NewTerritoryTool @_hgInstance, restoreLayer, @_areaIdx is 0


    ### LISTEN TO USER INPUT ###
    newTerritoryTool.onSubmit @, (clipGeometry, restoreLayer) =>  # incoming geometry: clipGeometry

      switch @_operationId

        # ======================================================================
        when 'CRE'                                            ## create new area

          @_CRE clipGeometry

          @_stepData.tempData.restoreLayers.push restoreLayer

          # only one step necessary => finish
          return @finish()

        # ======================================================================
        when 'SEP'                                             ## separate areas

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
          return @finish()

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

          # --------------------------------------------------------------------
          @_undoManager.add {                               # undo separate area
            undo: =>
              # cleanup
              @_hgInstance.newTerritoryTool?.destroy()
              @_hgInstance.newTerritoryTool = null

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


        # ======================================================================
        when 'TCH'                                  # territory / border change

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
          return @finish()

          # --------------------------------------------------------------------
          # TODO: put clip area back and make it editable ;)
          # -> that would be truly inversible!
          @_undoManager.add {                   # undo territory / border change
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

              # only one action in this step => abort step
              @abort()
          }

      # ========================================================================

      # cleanup
      @_hgInstance.newTerritoryTool?.destroy()
      @_hgInstance.newTerritoryTool = null

      # go to next territory
      @_makeNewTerritory 1


  ##############################################################################
  ### DEFINITION OF ACTUAL OPERATIONS ###

  # ============================================================================
  # CRE = create new area
  # ============================================================================

  _CRE: (clipGeometry) ->

    # approach: clip new geometry to existing geometries
    # check for intersection with each active area on the map
    # TODO: make more efficient later (Quadtree?)

    # manual loop, because some areas might be deleted on the way
    currAreas = @_hgInstance.areaController.getAreaHandles()
    areaIdx = currAreas.length-1
    while areaIdx >= 0
      if currAreas[areaIdx].isVisible()
        currArea =        currAreas[areaIdx].getArea()
        currTerritory =   currAreas[areaIdx].getArea().territory
        currName =        currAreas[areaIdx].getArea().name

        # if new geometry intersects with a current geometry
        intersectionGeometry = @_geometryOperator.intersection clipGeometry, currTerritory.geometry
        if intersectionGeometry.isValid()

          # => clip the curr geometry to the new geometry and update its area
          newGeometry = @_geometryOperator.difference currTerritory.geometry, clipGeometry

          # area has been clipped => update territory
          if newGeometry.isValid()

            # create new Territory
            newTerritory = new HG.AreaTerritory {
              id:                   @_hgInstance.editOperation.getRandomId()
              geometry:             newGeometry
              representativePoint:  newGeometry.getCenter()
            }

            # link Area <-> AreaTerritory
            newTerritory.area = currArea
            currArea.territory = newTerritory

            # update view
            currArea.handle.update()

            # add to workflow
            @_stepData.tempData.areas.push          currArea
            @_stepData.tempData.oldTerritories.push currTerritory
            @_stepData.tempData.newTerritories.push newTerritory


          # area has been hidden => remove territory and update
          else

            # update Area
            currArea.territory = null

            # update view
            currArea.handle.hide()

            # add to workflow
            @_stepData.tempData.areas.push          currArea
            @_stepData.tempData.oldTerritories.push currTerritory
            @_stepData.tempData.newTerritories.push null

      # test previous area
      areaIdx--

    ## create area based on the clip geometry
    newArea = new HG.Area @_hgInstance.editOperation.getRandomId()
    newTerritory = new HG.AreaTerritory {
      id:                   @_hgInstance.editOperation.getRandomId()
      geometry:             clipGeometry
      representativePoint:  clipGeometry.getCenter()
    }

    # link Area <-> AreaTerritory
    newArea.territory = newTerritory
    newTerritory.area = newArea

    # create AreaHandle <-> Area
    newHandle = new HG.AreaHandle @_hgInstance, newArea
    newArea.handle = newHandle

    # show area via areaHandle
    newHandle.show()
    newHandle.select()
    newHandle.startEdit()

    # add to operation workflow
    @_stepData.outData.areas[0] =            newArea
    @_stepData.outData.areaNames[0] =        null
    @_stepData.outData.areaTerritories[0] =  newTerritory


  # ============================================================================
  _CRE_reverse: () ->

    # delete created area
    newArea = @_stepData.outData.areas[0]
    newArea.handle.destroy()

    # restore old areas
    while @_stepData.tempData.areas.length > 0
      area =          @_stepData.tempData.areas.pop()
      oldTerritory =  @_stepData.tempData.oldTerritories.pop()
      newTerritory =  @_stepData.tempData.newTerritories.pop()

      # area has been clipped => recreate old territory
      if newTerritory
        area.territory = oldTerritory
        area.handle.update()

      # area has been hidden => recreate whole area with old territory
      else
        area.territory = oldTerritory
        area.handle.show()


  # ============================================================================
  # UNI = Unify Selected Areas (automatically, no input required)
  # ============================================================================

  _UNI: () ->

    # delete all selected areas
    oldGeometries = []
    for areaTerritory in @_stepData.inData.areaTerritories
      oldGeometries.push areaTerritory.geometry

      # get selected area
      oldArea = areaTerritory.area

      # unlink Area <- AreaName/AreaTerritory
      oldArea.name = null
      oldArea.territory = null

      # hide area
      oldArea.handle.hide()


    # unify old areas to new area
    unifiedGeometry = @_geometryOperator.union oldGeometries

    # create Area and AreaTerritory
    newArea = new HG.Area @_hgInstance.editOperation.getRandomId()
    newTerritory = new HG.AreaTerritory {
        id:                   @_hgInstance.editOperation.getRandomId()
        geometry:             unifiedGeometry
        representativePoint:  unifiedGeometry.getCenter()
      }

    # link Area <-> AreaTerritory
    newArea.territory = newTerritory
    newTerritory.area = newArea

    # create AreaHandle <-> Area
    newHandle = new HG.AreaHandle @_hgInstance, newArea
    newArea.handle = newHandle

    # show area via areaHandle
    newHandle.show()
    newHandle.select()
    newHandle.startEdit()

    # add to operation workflow
    @_stepData.outData.areas[0] =            newArea
    @_stepData.outData.areaNames[0] =        null
    @_stepData.outData.areaTerritories[0] =  newTerritory

  # ============================================================================
  _UNI_reverse: () ->

    # get areaHandle from operation workflow
    newArea = @_stepData.outData.areas[0]

    # remove it => hides, deselects and leaves edit mode automatically
    newArea.handle.destroy()

    # restore previously selected areas
    idx = 0
    while idx < @_stepData.inData.areas.length
      oldArea =       @_stepData.inData.areas[idx]
      oldName =       @_stepData.inData.areaNames[idx]
      oldTerritory =  @_stepData.inData.areaTerritories[idx]

      # link Area <- AreaName/AreaTerritory
      oldArea.name =      oldName
      oldArea.territory = oldTerritory

      # show area
      oldArea.handle.show()

      # restore next area
      idx++

  # ============================================================================
  # SEP = Separate Selected Area
  # ============================================================================

  _SEP: () ->

  # ============================================================================
  _SEP_reverse: () ->


  # ============================================================================
  # TCH = Change Territory of One or the Border Between Two Territoris
  # ============================================================================

  _TCH: () ->

  # ============================================================================
  _TCH_reverse: () ->


  # ============================================================================
  # DES = Destruction of an Area
  # ============================================================================

  _DES: () ->
    # get selected area
    oldArea =       @_stepData.inData.areas[0]
    oldName =       @_stepData.inData.areaNames[0]
    oldTerritory =  @_stepData.inData.areaTerritories[0]

    # unlink Area <- AreaName/AreaTerritory
    oldArea.name =      null
    oldArea.territory = null

    # hide area
    oldArea.handle.hide()

  # ============================================================================
  _DES_reverse: () ->
    # get selected area
    oldArea =       @_stepData.inData.areas[0]
    oldName =       @_stepData.inData.areaNames[0]
    oldTerritory =  @_stepData.inData.areaTerritories[0]

    # unlink Area <- AreaName/AreaTerritory
    oldArea.name =      oldName
    oldArea.territory = oldTerritory

    # show area
    oldArea.handle.show()



  ##############################################################################

  # ============================================================================
  # end the operation
  # ============================================================================

  _cleanup: (direction) ->

    ### CLEANUP OPERATION ###

    @_hgInstance.newTerritoryTool?.destroy()
    @_hgInstance.newTerritoryTool = null

    @_hgInstance.editMode.leaveAreaEditMode() if direction is -1