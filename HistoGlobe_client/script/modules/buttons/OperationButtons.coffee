window.HG ?= {}

class HG.OperationButtons

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (operations, iconPath) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @_operations = operations
    @_iconPath = iconPath


  # ============================================================================
  hgInit: (hgInstance) ->

    hgInstance.operation_buttons = @
    @addCallback 'onStartEditOperation'

    # create button for each operation
    for operation in @_operations

      # tooltip (same as title of operation window)
      operation.tooltip = operation.title

      # icon
      operation.ownIcon = true
      operation.icon = @_iconPath + operation.id + '.svg'

      # callback
      operation.callback = (div) =>
        operationName = div.id.slice -3 # horrible solution, please find a better way!
        @notifyAll 'onStartEditOperation', operationName
        # it is driving me nuts!
        # I could not find a better way for getting the name of the operation
        # for some reason the variable given into the callback is the containing
        # div of the button. I do not understand that :(


    # show operation buttons in edit mode
    hgInstance.edit_button.onEnterEditMode @, () ->
      hgInstance.button_area.addButtonGroup @_operations, "operation-buttons"

    # hide operation buttons in browsing mode
    hgInstance.edit_button.onLeaveEditMode @, () ->
      hgInstance.button_area.removeButtonGroup "operation-buttons"
