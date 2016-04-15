window.HG ?= {}

SAVE_TO_DB = no

# ==============================================================================
# control the workflow of a complete operation
# manage operation window (init, send data, get data)
# handle communication with backend (get data, send data)
# ==============================================================================

class HG.EditOperation

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # setup the whole operation
  # ============================================================================

  constructor: (@_hgInstance, operationConfig) ->
    # add module to HG Instance
    @_hgInstance.editOperation = @

    # error handling
    if not @_hgInstance.map.getMap()?
      console.error "Unable to load Edit Mode: There is no map, you idiot! Why would you want to have HistoGlobe without a map ?!?"

    if not @_hgInstance.areaController?
      console.error "Unable to load Edit Mode: AreaController module is not included in the current hg instance (has to be loaded before EditMode)"

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onStepComplete'
    @addCallback 'onStepIncomplete'
    @addCallback 'onStepTransition'
    @addCallback 'onOperationComplete'
    @addCallback 'onOperationIncomplete'
    @addCallback 'onFinish'

    # includes
    @_databaseInterface = new HG.DatabaseInterface

    ### SETUP OPERATION DATA CONFIG ###
    # public -> will be changed by OperationSteps directly

    @operation =
      {
        id:                 operationConfig.id
        title:              operationConfig.title
        verb:               operationConfig.verb
        historicalChange:   new HG.HistoricalChange {operation: operationConfig.id}
        idx:                0    # = step index -> 0 = start
        steps: [
          { # idx             0
            id:               'START'
          }
          { # idx             1
            id:               'SEL_OLD_AREA'
            title:            null
            userInput:        no
            number:           {}
          },
          { # idx             2
            id:               'SET_NEW_TERR'
            title:            null
            userInput:        no
            number:           {}
            tempAreas:        []
          },
          { # idx             3
            id:               'SET_NEW_NAME'
            title:            null
            userInput:        no
            number:           {}
            tempAreas:        []
          },
          { # idx             4
            id:               'ADD_CHNG'
            title:            "add change <br /> to historical event"
            userInput:        yes
          }
        ]
      }

    # fill up default information with information of loaded change operation
    for stepConfig in operationConfig.steps
      for stepData in @operation.steps
        if stepData.id is stepConfig.id
          stepData.title = stepConfig.title
          stepData.userInput = yes
          stepData.number = (@_getRequiredNum stepConfig.num) if stepData.number
          break

    # current step the user is in
    @_step = null


    ### SETUP UI ###
    new HG.WorkflowWindow @_hgInstance, @operation


    ### UNDO FUNCTIONALITY ###
    # global, it executed action from UndoManager
    @undoManager = new UndoManager

    # undo button
    @_hgInstance.buttons.undoStep.onClick @, () =>
      @undoManager.undo()

    # abort button
    @_hgInstance.buttons.abortOperation.onAbort @, () =>
      @undoManager.undo() while @undoManager.hasUndo()

    ### LET'S GO ###
    new HG.EditOperationStep @_hgInstance, 1

    @undoManager.add {
      undo: => @abort()
    }


  # ============================================================================
  # finish up the whole operation, send new data to server and update model
  # on the client with the reponse data from the server
  # ============================================================================

  finish: () ->
    # TODO: convert action list to new data to be stored in the database

    oldAreas = @operation.steps[0].outData.selectedAreas
    newAreas = @operation.steps[2].outData.namedAreas
    hivent =   @operation.steps[3].outData.hiventInfo

    request = {
      hivent:       hivent
      change: {
        operation:  @operation.id
        old_areas:  oldAreas
        new_areas:  []
      }
    }

    for area in newAreas
      newArea = @_hgInstance.areaController.getArea area
      request.change.new_areas.push @_databaseInterface.convertToServerModel newArea

    # save hivent + changes + new areas to server
    if SAVE_TO_DB
      $.ajax
        url:  'saveoperation/'
        type: 'POST'
        data: JSON.stringify request

        # success callback: add id to hivent and save it in hivent controller
        success: (response) =>
          data = $.parseJSON response

          # get old areas
          oldAreas = []
          for areaId in data.old_areas
            oldAreas.push @_hgInstance.areaController.getArea areaId

          # get and update new areas
          newAreas = []
          for areaData in data.new_areas
            area = @_hgInstance.areaController.getArea areaData.old_id
            area.setId areaData.new_id
            newAreas.push area

          # save hivent (call in the name of EditMode)
          @_hgInstance.editMode.notifyAll 'onCreateHivent', data.hivent, oldAreas, newAreas

          # TODO: update dates ?!? what ?

        # error callback: print error
        error: (xhr, errmsg, err) =>
          console.log xhr
          console.log errmsg, err
          console.log xhr.responseText


    @notifyAll 'onFinish'


  # ============================================================================
  # break up the whole operation
  # ============================================================================

  abort: () ->
    @notifyAll 'onFinish'



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # get minimum / maximum number of areas required for each step
  # possible inputs:  1   1+  2   2+
  # ============================================================================

  _getRequiredNum: (expr) ->
    return 0 if not expr?
    lastChar = expr.substr(expr.length-1)
    max = if lastChar is '+' then HGConfig.max_area_selection.val else lastChar
    min = (expr.substring 0,1)
    return {
      'min': parseInt(min)
      'max': parseInt(max)
    }