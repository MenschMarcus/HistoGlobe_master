window.HG ?= {}

class HG.EditMode

  # ==============================================================================
  # EditMode acts as an edit CONTROLLER has several controlling tasks:
  #   register clicks on edit operation buttons -> init operation
  #   manage operation window (init, send data, get data)
  #   handle communication with backend (get data, send data)
  # ==============================================================================


  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # init config
    defaultConfig =
      changeOperationsPath:     'HistoGlobe_client/config/common/hgChangeOperations.json'

    @_config = $.extend {}, defaultConfig, config

    # init variables
    @_hgChangeOperations = null
    @_currCO = {}                   # object of current change operation
    @_currStep = {}                 # object of current step in workflow


  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add to HG instance
    @_hgInstance.editController = @   # N.B. edit mode = edit controller :)

    $.getJSON(@_config.changeOperationsPath, (ops) =>

      @_hgChangeOperations = new HG.ObjectArray ops # all possible operations

      @_editButtons = new HG.EditButtons @_hgInstance, @_hgChangeOperations
      @_editModeButton = @_editButtons.getEditButton()  # todo: get rid of that :/
      @_title = new HG.Title @_hgInstance
      @_histoGraph = @_hgInstance.histoGraph
      @_areasOnMap = @_hgInstance.areasOnMap

      # listen to click on edit button => start edit mode
      @_editModeButton.onEnter @, () ->

        @_editButtons.activateEditButton()
        @_editButtons.show()
        @_title.resize()
        @_title.set 'EDIT MODE'   # TODO internationalization


        # workflow hierachy: operation -> step -> action

        ### OPERATION ###
        # listen to click on edit operation buttons => start operation
        @_hgChangeOperations.foreach (operation) =>
          @_hgInstance.buttons[operation.id].onStart @, (btn) =>

            # update current operation in workflow
            opId = btn._config.id # to do: more elegant way to get id?
            @_currCO = @_hgChangeOperations.getByPropVal 'id', opId
            @_currCO.totalSteps = @_currCO.steps.length
            @_currCO.stepIdx = 0
            @_currCO.finished = no

            # setup UI
            @_editButtons.disable()
            @_editButtons.activate @_currCO.id
            @_title.clear()
            @_coWindow?.destroy()
            @_coWindow = new HG.ChangeOperationWindow @_hgInstance, @_currCO
            @_coWindow.disableNext()
            @_histoGraph.show()

            # listen to click on next button
            @_hgInstance.buttons.coNext.onNext @, () =>
              # send info to server
              # receive new info from server

              # go to next step
              @_currCO.stepIdx++
              @_currStep = null
              @_makeStep()

            @_hgInstance.buttons.coNext.onFinish @, () =>
              console.log "Heureka!"

            # listen to click on back button
            @_hgInstance.buttons.coBack.onBack @, () =>
              console.log "I do not work yet"

            # listen to click on abort button
            @_hgInstance.buttons.coAbort.onClick @, () =>
                # reset UI
                @_coWindow.destroy()
                @_editButtons.deactivate @_currCO.id
                @_editButtons.enable @_currCO.id
                # reset current operation
                @_currCO    = null
                @_currStep  = null

            # start actual operation
            @_makeStep()


      # listen to next click on edit button => leave edit mode and cleanup
      @_editModeButton.onLeave @, () ->
        @_coWindow?.destroy()
        @_editButtons.deactivate @_currCO.id
        @_editButtons.enable @_currCO.id
        @_editButtons.deactivateEditButton()
        @_editButtons.hide()
        @_title.clear()

    )

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  ### STEP ###
  _makeStep: () ->

    # update step information
    @_currStep = @_currCO.steps[@_currCO.stepIdx]

    # setup UI
    console.log "make hivent in HistoGraph" if @_currStep.startNew
    @_coWindow.disableNext()
    @_areasOnMap.disableMultipleSelection()

    # step requirement
    switch @_currStep.id
      when 'SEL_OLD' then (

        # update step information
        @_currStep.reqNum = @_getRequiredNum @_currStep.reqNum
        selectedAreas = new HG.ObjectArray
        selectedAreas.push @_areasOnMap.getActiveArea() if @_areasOnMap.getActiveArea()?

        # setup UI
        @_areasOnMap.enableMultipleSelection @_currStep.reqNum.max

        ### ACTION ###

        # listen to area selection from AreasOnMap
        @_areasOnMap.onSelectArea @, (area) =>
          selectedAreas.push area
          @_histoGraph.addToSelection area

          # check if step is completed
          if selectedAreas.length() >= @_currStep.reqNum.min
            @_coWindow.enableFinish() if @_currCO.stepIdx is @_currCO.totalSteps-1
            @_coWindow.enableNext()

        # listen to area deselection from AreasOnMap
        @_areasOnMap.onDeselectArea @, (area) =>
          selectedAreas.remove '_id', area._id
          @_histoGraph.removeFromSelection area

          # check if step is not completed anymore
          if selectedAreas.length() < @_currStep.reqNum.min
            @_coWindow.disableNext()
      )

      when 'SET_GEOM' then (

        # update step information
        @_currStep.reqNum = @_getRequiredNum @_currStep.reqNum
        terrCtr = 0

        # setup UI
        tt = new HG.TerritoryTools @_hgInstance, @_config.iconPath
        newTerrButton = @_hgInstance.buttons.newTerritory
        reuseTerrButton = @_hgInstance.buttons.reuseTerritory
        importTerrButton = @_hgInstance.buttons.importTerritory
        snapToPointsSwitch = @_hgInstance.switches.snapToPoints
        snapToLinesSwitch = @_hgInstance.switches.snapToLines
        snapToleranceInput = @_hgInstance.inputs.snapTolerance
        clipTerrButton = @_hgInstance.buttons.clipTerritory
        useRestButton = @_hgInstance.buttons.useRest

        clipTerrButton.disable()
        useRestButton.disable()

        ### ACTION ###

        newTerrButton.onClick @, () =>
          console.log 'init new territory on the map'
          tt.addToList 'new territory # ' + terrCtr
          terrCtr++

        reuseTerrButton.onClick @, () =>
          console.log 'reuse territory'
          tt.addToList 'reused territory # ' + terrCtr
          terrCtr++

        importTerrButton.onClick @, () =>
          console.log 'import new territory from file'
          tt.addToList 'imported territory # ' + terrCtr
          terrCtr++

        snapToPointsSwitch.onSwitchOn @, () =>
          console.log "turn switch to border points on!"

        snapToPointsSwitch.onSwitchOff @, () =>
          console.log "turn switch to border points off!"

        snapToLinesSwitch.onSwitchOn @, () =>
          console.log "turn switch to border lines on!"

        snapToLinesSwitch.onSwitchOff @, () =>
          console.log "turn switch to border lines off!"

        snapToleranceInput.onChange @, (val) =>
          console.log "the new snap tolerance value is " + val

        clipTerrButton.onClick @, () =>
          console.log "clip the drawn territory to the existing territory"

        useRestButton.onClick @, () =>
          console.log "use the remaining territory for this new country"


        # finish up
        @_coWindow.enableFinish() if @_currCO.stepIdx is @_currCO.totalSteps-1
        @_coWindow.enableNext()

      )

      when 'SET_NAME' then (

        # update step information
        @_currStep.reqNum = @_getRequiredNum @_currStep.reqNum

        # setup UI

        ### ACTION ###
        @_coWindow.enableFinish() if @_currCO.stepIdx is @_currCO.totalSteps-1
        @_coWindow.enableNext()

      )

      when 'ADD_CHNG' then (

        # update step information

        # setup UI

        ### ACTION ###
        @_coWindow.enableFinish() if @_currCO.stepIdx is @_currCO.totalSteps-1
        @_coWindow.enableNext()

      )


  # ============================================================================
  # possible inputs:  1   1+  2   2+
  MAX_NUM = 25
  _getRequiredNum: (exp) ->
    return null if not exp?
    lastChar = exp.substr(exp.length-1)
    max = if lastChar is '+' then MAX_NUM else lastChar
    min = (exp.substring 0,1)
    {'min': parseInt(min), 'max': parseInt(max)}