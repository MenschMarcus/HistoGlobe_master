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

    ## unification operation
    if @_stepData.operationCommand is 'UNI'
      if @_isForward
        @_unifySelectedAreas()
      else
        @_unifySelectedAreas_reverse()
      return @finish() # no user input

    ## change name operation
    else if @_stepData.operationCommand is 'CHN'
      # nothing to do => hand area further to next / previous step
      if @_isForward
        @_stepData.outData.createdAreas.push @_stepData.inData.selectedAreas[0]
      else
        @_stepData.inData.selectedAreas.push @_stepData.outData.createdAreas[0]
      return @finish() # no user input

    ## delete operation
    else if @_stepData.operationCommand is 'DEL'
      if @_isForward
        id = @_stepData.inData.selectedAreas[0]
        @notifyEditMode 'onRemoveArea', @_stepData.inData.selectedAreas[0]
        # save in temporary areas to restore them later
        @_stepData.tempAreas.push {
          'id':             id
          'geometry':       @_areaController.getArea(id).getGeometry()
          'name':           @_areaController.getArea(id).getName()
        }
      else
        area = @_stepData.tempAreas[0]
        @notifyEditMode 'onRestoreArea', area.id, area.geometry, area.name
      return @finish() # no user input


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
    newGeometryTool.onSubmit @, (inGeometry) =>

      ## add new area operation
      if @_stepData.operationCommand is 'ADD'

        clipGeometry = inGeometry

        # clip new geometry to existing geometries
        # check for intersection with each active area on the map
        # TODO: make more efficient later

        # manual loop, because some areas might be deleted on the way
        existingAreas = @_areaController.getAreas()
        loopIdx = existingAreas.length-1
        while loopIdx >= 0
          existingAreaId = existingAreas[loopIdx].getId()
          existingGeometry = existingAreas[loopIdx].getGeometry()

          # if new geometry intersects with an existing geometry
          # => clip the existing geometry to the new geometry and update its area
          intersectionGeometry = @_geometryOperator.intersection clipGeometry, existingGeometry
          if intersectionGeometry.isValid()

            newGeometry = @_geometryOperator.difference existingGeometry, clipGeometry
            @_stepData.tempAreas.push {
              'id':           existingAreaId
              'clip':         clipGeometry
              'geometry':     existingGeometry
            }
            @notifyEditMode 'onUpdateAreaGeometry', existingAreaId, newGeometry

          loopIdx--

        # insert new geometry into new area and add to HistoGlobe
        addAreaId = 'NEW_AREA' # TODO: refine this id in next step
        @_stepData.outData.createdAreas.push addAreaId
        @notifyEditMode 'onCreateArea', addAreaId, clipGeometry, null
        @notifyEditMode 'onSelectArea', addAreaId

        # finish criterion: only one step necessary
        @_finish = yes

        # make action reversible
        @_undoManager.add {
          undo: =>
            # clean data
            @_stepData.outData.createdAreas = []

            # delete new area
            @notifyEditMode 'onRemoveArea', newId

            # restore old areas
            for area in @_stepData.tempAreas
              @notifyEditMode 'onUpdateAreaGeometry', area.id, area.geometry

            # cleanup
            @_hgInstance.newGeometryTool?.destroy()
            @_hgInstance.newGeometryTool = null

            # go to previous area
            @_finish = no
            @_makeNewGeometry -1
        }


      ## separate areas operation
      else if @_stepData.operationCommand is 'SEP'

        existingAreaId = @_stepData.inData.selectedAreas[0]
        existingGeometry = @_areaController.getArea(existingAreaId).getGeometry()
        existingName = @_areaController.getArea(existingAreaId).getName()
        clipGeometry = inGeometry

        # clip incoming geometry (= clipGeometry) to selected geometry
        # -> create new area
        newGeometry = @_geometryOperator.intersection existingGeometry, clipGeometry
        newId = 'SEP_AREA_' + @_stepData.outData.createdAreas.length
        @notifyEditMode 'onCreateArea', newId, newGeometry, null
        @notifyEditMode 'onSelectArea', newId
        @_stepData.outData.createdAreas.push newId

        # update existing geometry
        updatedGeometry = @_geometryOperator.difference existingGeometry, clipGeometry
        # update geometry
        # N.B: no difference between geometry left or no geometry left,
        # because "onRemoveArea" does not set the geometry to null
        # -> it could not be restored afterwards
        @notifyEditMode 'onUpdateAreaGeometry', existingAreaId, updatedGeometry
        @notifyEditMode 'onDeselectArea', existingAreaId

        # finish criterion: existing area is completely split up
        @_finish = yes  if not updatedGeometry.isValid()

        @_stepData.tempAreas.push {
          'id':           existingAreaId
          'clip':         clipGeometry
          'geometry':     existingGeometry
          'name':         existingName
          'usedRest':     @_finish    # bool: has user just clicked on rest?
        }


        # make action reversible
        @_undoManager.add {
          undo: =>
            # cleanup
            @_hgInstance.newGeometryTool?.destroy()
            @_hgInstance.newGeometryTool = null

            # delete new area
            createdAreaId = @_stepData.outData.createdAreas.pop()
            @notifyEditMode 'onRemoveArea', createdAreaId

            # restore old state of original area
            existingArea = @_stepData.tempAreas.pop()
            @notifyEditMode 'onUpdateAreaGeometry', existingArea.id, existingArea.geometry
            @notifyEditMode 'onUpdateAreaName', existingArea.id, existingArea.name
            @notifyEditMode 'onDeselectArea', existingArea.id

            # go to previous area
            @_finish = no
            @_makeNewGeometry -1
        }


      ## change border operation
      else if @_stepData.operationCommand is 'CHB'

        # idea: both areas A and B get a new common border
        # => unify both areas and use the drawn geometry C as a clip polygon
        # A' = (A \/ B) /\ C    intersection (A u B) with C
        # B' = (A \/ B) - C     difference (A u B) with C

        Aid = @_stepData.inData.selectedAreas[0]
        Bid = @_stepData.inData.selectedAreas[1]
        A = @_areaController.getArea(Aid).getGeometry()
        B = @_areaController.getArea(Bid).getGeometry()
        C = inGeometry  # clip geometry

        AuB = @_geometryOperator.union [A, B]

        A2 = @_geometryOperator.intersection AuB, C
        B2 = @_geometryOperator.difference AuB, C

        @_stepData.tempAreas.push {
          'id':          Aid
          'tempAreas':   C
          'oldGeometry': A
          'newGeometry': A2
        }
        @_stepData.tempAreas.push {
          'id':          Bid
          'tempAreas':   C
          'oldGeometry': B
          'newGeometry': B2
        }

        # update both geometries
        @notifyEditMode 'onUpdateAreaGeometry', Aid, A2
        @notifyEditMode 'onUpdateAreaGeometry', Bid, B2

        # add to workflow
        @_stepData.outData.createdAreas.push Aid
        @_stepData.outData.createdAreas.push Bid

        # done!
        @_finish = yes

        # make action reversible
        # TODO: put clip area back and make it editable ;)
        # -> that would be truly inversible!
        @_undoManager.add {
          undo: =>
            # clean data
            @_stepData.outData.createdAreas = []

            # restore old areas
            for area in @_stepData.tempAreas
              @notifyEditMode 'onUpdateAreaGeometry', area.id, area.oldGeometry
              @notifyEditMode 'onSelectArea', area.id

            # cleanup
            @_hgInstance.newGeometryTool?.destroy()
            @_hgInstance.newGeometryTool = null

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
  _unifySelectedAreas: () ->

    # delete all selected areas
    oldGeometries = []
    oldIds = []
    for id in @_stepData.inData.selectedAreas
      oldIds.push id
      oldGeometries.push @_areaController.getArea(id).getGeometry()
      @notifyEditMode 'onRemoveArea', id

      # save in temporary areas to restore them later
      @_stepData.tempAreas.push {
        'id':             id
        'geometry':       @_areaController.getArea(id).getGeometry()
        'name':           @_areaController.getArea(id).getName()
      }

    # unify old areas to new area
    unifiedGeometry = @_geometryOperator.union oldGeometries
    # TODO: give reasonable Area id in next step
    newId = "UNION"
    newId += ('_'+areaId) for areaId in oldIds

    @_stepData.outData.createdAreas.push newId

    @notifyEditMode 'onCreateArea', newId, unifiedGeometry, null
    @notifyEditMode 'onSelectArea', newId


  # ----------------------------------------------------------------------------
  _unifySelectedAreas_reverse: () ->

    # remove unified area
    unifiedAreaId = @_stepData.outData.createdAreas[0]
    @_stepData.outData.createdAreas = []
    @notifyEditMode 'onRemoveArea', unifiedAreaId

    # restore previously selected areas
    for area in @_stepData.tempAreas
      @notifyEditMode 'onCreateArea', area.id, area.geometry, area.name


  # ============================================================================
  _cleanup: () ->

    ### CLEANUP OPERATION ###
    @_hgInstance.newGeometryTool?.destroy()
    @_hgInstance.newGeometryTool = null

    @notifyEditMode 'onDisableAreaEditMode' if not @_isForward

