window.HG ?= {}

class HG.OperationButtons

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->

    @_iconPath = "../HistoGlobe_client/config/common/graphics/operations/"
    @_operations =
      [
        {
          "name":     "ADD",
          "tooltip":  "add new country"
        },
        {
          "name":     "UNI",
          "tooltip":  "unite countries"
        },
        {
          "name":     "SEP",
          "tooltip":  "separate country"
        },
        {
          "name":     "CHB",
          "tooltip":  "change borders between countries"
        },
        {
          "name":     "CHN",
          "tooltip":  "change name of country"
        },
        {
          "name":     "DEL",
          "tooltip":  "delete country"
        },
      ]


  hgInit: (hgInstance) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # generically create icons and callbacks on click on button
    for operation in @_operations
      callbackName = 'on' + operation.name
      @addCallback callbackName
      cn = callbackName

      # operation object
      operation.ownIcon = true
      operation.icon = @_iconPath + operation.name + '.svg'
      operation.callback = (div) =>
        operationName = div.id.slice -3 # horrible solution, please find a better way!
        @notifyAll 'on' + operationName
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
