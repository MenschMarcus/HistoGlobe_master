window.HG ?= {}

class HG.EditButtonArea

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  hgInit: (hgInstance) ->

    @_hgInstance = hgInstance
    @_hgInstance.edit_button_area = @

    @_container = document.createElement "div"
    @_container.className = "edit-buttons"
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
  addButtonGroup: (configs, name) ->
    group = @_addGroup name

    for config in configs
      @_addButton config, group

  # ============================================================================
  removeButtonGroup: (name) ->
    @_removeGroup name

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _addGroup: (name) ->
    group = document.createElement "div"
    group.id = name if name?  # in order to delete buttons when leaving edit mode
    group.className = "edit-buttons-group"
    @_container.appendChild group
    return group

  # ============================================================================
  _addGroup: (name) ->
    group = document.createElement "div"
    group.id = name if name?  # in order to delete buttons when leaving edit mode
    group.className = "edit-buttons-group"
    @_container.appendChild group
    return group

  # ============================================================================
  _removeGroup: (name) ->
    group = document.getElementById name
    group.parentNode.removeChild group

  # ============================================================================
  _addButton: (config, group) ->
    defaultConfig =
      icon: "fa-times"
      tooltip: "Unnamed button"
      callback: ()-> console.log "Not implmented"

    config = $.extend {}, defaultConfig, config

    button = document.createElement "div"
    button.className = "edit-buttons-button"
    $(button).tooltip {
      title: config.tooltip,
      placement: "left",  # TODO: how to set it to bottom?
      container:"body"
    }

    unless config.ownIcon  # font awesome
      icon = document.createElement "i"
      icon.className = "fa " + config.icon
    else                  # own icon
      icon = document.createElement "div"
      icon.className = "own-button"
      $(icon).css 'background-image', 'url("' + config.icon + '")'
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
