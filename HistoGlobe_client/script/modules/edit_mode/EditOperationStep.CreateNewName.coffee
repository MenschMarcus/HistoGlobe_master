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
    super @_hgInstance, @_stepData, isForward

    # skip operations without user input
    return @finish() if not @_stepData.userInput

    # get external modules
    @_areaController = @_hgInstance.areaController


    ### SETUP OPERATION ###
    @_numAreas = @_stepData.inData.createdAreas.length


    ### REACT ON USER INPUT ###
    if isForward
      @_areaIdx = -1
      @_makeNewName 1   # direction: positive

    else # backward
      @_areaIdx = @_numAreas
      @_makeNewName -1  # direction: negative


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _makeNewName: (direction) =>

    # error handling: last name -> forward    => finish
    #                 first name -> backward  => abort
    return @_finish() if (@_areaIdx is @_numAreas) and (direction is 1)
    return @_abort()  if (@_areaIdx is 0)          and (direction is -1)

    # go to next / previous area
    @_areaIdx += direction

    # get old and new step
    currentArea = @_areaController.getArea @_stepData.inData.createdAreas[@_areaIdx]
    id = currentArea.getId()
    name = currentArea.getName()
    position = currentArea.getRepresentativePoint()

    # forward: delete name and start from zero
    if direction is 1
      @notifyEditMode 'onUpdateAreaName', id, null if name

    # else backward: restore old name => nothing to do


    # set up NewNameTool to set name and position of area interactively
    @_newNameTool = new HG.NewNameTool @_hgInstance, name, position

    # collect data if step is complete
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

      # go to next name
      @_makeNewName 1


  # ============================================================================
  _cleanup: () ->

    ### CLEANUP OPERATION ###
    if @_newNameTool?
      @_newNameTool.destroy()
      delete @_newNameTool

    # if @_stepData.userInput