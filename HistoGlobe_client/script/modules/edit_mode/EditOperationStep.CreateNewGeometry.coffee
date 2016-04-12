window.HG ?= {}

# ==============================================================================
# Step 2 in Edit Operation Workflow: Newly create geometry(ies)
# ==============================================================================

class HG.EditOperationStep.CreateNewGeometry extends HG.EditOperationStep

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, @_stepData, @_isForward) ->

    # inherit functionality from base class
    super @_hgInstance, @_stepData, @_isForward

    # get external modules
    @_geometryOperator = new HG.GeometryOperator


    ### SETUP OPERATION (1) ###

    # reset states
    if @_isForward
      @_hgInstance.areaController.enableMultiSelection HGConfig.max_area_selection.val
      @_hgInstance.editMode.enterAreaEditMode()

    # some operations work directly on selected areas from first step
    # PROBLEM: AreaController deselects them by disabling multi-selection mode
    # SOLUTION: bring them manually into edit mode and select them

    if @_isForward
      if (@_stepData.operationCommand is 'SEP') or
         (@_stepData.operationCommand is 'CHB') or
         (@_stepData.operationCommand is 'CHN')

        # set each area as selected and editable
        for area in @_stepData.inData.selectedAreas
          @notifyEditMode 'onStartEditArea', area
          @notifyEditMode 'onSelectArea', area


    ### AUTOMATIC PROCESSING ###

    # --------------------------------------------------------------------------
    ## unification operation
    if @_stepData.operationCommand is 'UNI'

      if @_isForward

        # delete all selected areas
        oldGeometries = []
        oldIds = []
        for id in @_stepData.inData.selectedAreas
          area = @_hgInstance.areaController.getActiveArea(id)
          oldIds.push id
          oldGeometries.push area.getGeometry()
          # save in temporary areas to restore them later
          @_stepData.tempAreas.push id
          @notifyEditMode 'onDeactivateArea', id

        # unify old areas to new area
        unifiedGeometry = @_geometryOperator.union oldGeometries
        newId = "UNION"
        newId += ("_"+areaId) for areaId in oldIds

        @_stepData.outData.createdAreas.push newId

        @notifyEditMode 'onCreateArea', newId, unifiedGeometry

      else # backward operation => do reverse

        # remove unified area
        unifiedAreaId = @_stepData.outData.createdAreas[0]
        @_stepData.outData.createdAreas = []
        @notifyEditMode 'onRemoveArea', unifiedAreaId

        # restore previously selected areasunifiedAreaId
        for id in @_stepData.tempAreas
          @notifyEditMode 'onActivateArea', id

      return @finish() # no user input


    # --------------------------------------------------------------------------
    ## change name operation
    else if @_stepData.operationCommand is 'CHN'

      # each operation changes areas, even if they have the same geometry
      # => A copy area to have completely new area that can be renamed in next step
      # => new identity
      if @_isForward
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


    # --------------------------------------------------------------------------
    ## delete operation
    else if @_stepData.operationCommand is 'DEL'

      if @_isForward
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
    ### SETUP OPERATION (2) ###
    @_finish = no

    if @_isForward
      @_areaIdx = -1
      @_makeNewGeometry 1   # direction: positive

    else # backward
      @_areaIdx = @_stepData.outData.createdAreas.length
      @_makeNewGeometry -1  # direction: negative



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _makeNewGeometry: (direction) ->

    # error handling: finish criterion successful => finish
    #                 first geometry -> backward  => abort
    return @finish() if @_finish
    return @abort()  if (@_areaIdx is 0) and (direction is -1)

    # go to next/previous area
    @_areaIdx += direction

    # set up NewGeometryTool to define geometry of an area interactively
    newGeometryTool = new HG.NewGeometryTool @_hgInstance, @_areaIdx is 0


    ### LISTEN TO USER INPUT ###
    newGeometryTool.onSubmit @, (clipGeometry) =>  # incoming geometry: clipGeometry

      # ------------------------------------------------------------------------
      ## add new area operation
      if @_stepData.operationCommand is 'ADD'

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
            @_hgInstance.newGeometryTool?.destroy()
            @_hgInstance.newGeometryTool = null

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
            @_makeNewGeometry -1
        }


      # ------------------------------------------------------------------------
      ## separate areas operation
      else if @_stepData.operationCommand is 'SEP'
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
            @_hgInstance.newGeometryTool?.destroy()
            @_hgInstance.newGeometryTool = null

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
            @_makeNewGeometry -1
        }


# ------------------------------------------------------------------------------
      ## change border operation
      else if @_stepData.operationCommand is 'CHB'

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
            @_hgInstance.newGeometryTool?.destroy()
            @_hgInstance.newGeometryTool = null

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
            @_areaIdx = 0 # manual setting, because CHB step does two areas at once
            @_makeNewGeometry -1
        }


      # cleanup
      @_hgInstance.newGeometryTool?.destroy()
      @_hgInstance.newGeometryTool = null

      # go to next geometry
      @_makeNewGeometry 1


  # ============================================================================
  _cleanup: () ->

    ### CLEANUP OPERATION ###
    @_hgInstance.newGeometryTool?.destroy()
    @_hgInstance.newGeometryTool = null

    # leave edit mode for areas
    if not @_isForward
      @_hgInstance.editMode.leaveAreaEditMode()
      @_hgInstance.areaController.disableMultiSelection()