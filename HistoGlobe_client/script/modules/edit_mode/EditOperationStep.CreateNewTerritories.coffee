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


    ### SETUP OPERATION ###

    # make only edit areas focusable and make sure multiple areas can be selected
    @_hgInstance.editMode.enterAreaEditMode() if direction is 1
    @_hgInstance.areaController.enableMultiSelection HGConfig.max_area_selection.val

    # for SEP and TCH operation, put selected area into edit mode and select it
    if direction is 1
      switch @_operationId
        when 'SEP', 'SEC', 'TCH', 'BCH', 'NCH'
          for area in @_stepData.inData.areas
            area.handle.startEdit()
            area.handle.select()

    # start at first (forward) resp. last (backward) area
    if direction is 1
      @_areaIdx = -1
    else
      @_areaIdx = @_stepData.outData.areas.length


    # ==========================================================================

    ### AUTOMATIC PROCESSING ###

    switch @_operationId

      # ------------------------------------------------------------------------
      when 'UNI', 'INC'                                 ## unification operation
        if direction is 1   # forward
          @_UNI()
          return @finish()

        else                # backward
          @_UNI_reverse()
          return @abort()

      # ------------------------------------------------------------------------
      when 'NCH'                                        ## name change operation
        if direction is 1   # forward
          @_NCH()
          return @finish()

        else                # backward
          @_NCH_reverse()
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

    @_makeNewTerritory direction


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _makeNewTerritory: (direction) ->

    # go to next/previous area
    @_areaIdx += direction

    # special case: 'BCH' operation makes two operations at the same time
    # => de/increase areaIdx again for this operation
    @_areaIdx += direction if @_operationId is 'BCH'

    # restore previously drawn clip geometry (if there is one)
    drawLayer = @_stepData.tempData.drawLayers[@_areaIdx]

    # backward into this step => reverse last operation
    if direction is -1
      switch @_operationId
        when 'CRE'        then @_CRE_reverse()
        when 'SEP', 'SEC' then @_SEP_reverse()
        when 'TCH', 'BCH' then @_TCH_reverse()

    # set up NewTerritoryTool to define geometry of an area interactively
    newTerritoryTool = new HG.NewTerritoryTool @_hgInstance, drawLayer, @_areaIdx is 0


    ### LISTEN TO USER INPUT ###
    newTerritoryTool.onSubmit @, (clipGeometry, drawLayer) =>  # incoming geometry: clipGeometry

      # save leaflet:draw layers to be restores later
      @_stepData.tempData.drawLayers[@_areaIdx] = drawLayer

      switch @_operationId

        # ======================================================================
        when 'CRE'                                            ## create new area

          @_CRE clipGeometry

          # only one step necessary => finish
          return @finish()

        # ======================================================================
        when 'SEP', 'SEC'                                      ## separate areas

          complete = @_SEP clipGeometry

          # finish when old area was separated completely
          if complete
            return @finish()

          # otherwise cleanup and continue with next area
          else
            @_hgInstance.newTerritoryTool?.destroy()
            @_hgInstance.newTerritoryTool = null
            @_makeNewTerritory 1

            # make action reversible
            @_undoManager.add {
              undo: =>
                # cleanup
                @_hgInstance.newTerritoryTool?.destroy()
                @_hgInstance.newTerritoryTool = null
                # area left to restore => go back one step
                if @_stepData.tempData.areas.length > 0
                  @_makeNewTerritory -1
                # no area left => first action => abort step and go backwards
                else
                  @abort()
            }


        # ======================================================================
        when 'TCH', 'BCH'                            # territory / border change

          @_TCH clipGeometry

          # only one step necessary => finish
          return @finish()


  ##############################################################################
  # DEFINITION OF ACTUAL OPERATIONS

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


          # area has been hidden => remove territory and update
          else

            # update Area
            newTerritory = null
            currArea.territory = null

            # update view
            currArea.handle.hide()

          # add to workflow
          @_stepData.tempData.areas.push          currArea
          @_stepData.tempData.oldTerritories.push currTerritory
          @_stepData.tempData.newTerritories.push newTerritory

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
  # UNI = unify selected areas (automatically, no input required)
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
    newArea = new HG.Area   @_hgInstance.editOperation.getRandomId()
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
  # SEP = separate selected area (multiple iterations)
  # ============================================================================

  _SEP: (clipGeometry) ->

    # area separated completely?
    separationComplete = no

    ## get current area status
    currArea = @_stepData.inData.areas[0]

    # first action: get initial territory and detach name
    if @_areaIdx is 0
      currTerritory = @_stepData.inData.areaTerritories[0]
      currArea.name = null
      currArea.handle.update()

    # every other action: use the temporary territory from last step
    else
      currTerritory = @_stepData.tempData.newTerritories[@_areaIdx-1]

    ## update selected area and cut the drawn part out of it
    updateGeometry = @_geometryOperator.difference currTerritory.geometry, clipGeometry

    # area has been clipped => update territory
    if updateGeometry.isValid()

      # create new Territory
      updateTerritory = new HG.AreaTerritory {
        id:                   @_hgInstance.editOperation.getRandomId()
        geometry:             updateGeometry
        representativePoint:  updateGeometry.getCenter()
      }

      # link Area <-> AreaTerritory
      updateTerritory.area = currArea
      currArea.territory = updateTerritory

      # update view
      currArea.handle.update()

    # area has been hidden => remove territory and update
    else

      # update Area
      updateTerritory = null
      currArea.territory = null

      # update view
      currArea.handle.hide()
      separationComplete = yes


    # add to workflow
    @_stepData.tempData.areas.push          currArea
    @_stepData.tempData.oldTerritories.push currTerritory
    @_stepData.tempData.newTerritories.push updateTerritory

    # deselect current area so it can be selected now for use as rest polygon
    currArea.handle.deselect()


    ## create new area
    newGeometry = @_geometryOperator.intersection currTerritory.geometry, clipGeometry

    # create Area and AreaTerritory based on the clip geometry
    newArea = new HG.Area   @_hgInstance.editOperation.getRandomId()
    newTerritory = new HG.AreaTerritory {
      id:                   @_hgInstance.editOperation.getRandomId()
      geometry:             newGeometry
      representativePoint:  newGeometry.getCenter()
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
    # N.B. for outData use push() (forward operation) and pop() (backward)
    # to ensure that there is only data in that has actually been created
    @_stepData.outData.areas.push            newArea
    @_stepData.outData.areaNames.push        null
    @_stepData.outData.areaTerritories.push  newTerritory

    separationComplete


  # ============================================================================
  _SEP_reverse: () ->

    # remove new area => hides, deselects and leaves edit mode automatically
    newArea = @_stepData.outData.areas.pop()
    newName = @_stepData.outData.areaNames.pop()
    newTerritory = @_stepData.outData.areaTerritories.pop()
    newArea.handle.destroy()

    # restore old Area with its AreaTerritory
    oldArea =       @_stepData.tempData.areas.pop()
    oldTerritory =  @_stepData.tempData.oldTerritories.pop()
    newTerritory =  @_stepData.tempData.newTerritories.pop()

    oldArea.territory = oldTerritory

    # Area was visible before => update
    if newTerritory
      oldArea.handle.update()
    # Area was hidden before => show
    else
      oldArea.handle.show()
      oldArea.handle.startEdit()
      oldArea.handle.select()


    # in second step remaining area must be selectable as leftover geometry
    if @_stepData.tempData.areas.length is 1
      oldArea.handle.deselect()

    # in first action, prepare area for sending it back to first steP:
    # reattach the name, leave edit mode and select it
    else if @_stepData.tempData.areas.length is 0
      oldName = @_stepData.inData.areaNames[0]
      oldArea.name = oldName
      oldArea.handle.update()
      oldArea.handle.endEdit()
      oldArea.handle.select()

  # ============================================================================
  # TCH = change territory of one or the border between two territories
  # ============================================================================

  _TCH: (clipGeometry) ->

    # distinction: 1 (TCH) or 2 (BCH) areas changed
    if @_stepData.inData.areas.length is 1
      operation = 'TCH'
    else if @_stepData.inData.areas.length is 2
      operation = 'BCH'
    else
      return console.error "The TCH Operation does not have the necessary number of areas provided"


    # --------------------------------------------------------------------------
    if operation is 'TCH'                         # single-area territory change
      # write variable in editOperation
      @_hgInstance.editOperation.operation.id = 'TCH'

      currArea        = @_stepData.inData.areas[0]
      currName        = @_stepData.inData.areaNames[0]
      currTerritory   = @_stepData.inData.areaTerritories[0]

      newGeometry = @_geometryOperator.intersection currTerritory.geometry, clipGeometry

      # create AreaTerritory based on the clip geometry
      newTerritory = new HG.AreaTerritory {
        id:                   @_hgInstance.editOperation.getRandomId()
        geometry:             newGeometry
        representativePoint:  newGeometry.getCenter()
      }

      # link Area <-> AreaTerritory
      currArea.territory = newTerritory
      newTerritory.area = currArea

      # update area
      currArea.handle.update()

      # add to operation workflow
      @_stepData.outData.areas[0] =            currArea
      @_stepData.outData.areaNames[0] =        currName
      @_stepData.outData.areaTerritories[0] =  newTerritory


    # --------------------------------------------------------------------------
    else                                                # two-area border change
      # write variable in editOperation
      @_hgInstance.editOperation.operation.id = 'BCH'

      # idea: both areas A and B get a new common border
      # => unify both areas and use the drawn geometry C as a clip polygon
      # A' = (A \/ B) /\ C    intersection (A u B) with C
      # B' = (A \/ B) - C     difference (A u B) with C

      A_area = @_stepData.inData.areas[0]
      B_area = @_stepData.inData.areas[1]
      A_name = @_stepData.inData.areaNames[0]
      B_name = @_stepData.inData.areaNames[1]
      A_territory = @_stepData.inData.areaTerritories[0]
      B_territory = @_stepData.inData.areaTerritories[1]

      A = A_territory.geometry
      B = B_territory.geometry
      C = clipGeometry

      # test: which country was covered in clip area?
      A_covered = @_geometryOperator.isWithin A, C

      AuB = @_geometryOperator.union [A, B]

      # 2 cases: A first and B first
      if A_covered
        A_newGeometry = @_geometryOperator.intersection AuB, C
        B_newGeometry = @_geometryOperator.difference AuB, C
      else  # B is covered
        B_newGeometry = @_geometryOperator.intersection AuB, C
        A_newGeometry = @_geometryOperator.difference AuB, C

      # create new AreaTerritories
      A_newTerritory = new HG.AreaTerritory {
        id:                   @_hgInstance.editOperation.getRandomId()
        geometry:             A_newGeometry
        representativePoint:  A_newGeometry.getCenter()
      }
      B_newTerritory = new HG.AreaTerritory {
        id:                   @_hgInstance.editOperation.getRandomId()
        geometry:             B_newGeometry
        representativePoint:  B_newGeometry.getCenter()
      }

      # link Area <-> AreaTerritories
      A_newTerritory.area = A_area
      A_area.territory = A_newTerritory
      B_newTerritory.area = B_area
      B_area.territory = B_newTerritory

      # update handle
      A_area.handle.update()
      B_area.handle.update()

      # add to workflow
      @_stepData.outData.areas[0] = A_area
      @_stepData.outData.areas[1] = B_area
      @_stepData.outData.areaNames[0] = A_name
      @_stepData.outData.areaNames[1] = B_name
      @_stepData.outData.areaTerritories[0] = A_newTerritory
      @_stepData.outData.areaTerritories[1] = B_newTerritory


  # ============================================================================
  _TCH_reverse: () ->

    idx = 0   # for each selected Area
    while idx < @_stepData.inData.areas.length

      # get old AreaTerritory
      oldArea = @_stepData.inData.areas[idx]
      oldTerritory = @_stepData.inData.areaTerritories[idx]

      # restore old AreaTerritory
      oldArea.territory = oldTerritory
      oldArea.handle.update()

      # go to next area
      idx++


  # ============================================================================
  # NCH = change the name of an area
  # ============================================================================

  _NCH: () ->
    # hand over area to next step
    @_stepData.outData = @_stepData.inData

  # ============================================================================
  _NCH_reverse: () ->
    # hand over area to previous step
    @_stepData.inData = @_stepData.outData


  # ============================================================================
  # DES = destruct an area
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

    if direction is -1
      @_hgInstance.editMode.leaveAreaEditMode()
      switch @_operationId
        when 'SEP', 'SEC', 'TCH', 'BCH', 'NCH'
          for area in @_stepData.inData.areas
            area.handle.deselect()
            area.handle.endEdit()