window.HG ?= {}

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

    @addCallback 'onFinish'

    @addCallback 'onStepComplete'
    @addCallback 'onStepIncomplete'
    @addCallback 'onStepTransition'
    @addCallback 'onOperationComplete'
    @addCallback 'onOperationIncomplete'

    # make all actions reversible
    # -> array for undo managers for each step
    @_undoManagers = [null, null, null, null]
    @_fullyAborted = no


    ### SETUP CONFIG ###
    @_operation =
      {
        id:         operationConfig.id
        title:      operationConfig.title
        verb:       operationConfig.verb
        idx:        -1          # = step index -> -1 = start in the beginning
        steps: [
          { # idx             0
            id:               'SEL_OLD_AREA'
            title:            null
            userInput:        no
            number:           {}
            inData:           {}
            outData: {
              selectedAreas:  []
            }
          },
          { # idx             1
            id:               'SET_NEW_GEOM'
            title:            null
            userInput:        no
            number:           {}
            operationCommand: operationConfig.id
            tempAreas:        []
            inData:           {}
            outData: {
              createdAreas:   []
            }
          },
          { # idx             2
            id:               'SET_NEW_NAME'
            title:            null
            userInput:        no
            tempAreas:        []
            inData:           {}
            outData: {
              namedAreas:     []
            }
          },
          { # idx             3
            id:               'ADD_CHNG'
            title:            "add change <br /> to historical event"
            userInput:        yes
            inData:           {}
            outData: {
              hiventInfo:     {}
            }
          },
        ]
      }
    @_step = null

    # fill up default information with information of loaded change operation
    for stepConfig in operationConfig.steps
      for stepData in @_operation.steps
        if stepData.id is stepConfig.id
          stepData.title = stepConfig.title
          stepData.userInput = yes
          if stepData.number
            stepData.number = @_getRequiredNum stepConfig.num
          break


    ### SETUP UI ###
    new HG.WorkflowWindow @_hgInstance, @_operation

    # next step button
    @_hgInstance.buttons.nextStep.onNext @, () =>
      @_step.finish()

    # finish button
    @_hgInstance.buttons.nextStep.onFinish @, () =>
      @_step.finish()

    # undo button
    @_hgInstance.buttons.undoStep.onClick @, () =>
      @_undo()

    # abort button
    @_hgInstance.buttons.abortOperation.onAbort @, () =>
      @_undo() while not @_fullyAborted

    ### LET'S GO ###
    @_makeStep 1


  # ============================================================================
  ## handle undo

  # ----------------------------------------------------------------------------
  # listen to own callback, notified from operation step
  # @.onAddUndo @, (action) ->
    # @_undoManager.add action

  # ----------------------------------------------------------------------------
  addUndoManager: (undoManager) ->
    @_undoManagers[@_operation.idx] = undoManager

  # ----------------------------------------------------------------------------
  getUndoManager: () ->
    @_undoManagers[@_operation.idx]

  # ----------------------------------------------------------------------------
  # perform current undo action
  _undo: () ->

    # if current step has reversible actions
    # => undo it
    if @_undoManagers[@_operation.idx].hasUndo()
      @_undoManagers[@_operation.idx].undo()

    # else current step has no reversible actions
    # => destroy the step and go one step back
    else
      @_step.abort()



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _makeStep: (direction) ->

    # error handling: last step -> forward    => finish
    #                 first step -> backward  => abort
    return @_finish() if (@_operation.idx is 3) and (direction is 1)
    return @_abort()  if (@_operation.idx is 0) and (direction is -1)

    # 'step forward? yes / no?'
    isForward = direction is 1

    # get old and new step
    oldStep = @_operation.steps[@_operation.idx]
    newStep = @_operation.steps[@_operation.idx+direction]

    # step forward
    # outgoing data of previous (old) step is incoming data for next (new) step
    if isForward
      newStep.inData = @_deepCopy oldStep.outData unless @_operation.idx is -1

    # step backward
    # incoming data of next (old) step is outgoing data for previous (new) step
    else # not isForward = backward
      newStep.outData = @_deepCopy oldStep.inData

    # change workflow window
    if newStep.userInput
      @notifyAll 'onStepTransition', direction
      @notifyAll 'onStepIncomplete'

    # setup new step
    @_operation.idx += direction
    if @_operation.idx is 0
      @_step = new HG.EditOperationStep.SelectOldAreas    @_hgInstance, newStep, isForward
    else if @_operation.idx is 1
      @_step = new HG.EditOperationStep.CreateNewGeometry @_hgInstance, newStep, isForward
    else if @_operation.idx is 2
      @_step = new HG.EditOperationStep.CreateNewName     @_hgInstance, newStep, isForward
    else if @_operation.idx is 3
      @_step = new HG.EditOperationStep.AddChange         @_hgInstance, newStep, isForward

    # collect data if step is complete
    if newStep.userInput
      @_step.onFinish @, (stepData) ->
        newStep = stepData
        @_makeStep 1
      @_step.onAbort @, () ->
        @_makeStep -1

    # go to next step if no input required
    else
      @_makeStep direction

  # ============================================================================
  _finish: () ->
    # TODO: convert action list to new data to be stored in the database

    output = {
      hivent:       @_operation.steps[3].outData.hiventInfo
      change: {
        operation:  @_operation.id
        old_areas:  @_operation.steps[0].outData.selectedAreas
        new_areas:  []
      }
    }

    for area in @_operation.steps[2].outData.namedAreas
      newArea = @_hgInstance.areaController.getArea area
      output.change.new_areas.push {
        id:         newArea.getId()
        name:       newArea.getName()
        geometry:   newArea.getGeometry().wkt()
        repr_point: newArea.getRepresentativePoint().wkt()
      }

    console.log "SAVE TO SERVER:", output

    # TODO: update with reasonable id from server

    @notifyAll 'onFinish'

  # ----------------------------------------------------------------------------
  _abort: () ->
    @_fullyAborted = yes
    @notifyAll 'onFinish'

  # ============================================================================
  # possible inputs:  1   1+  2   2+
  _getRequiredNum: (expr) ->
    return 0 if not expr?
    lastChar = expr.substr(expr.length-1)
    max = if lastChar is '+' then HGConfig.max_area_selection.val else lastChar
    min = (expr.substring 0,1)
    return {
      'min': parseInt(min)
      'max': parseInt(max)
    }


  # ============================================================================
  # possible inputs:  1   1+  2   2+
  _getOperationDescription: () ->
    command = @_operation.verb
    oldAreas = []
    oldAreas.push id for id in @_operation.steps[0].outData.selectedAreas
    newAreas = []
    newAreas.push id for id in @_operation.steps[2].outData.namedAreas
    return command + " " + oldAreas.join(", ") + " to " + newAreas.join(", ")


  # ============================================================================
  # copy each property from one object to the nect object
  _deepCopy: (origObj) ->
    return JSON.parse(JSON.stringify(origObj))
    # for prop, val of origObj
    #   destObj[prop] = val
