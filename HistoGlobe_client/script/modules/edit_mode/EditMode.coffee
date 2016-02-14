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
            @_currCO.totalSteps = @_currCO.steps.length
            @_currCO.stepIdx = 0
            @_currCO.finished = no

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

              @_cleanupStep() # old step

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

              @_cleanupStep() # old step

              # update step information
              @_currCO.stepIdx--
              @_currStep = @_currCO.steps[@_currCO.stepIdx]

              # update UI
              @_wWindow.moveStepMarker @_currCO.stepIdx
              @_wWindow.highlightText @_currCO.stepIdx

              @_setupStep()


            # listen to click on abort button
            @_abortButton.onClick @, () =>

              @_cleanupStep()
              @_cleanupOperation()

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
            @_nextButton.changeState 'finish' if @_currCO.stepIdx is @_currCO.totalSteps-1
            @_nextButton.enable()

        # listen to area deselection from AreasOnMap
        @_areasOnMap.onDeselectArea @, (area) =>
          selectedAreas.remove '_id', area._id
          @_histoGraph.removeFromSelection area

          # check if step is not completed anymore
          if selectedAreas.length() < @_currStep.reqNum.min
            @_nextButton.disable()
      )

      ## SET GEOMETRY OF NEW COUNTRY/-IES ##
      when 'SET_GEOM' then (

        # TODO: take out
        @_nextButton.enable()

        # update step information
        @_currStep.reqNum = @_getRequiredNum @_currStep.num
        terrCtr = 0

        ## setup controls
        @_terrTools = new HG.TerritoryTools @_hgInstance, @_config.iconPath
        newTerrButton =       @_hgInstance.buttons.newTerritory
        reuseTerrButton =     @_hgInstance.buttons.reuseTerritory
        importTerrButton =    @_hgInstance.buttons.importTerritory
        snapToPointsSwitch =  @_hgInstance.switches.snapToPoints
        snapToLinesSwitch =   @_hgInstance.switches.snapToLines
        snapToleranceInput =  @_hgInstance.inputs.snapTolerance
        clipTerrButton =      @_hgInstance.buttons.clipTerritory
        useRestButton =       @_hgInstance.buttons.useRest

        clipTerrButton.disable()
        useRestButton.disable()

        ### ACTION ###

        # TODO: setup leaflet draw to work
        @_polygonDrawer = new L.Draw.Polygon @_map

        @_map.on 'draw:created', (e) =>
          type = e.layerType
          layer = e.layer
          console.log type
          console.log layer._latlngs
          layer.addTo @_map

        newTerrButton.onClick @, () =>
          @_polygonDrawer.enable()

          # add to list in territory tools
          @_terrTools.addToList 'new territory # ' + terrCtr
          terrCtr++

        reuseTerrButton.onClick @, () =>
          # TODO: reuse territory

          # add to list in territory tools
          @_terrTools.addToList 'reused territory # ' + terrCtr
          terrCtr++

        importTerrButton.onClick @, () =>
          # TODO: import new territory from file

          # add to list in territory tools
          @_terrTools.addToList 'imported territory # ' + terrCtr
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
        @_nextButton.changeState 'finish' if @_currCO.stepIdx is @_currCO.totalSteps-1
        @_nextButton.enable()

      )

      ## SET NAME OF NEW COUNTRY/-IES ##
      when 'SET_NAME' then (

        # update step information
        @_currStep.reqNum = @_getRequiredNum @_currStep.num

        # for each required country, set up text input that has to be filled interactively
        # TODO: handle number of countries + interaction with database
        @_ctrLabel = new HG.NewCountryLabel @_hgInstance, [500, 200]
        @_ctrLabel.onSubmitName @, (name) => console.log name
        @_ctrLabel.onSubmitPos @, (pos) => console.log pos

        ### ACTION ###
        @_nextButton.changeState 'finish' if @_currCO.stepIdx is @_currCO.totalSteps-1
        @_nextButton.enable()

      )

      ## ADD CHANGE TO HIVENT ##
      when 'ADD_CHNG' then (

        # update step information

        # setup UI
        # TODO: take out
        @_nextButton.enable()

        ### ACTION ###
        @_nextButton.changeState 'finish' if @_currCO.stepIdx is @_currCO.totalSteps-1
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
          @_terrTools.destroy()
        )

      when 'SET_NAME' then (
          @_ctrLabel.destroy()
        )

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