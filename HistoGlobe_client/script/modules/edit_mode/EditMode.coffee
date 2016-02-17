window.HG ?= {}

# DEBUG: take out if not needed anymore
TEST_BUTTON = yes


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

    @addCallback 'onStartAreaSelection'
    @addCallback 'onFinishAreaSelection'
    @addCallback 'onStartGeometrySetting'
    @addCallback 'onFinishGeometrySetting'
    @addCallback 'onStartNameSetting'
    @addCallback 'onFinishNameSetting'
    @addCallback 'onStartHiventSelection'
    @addCallback 'onFinishHiventSelection'

    @addCallback 'onAddArea'
    @addCallback 'onUpdateArea'
    @addCallback 'onRemoveArea'


    # init config
    defaultConfig =
      changeOperationsPath:     'HistoGlobe_client/config/common/hgChangeOperations.json'

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add to HG instance
    @_hgInstance.editController = @   # N.B. edit mode = edit controller :)

    # loading dependencies + error handling
    if @_hgInstance.map._map?
      @_map = @_hgInstance.map._map
    else
      console.error "Unable to load Edit Mode: There is no map, you idiot! Why would you want to have HistoGlobe without a map ?!?"

    if @_hgInstance.areasOnMap?
      @_areasOnMap = @_hgInstance.areasOnMap
    else
      console.error "Unable to load Edit Mode: AreasOnMap module is not included in the current hg instance (has to be loaded before EditMode)"

    # if @_hgInstance.histoGraph?
    #   @_histoGraph = @_hgInstance.histoGraph
    # else
    #   console.error "Unable to load Edit Mode: HistoGraph module is not included in the current hg instance (has to be loaded before EditMode)"





    if TEST_BUTTON
      testButton = new HG.Button @_hgInstance, 'test', null, [{'iconFA': 'question','callback': 'onClick'}]
      $(testButton.getDom()).css 'position', 'absolute'
      $(testButton.getDom()).css 'bottom', '0'
      $(testButton.getDom()).css 'right', '0'
      $(testButton.getDom()).css 'z-index', 100
      @_hgInstance._top_area.appendChild testButton.getDom()
      @_testButton = @_hgInstance.buttons.test
      @_testButton.onClick @, () =>


        toWKT = (inLayer) ->
          # credits: Bryan McBride - thank you!
          # https://gist.github.com/bmcbride/4248238
          # -> extended to deal with MultiPolylines and MultiPolygons as well
          # => returns array of wkt strings

          lng = undefined
          lat = undefined
          inLayers = [inLayer]
          wktStrings = []
          # preparation: transform MultiPolygons to multiple polygon layers *haha*
          if inLayer instanceof L.MultiPolygon or layer instanceof L.MultiPolyline
            for id, layer of inLayer._layers
              inLayers.push layer
          # create wkt string for each layer
          for layer in inLayers
            coords = []
            if layer instanceof L.Polygon or layer instanceof L.Polyline
              latlngs = layer.getLatLngs()
              i = 0
              while i < latlngs.length
                latlngs[i]
                coords.push latlngs[i].lng + ' ' + latlngs[i].lat
                if i == 0
                  lng = latlngs[i].lng
                  lat = latlngs[i].lat
                i++
              if layer instanceof L.Polygon
                wktStrings.push 'POLYGON((' + coords.join(',') + ',' + lng + ' ' + lat + '))'
              else if layer instanceof L.Polyline
                wktStrings.push 'LINESTRING(' + coords.join(',') + ')'
            else if layer instanceof L.Marker
              wktStrings.push 'POINT(' + layer.getLatLng().lng + ' ' + layer.getLatLng().lat + ')'
          wktStrings


        # credits: elrobis - thank you!
        # http://gis.stackexchange.com/questions/85229/looking-for-dissolve-algorithm-for-javascript
        # -> extended to perform cascaded union (unifies all (Multi)Polygons in array of wkt represenntations of (Multi)Polygons)
        union = (wktStrings) ->
          # Instantiate JSTS WKTReader and get two JSTS geometry objects
          wktReader = new (jsts.io.WKTReader)
          geoms = []
          geoms.push wktReader.read wkt for wkt in wktStrings

          # In JSTS, "union" is synonymous with "dissolve"
          # TODO: could be more efficient with a tree, but I really do not care about this at this point :P
          unionGeom = geoms[0]
          idx = 1 # = start at the second geometry
          while idx < geoms.length
            unionGeom = unionGeom.union geoms[idx]
            idx++

          # Instantiate JSTS WKTWriter and get new geometry's WKT
          wktWriter = new (jsts.io.WKTWriter)
          wktWriter.write unionGeom


        wkt = new Wkt.Wkt

        pure1 = [[
                  [20.0, -20.0],
                  [40.0, -20.0],
                  [40.0, -40.0],
                  [20.0, -40.0]
                ],
                [
                  [50.0, -20.0],
                  [70.0, -20.0],
                  [70.0, -40.0],
                  [50.0, -40.0]
                ]]

        pure2 = [[
                  [20.0, -20.0],
                  [40.0, -20.0],
                  [40.0, 0.0],
                  [20.0, 0.0]
                ]]

        layer1 = new L.multiPolygon pure1
        layer2 = new L.multiPolygon pure2

        wkt.fromObject layer1
        wkt1 = wkt.write()
        json1 = wkt.toJson()
        wkt.fromObject layer2
        wkt2 = wkt.write()
        json2 = wkt.toJson()

        wkts = []
        wkts.push wkt1
        wkts.push wkt2
        wktU = union wkts

        wkt.read wktU
        jsonU = wkt.toJson()

        console.log json1
        console.log json2
        console.log jsonU

        area1 = new HG.Area "test 1", json1, null
        area2 = new HG.Area "test 2", json2, null
        areaU = new HG.Area "test clip", jsonU, null

        @notifyAll "onAddArea", area1
        @notifyAll "onAddArea", area2
        @notifyAll "onAddArea", areaU





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

      @_editButton = new HG.Button @_hgInstance, 'editMode', null,
        [
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
                stepIdx:  -1            # start index -1 = no step
                steps: [
                  {
                    id:         'SEL_OLD_AREA'
                    title:      null
                    userInput:  no
                    minNum:     0
                    maxNum:     0
                    outAreas:   []
                  },
                  {
                    id:         'SET_NEW_GEOM'
                    title:      null
                    userInput:  no
                    minNum:     0
                    maxNum:     0
                    areaIdx:    0
                    inAreas:    []
                    clipAreas:  []
                    outAreas:   []
                  },
                  {
                    id:         'SET_NEW_NAME'
                    title:      null
                    userInput:  no
                    minNum:     0
                    maxNum:     0
                    areaIdx:    0
                    inAreas:    []
                    outAreas:   []
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

            @_nextStep()


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
    @_title = new HG.Title @_hgInstance, "EDIT MODE" # TODO: internationalization

  # ============================================================================
  _cleanupEditMode: () ->
    @_title.destroy()
    @_operationButtons.foreach (b) =>
      b.button.destroy()
    @_newHiventButton.destroy()
    @_editButton.deactivate()
    @_editButton.changeState 'normal'


  ## (3) STEP ###
  ## differentiate between a step
  ##  -> waiting for the users input
  ## and a transition from step i to i+1 (forward) or i-1 (backward)
  ##  -> preparing UI, doing interaction with the server
  ## each operation iterates through each step, but only for the ones where
  ## there is user input required

  # ============================================================================
  # waiting for user input in each step or automatically process information
  # => listening to other modules
  _makeStep: () ->

    ## SELECT OLD COUNTRY/-IES ##
    if @_currCO.stepIdx is 0

      ## skip step for certain operations
      if @_currCO.id is 'NEW'
        @_nextStep()

      ## user input for certain operations
      else
        @_areasOnMap.onSelectArea @, (area) =>
          @_currCO.steps[0].outAreas.push area
          # is step complete?
          if @_currCO.steps[0].outAreas.length >= @_currCO.steps[0].minNum
            @_wWindow.stepComplete()

        @_areasOnMap.onDeselectArea @, (area) =>
          @_currCO.steps[0].outAreas.splice (@_currCO.steps[0].outAreas.indexOf area), 1 # remove Area from array
          # is step incomplete?
          if @_currCO.steps[0].outAreas.length < @_currCO.steps[0].minNum
            @_wWindow.stepIncomplete()


    ## SET GEOMETRY OF NEW COUNTRY/-IES ##
    else if @_currCO.stepIdx is 1

      ## skip step for certain operations
      if @_currCO.id is 'UNI' or @_currCO.id is 'CHN' or @_currCO.id is 'DEL'
        @_nextStep()

      ## user input for certain operations
      else
        @_newGeomTool = new HG.NewGeometryTool @_hgInstance

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
        @_wWindow.stepComplete()
        # TODO: check if incomplete


    ## SET NAME OF NEW COUNTRY/-IES ##
    else if @_currCO.stepIdx is 2

      ## skip step for certain operations
      if @_currCO.id is 'CHB' or @_currCO.id is 'DEL'
        @_nextStep()

      ## user input for certain operations
      else
        # for each required area
        @_currCO.steps[2].areaIdx = 0

        @_newNameToolLoop = () =>
          # set up NewNameTool to set name and pos of area interactively
          @_newNameTool = new HG.NewNameTool @_hgInstance, [500, 200]  # TODO: real position
          @_newNameTool.onSubmit @, (name, pos) =>

            # copy area from input array, write name to it and save in output array
            idx = @_currCO.steps[2].areaIdx
            area = @_currCO.steps[2].inAreas[idx]
            area.setNames {
                'commonName': name
                'pos':        pos
              }
            area.treat()

            # update model
            @_currCO.steps[2].outAreas[idx] = area

            # update view
            @_newNameTool.destroy()
            @notifyAll 'onUpdateArea', area

            console.log @_currCO.steps[2].inAreas[idx]
            console.log @_currCO.steps[2].outAreas[idx]

            # go to next area
            @_currCO.steps[2].areaIdx++
            if @_currCO.steps[2].areaIdx < @_currCO.steps[2].maxNum
              @_newNameToolLoop()
            else # = loop completed = required areas named => step complete
              @_wWindow.stepComplete()

        @_newNameToolLoop()


    ## ADD CHANGE TO HIVENT ##
    else if @_currCO.stepIdx is 3

      ## TODO: Hivent window

      ### ACTION ###
      ## finish up
      # TODO: check if complete
      @_wWindow.operationComplete()
      # TODO: check if incomplete


  # ============================================================================
  _makeTransition: (oldStep, newStep) ->

    # 'START' -> 'SEL_OLD_AREA'
    if oldStep is -1 and newStep is 0
      console.log "'START' -> 'SEL_OLD_AREA'"

      ## send info to server

      ## get info from server

      ## treat special cases

      ## cleanup UI
      # nothing to do, because it is the first step

      ## setup UI
      # = setup operation
      # disable all buttons
      @_editButton.disable()
      @_newHiventButton.disable()
      @_operationButtons.foreach (obj) =>
        obj.button.disable()

      # highlight button of current operation
      (@_operationButtons.getById @_currCO.id).button.activate()

      # setup workflow window (in the space of the title)
      @_title.clear()
      @_wWindow = new HG.WorkflowWindow @_hgInstance, @_currCO
      @_wWindow.stepIncomplete()

      # listen to click on buttons in workflow window
      @_hgInstance.buttons.wwNext.onNext @, () => @_nextStep()
      @_hgInstance.buttons.wwBack.onBack @, () => @_prevStep()

      @_hgInstance.buttons.wwAbort.onAbort @, () =>
        # abort = back to the very beginning
        currStep = @_currCO.stepIdx
        while currStep > -1
          @_makeTransition currStep, currStep-1
          currStep--

      @_hgInstance.buttons.wwNext.onFinish @, () =>
        console.log "HEUREKA"

      # tell AreasOnMap to start selecting [minNum .. maxNum] of areas
      @notifyAll 'onStartAreaSelection', @_currCO.steps[0].maxNum


    # 'START' <- 'SEL_OLD_AREA'
    else if oldStep is 0 and newStep is -1
      console.log "'START' <- 'SEL_OLD_AREA'"

      ## send info to server

      ## get info from server

      ## treat special cases
      # unless @_currCO.id is 'NEW'

      ## cleanup UI
      # = cleanup operation
      @_wWindow.destroy()
      @_title.set "EDIT MODE"   # TODO: internationalization
      (@_operationButtons.getById @_currCO.id).button.deactivate()
      @_newHiventButton.enable()
      @_operationButtons.foreach (obj) =>
        obj.button.enable()
      @_editButton.enable()

      ## setup UI
      # nothing to set up, because it is abort


    # 'SEL_OLD_AREA' -> 'SET_NEW_GEOM'
    else if oldStep is 0 and newStep is 1
      console.log "'SEL_OLD_AREA' -> 'SET_NEW_GEOM'"

      ## knowledge transfer
      @_currCO.steps[newStep].inAreas = @_currCO.steps[oldStep].outAreas

      ## send info to server

      ## get info from server

      ## cleanup UI
      @notifyAll 'onFinishAreaSelection'

      ## treat special cases
      if @_currCO.id is 'UNI'   # unify old areas

        # delete all old areas
        for area in @_currCO.steps[1].inAreas
          @notifyAll 'onRemoveArea', area

        # TODO: unify @_currCO.steps[0].outAreas

        ########################################################################

        # @_currCO.steps[1].outAreas[0] = new HG.Area 'Horst', geomOut, null



        # @notifyAll 'onAddArea', @_currCO.steps[1].outAreas[0]

      else if @_currCO.id is 'DEL'   # delete old area
        @notifyAll 'onRemoveArea', @_currCO.steps[0].oldAreas[0]

      else if @_currCO.id is 'CHN'
        console.log "do nothing ;)"

      ## setup UI
      else
        @_wWindow.stepIncomplete()
        @notifyAll 'onStartGeometrySetting'


    # 'SEL_OLD_AREA' <- 'SET_NEW_GEOM'
    else if oldStep is 1 and newStep is 0
      console.log "'SEL_OLD_AREA' <- 'SET_NEW_GEOM'"

      ## send info to server

      ## get info from server

      ## treat special cases

      ## cleanup UI

      ## setup UI
      # @notifyAll 'onStartAreaSelection', @_currCO.steps[0].maxNum


    # 'SET_NEW_GEOM' -> 'SET_NEW_NAME'
    else if oldStep is 1 and newStep is 2
      console.log "'SET_NEW_GEOM' -> 'SET_NEW_NAME'"

      ## knowledge transfer
      @_currCO.steps[newStep].inAreas = @_currCO.steps[oldStep].outAreas

      ## send info to server

      ## get info from server

      ## cleanup UI
      @notifyAll 'onFinishGeometrySetting'

      ## treat special cases
      unless @_currCO.id is 'CHB' or @_currCO.id is 'DEL'

      ## setup UI
        @_wWindow.stepIncomplete()
        @notifyAll 'onStartNameSetting'


    # 'SET_NEW_GEOM' <- 'SET_NEW_NAME'
    else if oldStep is 2 and newStep is 1
      console.log "'SET_NEW_GEOM' <- 'SET_NEW_NAME'"

      ## send info to server

      ## get info from server

      ## treat special cases

      ## cleanup UI

      ## setup UI


    # 'SET_NEW_NAME' -> 'ADD_CHNG'
    else if oldStep is 2 and newStep is 3
      console.log "'SET_NEW_NAME' -> 'ADD_CHNG'"

      ## send info to server

      ## get info from server

      ## cleanup UI
      @notifyAll 'onFinishNameSetting'

      ## treat special cases
      # no special cases, because each operation ends with adding the change to an hivent

      ## setup UI
      console.log 'add change to an hivent'


    # 'SET_NEW_NAME' <- 'ADD_CHNG'
    else if oldStep is 3 and newStep is 2
      console.log "'SET_NEW_NAME' <- 'ADD_CHNG'"

      ## send info to server

      ## get info from server

      ## treat special cases

      ## cleanup UI

      ## setup UI


    @_makeStep()


  # ============================================================================
  _nextStep: () ->
    @_currCO.stepIdx++
    @_makeTransition @_currCO.stepIdx-1, @_currCO.stepIdx
  _prevStep: () ->
    @_currCO.stepIdx--
    @_makeTransition @_currCO.stepIdx+1, @_currCO.stepIdx

  # ============================================================================
  # possible inputs:  1   1+  2   2+
  MAX_NUM = 25
  _getRequiredNum: (expr) ->
    return 0 if not expr?
    lastChar = expr.substr(expr.length-1)
    max = if lastChar is '+' then MAX_NUM else lastChar
    min = (expr.substring 0,1)
    [parseInt(min), parseInt(max)]
