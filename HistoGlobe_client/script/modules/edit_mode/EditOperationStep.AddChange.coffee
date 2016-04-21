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

    # get the historical change data
    @_historicalChange = @_prepareChange()

    console.log @_historicalChange

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

    # get relevant data from operations object
    stepsData = @_hgInstance.editOperation.operation.steps
    oldAreas = stepsData[1].outData
    newAreas = stepsData[3].outData


    # => main HistoricalChange object that contains the AreaChanges
    # made in the workflow
    historicalChange = new HG.HistoricalChange @_getId()
    historicalChange.operation = @_getOperationId()

    areaChanges = []


    ### PREPARE AREA CHANGES ###

    switch @_getOperationId()

      # ------------------------------------------------------------------------
      when 'CRE'
        # TODO: what to do with the areas that got cut off?
        magic = 42


      # ------------------------------------------------------------------------
      when 'UNI'

        # create AreaChange to hide old Areas
        idx = 0
        while idx < oldAreas.areas.length
          oldChange = new HG.AreaChange @_getId()
          oldChange.operation =        'DEL'
          oldChange.historicalChange = historicalChange
          oldChange.area =             oldAreas.areas[idx]
          oldChange.oldAreaName =      oldAreas.areaNames[idx]
          oldChange.oldAreaTerritory = oldAreas.areaTerritories[idx]
          historicalChange.areaChanges.push oldChange

          idx++

        # create AreaChange to show new Area
        newChange = new HG.AreaChange @_getId()
        newChange.operation =        'ADD'
        newChange.historicalChange = historicalChange
        newChange.area =             newAreas.areas[0]
        newChange.newAreaName =      newAreas.areaNames[0]
        newChange.newAreaTerritory = newAreas.areaTerritories[0]
        historicalChange.areaChanges.push newChange


      # ------------------------------------------------------------------------
      when 'INC'

        # Area that the others are incorporated in
        incArea = newAreas.areas[0]
        incOldAreaIdx = null  # at which index in the oldAreas array is the Area?

        # create AreaChange to hide old Areas
        idx = 0
        while idx < oldAreas.areas.length

          # except for the incorporation area which will be handled afterwards
          if oldAreas.areas[idx] is incArea
            incOldAreaIdx = idx
            idx++
            continue

          oldChange = new HG.AreaChange @_getId()
          oldChange.operation =        'DEL'
          oldChange.historicalChange = historicalChange
          oldChange.area =             oldAreas.areas[idx]
          oldChange.oldAreaName =      oldAreas.areaNames[idx]
          oldChange.oldAreaTerritory = oldAreas.areaTerritories[idx]
          historicalChange.areaChanges.push oldChange

          idx++

        # create AreaChange to change the territory of the incorporation Area
        updateChange = new HG.AreaChange @_getId()
        updateChange.operation =        'TCH'
        updateChange.historicalChange = historicalChange
        updateChange.area =             newAreas.areas[0]
        updateChange.oldAreaTerritory = oldAreas.areaTerritories[incOldAreaIdx]
        updateChange.newAreaTerritory = newAreas.areaTerritories[0]
        historicalChange.areaChanges.push updateChange

        # if formal name has changed, add this areaChange as well
        if oldAreas.areaNames[incOldAreaIdx] isnt newAreas.areaNames[0]
          updateChange = new HG.AreaChange @_getId()
          updateChange.operation =        'NCH'
          updateChange.historicalChange = historicalChange
          updateChange.area =             newAreas.areas[0]
          updateChange.oldAreaName =      oldAreas.areaNames[incOldAreaIdx]
          updateChange.newAreaName =      newAreas.areaNames[0]
          historicalChange.areaChanges.push updateChange


      # ------------------------------------------------------------------------
      when 'SEP'

        # create AreaChange to hide old Area
        oldChange = new HG.AreaChange @_getId()
        oldChange.operation =        'DEL'
        oldChange.historicalChange = historicalChange
        oldChange.area =             oldAreas.areas[0]
        oldChange.oldAreaName =      oldAreas.areaNames[0]
        oldChange.oldAreaTerritory = oldAreas.areaTerritories[0]
        historicalChange.areaChanges.push oldChange

        # create AreaChanges to show new Areas
        idx = 0
        while idx < newAreas.areas.length
          newChange = new HG.AreaChange @_getId()
          newChange.operation =        'ADD'
          newChange.historicalChange = historicalChange
          newChange.area =             newAreas.areas[idx]
          newChange.newAreaName =      newAreas.areaNames[idx]
          newChange.newAreaTerritory = newAreas.areaTerritories[idx]
          historicalChange.areaChanges.push newChange

          idx++

      # ------------------------------------------------------------------------
      when 'SEC'

        # Area that the others are seceded from
        secArea = oldAreas.areas[0]
        secNewAreaIdx = null  # at which index in the oldAreas array is the Area?

        # create AreaChange to show new Areas
        idx = 0
        while idx < newAreas.areas.length

          # except for the secession area which will be handled afterwards
          if newAreas.areas[idx] is secArea
            secNewAreaIdx = idx
            idx++
            continue

          newChange = new HG.AreaChange @_getId()
          newChange.operation =        'ADD'
          newChange.historicalChange = historicalChange
          newChange.area =             newAreas.areas[idx]
          newChange.newAreaName =      newAreas.areaNames[idx]
          newChange.newAreaTerritory = newAreas.areaTerritories[idx]
          historicalChange.areaChanges.push newChange

          idx++

        # create AreaChange to change the territory of the secession Area
        updateChange = new HG.AreaChange @_getId()
        updateChange.operation =        'TCH'
        updateChange.historicalChange = historicalChange
        updateChange.area =             oldAreas.areas[0]
        updateChange.oldAreaTerritory = oldAreas.areaTerritories[0]
        updateChange.newAreaTerritory = newAreas.areaTerritories[secNewAreaIdx]
        historicalChange.areaChanges.push updateChange

        # if formal name has changed, add this areaChange as well
        if oldAreas.areaNames[0] isnt newAreas.areaNames[secNewAreaIdx]
          updateChange = new HG.AreaChange @_getId()
          updateChange.operation =        'NCH'
          updateChange.historicalChange = historicalChange
          updateChange.area =             oldAreas.areas[0]
          updateChange.oldAreaName =      oldAreas.areaNames[0]
          updateChange.newAreaName =      newAreas.areaNames[secNewAreaIdx]
          historicalChange.areaChanges.push updateChange


      # ------------------------------------------------------------------------
      when 'TCH', 'BCH'

        # create AreaChange to change the territory
        idx = 0
        while idx < newAreas.areas.length
          updateChange = new HG.AreaChange @_getId()
          updateChange.operation =        'TCH'
          updateChange.historicalChange = historicalChange
          updateChange.area =             oldAreas.areas[idx]
          updateChange.oldAreaTerritory = oldAreas.areaTerritories[idx]
          updateChange.newAreaTerritory = newAreas.areaTerritories[idx]
          historicalChange.areaChanges.push updateChange

          idx++

      # ------------------------------------------------------------------------
      when 'NCH'

        # create AreaChange to change the name
        updateChange = new HG.AreaChange @_getId()
        updateChange.operation =        'NCH'
        updateChange.historicalChange = historicalChange
        updateChange.area =             oldAreas.areas[0]
        updateChange.oldAreaName =      oldAreas.areaNames[0]
        updateChange.newAreaName =      newAreas.areaNames[0]
        historicalChange.areaChanges.push updateChange

      # ------------------------------------------------------------------------
      when 'ICH'

        # create AreaChange to hide old Area (with old AreaName)
        oldChange = new HG.AreaChange @_getId()
        oldChange.operation =        'DEL'
        oldChange.historicalChange = historicalChange
        oldChange.area =             oldAreas.areas[0]
        oldChange.oldAreaName =      oldAreas.areaNames[0]
        oldChange.oldAreaTerritory = oldAreas.areaTerritories[0]
        historicalChange.areaChanges.push oldChange

        # create AreaChanges to show new Areas (with new AreaName)
        newChange = new HG.AreaChange @_getId()
        newChange.operation =        'ADD'
        newChange.historicalChange = historicalChange
        newChange.area =             newAreas.areas[0]
        newChange.newAreaName =      newAreas.areaNames[0]
        newChange.newAreaTerritory = newAreas.areaTerritories[0]
        historicalChange.areaChanges.push newChange

      # ------------------------------------------------------------------------
      when 'DES'

        # create AreaChange to hide old Area
        oldChange = new HG.AreaChange @_getId()
        oldChange.operation =        'DEL'
        oldChange.historicalChange = historicalChange
        oldChange.area =             oldAreas.areas[0]
        oldChange.oldAreaName =      oldAreas.areaNames[0]
        oldChange.oldAreaTerritory = oldAreas.areaTerritories[0]
        historicalChange.areaChanges.push oldChange

    return historicalChange
