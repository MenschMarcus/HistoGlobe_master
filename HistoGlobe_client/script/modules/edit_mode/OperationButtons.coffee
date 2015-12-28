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
          "ownIcon":  true,
          "tooltip":  "add new country"
        },
        {
          "name":     "UNI",
          "ownIcon":  true,
          "tooltip":  "unite countries"
        },
        {
          "name":     "SEP",
          "ownIcon":  true,
          "tooltip":  "separate country"
        },
        {
          "name":     "CHB",
          "ownIcon":  true,
          "tooltip":  "change borders between countries"
        },
        {
          "name":     "CHN",
          "ownIcon":  true,
          "tooltip":  "change name of country"
        },
        {
          "name":     "DEL",
          "ownIcon":  true,
          "tooltip":  "delete country"
        },
      ]


  hgInit: (hgInstance) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # generically create callbacks
    for op in @_operations
      callbackName = 'on' + op.name
      @addCallback callbackName

    # generically create path to icon
    for op in @_operations
      op.icon = @_iconPath + op.name + '.svg'


    # if hgInstance.edit_button_area?
    #   zoom_in =
    #     icon: "fa-plus"
    #     tooltip: "Karte vergrößern"
    #     callback: () =>
    #       @notifyAll "onZoomIn"

    #   zoom_out =
    #     icon: "fa-minus"
    #     tooltip: "Karte verkleinern"
    #     callback: () =>
    #       @notifyAll "onZoomOut"

    #   hgInstance.control_button_area.addButtonGroup [zoom_in, zoom_out]

    # else
    #   console.error "Failed to add zoom buttons: ControlButtons module not found!"

    # show operation buttons in edit mode
    hgInstance.edit_button.onEnterEditMode @, () ->
      hgInstance.edit_button_area.addButtonGroup @_operations, "operation-buttons"

    # hide operation buttons in browsing mode
    hgInstance.edit_button.onLeaveEditMode @, () ->
      hgInstance.edit_button_area.removeButtonGroup "operation-buttons"
