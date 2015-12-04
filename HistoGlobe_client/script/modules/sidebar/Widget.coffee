window.HG ?= {}

class HG.Widget

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  constructor: (config) ->

    #HG.mixin @, HG.CallbackContainer
    #HG.CallbackContainer.call @

    #@addCallback "onLoaded"

    defaultConfig =
      collapsedAtStart : true,
      categories : []

    @_config = $.extend {}, defaultConfig, config

    #@_headerHeight = null

    @loaded = false

  # ============================================================================
  hgInit: (hgInstance) ->

    @loaded = true

    @_width = 0
    @_hgInstance = hgInstance
    @_sidebar = hgInstance.sidebar
    @_createLayout()
    @_sidebar.onWidthChanged @, (width) =>
      @setWidth width - 2*HGConfig.widget_margin.val - HGConfig.sidebar_scrollbar_width.val - HGConfig.widget_title_size.val - 2*HGConfig.widget_body_padding.val

    @_sidebar.addWidget @

  # ============================================================================
  setName: (title) ->
    @_title.innerHTML = title
    @_title_top.innerHTML = title

  # ============================================================================
  setIcon: (icon) ->
    @_icon.className = "fa fa-fw " + icon

  # ============================================================================
  setContent: (div) ->
    $(@_content).empty()
    @_content.appendChild div

  # ============================================================================
  setWidth: (width) ->
    @_width = width


  # ============================================================================
  onDivClick: (div, callback) ->
    div.addEventListener "mousedown", (e) =>
      div.my_click_x = e.x
      div.my_click_y = e.y

    $(div).click (e) =>
      unless Math.abs(div.my_click_x - e.clientX) > 10 or Math.abs(div.my_click_y - e.clientY) > 10
        callback(e)

  # ============================================================================
  #new:
  show:() ->

    # collapse=() =>
    #     # if $(@_header).hasClass("collapsed")
        # @_collapse()


    #if @_headerHeight
    #$(@_header).css
    #"height": @_headerHeight

    $(@container).show(300)
    # if @_config.collapsedAtStart
    #   $(@container).show(300, collapse)
    # else
    #   $(@container).show(300, collapse)
    #  collapse()

    @_sidebar.updateSize()


  # ============================================================================
  #new:
  hide:() ->

    '''if @_headerHeight is null
      @_headerHeight = $(@_header).css("height")
      console.log "header height",@_headerHeight'''

    '''$(@_header).css
        "height": 0'''
    $(@container).hide(300)

    @_sidebar.updateSize()

    #unless $(@_header).hasClass("collapsed")
    #  @_collapse()

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _createLayout: () ->
    @container = document.createElement "div"
    @container.className = "widgetContainer"

    # header -------------------------------------------------------------------
    @_header = document.createElement "div"
    @_header.className = "widgetHeader"
    @container.appendChild @_header

    # icon
    icon_container = document.createElement "div"
    icon_container.className = "iconContainer collapseOnClick"
    @_header.appendChild icon_container

    @_icon = document.createElement "i"
    icon_container.appendChild @_icon

    @_title_top = document.createElement "div"
    @_title_top.className = "topTitleContainer"
    @_header.appendChild @_title_top


    # collapse button
    collapse_button_container = document.createElement "div"
    collapse_button_container.className = "collapseButtonContainer"
    @_header.appendChild collapse_button_container

    collapse_button = document.createElement "i"
    collapse_button.className = "fa fa-chevron-down widgetCollapseItem"
    collapse_button_container.appendChild collapse_button

    @onDivClick @_title_top, @_collapse
    @onDivClick collapse_button_container, @_collapse
    @onDivClick @_icon, () =>
      if @_hgInstance._collapsed
        @_hgInstance._collapse()
        @_sidebar.scrollToWidgetIntoView @

        if $(@_header).hasClass("collapsed")
          @_collapse()
      else
        @_collapse()

    # body ---------------------------------------------------------------------
    body_collapsable = document.createElement "div"
    body_collapsable.className = "collapsable"
    @container.appendChild body_collapsable

    # title
    title_container = document.createElement "div"
    title_container.className = "verticalTitleContainer collapseOnClick"
    body_collapsable.appendChild title_container

    @_title = document.createElement "div"
    @_title.className = "verticalTextInner"
    @_title.innerHTML = name
    title_container.appendChild @_title

    # content
    @_content = document.createElement "div"
    @_content.className = "widgetBody"
    body_collapsable.appendChild @_content

    clear = document.createElement "div"
    clear.className = "clear"
    @container.appendChild clear

    @onDivClick title_container, () =>
      if @_hgInstance._collapsed
        @_sidebar.scrollToWidgetIntoView @
      @_hgInstance._collapse()

    @setName "New Widget"
    @setIcon "fa-star"

    if @_config.collapsedAtStart
       @_collapse()

    #@notifyAll "onLoaded", @


  # ============================================================================
  _collapse: () =>
    body = @_header.nextSibling

    $(@_header).toggleClass("collapsed")

    if $(@_header).hasClass("collapsed")
      $(body).animate
        height: 0
      , HGConfig.widget_aimation_speed.val * 1000, () =>
        @_sidebar.updateSize()

    else
      $(body).css
        "height": "auto"

      targetHeight = $(body).height()

      $(body).css
        "height": 0

      $(body).animate
        height: targetHeight
      , HGConfig.widget_aimation_speed.val * 1000, () =>
        $(body).css
          "height": "auto"
        @_sidebar.updateSize()
