window.HG ?= {}

# ==============================================================================
# Step 1 in Edit Operation Workflow: Select areas on the map subject to change
# interaction with AreaController module
# ==============================================================================

class HG.EditOperationStep.SelectOldAreas extends HG.EditOperationStep

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, @_stepData, isForward) ->

    # inherit functionality from base class
    super @_hgInstance, @_stepData, isForward

    # skip steps without user input
    return @finish() if not @_stepData.userInput


    ### SETUP OPERATION ###

    ## for both forward and backward step
    # tell AreaController to start selecting maximal X number of areas
    @notifyEditMode 'onEnableMultiSelection', @_stepData.number.max


    # forward change: only currently selected area and add it to array
    if isForward
      @_initSelectedArea = @_hgInstance.areaController.getSelectedAreas()[0]
      @_select @_initSelectedArea if @_initSelectedArea

    # backward change: all areas selected
    else
      # put all previously selected areas back on the map
      for area in @_stepData.outData.selectedAreas
        @notifyEditMode 'onEndEditArea', area
        @notifyEditMode 'onSelectArea', area


    ### REACT ON USER INPUT ###
    # listen to area (de)selection from AreaController

    @_hgInstance.areaController.onSelect @, (area) =>    @_select area
    @_hgInstance.areaController.onDeselect @, (area) =>  @_deselect area


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _select: (area) ->
    # error handling
    idx = @_stepData.outData.selectedAreas.indexOf area.getId()
    return if idx isnt -1

    @_stepData.outData.selectedAreas.push area.getId()

    # is step complete?
    if @_stepData.outData.selectedAreas.length >= @_stepData.number.min
      @notifyOperation 'onStepComplete'

    # make action reversible
    @_undoManager.add {
      # TODO: why does that work ???
      undo: =>
        @notifyEditMode 'onDeselectArea', area.getId()
    }

  # ----------------------------------------------------------------------------
  _deselect: (area) ->
    # error handling
    idx = @_stepData.outData.selectedAreas.indexOf area.getId()
    return if idx is -1

    @_stepData.outData.selectedAreas.splice idx, 1

    # is step incomplete?
    if @_stepData.outData.selectedAreas.length < @_stepData.number.min
      @notifyOperation 'onStepIncomplete'

    # make action reversible
    @_undoManager.add {
      undo: =>
        @notifyEditMode 'onSelectArea', area.getId()
    }


  # ============================================================================
  _cleanup: () ->

    ### STOP LISTENING ###
    @_hgInstance.areaController.removeListener 'onSelect', @
    @_hgInstance.areaController.removeListener 'onDeselect', @

    ### CLEANUP OPERATION ###
    # TODO: is that a problem that it also happens if there was no user input?
    @notifyEditMode 'onDisableMultiSelection' # if @_stepData.userInput