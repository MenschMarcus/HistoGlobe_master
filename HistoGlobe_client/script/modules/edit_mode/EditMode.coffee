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
      @_editModeButton = @_hgInstance.buttons.editMode
      @_title = new HG.Title @_hgInstance
      @_histoGraph = @_hgInstance.histoGraph
      @_areasOnMap = @_hgInstance.areasOnMap

      # listen to click on edit button => start edit mode
      @_editModeButton.onEnter @, () ->

        @_editModeButton.changeState 'edit-mode'
        @_editModeButton.activate()
        @_editButtons.show()
        @_title.resize()
        @_title.set 'EDIT MODE'   # TODO internationalization


        # workflow hierachy: operation -> step -> action

        ### OPERATION ###
        # listen to click on edit operation buttons => start operation
        @_hgChangeOperations.foreach (operation) =>
          @_hgInstance.buttons[operation.id].onStart @, (btn) =>

            # update current operation in workflow
            opId = btn.get().id
            @_currCO = @_hgChangeOperations.getByPropVal 'id', opId
            @_currCO.totalSteps = @_currCO.steps.length
            @_currCO.stepIdx = 0
            @_currCO.finished = no
            @_currStep = @_currCO.steps[@_currCO.stepIdx]

            # setup UI
            @_editButtons.disable()
            @_editButtons.activate @_currCO.id
            @_title.clear()
            @_coWindow?.destroy()
            @_coWindow = new HG.ChangeOperationWindow @_hgInstance, @_currCO
            @_backButton = @_hgInstance.buttons.coBack
            @_nextButton = @_hgInstance.buttons.coNext
            @_backButton.disable()
            @_nextButton.disable()
            @_histoGraph.show()

            @_makeStep()


            # listen to click on next button
            @_hgInstance.buttons.coNext.onNext @, () =>

              # send info to server
              # receive new info from server

              @_cleanupStep()

              # update step information
              @_currCO.stepIdx++
              @_currStep = @_currCO.steps[@_currCO.stepIdx]

              # update UI
              @_coWindow.moveStepMarker @_currCO.stepIdx
              @_coWindow.highlightText @_currCO.stepIdx
              @_backButton.enable()
              @_nextButton.disable()

              @_makeStep()


            @_hgInstance.buttons.coNext.onFinish @, () =>
              # TODO finish up


            # listen to click on back button
            @_hgInstance.buttons.coBack.onBack @, () =>

              # send info to server
              # receive new info from server

              @_cleanupStep()

              # update step information
              @_currCO.stepIdx--
              @_currStep = @_currCO.steps[@_currCO.stepIdx]

              # update UI
              @_coWindow.moveStepMarker @_currCO.stepIdx
              @_coWindow.highlightText @_currCO.stepIdx
              @_coWindow.disableFinish()
              @_backButton.disable() if @_currCO.stepIdx is 0
              @_nextButton.disable()

              @_makeStep()


            # listen to click on abort button
            @_hgInstance.buttons.coAbort.onClick @, () =>

              @_cleanupStep()

              # reset UI
              @_coWindow.destroy()
              @_editButtons.deactivate @_currCO.id
              @_editButtons.enable @_currCO.id

              # reset step information
              @_currCO    = {}
              @_currStep  = {}



      # listen to next click on edit button => leave edit mode and cleanup
      @_editModeButton.onLeave @, () ->
        @_cleanupStep() unless @_currStep?

        # reset UI
        @_title?.clear()
        @_coWindow?.destroy()
        @_editButtons.deactivate @_currCO.id unless @_currStep?
        @_editButtons.enable @_currCO.id unless @_currStep?
        @_editModeButton.changeState 'normal'
        @_editModeButton.deactivate()
        @_editButtons.hide()

        # reset step information
        @_currCO    = {}
        @_currStep  = {}
    )

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  ### STEP ###
  _makeStep: () ->

    # TODO "make hivent in HistoGraph" if @_currStep.startNew

    switch @_currStep.id

      when 'SEL_OLD' then (

        # update step information
        @_currStep.reqNum = @_getRequiredNum @_currStep.num
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
            @_nextButton.enable()

        # listen to area deselection from AreasOnMap
        @_areasOnMap.onDeselectArea @, (area) =>
          selectedAreas.remove '_id', area._id
          @_histoGraph.removeFromSelection area

          # check if step is not completed anymore
          if selectedAreas.length() < @_currStep.reqNum.min
            @_nextButton.disable()
      )

      when 'SET_GEOM' then (

        # TODO: take out
        @_nextButton.enable()

        # update step information
        @_currStep.reqNum = @_getRequiredNum @_currStep.num
        terrCtr = 0

        # init draw functionality on the map -> using leaflet.draw
        # TODO: get this to work
        map = @_hgInstance.map._map
        items = new L.FeatureGroup()
        map.addLayer items

        # draw control
        # TODO: replace by own territory tools at some point
        drawControl = new L.Control.Draw {
          edit: {
            featureGroup: items
          }
        }
        map.addLayer drawControl

        # functionality
        map.on 'draw:created', (e) ->
          type = e.layerType
          layer = e.layer
          if type is 'marker'
            # Do marker specific actions
          else
            # Do whatever else you need to. (save to db, add to map etc)
          drawnItems.addLayer layer

        map.on 'draw:edited', ->
          #TODO "update db to save latest changes"

        map.on 'draw:deleted', ->
          #TODO "update db to save latest changes"


        # setup UI
        @_tt = new HG.TerritoryTools @_hgInstance, @_config.iconPath
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
          # TODO: init new territory on the map
          @_tt.addToList 'new territory # ' + terrCtr
          terrCtr++

        reuseTerrButton.onClick @, () =>
          # TODO: reuse territory
          @_tt.addToList 'reused territory # ' + terrCtr
          terrCtr++

        importTerrButton.onClick @, () =>
          # TODO: import new territory from file
          @_tt.addToList 'imported territory # ' + terrCtr
          terrCtr++

        snapToPointsSwitch.onSwitchOn @, () =>
          # TODO: turn switch to border points on!

        snapToPointsSwitch.onSwitchOff @, () =>
          # TODO: turn switch to border points off!

        snapToLinesSwitch.onSwitchOn @, () =>
          # TODO: turn switch to border lines on!

        snapToLinesSwitch.onSwitchOff @, () =>
          # TODO: turn switch to border lines off!

        snapToleranceInput.onChange @, (val) =>
          # TODO: the new snap tolerance value is " + va

        clipTerrButton.onClick @, () =>
          # TODO: clip the drawn territory to the existing territory

        useRestButton.onClick @, () =>
          # TODO: use the remaining territory for this new country


        # finish up
        @_coWindow.enableFinish() if @_currCO.stepIdx is @_currCO.totalSteps-1
        @_nextButton.enable()

      )

      when 'SET_NAME' then (

        # update step information
        @_currStep.reqNum = @_getRequiredNum @_currStep.num

        # setup UI
        # TODO: take out
        @_nextButton.enable()

        ### ACTION ###
        @_coWindow.enableFinish() if @_currCO.stepIdx is @_currCO.totalSteps-1
        @_nextButton.enable()

      )

      when 'ADD_CHNG' then (

        # update step information

        # setup UI
        # TODO: take out
        @_nextButton.enable()

        ### ACTION ###
        @_coWindow.enableFinish() if @_currCO.stepIdx is @_currCO.totalSteps-1
        @_nextButton.enable()

      )


  # ============================================================================
  _cleanupStep: () ->

    switch @_currStep.id

      when 'SEL_OLD' then (
          #TODO: deselect active areas
          @_areasOnMap.disableMultipleSelection()
        )

      when 'SET_GEOM' then (
          @_tt.destroy()
        )

      when 'SET_NAME' then

      when 'ADD_CHNG' then


  # ============================================================================
  # possible inputs:  1   1+  2   2+
  MAX_NUM = 25
  _getRequiredNum: (exp) ->
    return null if not exp?
    lastChar = exp.substr(exp.length-1)
    max = if lastChar is '+' then MAX_NUM else lastChar
    min = (exp.substring 0,1)
    {'min': parseInt(min), 'max': parseInt(max)}