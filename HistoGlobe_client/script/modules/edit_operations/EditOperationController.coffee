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

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @_operations = operations   # all possible operation
    @_currOp = null             # currently active operation
    @_currStep = null           # currently active step


  # ============================================================================
  hgInit: (hgInstance) ->

    @_hgInstance = hgInstance
    @_hgInstance.edit_operation_controller = @

    # listen to click on edit operation buttons => start operation
    @_hgInstance.operation_buttons.onStartEditOperation @, (operationId) =>

      # get operation [json object]
      operation = $.grep @_operations, (op) ->
        op.id == operationId
      @_currOp = operation[0]

      # setup operation window
      @_opWindow.destroy() if @_opWindow? # cleanup before
      @_opWindow = new HG.EditOperationWindow @_hgInstance._config.container, @_currOp
