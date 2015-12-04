window.HG ?= {}

class HG.Styler

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    defaultConfig =
      normalStyle:
        areaColor:        "#FCFCFC",
        areaColor_hc:     "#FCFCFC",
        areaOpacity:      0.75,
        borderWidth:      1.0,
        borderColor:      "#BBBBBB",
        borderColor_hc:   "#BBBBBB",
        borderOpacity:    1.0,
        labelSize:        1,
        labelColor:       "#BBBBBB",
        labelColor_hc:    "#BBBBBB",
        labelOpacity:     1.0

    @_config = $.extend {}, defaultConfig, config

    ## get mapping: country -> theme -> time period
    @_loadMappingFromCSV config

    ## calculate styles
    # normal style: if not in modules.json, take default config

    # highlight style:  if not in modules.json, take normal style = no highlight style
    if @_config.highlightStyle?
      @_config.highlightStyle.areaColor       = @_config.highlightStyle.areaColor     ? @_config.normalStyle.areaColor
      @_config.highlightStyle.areaColor_hc    = @_config.highlightStyle.areaColor_hc  ? @_config.highlightStyle.areaColor
      @_config.highlightStyle.areaOpacity     = @_config.highlightStyle.areaOpacity   ? @_config.normalStyle.areaOpacity
      @_config.highlightStyle.borderWidth     = @_config.highlightStyle.borderWidth   ? @_config.normalStyle.borderWidth
      @_config.highlightStyle.borderColor     = @_config.highlightStyle.borderColor   ? @_config.normalStyle.borderColor
      @_config.highlightStyle.borderColor_hc  = @_config.highlightStyle.borderColor_hc ? @_config.highlightStyle.borderColor
      @_config.highlightStyle.borderOpacity   = @_config.highlightStyle.borderOpacity ? @_config.normalStyle.borderOpacity
      @_config.highlightStyle.labelSize       = @_config.highlightStyle.labelSize     ? @_config.normalStyle.labelSize
      @_config.highlightStyle.labelColor      = @_config.highlightStyle.labelColor    ? @_config.normalStyle.labelColor
      @_config.highlightStyle.labelColor_hc   = @_config.highlightStyle.labelColor_hc ? @_config.highlightStyle.labelColor
      @_config.highlightStyle.labelOpacity    = @_config.highlightStyle.labelOpacity  ? @_config.normalStyle.labelOpacity
    else
      @_config.highlightStyle = @_config.normalStyle

    # theme styles: take from modules.json and take normal style as fallback style
    if @_config.themeStyles?
      for themeName, themeClasses of @_config.themeStyles
        for themeClassName, themeClassStyle of themeClasses
          themeClassStyle.areaColor       = themeClassStyle.areaColor     ? @_config.normalStyle.areaColor
          themeClassStyle.areaColor_hc    = themeClassStyle.areaColor_hc  ? themeClassStyle.areaColor
          themeClassStyle.areaOpacity     = themeClassStyle.areaOpacity   ? @_config.normalStyle.areaOpacity
          themeClassStyle.borderWidth     = themeClassStyle.borderWidth   ? @_config.normalStyle.borderWidth
          themeClassStyle.borderColor     = themeClassStyle.borderColor   ? @_config.normalStyle.borderColor
          themeClassStyle.borderColor_hc  = themeClassStyle.borderColor_hc ? themeClassStyle.borderColor
          themeClassStyle.borderOpacity   = themeClassStyle.borderOpacity ? @_config.normalStyle.borderOpacity
          themeClassStyle.labelSize       = themeClassStyle.labelSize     ? @_config.normalStyle.labelSize
          themeClassStyle.labelColor      = themeClassStyle.labelColor    ? @_config.normalStyle.labelColor
          themeClassStyle.labelColor_hc   = themeClassStyle.labelColor_hc ? themeClassStyle.labelColor
          themeClassStyle.labelOpacity    = themeClassStyle.labelOpacity  ? @_config.normalStyle.labelOpacity

    # translate the style from the user point of view to the leaflet point of view
    @_normalStyle     = @_config.normalStyle
    @_highlightStyle  = @_config.highlightStyle

    # theme style structure:
    # each theme has a name and can have multpile classes, each class has a name and a style
    # => array of theme objects (name, classes), theme class as array of theme class objects (name, style)
    @_themeStyles     = []
    if @_config.themeStyles?
      for themeName, themeClasses of @_config.themeStyles
        theme = {}
        theme.themeName = themeName
        theme.themeClasses = []
        for className, classStyle of themeClasses
          themeClass = {}
          themeClass.className = className
          themeClass.classStyle = classStyle
          theme.themeClasses.push themeClass
        @_themeStyles.push theme

  # ============================================================================
  hgInit: (hgInstance) ->
    hgInstance.styler = @

  # ============================================================================
  getNormalStyle: () ->
    @_normalStyle

  # ============================================================================
  getHighlightStyle: () ->
    @_highlightStyle

  # ============================================================================
  getAreaThemeStyles: (inAreaId) ->
    themeStyles = []

    # for all themes
    for theme in @_themeStyles
      areaFoundInTheme = no

      themeStyle = {}
      themeStyle.themeName = theme.themeName
      themeStyle.themeClasses = []

      # find if country has a class in this theme
      for area in @_areaThemeMappings
        if area.areaId == inAreaId

          # if so, get the style and the start / end dates for the area for this theme class
          for themeClass in theme.themeClasses
            if themeClass.className == area.themeClass
              themeStyle.themeClasses.push {
                className  : themeClass.className
                startDate  : area.startDate
                endDate    : area.endDate
                style      : themeClass.classStyle
              }
              areaFoundInTheme = yes

      if areaFoundInTheme
        themeStyles.push themeStyle

    themeStyles

  # ============================================================================
  getLabelThemeStyles: (inLabelId) ->
    themeStyles = []

    # for all themes
    for theme in @_themeStyles
      labelFoundInTheme = no

      themeStyle = {}
      themeStyle.themeName = theme.themeName
      themeStyle.themeClasses = []

      # find if country has a class in this theme
      for label in @_labelThemeMappings
        if label.labelId == inLabelId

          # if so, get the style and the start / end dates for the label for this theme class
          for themeClass in theme.themeClasses
            if themeClass.className == label.themeClass
              themeStyle.themeClasses.push {
                className  : themeClass.className
                startDate  : label.startDate
                endDate    : label.endDate
                style      : themeClass.classStyle
              }
              labelFoundInTheme = yes

      if labelFoundInTheme
        themeStyles.push themeStyle

    themeStyles

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _loadMappingFromCSV: (config) ->

    @_areaThemeMappings = []
    @_labelThemeMappings = []

    if config.countryThemeMapping?

      # interpret each mapping as an own config
      # file path, to be ignored header lines of csv file and indices mapped to data
      for mappingConfig in config.countryThemeMapping

        defaultConfig =
          csvFilePath:    ""
          delimiter:      ","
          indexMapping:
            areaId:    0
            themeClass:   1
            startDate:    2
            endDate:      3

        mappingConfig = $.extend {}, defaultConfig, mappingConfig

        # load area file
        $.get mappingConfig.csvFilePathAreas, (data) =>
          parseResult = $.parse data
          # load mapping data for each row
          # each row is already an object, not an array! -> no indexMapping needed
          # N.B: data MUST have these column names, but order can be inpedendent:
          # country_id, theme_class, start_date, end_date
          for row in parseResult.results.rows

            # error handling for not given start and end dates
            startDate = row.start_date ?= 0
            endDate   = row.end_date   ?= 9999

            # final mapping object
            @_areaThemeMappings.push {
              areaId:     row.area_id
              themeClass: row.theme_class
              # create date objects from input date strings/numbers
              startDate:  new Date startDate.toString()
              endDate:    new Date endDate.toString()
            }

        # load label file
        $.get mappingConfig.csvFilePathLabels, (data) =>
          parseResult = $.parse data
          # load mapping data for each row
          # each row is already an object, not an array! -> no indexMapping needed
          # N.B: data MUST have these column names, but order can be inpedendent:
          # country_id, theme_class, start_date, end_date
          for row in parseResult.results.rows

            # error handling for not given start and end dates
            startDate = row.start_date ?= 0
            endDate   = row.end_date   ?= 9999

            # final mapping object
            @_labelThemeMappings.push {
              labelId:    row.label_id
              themeClass: row.theme_class
              # create date objects from input date strings/numbers
              startDate:  new Date startDate.toString()
              endDate:    new Date endDate.toString()
            }
