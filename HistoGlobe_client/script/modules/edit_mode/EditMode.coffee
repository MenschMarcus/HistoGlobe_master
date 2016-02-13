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

        # init draw functionality on the map -> using leaflet.draw
        # TODO: get this to work
        items = new L.FeatureGroup()
        @_map.addLayer items

        # draw control
        # TODO: replace by own territory tools at some point
        drawControl = new L.Control.Draw {
          edit: {
            featureGroup: items
          }
        }
        @_map.addLayer drawControl

        # functionality
        @_map.on 'draw:created', (e) ->
          type = e.layerType
          layer = e.layer
          if type is 'marker'
            # Do marker specific actions
          else
            # Do whatever else you need to. (save to db, add to map etc)
          drawnItems.addLayer layer

        @_map.on 'draw:edited', ->
          #TODO "update db to save latest changes"

        @_map.on 'draw:deleted', ->
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
        @_nextButton.changeState 'finish' if @_currCO.stepIdx is @_currCO.totalSteps-1
        @_nextButton.enable()

      )

      ## SET NAME OF NEW COUNTRY/-IES ##
      when 'SET_NAME' then (

        # update step information
        @_currStep.reqNum = @_getRequiredNum @_currStep.num

        ## PROBLEM:
        # I need a text field with the following three characterstics:
        # 1. it needs to be in the coordinate system of the world
        # 2. it needs to be draggable
        # 3. its text needs to be editable

        ## POSSIBLE SOLUTIONS:
        # A) use Leaflet element
        #   (+) in coordinate system
        #   (-) no element is both draggable and editable
        # => not possible without reimplementation of leaflet features!
        # B) use HTML text input in the view point
        #   (+) draggable and editable
        #   (-) not in coordinate system
        #   (-) position does not update on zoom / pan of the map
        # => possible, but hard...

        # setup UI
        # for each required country, set up text input that has to be filled interactively

        @_newName = new HG.Div 'new-name-wrapper', ['draggable']
        @_hgInstance._top_area.appendChild @_newName.dom()
        @_newNameInput = new HG.TextInput @_hgInstance, 'new-name-input', null
        @_newNameInput.j().attr 'size', 1 # starts with minimum size of 1
        @_newName.append @_newNameInput
        okButton = new HG.Button @_hgInstance, 'newNameOK', ['confirm-button'], [
          {
            'iconFA':   'check'
          }
        ]
        @_newName.dom().appendChild okButton.get()

        # make inout field draggable
        # this code snippet does MAGIC !!!
        # credits to: A. Wolff
        # http://stackoverflow.com/questions/22814073/how-to-make-an-input-field-draggable
        # http://jsfiddle.net/9SPvQ/2/
        $('.draggable').draggable start: (event, ui) ->
          $(this).data 'preventBehaviour', true
        $('.draggable :input').on('mousedown', (e) ->
          mdown = document.createEvent('MouseEvents')
          mdown.initMouseEvent 'mousedown', true, true, window, 0, e.screenX, e.screenY, e.clientX,   e.clientY, true, false, false, true, 0, null
          $(this).closest('.draggable')[0].dispatchEvent mdown
          return
        ).on 'click', (e) ->
          $draggable = $(this).closest('.draggable')
          if $draggable.data('preventBehaviour')
            e.preventDefault()
            $draggable.data 'preventBehaviour', false
          return

        # resize textinput on almost anything you want ...
        @_newNameInput.j().on 'keydown keydown click each', (e) ->
          width = Math.max 1, ($(this).val().length)*1.2  # makes sure width is at least 1
          # TODO: 1) set actual width, independent from font-size
          #       2) animate to the new width -> works not with 'size' but only with 'width' (size is not a CSS property)
          # width = Math.max 1, this.clientWidth
          $(this).attr 'size', width

        # transform to leaflet coordinates
        okButton.onClick @, () =>
          # get center coordinates
          offset = @_newNameInput.j().offset()
          width = @_newNameInput.j().width()
          height = @_newNameInput.j().height()
          center = L.point offset.left + width / 2, offset.top + height / 2
          console.log 'name      :', @_newNameInput.j().val()
          console.log 'pos (gps) :', @_map.containerPointToLatLng center

        # TODO
        # update position on zoom
        # math: scaling
        # @_map.on 'zoomend', (e) =>
        #   zoomCenter = @_map.latLngToContainerPoint e.target._initialCenter
        #   zoomFactor = @_map.getScaleZoom()
        #   windowCenterStart = @_inputCenter

        #   windowCenterEnd = L.point(
        #     zoomCenter.x - ((zoomCenter.x - windowCenterStart.x) / zoomFactor),
        #     zoomCenter.y - ((zoomCenter.y - windowCenterStart.y) / zoomFactor)
        #   )

        #   console.log e
        #   console.log zoomCenter
        #   console.log zoomFactor
        #   console.log windowCenterStart
        #   console.log windowCenterEnd


        # update position on drag
        # WHY DOES THAT NOT WORK ???
        @_viewCenter = @_map.getCenter()
        @_map.on 'drag', (e) =>
          # get movement of center of the map
          mapOld = @_viewCenter
          mapNew = @_map.getCenter()
          ctrOld = @_map.latLngToContainerPoint mapOld
          ctrNew = @_map.latLngToContainerPoint mapNew
          ctrDist = [
            (ctrNew.x - ctrOld.x),
            (ctrNew.y - ctrOld.y)
          ]
          # project movement to wrapper
          inputOld = @_newName.j().position()
          inputNew = L.point(
            inputOld.left + ctrDist[0], # x
            inputOld.top + ctrDist[1]  # y
          )
          @_newName.j().css 'left', inputNew[0]
          @_newName.j().css 'top', inputNew[1]
          # refresh
          @_viewCenter = mapNew



        # style nicely

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