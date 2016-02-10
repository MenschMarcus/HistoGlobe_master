window.HG ?= {}

class HG.Help

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      autoShow: false
      elements: []

    @_config = $.extend {}, defaultConfig, config

    @_div = new HG.Div null, "help-overlay"

    @_div.jq().click () =>
      @hide()
      window.setTimeout () =>
        $(@_button).attr('title', "Hilfe wieder einblenden").tooltip('fixTitle').tooltip('show');
        window.setTimeout () =>
          $(@_button).attr('title', "Hilfe einblenden").tooltip('fixTitle').tooltip('hide');
        , 2000
      , 500


    @_div.jq().fadeOut 0

    for e in @_config.elements
      @addHelp e

  # ============================================================================
  hgInit: (@_hgInstance) ->
    @_hgInstance.help = @

    @_hgInstance.getContainer().appendChild @_div.elem()

    if @_config.autoShow
      @_hgInstance.onAllModulesLoaded @, () =>
        hgInstance.hiventInfoAtTag?.onHashChanged @, (key, value) =>
          if key is "help" and value is "true"
            @show()
            hgInstance.hiventInfoAtTag?.unsetOption("help")

    if hgInstance.controlButtons?

      help =
        icon: "fa-question"
        tooltip: "Hilfe einblenden"
        callback: () =>
          unless @_hgInstance._collapsed
            @_hgInstance._collapse()
          @show()

      @_button = hgInstance.controlButtons.addButton help

  # ============================================================================
  show:() ->
    @_div.jq().fadeIn()

  # ============================================================================
  hide:() ->
    @_div.jq().fadeOut()

  # ============================================================================
  addHelp:(element) ->
    image = new HG.Img null, 'help-image', element.image
    @_div.append image

    image.jq().load () =>
      image.jq().css {"max-width": image.naturalWidth + "px"}
      image.jq().css {"width": element.width}

    if element.anchorX is "left"
      image.jq().css {"left":element.offsetX + "px"}
    else if element.anchorX is "right"
      image.jq().css {"right":element.offsetX + "px"}
    else if element.anchorX is "center"
      image.jq().css {"left": element.offsetX + "px", "right": 0, "margin-right": "auto", "margin-left": "auto"}

    if element.anchorY is "top"
      image.jq().css {"top":element.offsetY + "px"}
    else if element.anchorY is "bottom"
      image.jq().css {"bottom":element.offsetY + "px"}
    else if element.anchorY is "center"
      image.jq().css {"top": element.offsetY + "px", "bottom": 0, "margin-bottom": "auto", "margin-top": "auto"}



