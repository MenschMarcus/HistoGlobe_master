window.HG ?= {}

class HG.HiventGalleryWidget extends HG.TimeGalleryWidget

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      slides : []

    @_hivents = []
    @_hiventHandles = []
    # @_hiventsLoaded = false
    # @_onHiventAddedCallbacks = []

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onHiventAdded"

    @_config = $.extend {}, defaultConfig, config

    HG.TimeGalleryWidget.call @, @_config

  # ============================================================================
  hgInit: (hgInstance) ->
    super hgInstance

    hgInstance.hiventGalleryWidget = @

    @loadHiventsFromDSV()

  # ============================================================================
  addSlide: (config) ->
    defaultConfig =
      date : ""
      name : ""
      description : ""
      media : ""

    config = $.extend {}, defaultConfig, config
    # date = config.date.split "."
    # @_changeDates[@getSlideCount()] = new Date date[2], date[1] - 1, date[0]
    # super config.html
    
    div = document.createElement "div"
    div.className = "logo-widget"

    media = document.createElement "div"
    media.className = "logo-widget-image"
    indexStart = config.media.indexOf("<a href=") + 9
    indexEnd = config.media.indexOf(" rel",indexStart) - 1
    m = config.media.substring(indexStart,indexEnd)
    media.style.backgroundImage = "url('#{m}')"
    #media.style.backgroundImage = "url('#{config.media}')"
    div.appendChild media

    name = document.createElement "div"
    name.className = "text"
    n = "<h4>"+config.name+"</h4>"
    name.innerHTML = n
    div.appendChild name

    description = document.createElement "div"
    description.className = "text"
    description.innerHTML = config.description
    div.appendChild description

    displayDate = document.createElement "div"
    displayDate.className = "date"
    d = "<h6>"+config.date+"</h6>"
    displayDate.innerHTML = d
    div.appendChild displayDate

    @addDivSlide {date: config.date, div: div}
    
    #html = "<h5>" + config.name + "</h5>" + config.media
    #@addHTMLSlide {date: config.date, html: html}


  ############################### INIT FUNCTIONS ###############################

  # ============================================================================
  loadHiventsFromDSV: () ->
    if @_config.dsvPaths?
      defaultConfig =
        dsvPaths: []
        delimiter: "|"
        ignoredLines: [] # line indices starting at 1
        indexMappings: [
          id          : 0
          name        : 1
          description : 2
          startDate   : 3
          endDate     : 4
          displayDate : 5
          category    : 6
          multimedia  : 7
        ]

      @_config = $.extend {}, defaultConfig, @_config

      parse_config =
        delimiter: @_config.delimiter
        header: false

      pathIndex = 0
      for dsvPath in @_config.dsvPaths
        $.get dsvPath,
          (data) =>
            parse_result = $.parse data, parse_config
            builder = new HG.HiventBuilder @_config, @_hgInstance.multimediaController
            for result, i in parse_result.results
              unless i+1 in @_config.ignoredLines
                builder.constructHiventFromArray result, pathIndex, (hivent) =>
                  if hivent
                    handle = new HG.HiventHandle hivent

                    #quickhack for getnexthivent in hiventcontroller
                    handle._state = -1

                    @_hivents.push hivent
                    slide =
                      date : hivent.displayDate
                      name : hivent.name
                      description : hivent.description
                      media : hivent.content
                    @addSlide slide

                    @notifyAll "onHiventAdded", handle

                  	@_hiventHandles.push handle
                  	#callback handle for callback in @_onHiventAddedCallbacks
                    #@_filterHivents()
            pathIndex++

            @_hiventsLoaded = true


  # ============================================================================
  getHiventHandles: () ->
    return @_hiventHandles