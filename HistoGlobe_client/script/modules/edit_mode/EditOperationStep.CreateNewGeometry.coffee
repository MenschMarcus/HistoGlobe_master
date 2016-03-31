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
    @_areaController = @_hgInstance.areaController
    @_geometryOperator = new HG.GeometryOperator


    ### SETUP OPERATION (1) ###

    @notifyEditMode 'onEnableAreaEditMode' if @_isForward

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
          area = @_areaController.getArea(id)
          oldIds.push id
          oldGeometries.push area.getGeometry()
          # save in temporary areas to restore them later
          @_stepData.tempAreas.push {
            'id':             id
            'geometry':       area.getGeometry()
            'shortName':      area.getShortName()
            'formalName':     area.getFormalName()
            'reprPoint':      area.getRepresentativePoint()
          }
          # remove area
          @notifyEditMode 'onRemoveAreaName', id
          @notifyEditMode 'onRemoveAreaGeometry', id

        # unify old areas to new area
        unifiedGeometry = @_geometryOperator.union oldGeometries
        newId = "UNION"
        newId += ("_"+areaId) for areaId in oldIds

        @_stepData.outData.createdAreas.push newId

        @notifyEditMode 'onCreateAreaGeometry', newId, unifiedGeometry
        @notifyEditMode 'onSelectArea', newId

      else # backward operation => do reverse

        # remove unified area
        unifiedAreaId = @_stepData.outData.createdAreas[0]
        @_stepData.outData.createdAreas = []
        @notifyEditMode 'onDeselectArea', unifiedAreaId
        @notifyEditMode 'onRemoveAreaGeometry', unifiedAreaId

        # restore previously selected areasunifiedAreaId
        for area in @_stepData.tempAreas
          @notifyEditMode 'onCreateAreaGeometry', area.id, area.geometry
          @notifyEditMode 'onCreateAreaName', area.id, area.shortName, area.formalName, area.reprPoint

      return @finish() # no user input


    # --------------------------------------------------------------------------
    ## change name operation
    else if @_stepData.operationCommand is 'CHN'

      # nothing to do => hand area further to next / previous step
      if @_isForward
        @_stepData.outData.createdAreas.push @_stepData.inData.selectedAreas[0]
      else
        @_stepData.inData.selectedAreas.push @_stepData.outData.createdAreas[0]

      return @finish() # no user input


    # --------------------------------------------------------------------------
    ## delete operation
    else if @_stepData.operationCommand is 'DEL'

      if @_isForward
        for id in @_stepData.inData.selectedAreas
          area = @_areaController.getArea id
          # save in temporary areas to restore them later
          @_stepData.tempAreas.push {
            'id':             id
            'geometry':       area.getGeometry()
            'shortName':      area.getShortName()
            'formalName':     area.getFormalName()
            'reprPoint':      area.getRepresentativePoint()
          }
          @notifyEditMode 'onRemoveAreaName', id
          @notifyEditMode 'onRemoveAreaGeometry', id

      else # backward
        for area in @_stepData.tempAreas
          @notifyEditMode 'onCreateAreaGeometry', area.id, area.geometry
          @notifyEditMode 'onCreateAreaName', area.id, area.shortName, area.formalName, area.reprPoint

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
        # TODO: make more efficient later

        # manual loop, because some areas might be deleted on the way
        existingAreas = @_areaController.getActiveAreas()
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
              'removed':      not newGeometry.isValid()  # was the area rremoved in the process?
              'geometry':     existingGeometry
              'shortName':    existingShortName
              'formalName':   existingFormalName
              'reprPoint':    existingReprPoint
            }
            if newGeometry.isValid()
              @notifyEditMode 'onUpdateAreaGeometry', existingAreaId, newGeometry
            else # area is gone
              @notifyEditMode 'onRemoveAreaName', existingAreaId
              @notifyEditMode 'onRemoveAreaGeometry', existingAreaId

          loopIdx--

        # insert new geometry into new area and add it
        addAreaId = 'NEW_AREA'
        @_stepData.outData.createdAreas.push addAreaId
        @notifyEditMode 'onCreateAreaGeometry', addAreaId, clipGeometry
        @notifyEditMode 'onSelectArea', addAreaId

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
            @notifyEditMode 'onDeselectArea', newId
            @notifyEditMode 'onRemoveAreaGeometry', newId

            # restore old areas
            while @_stepData.tempAreas.length > 0
              area = @_stepData.tempAreas.pop()
              if area.removed # removed in forward => recreate in backward
                @notifyEditMode 'onCreateAreaGeometry', area.id, area.geometry
                @notifyEditMode 'onCreateAreaName', area.id, area.shortName, area.formalName, area.reprPoint
              else # updated in forward => update in backward
                @notifyEditMode 'onUpdateAreaGeometry', area.id, area.geometry, area.reprPoint

            # go to previous area
            @_finish = no
            @_makeNewGeometry -1
        }


      # ------------------------------------------------------------------------
      ## separate areas operation
      else if @_stepData.operationCommand is 'SEP'
        existingArea = @_areaController.getArea @_stepData.inData.selectedAreas[0]

        existingAreaId =      existingArea.getId()
        existingGeometry =    existingArea.getGeometry()
        existingShortName =   existingArea.getShortName()
        existingFormalName =  existingArea.getFormalName()
        existingReprPoint =   existingArea.getRepresentativePoint()

        # clip incoming geometry (= clipGeometry) to selected geometry
        # -> create new area
        newGeometry = @_geometryOperator.intersection existingGeometry, clipGeometry
        newId = 'SEP_AREA_' + @_stepData.outData.createdAreas.length
        @notifyEditMode 'onCreateAreaGeometry', newId, newGeometry
        @notifyEditMode 'onSelectArea', newId
        @_stepData.outData.createdAreas.push newId

        # update existing areas (or remove when fully separated)
        updatedGeometry = @_geometryOperator.difference existingGeometry, clipGeometry
        @notifyEditMode 'onDeselectArea', existingAreaId
        if updatedGeometry.isValid()
          @notifyEditMode 'onUpdateAreaGeometry', existingAreaId, updatedGeometry
        else
          @notifyEditMode 'onRemoveAreaName', existingAreaId
          @notifyEditMode 'onRemoveAreaGeometry', existingAreaId

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
              @notifyEditMode 'onCreateAreaGeometry', updatedArea.id, updatedArea.geometry
              @notifyEditMode 'onCreateAreaName', updatedArea.id, updatedArea.shortName, updatedArea.formalName, updatedArea.reprPoint
            else # update
              @notifyEditMode 'onUpdateAreaGeometry', updatedArea.id, updatedArea.geometry, updatedArea.reprPoint
            @notifyEditMode 'onSelectArea', updatedArea.id

            # delete newly created area
            newArea = @_stepData.outData.createdAreas.pop()
            @notifyEditMode 'onDeselectArea', newArea
            @notifyEditMode 'onRemoveAreaGeometry', newArea

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

        A_id = @_stepData.inData.selectedAreas[0]
        B_id = @_stepData.inData.selectedAreas[1]
        A_area = @_areaController.getArea A_id
        B_area = @_areaController.getArea B_id

        A_shortName = A_area.getShortName()
        B_shortName = B_area.getShortName()
        A_formalName = A_area.getFormalName()
        B_formalName = B_area.getFormalName()
        A_point = A_area.getRepresentativePoint()
        B_point = B_area.getRepresentativePoint()

        A = A_area.getGeometry()
        B = B_area.getGeometry()
        C = clipGeometry

        # test: which country was covered in clip area?
        A_covered = @_geometryOperator.isWithin A, C

        AuB = @_geometryOperator.union [A, B]

        # 2 cases: A first and B first
        if A_covered
          A_new = @_geometryOperator.intersection AuB, C
          B_new = @_geometryOperator.difference AuB, C
        else  # B is covered
          B_new = @_geometryOperator.intersection AuB, C
          A_new = @_geometryOperator.difference AuB, C

        @_stepData.tempAreas[0] = {
          'id':           A_id
          'clip':         C
          'geometry':     A
          'shortName':    A_shortName
          'formalName':   A_formalName
          'reprPoint':    A_point
        }
        @_stepData.tempAreas[1] = {
          'id':           B_id
          'clip':         C
          'geometry':     B
          'shortName':    B_shortName
          'formalName':   B_formalName
          'reprPoint':    B_point
        }

        # update both areas
        @notifyEditMode 'onUpdateAreaGeometry', A_id, A_new
        @notifyEditMode 'onUpdateAreaGeometry', B_id, B_new

        # add to workflow
        @_stepData.outData.createdAreas[0] = A_id
        @_stepData.outData.createdAreas[1] = B_id

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

            # revert changes of old areas
            A = @_stepData.tempAreas[0]
            B = @_stepData.tempAreas[1]
            @notifyEditMode 'onUpdateAreaGeometry', A.id, A.geometry, A.reprPoint
            @notifyEditMode 'onUpdateAreaGeometry', B.id, B.geometry, B.reprPoint
            @_stepData.tempAreas = []
            @_stepData.outData.createdAreas = []

            # # restore old areas + cleanup arrays
            # while @_stepData.tempAreas.length > 0
            #   @_stepData.outData.createdAreas.pop()
            #   area = @_stepData.tempAreas.pop()
            #   @notifyEditMode 'onUpdateAreaGeometry', {
            #     id:                   area.id,
            #     geometry:             area.geometry,
            #     shortName:            area.shortName,
            #     formalName:           area.formalName,
            #     representativePoint:  area.point
            #   }
            #   @notifyEditMode 'onSelectArea', area.id

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

    @notifyEditMode 'onDisableAreaEditMode' if not @_isForward