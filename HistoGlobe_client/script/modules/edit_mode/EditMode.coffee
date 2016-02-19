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
    @addCallback 'onStartAreaEdit'
    @addCallback 'onFinishAreaEdit'

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

    # for using the geooperator internally here
    @_geop = new HG.GeoOperator

    # problem: Edit Mode should listen to each listener only once
    # ugly solution: globally save to which callbacks it has already been added to
    # and prevent from adding more than once
    @_activeCallbacks = {}     # content: { 'nameOfCallback': yes/no}


    if TEST_BUTTON
      testButton = new HG.Button @_hgInstance, 'test', null, [{'iconFA': 'question','callback': 'onClick'}]
      $(testButton.getDom()).css 'position', 'absolute'
      $(testButton.getDom()).css 'bottom', '0'
      $(testButton.getDom()).css 'right', '0'
      $(testButton.getDom()).css 'z-index', 100
      @_hgInstance._top_area.appendChild testButton.getDom()
      @_testButton = @_hgInstance.buttons.test
      @_testButton.onClick @, () =>

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
                  [19.0, -21.0],
                  [39.0, -21.0],
                  [39.0, -1.0],
                  [19.0, -1.0]
                ]]

        jsons = []
        jsons.push new L.multiPolygon pure1
        jsons.push new L.multiPolygon pure2
        jsonU = @_geop.union jsons
        areaU = new HG.Area "test clip", jsonU, null
        console.log areaU
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

            @_co =
              {
                id:         inCO.id
                title:      inCO.title
                idx:        -1          # = step index -> -1 = start in the beginning
                initArea:   null
                selAreas:   []
                geomAreas:  []
                nameAreas:  []
                steps: [
                  {
                    id:         'SEL_OLD_AREA'
                    title:      null
                    userInput:  no
                    minNum:     0
                    maxNum:     0
                  },
                  {
                    id:         'SET_NEW_GEOM'
                    title:      null
                    userInput:  no
                    minNum:     0
                    maxNum:     0
                    areaIdx:    0
                    clipAreas:  []
                  },
                  {
                    id:         'SET_NEW_NAME'
                    title:      null
                    userInput:  no
                    minNum:     0
                    maxNum:     0
                    areaIdx:    0
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
              for defStep in @_co.steps
                if defStep.id is inStep.id
                  defStep.userInput = yes
                  defStep.title = inStep.title
                  num = @_getRequiredNum inStep.num
                  defStep.minNum = num[0]
                  defStep.maxNum = num[1]
                  break

            # go one step forward
            @_makeTransition 1


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



  ## DEBUG
  # as = []
  # as.push a.getNames().commonName for a in @_co.selAreas
  # console.log "stepId ) ", as

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
  _makeStep: (dir) ->

    #---------------------------------------------------------------------------
    # SELECT OLD COUNTRY/-IES #
    if @_co.idx is 0

      ## skip step for certain operations
      if @_co.id is 'ADD'
        @_makeTransition dir

      ## wait for user input in other operations
      else

        # problem: listens to callback multiple times if function is called multiple times
        # solution: ensure listen to callback only once
        if not @_activeCallbacks.onSelectArea
          @_areasOnMap.onSelectArea @, (area) =>
            if @_co.selAreas.indexOf area is -1
              @_co.selAreas.push area

            # is step complete?
            if @_co.selAreas.length >= @_co.steps[0].minNum
              @_wWindow.stepComplete()

          # add to active callback list
          @_activeCallbacks.onSelectArea = yes

        if not @_activeCallbacks.onDeselectArea
          @_areasOnMap.onDeselectArea @, (area) =>
            if @_co.selAreas.indexOf area isnt -1
              @_co.selAreas.splice (@_co.selAreas.indexOf area), 1 # remove Area from array

            # is step incomplete?
            if @_co.selAreas.length < @_co.steps[0].minNum
              @_wWindow.stepIncomplete()

          # add to active callback list
          @_activeCallbacks.onDeselectArea = yes


    #---------------------------------------------------------------------------
    # SET GEOMETRY OF NEW COUNTRY/-IES #
    else if @_co.idx is 1

      ## skip step for certain operations
      if @_co.id is 'UNI' or @_co.id is 'CHN' or @_co.id is 'DEL'
        @_makeTransition dir

      ## wait for user input in other operations
      else
        # for each required area
        @_newGeomToolLoop = () =>

          # set up NewGeometryTool to define geometry of an area interactively
          @_newGeomTool = new HG.NewGeometryTool @_hgInstance

          @_newGeomTool.onSubmit @, (geom) =>
            # check data
            if no
              # send back to tool and redo
            else
              # cleanup
              @_newGeomTool.destroy()
              delete @_newGeomTool

              # save data
              newArea = new HG.Area "Test", geom
              @_co.geomAreas.push newArea
              @notifyAll 'onAddArea', newArea

              # go to next area
              @_co.steps[1].areaIdx++
              if @_co.steps[1].areaIdx < @_co.steps[1].maxNum
                @_newGeomToolLoop()
              # if required areas named => loop complete => step complete => next
              else
                @_makeTransition 1

        @_newGeomToolLoop()

    #---------------------------------------------------------------------------
    # SET NAME OF NEW COUNTRY/-IES #
    else if @_co.idx is 2

      ## skip step for certain operations
      if @_co.id is 'CHB' or @_co.id is 'DEL'
        @_makeTransition dir

      ## wait for user input in other operations
      else
        # for each required area
        @_newNameToolLoop = () =>

          # get current area
          currArea = @_co.geomAreas[@_co.steps[2].areaIdx]

          # set up NewNameTool to set name and pos of area interactively
          @_newNameTool = new HG.NewNameTool @_hgInstance, currArea.getCenter()
          @_newNameTool.onSubmit @, (name, pos) =>

            # save the named area
            currArea = @_co.geomAreas[@_co.steps[2].areaIdx]
            currArea.setNames {'commonName': name}
            currArea.setCenter pos
            currArea.treat()
            @_co.nameAreas[@_co.steps[2].areaIdx] = currArea          # Model
            @notifyAll 'onUpdateArea', currArea                       # View

            # cleanup
            @_newNameTool.destroy()
            delete @_newNameTool

            # go to next area
            @_co.steps[2].areaIdx++
            if @_co.steps[2].areaIdx < @_co.steps[2].maxNum
              @_newNameToolLoop()
            # if required areas named => loop complete => step complete => next
            else
              @_makeTransition 1

        @_newNameToolLoop()


    #---------------------------------------------------------------------------
    # ADD CHANGE TO HIVENT #
    else if @_co.idx is 3

      ## TODO: Hivent window

      ### ACTION ###
      ## finish up
      @_wWindow.stepComplete()
      # TODO: check if complete
      # TODO: check if incomplete


  # ============================================================================
  _makeTransition: (dir, aborted=no) ->

    #---------------------------------------------------------------------------
    # 'START' -> 'SEL_OLD_AREA'                                             DONE
    if @_co.idx is -1 and dir is 1
      console.log "'START' -> 'SEL_OLD_AREA'"

      ## setup operation management for each operation
      # disable all buttons
      @_editButton.disable()
      @_newHiventButton.disable()
      @_operationButtons.foreach (obj) =>
        obj.button.disable()

      # highlight button of current operation
      (@_operationButtons.getById @_co.id).button.activate()

      # setup workflow window (in the space of the title)
      @_title.clear()
      @_wWindow = new HG.WorkflowWindow @_hgInstance, @_co
      @_wWindow.stepIncomplete()

      # listen to click on buttons in workflow window
      @_hgInstance.buttons.wwNext.onNext @, () => @_makeTransition 1
      @_hgInstance.buttons.wwBack.onBack @, () => @_makeTransition -1

      @_hgInstance.buttons.wwAbort.onAbort @, () =>
        # abort = back to the very beginning
        while @_co.idx > -1
          @_makeTransition -1, yes  # yes = abort = skip all user input steps

      @_hgInstance.buttons.wwNext.onFinish @, () =>
        # TODO: better design
        console.log "HEUREKA"
        @_wWindow.destroy()
        @_title.set "EDIT MODE"   # TODO: internationalization
        (@_operationButtons.getById @_co.id).button.deactivate()
        @_newHiventButton.enable()
        @_operationButtons.foreach (obj) =>
          obj.button.enable()
        @_editButton.enable()



      ## setup selection step for all active operations
      if @_co.id isnt 'ADD'

        # tell AreasOnMap to start selecting [minNum .. maxNum] of areas
        @notifyAll 'onStartAreaSelection', @_co.steps[0].maxNum

        # add already selected areas to list
        if @_areasOnMap.getSelectedAreas()[0]
          @_co.initArea = @_areasOnMap.getSelectedAreas()[0]
          @_co.selAreas.push @_co.initArea

        @_wWindow.makeTransition dir
        @_wWindow.stepIncomplete()



    #---------------------------------------------------------------------------
    # 'START' <- 'SEL_OLD_AREA'                                             DONE
    else if @_co.idx is 0 and dir is -1
      console.log "'START' <- 'SEL_OLD_AREA'"

      ## cleanup area selection (except for initially selected area)
      if @_co.id isnt 'ADD'
        for area in @_co.selAreas
          area.deselect()
          if @_co.initArea and @_co.initArea.getId() is area.getId()
            area.select()
          @notifyAll 'onUpdateArea', area
        @notifyAll 'onFinishAreaSelection'
        @_wWindow.makeTransition -1

      ## cleanup everything from each operation
      @_title.set "EDIT MODE"   # TODO: internationalization
      (@_operationButtons.getById @_co.id).button.deactivate()
      @_newHiventButton.enable()
      @_operationButtons.foreach (obj) =>
        obj.button.enable()
      @_editButton.enable()


    #---------------------------------------------------------------------------
    # 'SEL_OLD_AREA' -> 'SET_NEW_GEOM'                               ALMOST DONE
    else if @_co.idx is 0 and dir is 1
      console.log "'SEL_OLD_AREA' -> 'SET_NEW_GEOM'"

      ## setup for active operations
      if @_co.id isnt 'UNI' and @_co.id isnt 'CHN' and @_co.id isnt 'DEL'
        @notifyAll 'onFinishAreaSelection'
        @notifyAll 'onStartAreaEdit'
        @_wWindow.makeTransition dir
        @_wWindow.stepIncomplete()


    #---------------------------------------------------------------------------
    # 'SEL_OLD_AREA' <- 'SET_NEW_GEOM'                                      DONE
    else if @_co.idx is 1 and dir is -1
      console.log "'SEL_OLD_AREA' <- 'SET_NEW_GEOM'"

      # cleanup geometry tool if it was there
      if @_newGeomTool?
        @_newGeomTool.destroy()
        delete @_newGeomTool


      ## setup for active operations
      if @_co.id isnt 'UNI' and @_co.id isnt 'CHN' and @_co.id isnt 'DEL'
        @notifyAll 'onFinishAreaEdit'
        @notifyAll 'onStartAreaSelection', @_co.steps[0].maxNum
        @_wWindow.makeTransition dir
        @_wWindow.stepComplete()


    #---------------------------------------------------------------------------
    # 'SET_NEW_GEOM' -> 'SET_NEW_NAME'                                      TODO
    else if @_co.idx is 1 and dir is 1
      console.log "'SET_NEW_GEOM' -> 'SET_NEW_NAME'"

      # cleanup geometry tool if it was there
      if @_newGeomTool?
        @_newGeomTool.destroy()
        delete @_newGeomTool

      ## background processing for passive operations
      if @_co.id is 'UNI'               # unify selected areas
        @notifyAll 'onFinishAreaSelection'
        @notifyAll 'onStartAreaEdit'
        # delete all selected areas
        oldAreas = []
        for area in @_co.selAreas
          oldAreas.push area.geomLayer
          @notifyAll 'onRemoveArea', area
        # unify old areas to new area
        uniArea = @_geop.union oldAreas
        newArea = new HG.Area "test clip", uniArea
        newArea.select()
        newArea.treat()   # TODO: correct?
        @_co.geomAreas.push newArea
        @notifyAll "onAddArea", newArea

      else if @_co.id is 'DEL'          # remove selected area
        @notifyAll 'onFinishAreaSelection'
        @notifyAll 'onStartAreaEdit'
        @notifyAll 'onRemoveArea', @_co.selAreas[0]

      ## setup for active operations
      if @_co.id isnt 'CHB' and @_co.id isnt 'DEL'
        @_co.steps[2].areaIdx = 0
        @_wWindow.makeTransition dir
        @_wWindow.stepIncomplete()


    #---------------------------------------------------------------------------
    # 'SET_NEW_GEOM' <- 'SET_NEW_NAME'                                      TODO
    else if @_co.idx is 2 and dir is -1
      console.log "'SET_NEW_GEOM' <- 'SET_NEW_NAME'"

      # cleanup name tool if it was there
      @_newNameTool?.destroy()

      ## background processing for passive operations: restore areas
      # TODO: edit last area
      if @_co.id is 'ADD'               # remove selected area
        @notifyAll 'onRemoveArea', @_co.geomAreas[0]
        @_co.geomAreas = []

      else if @_co.id is 'UNI'          # restore selected areas
        @notifyAll 'onFinishAreaEdit'
        @notifyAll 'onStartAreaSelection', @_co.steps[0].maxNum
        # delete new unified
        @notifyAll "onRemoveArea", @_co.geomAreas[0]
        @_co.geomAreas = []
        # TODO: delete the area? will it stay in the memory?
        # re-add all previously selected areas
        for area in @_co.selAreas
          @notifyAll 'onAddArea', area

      else if @_co.id is 'DEL'          # restore selected area
        @notifyAll 'onFinishAreaEdit'
        @notifyAll 'onStartAreaSelection'
        @notifyAll 'onAddArea', @_co.selAreas[0]

      ## setup for active operations
      if @_co.id isnt 'CHB' and @_co.id isnt 'DEL'
        @_wWindow.makeTransition dir
        @_wWindow.stepComplete()


    #---------------------------------------------------------------------------
    # 'SET_NEW_NAME' -> 'ADD_CHNG'                                          TODO
    else if @_co.idx is 2 and dir is 1
      console.log "'SET_NEW_NAME' -> 'ADD_CHNG'"

      @notifyAll 'onFinishAreaEdit'

      # cleanup name tool if it was there
      @_newNameTool?.destroy()

      ## setup for each operations (all are active in this step)
      @_wWindow.setupOkButton()
      @_wWindow.stepIncomplete()
      @_wWindow.makeTransition dir


    #---------------------------------------------------------------------------
    # 'SET_NEW_NAME' <- 'ADD_CHNG'                                          TODO
    else if @_co.idx is 3 and dir is -1
      console.log "'SET_NEW_NAME' <- 'ADD_CHNG'"

      ## restore areas without names
      # TODO: really hacky... isn't there a nicer way to do that?
      if @_co.id isnt 'CHB' and @_co.id isnt 'DEL'
        for area in @_co.nameAreas
          # delete the name
          area.setNames {}
          # update
          @notifyAll 'onUpdateArea', area     # View
        @_co.steps[2].areaIdx = 0
        @_co.nameAreas = []


      ## setup for each operations (all are active in this step)
      @_wWindow.makeTransition dir
      @_wWindow.cleanupOkButton()



    #---------------------------------------------------------------------------
    @_co.idx += dir
    @_makeStep dir unless aborted
    # new step = either next (dir = +1) or previous (dir = -1)
    # only do it if operation is not aborted

  # ============================================================================
  # possible inputs:  1   1+  2   2+
  MAX_NUM = 25
  _getRequiredNum: (expr) ->
    return 0 if not expr?
    lastChar = expr.substr(expr.length-1)
    max = if lastChar is '+' then MAX_NUM else lastChar
    min = (expr.substring 0,1)
    [parseInt(min), parseInt(max)]