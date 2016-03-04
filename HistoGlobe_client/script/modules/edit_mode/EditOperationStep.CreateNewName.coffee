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
  constructor: (@_hgInstance, @_stepData) ->

    # inherit functionality from base class
    super @_hgInstance, @_stepData

    # skip steps without user input
    return @finish() if not @_stepData.userInput

    # get external modules
    @_areaController = @_hgInstance.areaController

    ### SETUP OPERATION ###
    # nothing to do here ?!?

    ### REACT ON USER INPUT ###
    if @_stepData.userInput

      # for each new area
      @_makeNewName = () =>

        currentArea = @_areaController.getArea @_stepData.inData.createdAreas[@_areaIdx]

        # if name is already given, save it, hand it over to name tool, but delete it from the area
        id = currentArea.getId()
        name = currentArea.getName()
        position = currentArea.getRepresentativePoint()
        @notifyEditMode 'onUpdateAreaName', id, null if name

        # set up NewNameTool to set name and position of area interactively
        @_newNameTool = new HG.NewNameTool @_hgInstance, name, position
        @_newNameTool.onSubmit @, (name, position) =>

          # save the named area
          currentAreaId = @_stepData.inData.createdAreas[@_areaIdx]
          @_stepData.outData.namedAreas[@_areaIdx] = currentAreaId
          # TODO: better name handling
          @notifyEditMode 'onUpdateAreaName', currentAreaId, name, position
          @notifyEditMode 'onSelectArea', currentAreaId

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