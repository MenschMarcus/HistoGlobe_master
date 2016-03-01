window.HG ?= {}

# ==============================================================================
# Step 3 in Edit Operation Workflow: define name of newly created area
# TODO: set id of area!
# TODO: set names in all languages
# ==============================================================================

class HG.EditOperationStep.CreateNewName extends HG.EditOperationStep

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, @_stepData, isForward) ->

    # inherit functionality from base class
    super @_hgInstance, @_stepData

    # skip steps without user input
    return @finish() if not @_stepData.userInput

    # get external modules
    @_workflowWindow = @_hgInstance.workflowWindow
    @_areaController = @_hgInstance.areaController

    ### SETUP OPERATION ###
    # nothing to do here ?!?

    ### REACT ON USER INPUT ###
    if @_stepData.userInput

      # for each new area
      @_makeNewName = () =>

        # get current area
        currAreaId = @_stepData.inData.createdAreas[@_areaIdx]
        currArea = @_areaController.getArea currAreaId

        # set up NewNameTool to set name and position of area interactively
        @_newNameTool = new HG.NewNameTool @_hgInstance, currArea.getLabelPosition(yes)
        @_newNameTool.onSubmit @, (name, position) =>

          # save the named area
          currAreaId = @_stepData.inData.createdAreas[@_areaIdx]
          # TODO: better name handling
          @notifyEditMode 'onUpdateAreaName', currAreaId, {'commonName': name}, position
          @notifyEditMode 'onUpdateAreaStatus', currAreaId, yes # treated
          @_stepData.outData.namedAreas[@_areaIdx] = currAreaId

          # cleanup
          @_newNameTool.destroy()
          delete @_newNameTool

          @_areaIdx++

          # go to next area if not all of the new areas were successfully named
          if @_areaIdx < @_stepData.inData.createdAreas.length
            @_makeNewName()

          # required number of areas reached => loop complete => step complete
          else
            @finish()


      # start new name loop here
      @_areaIdx = 0
      @_makeNewName()


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  _cleanup: () ->

    ### CLEANUP OPERATION ###
    if @_newNameTool?
      @_newNameTool.destroy()
      delete @_newNameTool

    # if @_stepData.userInput