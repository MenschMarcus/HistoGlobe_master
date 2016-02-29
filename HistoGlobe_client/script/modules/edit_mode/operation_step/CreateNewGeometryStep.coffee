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
    @_areasOnMap = @_hgInstance.areasOnMap
    @_geometryOperator = new HG.GeometryOperator


    ### SETUP OPERATION ###

    # set AreasOnMap in area edit mode (for all operations)
    @_areasOnMap.startAreaEdit()

    ## unification operation
    if @_stepData.operationCommand is 'UNI'

      # delete all selected areas
      oldGeometries = []
      oldIds = []
      for area in @_stepData.inData.selectedAreas
        oldIds.push area.geomLayer.hgArea.getId()
        oldGeometries.push area.geomLayer.hgArea.getGeometry()
        @_areasOnMap.removeArea area

      # unify old areas to new area
      uniArea = @_geometryOperator.union oldGeometries
      # TODO: give reasonable Area id!
      newId = "UNION"
      newId += ('_'+areaId) for areaId in oldIds
      newArea = new HG.Area newId, uniArea
      newArea.select()
      newArea.treat()   # TODO: correct?
      @_stepData.outData.createdAreas.push newArea
      @_areasOnMap.addArea newArea

    ## change name operation
    else if @_stepData.operationCommand is 'CHN'

      # remove the name from the area, but leave its geometry untouched
      renameArea = @_stepData.inData.selectedAreas[0]
      renameArea.setNames {} # TODO: make name handling nicer...
      renameArea.select()
      renameArea.treat()
      @_areasOnMap.updateArea renameArea
      @_stepData.outData.createdAreas.push renameArea


    ## delete operation
    else if @_stepData.operationCommand is 'DEL'

      # delete selected area
      @_areasOnMap.removeArea @_stepData.inData.selectedAreas[0]



    ## for backward step
    # else

    #   ## unification operation
    #   if @_stepData.operationCommand is 'UNI'

    #     # restore unified area
    #     @_areasOnMap.removeArea @_stepData.outData.createdAreas[0]
    #     @_stepData.outData.createdAreas = []
    #     # TODO: delete the area? will it stay in the memory?
    #     # re-add all previously selected areas
    #     for area in @_stepData.inData.selectedAreas
    #       @_areasOnMap.addArea area

    #   ## delete operation
    #   else if @_stepData.operationCommand is 'DEL'

    #     # restore selected area
    #     @_areasOnMap.addArea @_stepData.inData.selectedAreas[0]



    ### REACT ON USER INPUT ###
    if @_stepData.userInput

      # for each required area
      @_makeNewGeometry = () =>

        # set up NewGeometryTool to define geometry of an area interactively
        @_newGeometryTool = new HG.NewGeometryTool @_hgInstance
        @_newGeometryTool.onSubmit @, (newGeometry) =>

          ## create new country operation
          if @_stepData.operationCommand is 'ADD'

            # clip new geometry to existing geomtries
            existingAreas = @_areasOnMap.getAreas()
            # check for intersection with each country
            # TODO: make more efficient later
            for existingArea in existingAreas
              existingGeometry = existingArea.hgArea.getGeometry()
              intersectionGeometry = @_geometryOperator.intersection newGeometry, existingGeometry
              if intersectionGeometry.isValid()
                clippedGeometry = @_geometryOperator.difference existingGeometry, intersectionGeometry
                # console.log "draw area 1:      ", newGeometry
                # console.log "original area 2:  ", existingGeometry
                # console.log "intersection:     ", intersectionGeometry
                # console.log "difference 2-int: ", clippedGeometry
                # only change, if area actually changed
                existingArea.hgArea.setGeometry clippedGeometry
                @_areasOnMap.updateArea existingArea.hgArea

          # cleanup
          @_newGeometryTool.destroy()
          delete @_newGeometryTool  # TODO: necessary?

          # save new area data
          id = 'NEW_AREA' # TODO: refine this id in next step
          newArea = new HG.Area id, newGeometry
          newArea.select()
          newArea.treat()
          @_stepData.outData.createdAreas.push newArea
          @_areasOnMap.addArea newArea

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

    # TODO: only do on backwards change!
    # @_areasOnMap.finishAreaEdit()

    # if @_stepData.userInput