window.HG ?= {}

# DEBUG: take out if not needed anymore
TEST_BUTTON = no
TEST_GEOM = [[
  [49.32512, -45.43945],
  [55.52863, -37.44140],
  [52.16045, -16.61132],
  [46.67959, -32.69531]
]]
TEST_NAME = {
  'commonName': 'Testland'
  'pos':        [50.5, -27.5]
}

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

    @addCallback 'onEnterEditMode'
    @addCallback 'onLeaveEditMode'

    @addCallback 'onStartOperation'
    @addCallback 'onEndOperation'

    @addCallback 'onStepComplete'
    @addCallback 'onStepIncomplete'
    @addCallback 'onOperationComplete'
    @addCallback 'onOperationIncomplete'

    # TODO: check which ones are necessary
    @addCallback 'onEnterOldAreaSelection'
    @addCallback 'onFinishOldAreaSelection'
    @addCallback 'onEnterNewAreaSelection'
    @addCallback 'onFinishNewAreaSelection'
    @addCallback 'onEnterHiventSelection'
    @addCallback 'onFinishHiventSelection'

    @addCallback 'onAddNewGeometry'
    @addCallback 'onRemoveNewGeometry'
    @addCallback 'onAddNewName'
    @addCallback 'onRemoveNewName'


    # init config
    defaultConfig =
      changeOperationsPath:     'HistoGlobe_client/config/common/hgChangeOperations.json'

    @_config = $.extend {}, defaultConfig, config


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
      $(testButton.getDom()).css 'position', 'absolute'
      $(testButton.getDom()).css 'bottom', '0'
      $(testButton.getDom()).css 'right', '0'
      $(testButton.getDom()).css 'z-index', 100
      @_hgInstance._top_area.appendChild testButton.getDom()
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
        'posX':         'right'
        'posY':         'top'
        'orientation':  'horizontal'
        'direction':    'prepend'
      }
      @_hgInstance._top_area.appendChild @_editButtonArea.getDom()

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
        @_operationButtons.foreach (btn) =>
          btn.button.onClick @, (btn) =>

            # get current operation
            inCO = @_changeOperations.getByPropVal 'id', btn.getDom().id

            @_currCO =
              {
                id:       inCO.id
                title:    inCO.title
                stepIdx:  0
                steps: [
                  {
                    id:         'SEL_OLD_AREA'
                    userInput:  no
                    minNum:     0
                    maxNum:     0
                    title:      null
                    selAreas:   []
                  },
                  {
                    id:         'SET_NEW_GEOM'
                    userInput:  no
                    minNum:     0
                    maxNum:     0
                    title:      null
                    clipAreas:  []
                    newAreas:   []
                  },
                  {
                    id:         'SET_NEW_NAME'
                    userInput:  no
                    minNum:     0
                    maxNum:     0
                    title:      null
                    newAreas:   []
                  },
                  {
                    id:         'ADD_CHNG'
                    userInput:  yes
                    title:      "add change <br /> to historical event"
                  },
                ]
              }

            # fill up default information with information of loaded change operation
            for inStep in inCO.steps
              for defStep in @_currCO.steps
                if defStep.id is inStep.id
                  defStep.userInput = yes
                  defStep.title = inStep.title
                  num = @_getRequiredNum inStep.num
                  defStep.minNum = num[0]
                  defStep.maxNum = num[1]
                  break

            console.log @_currCO

            # start operation
            @_setupOperation()

            ## (3) STEP ##
            @_makeStep()


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
    @_title = new HG.Title @_hgInstance

    @notifyAll 'onEnterEditMode'

  # ============================================================================
  _cleanupEditMode: () ->
    @notifyAll 'onLeaveEditMode'

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
    @_wWindow = new HG.WorkflowWindow @_hgInstance, @_currCO

    # listen to click on buttons in workflow window
    @_hgInstance.buttons.wwNext.onNext @, () =>   @_nextStep()
    @_hgInstance.buttons.wwBack.onBack @, () =>   @_prevStep()

    @_hgInstance.buttons.wwBack.onClick @, () =>
      # abort = back to the very beginning
      currStep = @_currCO.stepIdx
      while currStep > 0
        @_makeTransition currStep, currStep-1
        currStep--
      @_cleanupOperation()

    @_hgInstance.buttons.wwFinish.onFinish @, () =>
      console.log "HEUREKA"
      @_cleanupOperation()

    @notifyAll 'onStartOperation', @_currCO.id


  # ============================================================================
  _cleanupOperation: () ->
    @notifyAll 'onEndOperation', @_currCO.id

    # own UI
    (@_operationButtons.getById @_currCO.id).button.deactivate()
    @_newHiventButton.enable()
    @_operationButtons.foreach (obj) =>
      obj.button.enable()
    @_editButton.enable()


  ## (3) STEP ###

  # ============================================================================
  # waiting for user input in each step or automatically process information
  _makeStep: () ->

    ## SELECT OLD COUNTRY/-IES ##
    if @_currCO.stepIdx is 0

      ## skip step for certain operations
      if @_currCO.id is 'NEW'
        @_nextStep()

      ## user input for certain operations
      else
        @_areasOnMap.onSelectArea @, (area) =>
          @_currCO.steps[0].selAreas.push area
          # is step complete?
          if @_currCO.steps[0].selAreas.length >= @_currCO.steps[0].minNum
            @notifyAll 'onStepComplete'

        @_areasOnMap.onDeselectArea @, (area) =>
          @_currCO.selAreas.splice @_currCO.selAreas.indexOf area, 1 # remove Area from array
          # is step incomplete?
          if @_currCO.selAreas.length < xxx.reqNum.min
            @notifyAll 'onStepIncomplete'


    ## SET GEOMETRY OF NEW COUNTRY/-IES ##
    else if @_currCO.stepIdx is 1

      ## skip step for certain operations
      if @_currCO.id is 'UNI' or @_currCO.id is 'CHN' or @_currCO.id is 'DEL'
        @_nextStep()

      ## user input for certain operations
      else
        @_hgInstance.buttons.newTerritory.onClick @, () =>
          # TODO: what to do on add territory?

        @_hgInstance.buttons.reuseTerritory.onClick @, () =>
          # TODO: what to do on reuse territory?

        @_hgInstance.buttons.importTerritory.onClick @, () =>
          # TODO: what to do on import new territory from file?

        @_hgInstance.buttons.editTerritory.onClick @, () =>
          # TODO: what to do on edit territory?

        @_hgInstance.buttons.deleteTerritory.onClick @, () =>
          # TODO: what to do on delete territory?

        # @_hgInstance.switches.snapToPoints.onSwitchOn @, () =>
          # TODO: what to do on turn switch to border points on!?

        # @_hgInstance.switches.snapToPoints.onSwitchOff @, () =>
          # TODO: what to do on turn switch to border points off!?

        # @_hgInstance.switches.snapToLines.onSwitchOn @, () =>
          # TODO: what to do on turn switch to border lines on!?

        # @_hgInstance.switches.snapToLines.onSwitchOff @, () =>
          # TODO: what to do on turn switch to border lines off!?

        # @_hgInstance.inputs.snapTolerance.onChange @, (val) =>
          # TODO: what to do on the new snap tolerance value is " + va?

        @_hgInstance.buttons.clipTerritory.onClick @, () =>
          # TODO: what to do on clip the drawn territory to the existing territory?

        @_hgInstance.buttons.useRest.onClick @, () =>
          # TODO: what to do on use the remaining territory for this new country?

        ## finish up
        # TODO: check if complete
        @notifyAll 'onStepComplete'
        # TODO: check if incomplete


    ## SET NAME OF NEW COUNTRY/-IES ##
    else if @_currCO.stepIdx is 2

      ## skip step for certain operations
      if @_currCO.id is 'CHB' or @_currCO.id is 'DEL'
        @_nextStep()

      ## user input for certain operations
      else
        # for each required country, set up text input that has to be filled interactively
        # TODO: handle number of countries + interaction with database
        @_ctrLabel.onSubmitName @, (name) =>
          console.log name

        @_ctrLabel.onSubmitPos @, (pos) =>
          console.log pos

        ## finish up
        # TODO: check if complete
        @notifyAll 'onStepComplete'
        # TODO: check if incomplete


    ## ADD CHANGE TO HIVENT ##
    else if @_currCO.stepIdx is 3

      ## TODO: Hivent window

      ### ACTION ###
      ## finish up
      # TODO: check if complete
      @notifyAll 'onOperationComplete'
      # TODO: check if incomplete


  # ============================================================================
  _makeTransition: (oldStep, newStep) ->
    console.log 'HORST'

    # setup buttons
    if @_currCO.stepIdx is 0
      @_backButton.disable()
    else
      @_backButton.enable()
    @_nextButton.changeState 'normal'
    @_nextButton.disable()

    # 'SEL_OLD_AREA' -> 'SET_NEW_GEOM'
    if oldStep is 0 and newStep is 1

      # cleanup UI
      @notifyAll 'onFinishOldAreaSelection'

      if @_currCO.id is 'UNI'   # unify old areas
        @_currCO.steps[1].newAreas = [] # TODO: unify @_currCO.steps[0].selAreas
        # DEBUG: create new country
        # na = new HG.Area 'Horst', TEST_GEOM, null
        # na.select()
        # @notifyAll 'onAddNewGeometry', na


      else if @_currCO.id is 'DEL'   # delete old area
        @notifyAll 'onRemoveArea', @_currCO.steps[0].oldAreas[0]

      else if @_currCO.id is 'CHN'
        console.log "do nothing ;)"

      # setup UI
      else
        @_ctrTerritory = new HG.NewCountryTerritory @_hgInstance

    # 'SEL_OLD_AREA' <- 'SET_NEW_GEOM'
    # else if oldStep is 1 and newStep is 0

    # 'SET_NEW_GEOM' -> 'SET_NEW_NAME'
    # else if oldStep is 1 and newStep is 2

    # 'SET_NEW_GEOM' <- 'SET_NEW_NAME'
    else if oldStep is 2 and newStep is 1
      @_ctrLabel = new HG.NewCountryLabel @_hgInstance, [500, 200]  # TODO: real position


    # 'SET_NEW_NAME' -> 'ADD_CHNG'
    # else if oldStep is 2 and newStep is 3

    # 'SET_NEW_NAME' <- 'ADD_CHNG'
    else if oldStep is 3 and newStep is 2
      @_ctrLabel = new HG.NewCountryLabel @_hgInstance, [500, 200]  # TODO: real position



  # ============================================================================
  _nextStep: () ->
    @_makeTransition @_currCO.stepIdx, @_currCO.stepIdx+1
    @_currCO.stepIdx++
    @_makeStep()
  _prevStep: () ->
    @_makeTransition @_currCO.stepIdx, @_currCO.stepIdx-1
    @_currCO.stepIdx--
    @_makeStep()


  # ============================================================================
  # possible inputs:  1   1+  2   2+
  MAX_NUM = 25
  _getRequiredNum: (expr) ->
    return 0 if not expr?
    lastChar = expr.substr(expr.length-1)
    max = if lastChar is '+' then MAX_NUM else lastChar
    min = (expr.substring 0,1)
    [parseInt(min), parseInt(max)]
