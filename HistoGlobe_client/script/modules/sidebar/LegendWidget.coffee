window.HG ?= {}

class HG.LegendWidget extends HG.Widget

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      icon: ""
      name: ""
      elements: []

    @_config = $.extend {}, defaultConfig, config

    @_hiventController = null

    @_init()

    HG.Widget.call @, @_config

  # ============================================================================
  hgInit: (hgInstance) ->
    super hgInstance

    @setName @_config.name
    @setIcon @_config.icon

    @setContent @_mainDiv

    @_hiventController = hgInstance.hiventController
    @_categoryIconMapping = hgInstance.categoryIconMapping

    @_categoryFilter = hgInstance.categoryFilter

    for column in @_config.columns
      col_div = @addColumn @_config.columns.length

      for group in column.groups
        group_div = @addGroup group.name, col_div

        for element in group.elements
          if element.type is "category"
            @addCategory element, group_div
          else if element.type is "categoryWithColor"
            @addCategoryWithColor element, group_div
          else if element.type is "categoryWithIcon"
            @addCategoryWithIcon element, group_div
          else
            @addSpacer()

    unless @_hiventController
      console.error "Unable to filter hivents: HiventController module not detected in HistoGlobe instance!"


  # ============================================================================
  addColumn: (column_count) ->
    col_div = document.createElement "div"
    col_div.className = "legend-column legend-column-#{column_count}"
    @_mainDiv.appendChild col_div
    return col_div

  # ============================================================================
  addCategory: (config, col_div) ->
    defaultConfig =
      category: ""
      name: ""
      filterable: false
      useCategoryAsPrefix: false

    config = $.extend {}, defaultConfig, config

    row = document.createElement "div"
    col_div.appendChild row

    if @_categoryIconMapping
      cellIcon = document.createElement "span"
      cellIcon.className = "legend-icon"
      cellIcon.style.backgroundImage = "url('#{@_categoryIconMapping.getIcons(config.category).default}')"
      row.appendChild cellIcon

    row.className = "legend-row"
    @_categoryFilter?.make_filterable(row,config)
    if config.filterable
      if config.useCategoryAsPrefix
        @onDivClick row, () => @_categoryFilter?.checkPrefixFilter(row,config.category)
      else
        @onDivClick row, () => @_categoryFilter?.checkFilter(row,config.category)
    #@_make_filterable row, config

    cellName = document.createElement "span"
    cellName.innerHTML = config.name
    cellName.className = "legend-text"
    row.appendChild cellName

    cellCheck = document.createElement "i"
    cellCheck.className = "fa fa-check legend-check"
    row.appendChild cellCheck

  # ============================================================================
  addCategoryWithIcon: (config, col_div) ->
    defaultConfig =
      category: ""
      icon: ""
      name: ""
      filterable: false
      useCategoryAsPrefix: false

    config = $.extend {}, defaultConfig, config


    row = document.createElement "div"
    col_div.appendChild row

    cellIcon = document.createElement "span"
    cellIcon.className = "legend-icon"
    cellIcon.style.backgroundImage = "url('#{config.icon}')"
    row.appendChild cellIcon

    row.className = "legend-row"
    @_categoryFilter?.make_filterable(row,config)
    if config.filterable
      if config.useCategoryAsPrefix
        @onDivClick row, () => @_categoryFilter?.checkPrefixFilter(row,config.category)
      else
        @onDivClick row, () => @_categoryFilter?.checkFilter(row,config.category)
    #@_make_filterable row, config

    cellName = document.createElement "span"
    cellName.innerHTML = config.name
    cellName.className = "legend-text"
    row.appendChild cellName

    cellCheck = document.createElement "i"
    cellCheck.className = "fa fa-check legend-check"
    row.appendChild cellCheck

  # ============================================================================
  addCategoryWithColor: (config, col_div) ->
    defaultConfig =
      category: ""
      color: ""
      name: ""
      filterable: false
      useCategoryAsPrefix: false

    config = $.extend {}, defaultConfig, config

    row = document.createElement "div"
    col_div.appendChild row

    cellColor = document.createElement "span"
    cellColor.style.backgroundColor = config.color
    cellColor.className = "legend-color"
    row.appendChild cellColor

    row.className = "legend-row"
    @_categoryFilter?.make_filterable(row,config)
    if config.filterable
      if config.useCategoryAsPrefix
        @onDivClick row, () => @_categoryFilter?.checkPrefixFilter(row,config.category)
      else
        @onDivClick row, () => @_categoryFilter?.checkFilter(row,config.category)
    #@_make_filterable row, config

    cellName = document.createElement "span"
    cellName.innerHTML = config.name
    cellName.className = "legend-text"
    row.appendChild cellName

    cellCheck = document.createElement "i"
    cellCheck.className = "fa fa-check legend-check"
    row.appendChild cellCheck

  # ============================================================================
  addSpacer: (col_div) ->
    row = document.createElement "div"
    row.className = "legend-row legend-row-spacer"
    col_div.appendChild row

  # ============================================================================
  addGroup: (name, col_div) ->

    group_div = document.createElement "div"
    group_div.className = "legend-group"

    heading = document.createElement "div"
    heading.className = "legend-row legend-row-heading"
    heading.innerHTML = name

    col_div.appendChild group_div
    group_div.appendChild heading

    return group_div


  ############################### INIT FUNCTIONS ###############################

  # ============================================================================
  _init: () ->
    @_mainDiv = document.createElement "div"
    @_mainDiv.className = "legend-widget"

    #@_categoryFilter = []

  ############################# MAIN FUNCTIONS #################################

  '''# ============================================================================
  _make_filterable : (row, config) ->

    if config.filterable
      row.className = "legend-row legend-row-filterable active"

      @_categoryFilter.push config.category

      @onDivClick row, () =>

        $(row).toggleClass "active"

        if $(row).hasClass("active")
          @_categoryFilter.push config.category
        else
          @_categoryFilter = @_categoryFilter.filter (item) -> item isnt config.category

        @_hiventController?.setCategoryFilter @_categoryFilter

        console.log "filtered: ", @_categoryFilter

    else
      row.className = "legend-row legend-row-non-filterable"'''

