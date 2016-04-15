window.HG ?= {}

# ==============================================================================
# Step 3 in Edit Operation Workflow: define name of newly created area
# TODO: set id of area!
# TODO: set names in all languages
# ==============================================================================

class HG.EditOperationStep.CreateNewNames extends HG.EditOperationStep

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

    # get area to work with
    # actually, this distinction is not necessary, since the created area from
    # the step before will be used and changed (passing by reference!)
    if direction is 1 # forward => take area from previous step
      currentArea = @_areaController.getActiveArea @_stepData.inData.createdAreas[@_areaIdx]
    else              # backward => take area from next step
      currentArea = @_areaController.getActiveArea @_stepData.outData.namedAreas[@_areaIdx]

    @_currentArea = {
      id:           currentArea.getId()
      shortName:    currentArea.getShortName()
      formalName:   currentArea.getFormalName()
      reprPoint:    currentArea.getRepresentativePoint()
      hasName:      currentArea.hasName()
    }

    # temporarily save the old name
    # -> only in forward direction to avoid overriding temp area on backward operation
    @_stepData.tempAreas[@_areaIdx] = @_currentArea if direction is 1

    if @_currentArea.hasName
      @notifyEditMode 'onRemoveAreaName', @_currentArea.id

    # set up NewNameTool to set name and position of area interactively
    newNameTool = new HG.NewNameTool @_hgInstance,
      @_currentArea.shortName,
      @_currentArea.formalName,
      @_currentArea.reprPoint


    ### LISTEN TO USER INPUT ###
    newNameTool.onSubmit @, (newShortName, newFormalName, newPoint) =>

      # save the named area
      @notifyEditMode 'onAddAreaName', @_currentArea.id, newShortName, newFormalName
      @notifyEditMode 'onUpdateAreaRepresentativePoint', @_currentArea.id, newPoint
      @_stepData.tempAreas[@_areaIdx].nameUpdated = yes
      @_stepData.outData.namedAreas[@_areaIdx] = @_currentArea.id

      # make action reversible
      @_undoManager.add {
        undo: =>
          # restore old name
          area = @_stepData.tempAreas[@_areaIdx]
          if area.nameRemoved
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

    ### RESTORE NAME OF FIRST AREA ###
    # if it has not been updated yet
    # this is not covered by any undo action, because before the new name was
    # not submitted from newNameTool, there is no undo event in the undoManager
    area = @_stepData.tempAreas[@_areaIdx]
    if area.nameRemoved and not area.nameUpdated
      @notifyEditMode 'onAddAreaName', area.id, area.shortName, area.formalName