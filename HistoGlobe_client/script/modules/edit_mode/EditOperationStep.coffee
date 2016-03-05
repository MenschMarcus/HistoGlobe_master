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
  constructor: (@_hgInstance, @_stepData, @_isForward) ->

    # console.log "IN :", @_stepData.id, @_stepData

    ## handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onFinish"

    ## handle undo
    # only add undo manager on forward direction, to be able to undo the actions
    # when going backwards through the steps
    if @_isForward
      @_undoManager = new UndoManager
      @_hgInstance.editOperation.addUndoManager @_undoManager
    else
      @_undoManager = @_hgInstance.editOperation.getUndoManager()


  # ============================================================================
  # simple interface for each of the steps to divert their notification callbacks
  # to the EditMode resp. editOperation, so that it can notify all its listeners
  # => makes EditMode pretty much equivalent to all its subclasses in terms
  # of callbacks and notifications to the outside
  # usage: just like with @notifyAll 'onSomething', parameters...
  #                   ->  @notifyEditMode 'onSomething', parameters...

  # ----------------------------------------------------------------------------
  notifyEditMode: (callbackName, parameters...) ->
    @_hgInstance.editMode.notifyAll callbackName, parameters...

  # ----------------------------------------------------------------------------
  notifyOperation: (callbackName, parameters...) ->
    @_hgInstance.editOperation.notifyAll callbackName, parameters...

  # ============================================================================
  # finish method can be intervoked both by clicking next button
  # in the workflow window and by the operation itself
  # (e.g. if last area successfully named)
  finish: () ->
    @_cleanup()

    # console.log "OUT:", @_stepData.id, @_stepData

    @notifyAll 'onFinish', @_stepData

  # ----------------------------------------------------------------------------
  abort: () ->
    @_cleanup()