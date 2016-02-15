window.HG ?= {}

TEST_BUTTON = no    # DEBUG: take out if not needed anymore

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
    @_currCO = {}                   # object of current change operation
    @_currStep = {}                 # object of current step in workflow


  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add to HG instance
    @_hgInstance.editController = @   # N.B. edit mode = edit controller :)

    # init variables for convenience ;)
    @_histoGraph = @_hgInstance.histoGraph
    @_map = @_hgInstance.map._map
    @_areasOnMap = @_hgInstance.areasOnMap


    if TEST_BUTTON
      testButton = new HG.Button @_hgInstance, 'test', null, [{'iconFA': 'question','callback': 'onClick'}]
      $(testButton.get()).css 'position', 'absolute'
      $(testButton.get()).css 'bottom', '0'
      $(testButton.get()).css 'right', '0'
      $(testButton.get()).css 'z-index', 100
      @_hgInstance._top_area.appendChild testButton.get()
      @_testButton = @_hgInstance.buttons.test
      @_testButton.onClick @, () =>
        console.log '============================================================'
        console.log "center   ", @_map.getCenter()
        console.log "zoom     ", @_map.getZoom()
        console.log "bounds   ", '[', @_map.getBounds()._northEast.lat, ',', @_map.getBounds()._northEast.lng, '], [', @_map.getBounds()._southWest.lat, ',', @_map.getBounds()._southWest.lng, ']'
        console.log "map size ", @_map.getSize()
        console.log "px bounds", '[', @_map.getPixelBounds().min.x, ',', @_map.getPixelBounds().min.y, '], [', @_map.getPixelBounds().max.x, ',', @_map.getPixelBounds().max.y, ']'
        console.log "px orig  ", @_map.getPixelOrigin()
        console.log '============================================================'



    # init everything
    $.getJSON(@_config.changeOperationsPath, (ops) =>

      # load operations
      @_changeOperations = new HG.ObjectArray ops # all possible operations

      # setup edit button area and add editButton to it
      # is always there, never has to be destructed
      @_editButtonArea = new HG.ButtonArea @_hgInstance,
      {
        'id':           'editButtons'
        'positionX':    'right'
        'positionY':    'top'
        'orientation':  'horizontal'
        'direction':    'prepend'
      }
      @_editButton = new HG.Button @_hgInstance, 'editMode', null, [
          {
            'id':       'normal',
            'tooltip':  "Enter Edit Mode",
            'iconFA':   'pencil',
            'callback': 'onEnter'
          },
          {
            'id':       'edit-mode',
            'tooltip':  "Leave Edit Mode",
            'iconFA':   'pencil',
            'callback': 'onLeave'
          }
        ]
      @_editButtonArea.addButton @_editButton


      ### EDIT HIERACHY: EDIT MODE -> OPERATION -> STEP -> ACTION ###

      ## (1) EDIT MODE ##
      # listen to click on edit button => start edit mode
      @_editButton.onEnter @, () ->

        @_setupEditMode()

        ## (2) OPERATION ##
        # listen to click on edit operation buttons => start operation
        @_operationButtons.foreach (b) =>
          b.button.onClick @, (btn) =>

            # update current operation in workflow
            opId = btn.get().id
            @_currCO = @_changeOperations.getByPropVal 'id', opId
            @_currCO.oldAreas = new HG.ObjectArray      # areas that are subject to change (old)
            @_currCO.newAreas = new HG.ObjectArray      # areas that replace old areas (new)
            @_currCO.numSteps = @_currCO.steps.length   # total number of steps in the operation
            @_currCO.stepIdx = 0                        # current step number [0 .. numSteps-1]
            @_currCO.finished = no                      # operation successfully finished # TODO: necessary?

            @_setupOperation()

            ## (3) STEP ##
            # 1. step comes automatically, without need to click on a button
            while true

              # update current step in workflow
              @_currStep = @_currCO.steps[@_currCO.stepIdx]

              @_setupStep()

              break


            # listen to click on next button
            @_nextButton.onNext @, () =>

              # send info to server
              # receive new info from server

              @_cleanupStep false # old step

              # update current step in  workflow
              @_currCO.stepIdx++
              @_currStep = @_currCO.steps[@_currCO.stepIdx]

              # update UI
              @_wWindow.moveStepMarker @_currCO.stepIdx
              @_wWindow.highlightText @_currCO.stepIdx

              @_setupStep()



            # listen to click on back button
            @_backButton.onBack @, () =>

              # send info to server
              # receive new info from server

              @_cleanupStep true # old step

              # update step information
              @_currCO.stepIdx--
              @_currStep = @_currCO.steps[@_currCO.stepIdx]

              # update UI
              @_wWindow.moveStepMarker @_currCO.stepIdx
              @_wWindow.highlightText @_currCO.stepIdx

              @_setupStep()


            # listen to click on abort button
            @_abortButton.onClick @, () =>

              @_cleanupStep true
              @_cleanupOperation true

              # reset step information
              @_currCO    = {}
              @_currStep  = {}


            @_nextButton.onFinish @, () =>
              console.log "HEUREKA"
              # TODO finish up


      # listen to next click on edit button => leave edit mode and cleanup
      @_editButton.onLeave @, () ->
        @_cleanupEditMode()
    )


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  ## (1) EDIT MODE ##

  # ============================================================================
  _setupEditMode: () ->
    # activate edit button
    @_editButton.changeState 'edit-mode'
    @_editButton.activate()

    # setup new hivent button
    @_editButtonArea.addSpacer()
    @_newHiventButton = new HG.Button @_hgInstance, 'newHivent', null,  [
        {
          'id':       'normal',
          'tooltip':  "Add New Hivent",
          'iconOwn':  @_hgInstance._config.graphicsPath + 'buttons/new_hivent.svg',
          'callback': 'onAdd'
        }
      ]
    @_editButtonArea.addButton @_newHiventButton

    # setup operation buttons
    @_editButtonArea.addSpacer()
    @_operationButtons = new HG.ObjectArray
    @_changeOperations.foreach (operation) =>
      # add button to UI
      coButton = new HG.Button @_hgInstance, operation.id, ['button-horizontal'], [
          {
            'id':       'normal',
            'tooltip':  operation.title,
            'iconOwn':  @_hgInstance._config.graphicsPath + 'buttons/' + operation.id + '.svg',
            'callback': 'onClick'
          }
        ]
      @_editButtonArea.addButton coButton, 'changeOperations-group'
      # add button in object array to keep track of it
      @_operationButtons.push {
          'id': operation.id,
          'button': coButton
        }

    # setup title
    @_title = new HG.Title @_hgInstance, "EDIT MODE"  # TODO internationalization

  # ============================================================================
  _cleanupEditMode: () ->
    @_title.destroy()
    @_operationButtons.foreach (b) =>
      b.button.destroy()
    @_newHiventButton.destroy()
    @_editButton.deactivate()
    @_editButton.changeState 'normal'


  ## (2) OPERATION ##

  # ============================================================================
  _setupOperation: () ->
    # disable all buttons
    @_editButton.disable()
    @_newHiventButton.disable()
    @_operationButtons.foreach (obj) =>
      obj.button.disable()

    # highlight button of current operation
    (@_operationButtons.getById @_currCO.id).button.activate()

    # setup workflow window
    @_title.clear()
    @_wWindow = new HG.WorkflowWindow @_hgInstance, @_currCO
    @_backButton = @_hgInstance.buttons.coBack
    @_nextButton = @_hgInstance.buttons.coNext
    @_abortButton = @_hgInstance.buttons.coAbort
    @_backButton.disable()
    @_nextButton.disable()

    # setup histograph for visualization of operation
    @_histoGraph.show()

  # ============================================================================
  _cleanupOperation: () ->
    @_histoGraph.hide()
    @_abortButton.destroy()
    @_nextButton.destroy()
    @_backButton.destroy()
    @_wWindow.destroy()
    @_title.set "EDIT MODE"
    (@_operationButtons.getById @_currCO.id).button.deactivate()
    @_newHiventButton.enable()
    @_operationButtons.foreach (obj) =>
      obj.button.enable()
    @_editButton.enable()


  ## (3) STEP ###

  # ============================================================================
  _setupStep: () ->

    # setup buttons
    if @_currCO.stepIdx is 0
      @_backButton.disable()
    else
      @_backButton.enable()
    @_nextButton.changeState 'normal'
    @_nextButton.disable()


    # TODO "make hivent in HistoGraph" if @_currStep.startNew

    switch @_currStep.id

      ## SELECT OLD COUNTRY/-IES ##
      when 'SEL_OLD' then (

        # update step information
        @_currStep.reqNum = @_getRequiredNum @_currStep.num

        # setup UI
        @_areasOnMap.enableMultipleSelectionMode @_currStep.reqNum.max

        ### ACTION ###

        # listen to area selection from AreasOnMap
        @_areasOnMap.onSelectArea @, (obj) =>
          @_currCO.oldAreas.push obj
          @_histoGraph.addToSelection obj

          # check if step is completed
          if @_currCO.oldAreas.length() >= @_currStep.reqNum.min
            @_nextButton.enable()
            @_nextButton.changeState 'finish' if @_currCO.stepIdx is @_currCO.numSteps-1

        # listen to area deselection from AreasOnMap
        @_areasOnMap.onDeselectArea @, (id) =>
          @_currCO.oldAreas.removeById id
          @_histoGraph.removeFromSelection id

          # check if step is not completed anymore
          if @_currCO.oldAreas.length() < @_currStep.reqNum.min
            @_nextButton.disable()
      )

      ## SET GEOMETRY OF NEW COUNTRY/-IES ##
      when 'SET_GEOM' then (

        # update step information
        @_currStep.reqNum = @_getRequiredNum @_currStep.num

        # setup ui
        @_areasOnMap.leaveFocusMode() if @_currStep.startNew # only if this is the first step in "start new"
        @_areasOnMap.enterNewGeomMode()

        # init new country territory dialoge
        @_ctrTerritory = new HG.NewCountryTerritory @_hgInstance

        newTerrButton =       @_hgInstance.buttons.newTerritory
        reuseTerrButton =     @_hgInstance.buttons.reuseTerritory
        importTerrButton =    @_hgInstance.buttons.importTerritory
        editTerrButton =      @_hgInstance.buttons.editTerritory
        deleteTerrButton =    @_hgInstance.buttons.deleteTerritory
        # snapToPointsSwitch =  @_hgInstance.switches.snapToPoints
        # snapToLinesSwitch =   @_hgInstance.switches.snapToLines
        # snapToleranceInput =  @_hgInstance.inputs.snapTolerance
        clipTerrButton =      @_hgInstance.buttons.clipTerritory
        useRestButton =       @_hgInstance.buttons.useRest

        editTerrButton.disable()
        deleteTerrButton.disable()
        clipTerrButton.disable()
        useRestButton.disable()

        # ### ACTION ###

        newTerrButton.onClick @, () =>
          # TODO: what to do on add territory?

        reuseTerrButton.onClick @, () =>
          # TODO: what to do on reuse territory?

        importTerrButton.onClick @, () =>
          # TODO: what to do on import new territory from file?

        editTerrButton.onClick @, () =>
          # TODO: what to do on edit territory?

        deleteTerrButton.onClick @, () =>
          # TODO: what to do on delete territory?

        # snapToPointsSwitch.onSwitchOn @, () =>
          # TODO: what to do on turn switch to border points on!?

        # snapToPointsSwitch.onSwitchOff @, () =>
          # TODO: what to do on turn switch to border points off!?

        # snapToLinesSwitch.onSwitchOn @, () =>
          # TODO: what to do on turn switch to border lines on!?

        # snapToLinesSwitch.onSwitchOff @, () =>
          # TODO: what to do on turn switch to border lines off!?

        # snapToleranceInput.onChange @, (val) =>
          # TODO: what to do on the new snap tolerance value is " + va?

        clipTerrButton.onClick @, () =>
          # TODO: what to do on clip the drawn territory to the existing territory?

        useRestButton.onClick @, () =>
          # TODO: what to do on use the remaining territory for this new country?


        # finish up
        @_nextButton.enable()
        @_nextButton.changeState 'finish' if @_currCO.stepIdx is @_currCO.numSteps-1

      )

      ## SET NAME OF NEW COUNTRY/-IES ##
      when 'SET_NAME' then (

        # update step information
        @_currStep.reqNum = @_getRequiredNum @_currStep.num

        # setup UI
        @_areasOnMap.leaveFocusMode() if @_currStep.startNew # only if this is the first step in "start new"

        # for each required country, set up text input that has to be filled interactively
        # TODO: handle number of countries + interaction with database
        @_ctrLabel = new HG.NewCountryLabel @_hgInstance, [500, 200]
        @_ctrLabel.onSubmitName @, (name) => console.log name
        @_ctrLabel.onSubmitPos @, (pos) => console.log pos

        ### ACTION ###
        @_nextButton.enable()
        @_nextButton.changeState 'finish' if @_currCO.stepIdx is @_currCO.numSteps-1

      )

      ## ADD CHANGE TO HIVENT ##
      when 'ADD_CHNG' then (

        # update step information

        # setup UI
        # TODO: take out
        @_nextButton.enable()

        ### ACTION ###
        @_nextButton.enable()
        @_nextButton.changeState 'finish' if @_currCO.stepIdx is @_currCO.numSteps-1

      )


  # ============================================================================
  _cleanupStep: (aborted=false) ->

    # for some reason, switch @_currStep.id when '...' then () does not work here ?!?

    if @_currStep.id is 'SEL_OLD'
      @_areasOnMap.disableMultipleSelectionMode()
      if aborted
        @_areasOnMap.clearSelectedAreas()

    else if @_currStep.id is 'SET_GEOM'
      @_ctrTerritory.destroy()

    else if @_currStep.id is 'SET_NAME'
      @_ctrLabel.destroy()

    else if @_currStep.id is 'ADD_CHNG'
      console.log 'OUT'


  # ============================================================================
  # possible inputs:  1   1+  2   2+
  MAX_NUM = 25
  _getRequiredNum: (exp) ->
    return null if not exp?
    lastChar = exp.substr(exp.length-1)
    max = if lastChar is '+' then MAX_NUM else lastChar
    min = (exp.substring 0,1)
    {'min': parseInt(min), 'max': parseInt(max)}