window.HG ?= {}

# ==============================================================================
# base class for all steps
# handles input/output from/to workflow window and operation class
# ==============================================================================

class HG.EditOperationStep

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, direction, start=no) ->

    # main data: operation and step data (local reference => accessible anywhere)
    @_operationId =       @_hgInstance.editOperation.operation.id
    @_stepData =          @_hgInstance.editOperation.operation.steps[@_hgInstance.editOperation.operation.idx]
    @_undoManager =       @_hgInstance.editOperation.undoManager

    # if step requires user input: setup next step in WorkflowWindow and listen
    # to its events
    if @_stepData.userInput
      @_hgInstance.editOperation.notifyAll 'onStepTransition', direction
      @_hgInstance.editOperation.notifyAll 'onStepIncomplete'

      # next step button
      @_hgInstance.buttons.nextStep.onNext @, () =>
        @_makeTransition 1

      # finish button
      @_hgInstance.buttons.nextStep.onFinish @, () =>
        @_makeTransition 1

    # initial call: transit immediately to first step
    @_makeTransition direction if start



  # ============================================================================
  # makeTransition method can be intervoked both by clicking next button
  # in the workflow window and by the operation itself
  # (e.g. if last area successfully named)
  # ============================================================================

  _makeTransition: (direction) ->

    @_cleanup direction

    # transfer data
    # can not use @_stepData, because if undoManager jumps back in this base
    # that was called from anothers step inherited class, @_stepData is not what
    # what you want it to be ;) => regain @_stepData
    if direction is 1
      thisStep = @_hgInstance.editOperation.operation.steps[@_hgInstance.editOperation.operation.idx]
      nextStep = @_hgInstance.editOperation.operation.steps[@_hgInstance.editOperation.operation.idx+1]
      nextStep.inData = thisStep.outData
    else
      thisStep = @_hgInstance.editOperation.operation.steps[@_hgInstance.editOperation.operation.idx]
      prevStep = @_hgInstance.editOperation.operation.steps[@_hgInstance.editOperation.operation.idx-1]
      prevStep.outData = thisStep.inData

    # go to next step
    @_hgInstance.editOperation.operation.idx += direction

    # setup new step
    switch @_hgInstance.editOperation.operation.idx
      when 0 then @_hgInstance.editOperation.abort()  # only on undo from first step
      when 1 then new HG.EditOperationStep.SelectOldAreas        @_hgInstance, direction
      when 2 then new HG.EditOperationStep.CreateNewTerritories  @_hgInstance, direction
      when 3 then new HG.EditOperationStep.CreateNewNames        @_hgInstance, direction
      when 4 then new HG.EditOperationStep.AddChange             @_hgInstance, direction
      when 5 then @_hgInstance.editOperation.finish()


  # ============================================================================
  # cleanup to be implemented by each step on its own
  # ============================================================================

  _cleanup: (direction) ->