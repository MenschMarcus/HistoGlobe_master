window.HG ?= {}

# ==============================================================================
# ChangeController has several controlling tasks:
#   register clicks on edit operation buttons -> init operation
#   manage operation window (init, send data, get data)
#   handle communication with backend (get data, send data)
# ==============================================================================
class HG.ChangeController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_editButtonArea, editConfig) ->

    # init variables
    @_iconPath = editConfig['iconPath']
    @_ops = new HG.ObjectArray editConfig['operations'] # all possible operations
    @_curr = {                      # object storing current state of workflow
      op          : null            # object of current operation
      stepNumTotal: null            # total number of steps of current operation
      stepNum     : null            # number of current step in workflow [starting at 1!]
      step        : null            # object of current step in workflow
    }

    # init callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # init operation buttons (hidden)
    @_opButtons = new HG.ChangeOperationButtons @_editButtonArea, @_ops, @_iconPath

  # ============================================================================
  hgInit: (@_hgInstance) ->

    @_hgInstance.change_controller = @

    @_editButton = @_hgInstance.buttons.editButton
    @_container = @_hgInstance._hgInstance._config.container

    # listen to click on edit button => start edit mode
    @_hgInstance.buttons.editButton.onEnterEditMode @, (btn) ->
      btn.changeState 'edit-mode'
      btn.activate()
      @_opButtons.hgInit @_hgInstance

      # listen to click on edit operation buttons => start operation
      # for operation in @_ops
      @_ops.foreach (operation) =>
        @_hgInstance.buttons[operation.id].onStart @, (btn) =>

          # get operation [json object]
          opId = btn._button.id # to do: more elegant way to get button?
          @_curr.op = @_ops.getByPropVal 'id', opId

          # reset edit operation windows
          # disable all edit buttons, activate current operation
          @_opButtons.disable()
          @_opButtons.activate @_curr.op.id

          # setup operation window
          @_opWindow.destroy() if @_opWindow? # cleanup before
          @_opWindow = new HG.ChangeOperationWorkflow @_hgInstance, @_container, @_curr.op

          # update information about current state in workflow
          @_curr.stepNumTotal = @_curr.op.steps.length
          @_curr.stepNum = 1
          @_curr.step = @_curr.op.steps[@_curr.stepNum-1]

          # disable buttons
          @_opWindow.disableNext()
          @_opWindow.disableBack()


          # listen to click on previous step button
          @_hgInstance.buttons.backButton.onPrevStep @, () =>
            # update information
            unless @_curr.stepNum is 1
              @_curr.stepNum--
              @_curr.step = @_curr.op.steps[@_curr.stepNum-1]
            # change window
            if @_curr.stepNum is 1
              @_opWindow.disableBack()
            if @_curr.stepNum is @_curr.stepNumTotal-1
              @_opWindow.disableFinish()

          # listen to click on next step button
          @_hgInstance.buttons.nextButton.onNextStep @, () =>
              # update information
              unless @_curr.stepNum is @_curr.stepNumTotal
                @_curr.stepNum++
                @_curr.step = @_curr.op.steps[@_curr.stepNum-1]
              # change window
              @_opWindow.enableBack()
              if @_curr.stepNum is @_curr.stepNumTotal
                @_opWindow.enableFinish()

          # listen to click on abort button
          @_hgInstance.buttons.abortButton.onAbort @, () =>
              # remove window
              @_opWindow.destroy()
              # reset buttons
              @_opButtons.deactivate @_curr.op.id
              @_opButtons.enable()
              # update information
              @_curr.op = null
              @_curr.stepNumTotal = null
              @_curr.stepNum = null
              @_curr.step = null


    # listen to click on edit mode => leave edit mode
    @_hgInstance.buttons.editButton.onLeaveEditMode @, (btn) ->
      btn.changeState 'normal'
      btn.deactivate()
      @_opButtons.destroy()


  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################
