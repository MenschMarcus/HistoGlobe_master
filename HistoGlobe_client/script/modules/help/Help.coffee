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

    @_domElemCreator = new HG.DOMElementCreator

    @_div = @_domElemCreator.create 'div', null, ['help-overlay']

    @_div.j().click () =>
      @hide()
      window.setTimeout () =>
        $(@_button).attr('title', "Hilfe wieder einblenden").tooltip('fixTitle').tooltip('show');
        window.setTimeout () =>
          $(@_button).attr('title', "Hilfe einblenden").tooltip('fixTitle').tooltip('hide');
        , 2000
      , 500


    @_div.j().fadeOut 0

    for e in @_config.elements
      @addHelp e

  # ============================================================================
  hgInit: (@_hgInstance) ->
    @_hgInstance.help = @

    @_hgInstance.getContainer().appendChild @_div

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
          @show()

      @_button = hgInstance.controlButtons.addButton help

  # ============================================================================
  show:() ->
    @_div.j().fadeIn()

  # ============================================================================
  hide:() ->
    @_div.j().fadeOut()

  # ============================================================================
  addHelp:(element) ->
    image = @_domElemCreator.create 'img', null, 'help-image', [['src', element.image]]
    @_div.appendChild image

    image.j().load () =>
      image.j().css {"max-width": image.naturalWidth + "px"}
      image.j().css {"width": element.width}

    if element.anchorX is "left"
      image.j().css {"left":element.offsetX + "px"}
    else if element.anchorX is "right"
      image.j().css {"right":element.offsetX + "px"}
    else if element.anchorX is "center"
      image.j().css {"left": element.offsetX + "px", "right": 0, "margin-right": "auto", "margin-left": "auto"}

    if element.anchorY is "top"
      image.j().css {"top":element.offsetY + "px"}
    else if element.anchorY is "bottom"
      image.j().css {"bottom":element.offsetY + "px"}
    else if element.anchorY is "center"
      image.j().css {"top": element.offsetY + "px", "bottom": 0, "margin-bottom": "auto", "margin-top": "auto"}



