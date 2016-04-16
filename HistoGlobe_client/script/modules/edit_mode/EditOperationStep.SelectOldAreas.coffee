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


    ### SETUP OPERATION ###

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



    ### SETUP USER INPUT ###

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

    # create AreaChange
    areaChange = new HG.AreaChange @_hgInstance.editOperation.getRandomId()

    # link AreaChange <-> HistoricalChange
    areaChange.historicalChange = @_historicalChange
    @_historicalChange.areaChanges.push areaChange

    # spefify operation for AreaChange and relation to area
    switch @_historicalChange.operation
      # ------------------------------------------------------------------------
      when 'NCH', 'TCH'                     # name change or territorial change

        areaChange.operation = @_historicalChange.operation  # 'NCH' or 'TCH'

        # link AreaChange <-> Area
        areaChange.area = areaHandle.getArea()
        areaHandle.getArea().updateChanges.push areaChange

      # ------------------------------------------------------------------------
      else  # 'UNI','INC','SEP','SEC','DES' => all operations delete the area

        areaChange.operation = 'DEL'
        # for 'INC' and 'SEC' this may later be changed to 'TCH'

        # link AreaChange <-> Area
        areaChange.area = areaHandle.getArea()
        areaHandle.getArea().endChange = areaChange

      # ------------------------------------------------------------------------

    # is step complete?
    @_numSelections++
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

    # is step incomplete?
    @_numSelections--
    if @_numSelections < @_stepData.number.min
      @_hgInstance.editOperation.notifyAll 'onStepIncomplete'

    # remove from HistoricalChange
    for areaChange, idx in @_historicalChange.areaChanges
      if areaChange.area is areaHandle.getArea()

        # unlink AreaChange from HistoricalChange
        areaChange.historicalChange = null
        @_historicalChange.areaChanges.splice idx, 1

        switch @_historicalChange.operation
          # --------------------------------------------------------------------
          when 'NCH', 'TCH'                  # name change or territorial change

            # unlink AreaChange from Area
            chIdx = areaHandle.getArea().updateChanges.indexOf areaChange
            areaHandle.getArea().updateChanges.splice chIdx, 1

          # --------------------------------------------------------------------
          else  # 'UNI','INC','SEP','SEC','DES' => all operations delete the area

            # unlink AreaChange from Area
            areaHandle.getArea().endChange = null

          # --------------------------------------------------------------------

        areaChange = null
        # no reference to AreaChange anymore => deleted

    # make action reversible
    @_undoManager.add {
      undo: =>
        areaHandle.select()
    }


  # ============================================================================
  _cleanup: () ->

    ### CLEANUP USER INPUT LISTENING ###

    for areaHandle in @_hgInstance.areaController.getAreaHandles()
      areaHandle.removeListener 'onSelect', @
      areaHandle.removeListener 'onDeselect', @


    ### CLEANUP OPERATION ###

    # tell AreaController to stop selecting multiple areas
    @_hgInstance.areaController.disableMultiSelection()