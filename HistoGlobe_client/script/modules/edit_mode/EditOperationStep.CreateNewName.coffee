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

    if isForward
      @_areaIdx = -1
      @_makeNewName 1   # direction: positive

    else # backward
      # reselect all areas
      # for area in @_stepData.outData.namedAreas

      @_areaIdx = @_numAreas
      @_makeNewName -1  # direction: negative



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _makeNewName: (direction) =>

    # error handling: last name -> forward    => finish
    #                 first name -> backward  => abort
    return @finish() if (@_areaIdx is @_numAreas-1) and (direction is 1)
    return @abort()  if (@_areaIdx is 0)            and (direction is -1)

    # go to next/previous area
    @_areaIdx += direction

    # get old and new step
    currentArea = @_areaController.getArea @_stepData.inData.createdAreas[@_areaIdx]
    id = currentArea.getId()
    name = currentArea.getName()
    position = currentArea.getRepresentativePoint()

    # delete name, but put it into name tool
    @notifyEditMode 'onUpdateAreaName', id, null if name

    # set up NewNameTool to set name and position of area interactively
    newNameTool = new HG.NewNameTool @_hgInstance, name, position

    ### REACT ON USER INPUT ###
    newNameTool.onSubmit @, (name, position) =>

      # save the named area
      currentAreaId = @_stepData.inData.createdAreas[@_areaIdx]
      @_stepData.outData.namedAreas[@_areaIdx] = currentAreaId

      # make action reversible
      @_undoManager.add {
        undo: =>
          # remove name
          # @notifyEditMode 'onDeselectArea', currentAreaId
          @notifyEditMode 'onUpdateAreaName', currentAreaId, null

          # go to previous area
          @_cleanup()
          @_makeNewName -1
      }

      # update name
      @notifyEditMode 'onUpdateAreaName', currentAreaId, name, position
      # @notifyEditMode 'onSelectArea', currentAreaId

      # go to next area
      @_cleanup()
      @_makeNewName 1


  # ============================================================================
  _cleanup: () ->

    ### CLEANUP OPERATION ###
    newNameTool = @_hgInstance.newNameTool
    newNameTool?.destroy()