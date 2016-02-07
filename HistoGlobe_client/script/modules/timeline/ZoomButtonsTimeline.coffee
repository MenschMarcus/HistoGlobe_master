window.HG ?= {}

# TODO: use normal button, to be consistent

class HG.ZoomButtonsTimeline

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add buttons to HG instance
    @_hgInstance.zoomButtonsTimeline = @

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onZoomIn"
    @addCallback "onZoomOut"

    # init variables
    @_timeline = @_hgInstance.timeline


    if @_timeline

        @_container = @_timeline.getParentDiv()

        group = document.createElement 'div'
        group.className = "timeline-control-buttons-group"
        @_container.appendChild group

        zoom_in =
          icon: "fa-plus"
          tooltip: "Zoom In"
          callback: () =>
            @notifyAll "onZoomIn"

        zoom_out =
          icon: "fa-minus"
          tooltip: "Zoom Out"
          callback: () =>
            @notifyAll "onZoomOut"

        @_addButton zoom_in, group
        @_addButton zoom_out, group


    else
      console.error "Failed to add timeline zoom buttons: Timeline module not found!"



  # ============================================================================
  _addButton: (config, group) ->
    defaultConfig =
      icon: "fa-times"
      tooltip: "Unnamed button"
      callback: ()-> console.log "Not implemented"

    config = $.extend {}, defaultConfig, config

    button = document.createElement 'div'
    button.className = "timeline-control-buttons-button"
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

