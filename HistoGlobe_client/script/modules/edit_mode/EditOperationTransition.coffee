window.HG ?= {}

# ==============================================================================
# base class for all transitions
# handles input/output from/to next/previous EditOperationStep
# ==============================================================================

class HG.EditOperationTransition

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, direction) ->

    # main data: operation and step data (local reference => accessible anywhere)
    @_operation =         @_hgInstance.editOperation.operation
    @_historicalChange =  @_operation.historicalChange


  # ============================================================================
  # nextStep function is intervoked by each EditOperationTransition class
  # on its own, but the base class knows where to go next and performs the swap
  # ============================================================================

  _makeStep: (direction) ->
    # go to next step
    @_operation.idx += direction

    # setup new step
    switch @_operation.idx
      when 0 then @_hgInstance.editOperation.abort()  # only on undo from first step
      when 1 then new HG.EditOperationStep.SelectOldAreas        @_hgInstance, direction
      when 2 then new HG.EditOperationStep.CreateNewTerritories  @_hgInstance, direction
      when 3 then new HG.EditOperationStep.CreateNewName         @_hgInstance, direction
      when 4 then new HG.EditOperationStep.AddChange             @_hgInstance, direction
      when 5 then @_hgInstance.editOperation.finish()