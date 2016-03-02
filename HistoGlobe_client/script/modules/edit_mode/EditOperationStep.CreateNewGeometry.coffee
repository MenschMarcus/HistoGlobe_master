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


    ### SETUP OPERATION ###

    @notifyEditMode 'onEnableAreaEditMode'

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
      @_stepData.outData.createdAreas.push newId

    ## change name operation
    else if @_stepData.operationCommand is 'CHN'

      # remove the name from the area
      id = @_stepData.inData.selectedAreas[0]
      @notifyEditMode 'onRemoveAreaName', id
      @_stepData.outData.createdAreas.push id


    ## delete operation
    else if @_stepData.operationCommand is 'DEL'

      # delete selected area
      @notifyEditMode 'onRemoveArea', @_stepData.inData.selectedAreas[0]



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
        @_newGeometryTool = new HG.NewGeometryTool @_hgInstance
        @_newGeometryTool.onSubmit @, (inGeometry) =>

          ## create new country operation
          if @_stepData.operationCommand is 'ADD'

            newGeometry = inGeometry

            # clip new geometry to existing geomtries
            # check for intersection with each country
            # TODO: make more efficient later
            for existingArea in @_areaController.getAreas()
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

            # insert new geometry into new area and add to HistoGlobe
            newId = 'NEW_AREA' # TODO: refine this id in next step
            @notifyEditMode 'onCreateArea', newId, newGeometry, null
            @notifyEditMode 'onSelectArea', newId
            @_stepData.outData.createdAreas.push newId


          ## separate geometries operation
          else if @_stepData.operationCommand is 'SEP'

            existingAreaId = @_stepData.inData.selectedAreas[0]

            # is there a remaining area left that can be used?
            # -> i.e. has the existing area ever been changed?
            # -> i.e. is there at least one created area based on this existing area?
            # if @_stepData.outData.createdAreas.length > 0

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


          # cleanup
          @_newGeometryTool.destroy()
          delete @_newGeometryTool  # TODO: necessary?

          # go to next area if limit not reached
          if @_stepData.outData.createdAreas.length < @_stepData.number.max
            @_makeNewGeometry()

          # required number of areas reached => loop complete => step complete
          else
            @finish()


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

