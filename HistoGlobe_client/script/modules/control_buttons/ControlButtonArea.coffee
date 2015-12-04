window.HG ?= {}

class HG.ControlButtonArea

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  hgInit: (hgInstance) ->

    @_hgInstance = hgInstance
    @_hgInstance.control_button_area = @

    @_container = document.createElement "div"
    @_container.className = "control-buttons"
    @_hgInstance._top_area.appendChild @_container

    @_hgInstance.onTopAreaSlide @, (t) =>
      if @_hgInstance.isInMobileMode()
        @_container.style.left = "#{t*0.5}px"
      else
        @_container.style.left = "0px"

  # ============================================================================
  addButton: (config) ->
    group = @_addGroup()
    @_addButton config, group

  # ============================================================================
  addButtonGroup: (configs) ->
    group = @_addGroup()

    for config in configs
      @_addButton config, group

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _addGroup: () ->
    group = document.createElement "div"
    group.className = "control-buttons-group"
    @_container.appendChild group
    return group

  # ============================================================================
  _addButton: (config, group) ->
    defaultConfig =
      icon: "fa-times"
      tooltip: "Unnamed button"
      callback: ()-> console.log "Not implmented"

    config = $.extend {}, defaultConfig, config

    button = document.createElement "div"
    button.className = "control-buttons-button"
    $(button).tooltip {title: config.tooltip, placement: "right", container:"body"}

    icon = document.createElement "i"
    icon.className = "fa " + config.icon
    button.appendChild icon

    $(button).click () ->
      c = config.callback(@)
      if c? and c.icon? and c.tooltip?
        c = $.extend {}, defaultConfig, c
        config = c
        icon.className = "fa " + config.icon
        $(button).attr('title', config.tooltip).tooltip('fixTitle').tooltip('show');

    group.appendChild button

    return button



