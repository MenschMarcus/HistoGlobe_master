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
  constructor: (@_hgInstance, direction) ->

    # inherit functionality from base class
    super @_hgInstance, direction

    @_numSelections = 0

    # tell AreaController to start selecting maximal X number of areas
    @_hgInstance.areaController.enableMultiSelection @_stepData.number.max

    # forward change
    if direction is 1
      # select currently selected area (if there is one)
      @_select (@_hgInstance.areaController.getSelectedAreaHandles())[0]

    # backward change
    else
      # get current number of selections
      for areaChange in @_historicalChange.areaChanges
        @_numSelections++ if areaChange.area.areaHandle.isSelected()
      # restore areas on the map
      # for area in @_stepData.outData.selectedAreas
      #   @notifyEditMode 'onEndEditArea', area
      #   @notifyEditMode 'onSelectArea', area



    ### REACT ON USER INPUT ###

    # listen to area (de)selection from AreaController
    for areaHandle in @_hgInstance.areaController.getAreaHandles()
      areaHandle.onSelect @,    @_select
      areaHandle.onDeselect @,  @_deselect


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # select an area = make him part of the HistoricalChange
  # -> create an 'DEL' AreaChange for it
  # ============================================================================

  _select: (areaHandle) ->

    # error handling
    return if not areaHandle

    # create AreaChange for the area
    switch @_historicalChange.operation
      when 'NCH' then operation = 'NCH'
      when 'TCH' then operation = 'TCH'
      else            operation = 'DEL'

    areaChange = new HG.AreaChange {
        historicalChange:   @_historicalChange
        operation:          operation
        area:               areaHandle.getArea()
        oldAreaName:        areaHandle.getArea().name
        oldAreaTerritory:   areaHandle.getArea().territory
      }

    # add to HistoricalChange
    @_historicalChange.areaChanges.push areaChange

    @_numSelections++

    # is step complete?
    if @_numSelections >= @_stepData.number.min
      @_hgInstance.editOperation.notifyAll 'onStepComplete'

    # make action reversible
    @_undoManager.add {
      undo: =>
        areaHandle.deselect()
    }

  # ----------------------------------------------------------------------------
  _deselect: (areaHandle) ->

    # error handling
    return if not areaHandle

    # remove from HistoricalChange
    for areaChange, idx in @_historicalChange.areaChanges
      if areaChange.area is areaHandle.getArea()
        @_historicalChange.areaChanges.splice idx, 1
        break

    @_numSelections--

    # is step incomplete?
    if @_numSelections < @_stepData.number.min
      @_hgInstance.editOperation.notifyAll 'onStepIncomplete'

    # make action reversible
    @_undoManager.add {
      undo: =>
        areaHandle.select()
    }


  # ============================================================================
  _cleanup: () ->

    ### STOP LISTENING ###
    for areaHandle in @_hgInstance.areaController.getAreaHandles()
      areaHandle.removeListener 'onSelect', @
      areaHandle.removeListener 'onDeselect', @

    # tell AreaController to stop selecting multiple areas
    @_hgInstance.areaController.disableMultiSelection()