window.HG ?= {}

class HG.Sidebar

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  hgInit: (hgInstance) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onWidthChanged"

    @_container = @_createElement hgInstance._sidebar_area, "div", "sidebar"
    @_container.className = "swiper-container"

    scrollbar = @_createElement @_container, "div", "sidebar-scrollbar"

    @_wrapper = @_createElement @_container, "div", ""
    @_wrapper.className = "swiper-wrapper"

    @_slide = @_createElement @_wrapper, "div", ""
    @_slide.className = "swiper-slide"

    @_isScrolling = false

    @_sidebar_swiper = new Swiper '#sidebar',
      mode:'vertical'
      grabCursor: true
      scrollContainer: true
      mousewheelControl: true
      moveStartThreshold: 10
      scrollbar:
        hide: false
        container: '#sidebar-scrollbar'

    @_widgets = []

    # needed for some reason...
    window.setTimeout () =>
      @updateSize()
    , 1000

    hgInstance.onAllModulesLoaded @, () =>
      hgInstance.hiventInfoAtTag?.onHashChanged @, (key, value) =>
        if key is "sidebar"
          if value is "open"
            if hgInstance._collapsed
              hgInstance._collapse()
          else if value is "close"
            unless hgInstance._collapsed
              hgInstance._collapse()

          else
            console.log "Failed to parse document hash: Valid values for sidebar are 'open' and 'close'!"

  # ============================================================================
  addWidget: (widget) ->
    
    insertBeforeThis = null

    if widget.sequenceNr
      for w in @_widgets
        if w.sequenceNr and w.sequenceNr > widget.sequenceNr
          if insertBeforeThis is null
            insertBeforeThis = w
          else if w.sequenceNr < insertBeforeThis.sequenceNr
            insertBeforeThis = w
    else
      @_slide.appendChild widget.container

    if insertBeforeThis isnt null
      #console.log "insert ",widget," before ",insertBeforeThis
      @_slide.insertBefore widget.container,insertBeforeThis.container
    else
      @_slide.appendChild widget.container  
    
    @updateSize()

    @_widgets.push widget

  # ============================================================================
  updateSize: () ->
    @_sidebar_swiper?.reInit()

  # ============================================================================
  scrollWidgetToTop: (widget) ->
    @_sidebar_swiper.setTransition @_wrapper, 1000 * HGConfig.sidebar_aimation_speed.val
    @_sidebar_swiper.setTranslate @_wrapper,
      y: @_clampSidebarPosition(-$(widget.container).position().top + HGConfig.widget_margin.val)

    # ============================================================================
  scrollWidgetToBottom: (widget) ->
    @_sidebar_swiper.setTransition @_wrapper, 1000 * HGConfig.sidebar_aimation_speed.val
    @_sidebar_swiper.setTranslate @_wrapper,
      y: @_clampSidebarPosition(-$(widget.container).position().top - $(widget.container).height() + $(@_container).height() - 3*HGConfig.widget_margin.val)

  # ============================================================================
  scrollToWidgetIntoView: (widget) ->
    if $(widget.container).offset().top < -HGConfig.widget_margin.val
      @scrollWidgetToTop widget
    else if $(widget.container).offset().top + $(widget.container).height() + 3*HGConfig.widget_margin.val > $(@_container).height()
      @scrollWidgetToBottom widget

  # ============================================================================
  resize: (width, height) ->

    oldWidth = $(@_container).width()

    @_container.style.width = "#{width}px"
    @_container.style.height = "#{height}px"
    $(".widgetBody").css("width", width - 2*HGConfig.widget_margin.val - HGConfig.sidebar_scrollbar_width.val)
    $(".widgetContainer").css("width", width - 2*HGConfig.widget_margin.val - HGConfig.sidebar_scrollbar_width.val)
    @_sidebar_swiper?.reInit()

    if width != oldWidth
      @notifyAll "onWidthChanged", width

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _clampSidebarPosition: (offset) ->
    Math.min(0, Math.max(-($(@_wrapper).height() - $(@_container).height()), offset))

  # ============================================================================
  _createElement: (container, type, id) ->
    div = document.createElement type
    div.id = id
    container.appendChild div
    return div
