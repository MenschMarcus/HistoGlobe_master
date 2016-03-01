window.HG ?= {}

# ==============================================================================
# Step 2 in Edit Operation Workflow: Newly create geometry(ies)
# ==============================================================================

class HG.CreateNewGeometryStep extends HG.EditOperationStep

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

    @_areaController.startAreaEdit()

    ## unification operation
    if @_stepData.operationCommand is 'UNI'

      # delete all selected areas
      oldGeometries = []
      oldIds = []
      for area in @_stepData.inData.selectedAreas
        oldIds.push area.getId()
        oldGeometries.push area.getGeometry()
        @_areaController.removeArea area

      # unify old areas to new area
      uniArea = @_geometryOperator.union oldGeometries
      # TODO: give reasonable Area id!
      newId = "UNION"
      newId += ('_'+areaId) for areaId in oldIds
      newArea = new HG.Area newId, uniArea
      newArea.select()
      newArea.treat()   # TODO: correct?
      @_stepData.outData.createdAreas.push newArea
      @_areaController.addArea newArea

    ## change name operation
    else if @_stepData.operationCommand is 'CHN'

      # remove the name from the area, but leave its geometry untouched
      renameArea = @_stepData.inData.selectedAreas[0]
      renameArea.setNames {} # TODO: make name handling nicer...
      renameArea.select()
      renameArea.treat()
      @_areaController.updateArea renameArea
      @_stepData.outData.createdAreas.push renameArea


    ## delete operation
    else if @_stepData.operationCommand is 'DEL'

      # delete selected area
      @_areaController.removeArea @_stepData.inData.selectedAreas[0]



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
              existingGeometry = existingArea.getGeometry()
              intersectionGeometry = @_geometryOperator.intersection newGeometry, existingGeometry

              # if new geometry intersects with an existing geometry
              # clip the existing geometry to the new geometry and update its area
              if intersectionGeometry.isValid()
                clipGeometry = @_geometryOperator.difference existingGeometry, newGeometry
                # if something is still left, update it
                if updatedGeometry.isValid()
                  existingArea.setGeometry clipGeometry
                  @_areaController.updateArea existingArea
                # if nothing is left, delete it
                else
                  @_areaController.removeArea existingArea

            # insert new geometry into new area and add to HistoGlobe
            newId = 'NEW_AREA' # TODO: refine this id in next step
            newArea = new HG.Area newId, newGeometry
            newArea.select()
            newArea.treat()
            @_areaController.addArea newArea
            @_stepData.outData.createdAreas.push newArea


          ## separate geometries operation
          else if @_stepData.operationCommand is 'SEP'

            existingArea = @_stepData.inData.selectedAreas[0]

            # is there a remaining area left that can be used?
            # -> i.e. has the existing area ever been changed?
            # -> i.e. is there at least one created area based on this existing area?
            # if @_stepData.outData.createdAreas.length > 0

            existingGeometry = existingArea.getGeometry()
            clipGeometry = inGeometry

            # clip incoming geometry (= clipGeometry) to selected geometry
            # -> create new area
            newGeometry = @_geometryOperator.intersection existingGeometry, clipGeometry
            newId = 'SEP_AREA_' + @_stepData.outData.createdAreas.length
            newArea = new HG.Area newId, newGeometry
            newArea.select()
            newArea.treat()
            @_areaController.addArea newArea
            @_stepData.outData.createdAreas.push newArea

            # update existing geometry
            updatedGeometry = @_geometryOperator.difference existingGeometry, clipGeometry
            # if something is still left, update it
            if updatedGeometry.isValid()
              existingArea.setGeometry updatedGeometry
              existingArea.untreat()
              @_areaController.updateArea existingArea
            # if nothing is left, delete it
            else
              @_areaController.removeArea existingArea


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

