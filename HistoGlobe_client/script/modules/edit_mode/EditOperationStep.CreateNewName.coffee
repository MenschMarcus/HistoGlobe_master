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
      @_areaIdx = @_numAreas
      @_makeNewName -1  # direction: negative



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _makeNewName: (direction) ->

    # error handling: last name -> forward    => finish
    #                 first name -> backward  => abort
    return @finish() if (@_areaIdx is @_numAreas-1) and (direction is 1)
    return @abort()  if (@_areaIdx is 0)            and (direction is -1)

    # go to next/previous area
    @_areaIdx += direction

    # get old and new step
    currentArea = @_areaController.getActiveArea @_stepData.inData.createdAreas[@_areaIdx]
    @_currentId = currentArea.getId()
    @_currentShortName = currentArea.getShortName()
    @_currentFormalName = currentArea.getFormalName()
    @_currentPoint = currentArea.getRepresentativePoint()
    @_currentNameRemoved = currentArea.hasName()

    # delete name, but put it into name tool
    @notifyEditMode 'onRemoveAreaName', @_currentId if @_currentNameRemoved

    # set up NewNameTool to set name and position of area interactively
    newNameTool = new HG.NewNameTool @_hgInstance, @_currentShortName, @_currentFormalName, @_currentPoint

    ### LISTEN TO USER INPUT ###
    newNameTool.onSubmit @, (newShortName, newFormalName, newPoint) =>

      # save the old name
      @_stepData.tempAreas[@_areaIdx] = {
        'id':         @_currentId
        'removed':    @_currentNameRemoved
        'shortName':  @_currentShortName
        'formalName': @_currentFormalName
        'reprPoint':  @_currentPoint
      }

      # save the named area
      @notifyEditMode 'onAddAreaName', @_currentId, newShortName, newFormalName
      @notifyEditMode 'onUpdateAreaRepresentativePoint', @_currentId, newPoint
      @_stepData.outData.namedAreas[@_areaIdx] = @_currentId

      # make action reversible
      @_undoManager.add {
        undo: =>
          # restore old name
          area = @_stepData.tempAreas[@_areaIdx]
          if @_currentNameRemoved
            @notifyEditMode 'onAddAreaName', area.id, area.shortName, area.formalName
          else
            @notifyEditMode 'onUpdateAreaName', area.id, area.shortName, area.formalName
          @notifyEditMode 'onUpdateAreaRepresentativePoint', area.id, area.reprPoint

          # go to previous area
          @_cleanup()
          @_makeNewName -1
      }

      # go to next name
      @_cleanup()
      @_makeNewName 1


  # ============================================================================
  _cleanup: () ->

    ### CLEANUP OPERATION ###
    @_hgInstance.newNameTool?.destroy()
    @_hgInstance.newNameTool = null