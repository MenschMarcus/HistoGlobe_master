window.HG ?= {}

# ==============================================================================
# Step 4 in Edit Operation Workflow: Add change to a Hivent
# ==============================================================================

class HG.EditOperationStep.AddChange extends HG.EditOperationStep

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, direction) ->

    # inherit functionality from base class
    super @_hgInstance, direction

    console.log @_getOperationId()

    ### SETUP OPERATION ###

    if direction is -1
      @_hgInstance.areaController.enableMultiSelection HGConfig.max_area_selection.val
      @_hgInstance.editMode.enterAreaEditMode()

    # hivent box: select existing or create new hivent
    @_hiventBox = new HG.NewHiventBox @_hgInstance, @_stepData, "HORST"

    ### INTERACTION ###
    # tell workflow window to change to the finish button
    @_hiventBox.onReady @, () ->
      @notifyOperation 'onOperationComplete'

    @_hiventBox.onUnready @, () ->
      @notifyOperation 'onOperationIncomplete'


    ## that would be the nice way to do it, directly in HistoGlobe
    ## but I am going to go the easy way :-)
    # builder = new HG.HiventBuilder
    # hivent = builder._createHivent hiventData
    # hiventHandle = new HG.HiventHandle @_hgInstance, hivent

    # @_popover = new HG.HiventInfoPopover(
    #     hiventHandle,
    #     @_hgInstance.getTopArea(),
    #     @_hgInstance,
    #     1,
    #     yes
    #   )

    # $('.guiPopoverTitle')[0].contentEditable = true
    # $('.hivent-content')[0].contentEditable = true

    # @_popover.show new HG.Vector $('body').width()-237, 380


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _cleanup: () ->

    @_hiventBox.destroy()

    # TODO: decide which area to have seleted after everything is over
    @_hgInstance.editMode.leaveAreaEditMode()
    @_hgInstance.areaController.disableMultiSelection()


  # ============================================================================
  _prepareChange: () ->

    # => main object that will be populated throughout the workflow
    historicalChange = new HG.HistoricalChange @getRandomId()
    historicalChange.operation = @operation.id


    ### SEL_OLD_AREA ###

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

    ### SET_NEW_TERR ###

    # create AreaChange
    newChange = new HG.AreaChange @_hgInstance.editOperation.getRandomId()
    newChange.operation = 'ADD'

    # link AreaChange <-> HistoricalChange
    newChange.historicalChange = @_historicalChange
    @_historicalChange.areaChanges.push newChange

    # link AreaChange <-> Area
    newChange.area = newArea
    newArea.startChange = newChange

    # link AreaChange <-> AreaTerritory
    newChange.newAreaTerritory = newTerritory
    newTerritory.startChange = newChange