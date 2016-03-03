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
    super @_hgInstance, @_stepData

    # get external modules
    @_workflowWindow = @_hgInstance.workflowWindow
    @_areaController = @_hgInstance.areaController
    @_geometryOperator = new HG.GeometryOperator

    @_firstIteration = yes


    ### SETUP OPERATION ###

    @notifyEditMode 'onEnableAreaEditMode'

    # some operations work directly on selected areas from first step
    # PROBLEM: AreaController deselects them by disabling multi-selection mode

    if @_stepData.operationCommand is 'SEP'
      @notifyEditMode 'onStartEditArea', @_stepData.inData.selectedAreas[0]
      @notifyEditMode 'onSelectArea', @_stepData.inData.selectedAreas[0]

    else if @_stepData.operationCommand is 'CHB'
      @notifyEditMode 'onStartEditArea', @_stepData.inData.selectedAreas[0]
      @notifyEditMode 'onStartEditArea', @_stepData.inData.selectedAreas[1]
      @notifyEditMode 'onSelectArea', @_stepData.inData.selectedAreas[0]
      @notifyEditMode 'onSelectArea', @_stepData.inData.selectedAreas[1]

    else if @_stepData.operationCommand is 'CHN'
      @notifyEditMode 'onStartEditArea', @_stepData.inData.selectedAreas[0]
      @notifyEditMode 'onSelectArea', @_stepData.inData.selectedAreas[0]


    ## unification operation
    if @_stepData.operationCommand is 'UNI'

      # delete all selected areas
      oldGeometries = []
      oldIds = []
      for id in @_stepData.inData.selectedAreas
        oldIds.push id
        oldGeometries.push @_areaController.getArea(id).getGeometry()
        @notifyEditMode 'onRemoveArea', id

      # unify old areas to new area
      unifiedGeometry = @_geometryOperator.union oldGeometries
      # TODO: give reasonable Area id in next step
      newId = "UNION"
      newId += ('_'+areaId) for areaId in oldIds
      @notifyEditMode 'onCreateArea', newId, unifiedGeometry, null
      @notifyEditMode 'onSelectArea', newId
      @_stepData.outData.createdAreas.push newId

      return @finish()


    ## change name operation
    else if @_stepData.operationCommand is 'CHN'

      # nothing to do => hand area further to next sstep
      @_stepData.outData.createdAreas.push @_stepData.inData.selectedAreas[0]

      return @finish()


    ## delete operation
    else if @_stepData.operationCommand is 'DEL'

      # delete selected area
      @notifyEditMode 'onRemoveArea', @_stepData.inData.selectedAreas[0]

      return @finish()


    ## for backward step
    # else

    #   ## unification operation
    #   if @_stepData.operationCommand is 'UNI'

    #     # restore unified area
    #     @_areaController.removeArea @_stepData.outData.createdAreas[0]
    #     @_stepData.outData.createdAreas = []
    #     # TODO: delete the area? will it stay in the memory?
    #     # re-add all previously selected areas
    #     for area in @_stepData.inData.selectedAreas
    #       @_areaController.addArea area

    #   ## delete operation
    #   else if @_stepData.operationCommand is 'DEL'

    #     # restore selected area
    #     @_areaController.addArea @_stepData.inData.selectedAreas[0]


    ### REACT ON USER INPUT ###
    if @_stepData.userInput

      # for each required area
      @_makeNewGeometry = () =>

        # set up NewGeometryTool to define geometry of an area interactively
        @_newGeometryTool = new HG.NewGeometryTool @_hgInstance, @_firstIteration
        @_newGeometryTool.onSubmit @, (inGeometry) =>

          # finish criterion, to be decided by each step on its own
          finish = no

          ## create new country operation
          if @_stepData.operationCommand is 'ADD'

            newGeometry = inGeometry

            # clip new geometry to existing geomtries
            # check for intersection with each country
            # TODO: make more efficient later

            # manual loop, because some areas might be deleted on the way
            existingAreas = @_areaController.getAreas()
            loopIdx = existingAreas.length-1
            while loopIdx >= 0
              existingArea = existingAreas[loopIdx]
              existingAreaId = existingArea.getId()
              existingGeometry = existingArea.getGeometry()
              intersectionGeometry = @_geometryOperator.intersection newGeometry, existingGeometry

              # if new geometry intersects with an existing geometry
              # clip the existing geometry to the new geometry and update its area
              if intersectionGeometry.isValid()
                clipGeometry = @_geometryOperator.difference existingGeometry, newGeometry
                # if something is still left, update it
                if clipGeometry.isValid()
                  @notifyEditMode 'onUpdateAreaGeometry', existingAreaId, clipGeometry
                # if nothing is left, delete it
                else
                  @notifyEditMode 'onRemoveArea', existingAreaId
              loopIdx--

            # insert new geometry into new area and add to HistoGlobe
            newId = 'NEW_AREA' # TODO: refine this id in next step
            @notifyEditMode 'onCreateArea', newId, newGeometry, null
            @notifyEditMode 'onSelectArea', newId
            @_stepData.outData.createdAreas.push newId

            # finish criterion: only one step necessary
            finish = yes


          ## separate geometries operation
          else if @_stepData.operationCommand is 'SEP'

            existingAreaId = @_stepData.inData.selectedAreas[0]
            existingGeometry = @_areaController.getArea(existingAreaId).getGeometry()
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
            # if something is still left, update it
            if updatedGeometry.isValid()
              @notifyEditMode 'onUpdateAreaGeometry', existingAreaId, updatedGeometry
              @notifyEditMode 'onDeselectArea', existingAreaId
            # if nothing is left, delete it
            else
              @notifyEditMode 'onRemoveArea', existingAreaId

              # finish criterion: existing area is completely split up
              finish = yes


          ## separate geometries operation
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

            # update both geometries
            @notifyEditMode 'onUpdateAreaGeometry', Aid, A2
            @notifyEditMode 'onUpdateAreaGeometry', Bid, B2

            # add to workflow
            @_stepData.outData.createdAreas.push Aid
            @_stepData.outData.createdAreas.push Bid

            # done!
            finish = yes


          # cleanup
          @_newGeometryTool.destroy()
          delete @_newGeometryTool  # TODO: necessary?

          @_firstIteration = no # will stay no forever


          ## finish criteria
          if finish
            @finish()

          # not finished => go to next step
          else
            @_makeNewGeometry()


      # start new geometry loop here
      @_makeNewGeometry()


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  _cleanup: () ->

    ### CLEANUP OPERATION ###
    if @_newGeometryTool?
      @_newGeometryTool.destroy()
      delete @_newGeometryTool

