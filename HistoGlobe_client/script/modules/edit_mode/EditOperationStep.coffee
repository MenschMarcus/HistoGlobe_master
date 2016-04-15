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
  constructor: (@_hgInstance, direction) ->

    # main data: operation and step data (local reference => accessible anywhere)
    @_historicalChange =  @_hgInstance.editOperation.operation.historicalChange
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
        @_makeTransition -1

    else # skip
      @_makeTransition direction




  # ============================================================================
  # makeTransition method can be intervoked both by clicking next button
  # in the workflow window and by the operation itself
  # (e.g. if last area successfully named)
  # => executes next EditOperationTransition
  # ============================================================================

  _makeTransition: (direction) ->
    @_cleanup()

    idx = @_hgInstance.editOperation.operation

    if                                       (idx is 1 and direction is -1)
      new HG.EditOperationTransition0to1 @_hgInstance, direction

    else if (idx is 1 and direction is 1) or (idx is 2 and direction is -1)
      new HG.EditOperationTransition1to2 @_hgInstance, direction

    else if (idx is 2 and direction is 1) or (idx is 3 and direction is -1)
      new HG.EditOperationTransition2to3 @_hgInstance, direction

    else if (idx is 3 and direction is 1) or (idx is 4 and direction is -1)
      new HG.EditOperationTransition3to4 @_hgInstance, direction

    else if (idx is 4 and direction is 1)
      new HG.EditOperationTransition4to5 @_hgInstance, direction

    @_undoManager.add {
      undo: => @_makeTransition (-1)*direction
    }