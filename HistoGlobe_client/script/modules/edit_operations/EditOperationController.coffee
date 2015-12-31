window.HG ?= {}

# ==============================================================================
# EditOperationController has several controlling tasks:
#   register clicks on edit operation buttons -> init operation
#   manage operation window (init, send data, get data)
#   handle communication with backend (get data, send data)
# ==============================================================================
class HG.EditOperationController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (operations) ->

    # init variables
    @_operations = operations       # all possible operation
    @_curr = {                      # object storing current state of workflow
      op          : null            # object of current operation
      stepNumTot  : null            # total number of steps of current operation
      stepNum     : null            # number of current step in workflow [starting at 1!]
      step        : null            # object of current step in workflow
    }

    # init callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "möööp"


  # ============================================================================
  hgInit: (hgInstance) ->

    @_hgInstance = hgInstance
    @_hgInstance.edit_operation_controller = @

    # listen to click on edit operation buttons => start operation
    @_hgInstance.operation_buttons.onStartEditOperation @, (operationId) =>

      # get operation [json object]
      operation = $.grep @_operations, (op) ->
        op.id == operationId
      @_curr.op = operation[0]

      # setup operation window
      @_opWindow.destroy() if @_opWindow? # cleanup before
      @_opWindow = new HG.EditOperationWindow @_hgInstance, @_hgInstance._config.container, @_curr.op

      # update information about current state in workflow
      @_curr.stepNumTot = @_curr.op.steps.length
      @_curr.stepNum = 1
      @_curr.step = @_curr.op.steps[@_curr.stepNum-1]

      # disable back button
      # @_opWindow.disableNext()
      @_opWindow.disableBack()
      if @_curr.stepNum is @_curr.stepNumTot
        @_opWindow.enableFinish()    # in case operation has only one step


      # listen to click on previous step button
      @_hgInstance.buttons.backButton.onPrevStep @, () =>

        # update information
        unless @_curr.stepNum is 1
          @_curr.stepNum--
          @_curr.step = @_curr.op.steps[@_curr.stepNum-1]

        # change window
        if @_curr.stepNum is 1
          @_opWindow.disableBack()
        if @_curr.stepNum is @_curr.stepNumTot-1
          @_opWindow.disableFinish()


      # listen to click on next step button
      @_hgInstance.buttons.nextButton.onNextStep @, () =>

          # update information
          unless @_curr.stepNum is @_curr.stepNumTot
            @_curr.stepNum++
            @_curr.step = @_curr.op.steps[@_curr.stepNum-1]

          # change window
          @_opWindow.enableBack()
          if @_curr.stepNum is @_curr.stepNumTot
            @_opWindow.enableFinish()


  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # TODO: get this to work
  # goal: in the code use "@_getButtonCallback('onCallbackName') @, () =>"
  # ============================================================================
  _getButtonCallback: (id) ->
    cb = null
    for bt in @_hgInstance.buttons
      cb = bt[id] if bt[id]
    cb
