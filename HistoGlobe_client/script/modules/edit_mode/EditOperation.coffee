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

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onFinish"

    # get dependend classes

    ### SETUP CONFIG ###
    @_operation =
      {
        id:         operationConfig.id
        title:      operationConfig.title
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
            clipAreas:        []
            inData:           {}
            outData: {
              createdAreas:   []
            }
          },
          { # idx             2
            id:               'SET_NEW_NAME'
            title:            null
            userInput:        no
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
    @_workflowWindow = new HG.WorkflowWindow @_hgInstance, @_operation

    # listen to input from workflow window buttons
    @_hgInstance.buttons.nextOperationStep.onNext @, () =>
      @_step.finish()

    @_hgInstance.buttons.nextOperationStep.onFinish @, () =>
      # TODO: what to do?

    @_hgInstance.buttons.lastOperationStep.onBack @, () =>
      # backwards logic to be done in a different way
      # really cool idea: actionList (just revert the action later)

    # listen to abort button
    @_hgInstance.buttons.abortOperation.onAbort @, () =>
      # abort = back to the very beginning
      while @_operation.idx > -1
        @_makeStep -1, yes  # yes = abort = skip all user input steps


    ### LET'S GO ###
    @_makeStep 1



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  #
  _makeStep: (direction, aborted=no) ->

    # create bool variable: 'step forward? yes / no?'
    isForward = direction is 1

    # get old and new step
    oldStep = @_operation.steps[@_operation.idx]
    newStep = @_operation.steps[@_operation.idx+direction]

    # step forward
    # outgoing data of previous (old) step is incoming data for next (new) step
    if isForward
      newStep.inData = oldStep.outData unless @_operation.idx is -1

    # step backward
    # incoming data of next (old) step is outgoing data for previous (new) step
    else # not isForward = backward
      newStep.outData = oldStep.inData

    # setup new step
    @_operation.idx += direction
    if @_operation.idx is 0
      @_step = new HG.SelectOldAreasStep @_hgInstance, newStep, isForward
    else if @_operation.idx is 1
      @_step = new HG.CreateNewGeometryStep @_hgInstance, newStep, isForward
    else if @_operation.idx is 2
      @_step = new HG.CreateNewNameStep @_hgInstance, newStep, isForward
    else if @_operation.idx is 3
      @_step = new HG.AddChangeStep @_hgInstance, newStep, isForward

    # change workflow window
    if newStep.userInput
      @_workflowWindow.makeTransition direction
      if isForward
        @_workflowWindow.stepIncomplete()
      else
        @_workflowWindow.stepComplete()

    # collect data if step is complete
    if newStep.userInput
      @_step.onFinish @, (stepData) ->
        newStep = stepData
        @_makeStep 1

    # go to next step if no input required
    else
      @_makeStep direction

  # ============================================================================
  _finish: () ->
    @_workflowWindow.destroy()

    # TODO: convert action list to new data to be stored in the database

    @notifyAll 'onFinish'


  # ============================================================================
  # possible inputs:  1   1+  2   2+
  _getRequiredNum: (expr) ->
    return 0 if not expr?
    lastChar = expr.substr(expr.length-1)
    max = if lastChar is '+' then MAX_NUM else lastChar
    min = (expr.substring 0,1)
    return {
      'min': parseInt(min)
      'max': parseInt(max)
    }

  MAX_NUM = 50  # arbitrary number that limits excessive area selection