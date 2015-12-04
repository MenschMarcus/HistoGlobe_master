window.HG ?= {}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##
## ## ## ##
## ##             STATIC PUBLIC

MIN_INTERVAL_INDEX = 0      # 0 = 1 Year | 1 = 2 Year | 2 = 5 Years | 3 = 10 Years | ...
INTERVAL_SCALE = 0.05       # higher value makes greater intervals between datemarkers
FADE_ANIMATION_TIME = 200   # fade in time for datemarkers and so

MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]

DATE_LOCALE = 'de-DE'
DATE_OPTIONS = {
  year: 'numeric',
  month: '2-digit',
  day: '2-digit'
}

class HG.Timeline

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##
  ## ## ## ##
  ## ##           PUBLIC

  constructor: (config) ->

    @_activeTopic = null
    @_dragged = false
    @topicsloaded = false
    @_timelineClicked = false

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onNowChanged"
    @addCallback "onIntervalChanged"
    @addCallback "onZoom"
    @addCallback "OnTopicsLoaded"

    defaultConfig =
      minYear: 1850
      maxYear: 2000
      nowYear: 1925
      minZoom: 1
      maxZoom: 7
      startZoom: 2
      topics: []
      dsvPaths: []
      rootDirs: []
      ignoredLines : []
      indexMappings: []
      delimiter: ","

    @_config = $.extend {}, defaultConfig, config

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

  hgInit: (hgInstance) ->
    @_hgInstance = hgInstance
    @_hgInstance.timeline = @

    @_config.minYear = @_hgInstance.getMinMaxYear()[0]
    @_config.maxYear = @_hgInstance.getMinMaxYear()[1]
    @_config.nowYear = @_hgInstance.getStartYear()

    @_HGContainer = @_hgInstance.getContainer()

    @_hgInstance.onAllModulesLoaded @, () =>
      @_hiventController = @_hgInstance.hiventController
      @notifyAll "onNowChanged", @_cropDateToMinMax @_now.date
      @notifyAll "onIntervalChanged", @_getTimeFilter()
      @_hgInstance.minGUIButton?.onRemoveGUI @, () ->
        @_hideCategories()

      @_hgInstance.minGUIButton?.onOpenGUI @, () ->
        @_showCategories()

      if @_hgInstance.zoom_buttons_timeline
        @_hgInstance.zoom_buttons_timeline.onZoomIn @, () =>
          @_zoom(1)
        @_hgInstance.zoom_buttons_timeline.onZoomOut @, () =>
          @_zoom(-1)

      # show or hide topic
      @_hgInstance.categoryFilter?.onFilterChanged @, (categoryFilter) =>
        @_unhighlightTopics()
        for topic in @_config.topics
          if categoryFilter[0] is topic.id
            @_switchTopic(topic)
            break

      @_hgInstance.timeline?.onNowChanged @, (date) =>
        @_now.dateField.innerHTML = date.toLocaleDateString DATE_LOCALE, DATE_OPTIONS

    @_parentDiv = @addUIElement "timeline-area", "timeline-area", @_HGContainer

    ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

    @_uiElements =
      tl:           @addUIElement "tl", "swiper-container", @_parentDiv
      tl_wrapper:   @addUIElement "tl_wrapper", "swiper-wrapper", tl
      tl_slide:     @addUIElement "tl_slide", "swiper-slide", tl_wrapper
      dateMarkers:  []

    ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

    @_now =
      date: @yearToDate(@_config.nowYear)
      marker: @addUIElement "now_marker_arrow_bottom", null, @_HGContainer
      dateField: @addUIElement "now_date_field", null, @_HGContainer

    ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

    # transition of timeline container with swiper.js
    #@_moveDelay = 0
    @_timeline_swiper ?= new Swiper '#tl',
      mode:'horizontal'
      freeMode: true
      momentumRatio: 0.5
      scrollContainer: true
      onTouchStart: =>
        @_dragged = false
        @_timelineClicked = true
        @_moveDelay = 0
      onTouchMove: =>
        @_dragged = true
        @_updateNowDate(@_moveDelay++ % 10 == 0)
        @_updateDateMarkers()
        @_updateTextInTopics()
      onTouchEnd: =>
        @_timelineClicked = false
      onSetWrapperTransition: (s, d) =>
        update_iteration_obj = setInterval =>
          @_updateNowDate(true)
          @_updateDateMarkers()
          @_updateTextInTopics()
        , 50
        setTimeout =>
          clearInterval(update_iteration_obj)
        , d

    ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

    #   ZOOM
    @_uiElements.tl.addEventListener "mousewheel", (e) =>
      e.preventDefault()
      @_zoom(e.wheelDelta, e)
    @_uiElements.tl.addEventListener "DOMMouseScroll", (e) =>
      e.preventDefault()
      @_zoom(-e.detail, e)

    ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

    $(window).resize  =>
      @_updateLayout()
      @_updateDateMarkers()
      @_updateTopics()
      @_updateNowDate()

    ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

    # Start the timeline here !!!
    @_uiElements.tl.style.display = "none"
    @_loadTopicsFromDSV( =>
      @_updateLayout()
      @_updateDateMarkers()
      @_updateTopics()
      @_updateTextInTopics()
      @_updateNowDate()
      categoryFilter = @_hgInstance.categoryFilter.getCurrentFilter()
      for topic in @_config.topics
        if categoryFilter[0] is topic.id

          #   switch topic
          #   Params: name of topic, setHash in URL?, move to Topic?
          @_switchTopic(topic)
          break
      @notifyAll "OnTopicsLoaded"
      @topicsloaded = true
      $(@_uiElements.tl).fadeIn()
    )

    # DIRTY HACK: at the end of everything, init now date again
    # and move the timeline, so the markers on the timeline are initially at the correct position
    setTimeout () =>
        @_updateNowDate()
      , 3000  # happy magic timeout

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

  _loadTopicsFromDSV: (callback = undefined) ->

    if @_config.dsvPaths?
      parse_config =
        delimiter: @_config.delimiter
        header: false

      pathIndex = 0
      for dsvPath in @_config.dsvPaths
        $.get dsvPath,
          (data) =>
            parse_result = $.parse data, parse_config
            for result, i in parse_result.results
              unless i+1 in @_config.ignoredLines

                # is head topic
                if result[@_config.indexMappings[pathIndex].subtopic_of] is ""
                  tmp_topic =
                    startDate: @stringToDate result[@_config.indexMappings[pathIndex].start]
                    endDate: @stringToDate result[@_config.indexMappings[pathIndex].end]
                    name: result[@_config.indexMappings[pathIndex].topic]
                    id: result[@_config.indexMappings[pathIndex].id]
                    token: result[@_config.indexMappings[pathIndex].token]
                    row: parseInt(result[@_config.indexMappings[pathIndex].row])
                    subtopics: []
                  @_config.topics.push tmp_topic

                # is subtopic
                else
                  for headtopic in @_config.topics
                    if headtopic.id == result[@_config.indexMappings[pathIndex].subtopic_of]
                      tmp_subtopic =
                        startDate: @stringToDate result[@_config.indexMappings[pathIndex].start]
                        endDate: @stringToDate result[@_config.indexMappings[pathIndex].end]
                        name: result[@_config.indexMappings[pathIndex].topic]
                        id: result[@_config.indexMappings[pathIndex].id]
                        token: result[@_config.indexMappings[pathIndex].token]
                      headtopic.subtopics.push tmp_subtopic

            if pathIndex == @_config.dsvPaths.length - 1
              callback() if callback?

            else pathIndex++

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

  # getter
  getTopics: =>
    @_config.topics
  getRowFromTopicId: (id) =>
    for tmp_topic in @_config.topics
      if tmp_topic.id is id
        return tmp_topic.row
        break
      else
        if tmp_topic.subtopics?
          for tmp_subtopic in tmp_topic.subtopics
            if id is tmp_subtopic.id
              return tmp_topic.row + 0.5
              break
    return -1
  getMinYear: =>
    @_config.minYear
  getMaxYear: =>
    @_config.maxYear
  getTimeInterval: ->
    intervalIndex = MIN_INTERVAL_INDEX
    while @timeInterval(intervalIndex) <= window.innerWidth * @millisPerPixel() * INTERVAL_SCALE
      intervalIndex++
    @timeInterval(intervalIndex)
  getLayout: ->
    @_uiElements
  getNowDate: ->
    @_now.date
  getNowMarker: ->
    @_now.marker
  getParentDiv: ->
    @_parentDiv
  getCanvas: ->
    @_uiElements.tl_slide

  _getTimeFilter: ->
    timefilter = []
    if @_activeTopic?
      timefilter.end = @_activeTopic.endDate
      timefilter.start = @_activeTopic.startDate
    else
      timefilter.end = @maxVisibleDate()
      timefilter.start = @minVisibleDate()
    timefilter.now = @_now.date
    timefilter

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

  millisPerPixel: ->
    mpp = (@yearsToMillis(@_config.maxYear - @_config.minYear) / window.innerWidth) / @_config.startZoom
  minVisibleDate: ->
    d = new Date(@_now.date.getTime() - (@millisPerPixel() * window.innerWidth / 2))
  maxVisibleDate: ->
    d = new Date(@_now.date.getTime() + (@millisPerPixel() * window.innerWidth / 2))
  timelineLength: ->
    @yearsToMillis(@_config.maxYear - @_config.minYear) / @millisPerPixel()
  timeInterval: (i) ->
    x = Math.floor(i/3)
    if i % 3 == 0
      return @yearsToMillis(Math.pow(10, x))
    if i % 3 == 1
      return @yearsToMillis(2 * Math.pow(10, x))
    if i % 3 == 2
      return @yearsToMillis(5 * Math.pow(10, x))
  dateToPosition: (date) ->
    dateDiff = date.getTime() - @yearToDate(@_config.minYear).getTime()
    pos = (dateDiff / @millisPerPixel()) + window.innerWidth/2

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

  moveToDate: (date, delay=0, successCallback=undefined) ->
    if @yearToDate(@_config.minYear).getTime() > date.getTime()
      @moveToDate @yearToDate(@_config.minYear), delay, successCallback
    else if @yearToDate(@_config.maxYear).getTime() < date.getTime()
      @moveToDate @yearToDate(@_config.maxYear), delay, successCallback
    else
      dateDiff = @yearToDate(@_config.minYear).getTime() - date.getTime()
      @_uiElements.tl_wrapper.style.transition =  delay + "s"
      @_uiElements.tl_wrapper.style.transform = "translate3d(" + dateDiff / @millisPerPixel() + "px ,0px, 0px)"
      @_uiElements.tl_wrapper.style.webkitTransform = "translate3d(" + dateDiff / @millisPerPixel() + "px ,0px, 0px)"
      @_uiElements.tl_wrapper.style.MozTransform = "translate3d(" + dateDiff / @millisPerPixel() + "px ,0px, 0px)"
      @_uiElements.tl_wrapper.style.MsTransform = "translate3d(" + dateDiff / @millisPerPixel() + "px ,0px, 0px)"
      @_uiElements.tl_wrapper.style.oTransform = "translate3d(" + dateDiff / @millisPerPixel() + "px ,0px, 0px)"

      @_now.date = @_cropDateToMinMax date

      @notifyAll "onNowChanged", @_now.date
      @notifyAll "onIntervalChanged", @_getTimeFilter()

      setTimeout(successCallback, delay * 1000) if successCallback?

  addUIElement: (id, className, parentDiv, type="div") ->
    container = document.createElement(type)
    container.id = id
    container.className = className if className?

    # hack to disable text select on timeline
    container.classList.add "no-text-select"

    parentDiv.appendChild container if parentDiv?
    container

  yearToDate: (year) ->
    date = new Date(0)
    date.setFullYear year
    date.setMonth 0
    date.setDate 1
    date.setHours 0
    date.setMinutes 0
    date.setSeconds 0
    date

  yearsToMillis: (year) ->
    millis = year * 365.25 * 24 * 60 * 60 * 1000

  monthsToMillis: (months) ->
    millis = months * 30 * 24 * 60 * 60 * 1000

  yearsToMonths: (years) ->
    months = Math.round(years * 12)

  millisToYears: (millis) ->
    year = millis / 1000 / 60 / 60 / 24 / 365.25

  millisToMonths: (millis) ->
    months = Math.round(millis / 1000 / 60 / 60 / 24 / 365.25 / 12)

  daysToMillis: (days) ->
    millis = days * 24 * 60 * 60 * 1000

  millisToDays: (millis) ->
    days = millis / 1000 / 60 / 60 / 24

  stringToDate: (string) ->
    res = (string + "").split(".")
    i = res.length
    d = new Date(1900, 0, 1)
    if i > 0
        d.setFullYear(res[i - 1])
    else
        alert "Error: were not able to convert string to date."
    if i > 1
        d.setMonth(res[i - 2] - 1)
    if i > 2
        d.setDate(res[i - 3])
    d

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##
  ## ## ## ##
  ## ##             PRIVATE

  # move and zoom
  _zoom: (delta, e=null, layout=true) =>
    zoomed = false
    if delta > 0
      if @millisToDays(@maxVisibleDate().getTime()) - @millisToDays(@minVisibleDate().getTime()) > @_config.maxZoom
        @_config.startZoom *= 1.1
        zoomed = true
    else
      if @_config.startZoom > @_config.minZoom
        @_config.startZoom /= 1.1
        zoomed = true

    if zoomed
      if layout
        @_updateLayout()
      @_updateTopics()
      @_updateDateMarkers()
      @_updateTextInTopics()
      @notifyAll "onZoom"
    zoomed

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

  #update
  _updateLayout: ->
    @_uiElements.tl.style.width       = window.innerWidth + "px"
    @_uiElements.tl_slide.style.width = (@timelineLength() + window.innerWidth) + "px"
    @_now.marker.style.left           = (window.innerWidth / 2) + "px"
    @_now.dateField.style.left        = (window.innerWidth / 2) + "px"
    @moveToDate(@_now.date, 0)
    @_timeline_swiper.reInit()

  _updateNowDate: (fireCallbacks = true) ->
    @_now.date = @_cropDateToMinMax new Date(@yearToDate(@_config.minYear).getTime() + (-1) * @_timeline_swiper.getWrapperTranslate("x") * @millisPerPixel())
    @_now.dateField.innerHTML = @_now.date.toLocaleDateString DATE_LOCALE, DATE_OPTIONS
    if fireCallbacks
      @notifyAll "onNowChanged", @_now.date
      @notifyAll "onIntervalChanged", @_getTimeFilter()

  _cropDateToMinMax: (date) ->
    if date.getFullYear() <= @_config.minYear
      date = @yearToDate @_config.minYear+1
    if date.getFullYear() > @_config.maxYear
      date = @yearToDate @_config.maxYear
    date

  _updateTopics:()->
    max_pos   = @dateToPosition(@maxVisibleDate())
    min_pos   = @dateToPosition(@minVisibleDate())

    for topic in @_config.topics
      end_pos   = @dateToPosition(topic.endDate)
      start_pos = @dateToPosition(topic.startDate)

      if !topic.div?
        topic.div = document.createElement("div")
        topic.div.id = "topic" + topic.id
        topic.div.className = "tl_topic tl_topic_row" + topic.row
        @getCanvas().appendChild topic.div

        if topic.subtopics?
          subtopics_element = document.createElement("div")
          subtopics_element.className = "tl_subtopics"
          topic.div.appendChild subtopics_element

          for subtopic in topic.subtopics
            subtopic.div = document.createElement("div")
            subtopic.div.id = "subtopic" + subtopic.id
            subtopic.div.className = "tl_subtopic"
            subtopic.div.innerHTML = subtopic.name
            $("#topic" + topic.id + " > .tl_subtopics" ).append subtopic.div

        topic.text_element = document.createElement("div")
        topic.text_element.id = 'topic_inner_' + topic.id
        topic.text_element.className = "topic_inner"
        topic.text_element.innerHTML = topic.name
        topic.div.appendChild topic.text_element

        #   onclick switch topic
        $(topic.div).on "mouseup", value: topic, (event) =>
          if @_timelineClicked and !@_dragged
            @_hgInstance.hiventInfoAtTag?.setOption 'event', 'noEvent'
            if @_activeTopic? and event.data.value.id is @_activeTopic.id
                @_hgInstance.hiventInfoAtTag?.setOption 'categories', 'noCategory'
                @_activeTopic = null
            else
              @_hgInstance.hiventInfoAtTag?.setOption 'categories', event.data.value.id
      topic.div.style.left = start_pos + "px"
      topic.div.style.width = (end_pos - start_pos) + "px"

      # update position of subtopics
      if topic.subtopics?
        for subtopic in topic.subtopics
          subtopic.div.style.left = ((subtopic.startDate.getTime() - topic.startDate.getTime()) / @millisPerPixel()) + "px"
          subtopic.div.style.width = (@dateToPosition(subtopic.endDate) - @dateToPosition(subtopic.startDate)) + "px"

  _textCutted: (element) ->
    $element = $(element)
    $c = $element.clone().css({display: 'inline', width: 'auto', visibility: 'hidden'}).appendTo('body')
    width = $c.width()
    $c.remove()
    return width > $element.width()

  _scaleTopicText: (topic, start_pos, end_pos, min_pos, max_pos) ->
    topic.text_element.style.width = (end_pos - start_pos) + "px"
    topic.text_element.style.marginLeft = "auto"
    if end_pos > max_pos and start_pos < min_pos
      topic.text_element.style.width = (max_pos - min_pos) + "px"
      topic.text_element.style.marginLeft = (min_pos - start_pos) + "px"
    else if end_pos > max_pos
      topic.text_element.style.width = (max_pos - start_pos) + "px"
    else if start_pos < min_pos
      topic.text_element.style.width = (end_pos - min_pos) + "px"
      topic.text_element.style.marginLeft = (min_pos - start_pos) + "px"

    if !(end_pos > max_pos and start_pos < min_pos)
      topic.text_element.innerHTML = topic.name
      topic.text_element.innerHTML = topic.token if @_textCutted topic.text_element

  _updateTextInTopics: () ->
    max_pos   = @dateToPosition(@maxVisibleDate())
    min_pos   = @dateToPosition(@minVisibleDate())

    for topic in @_config.topics
      start_pos = @dateToPosition(topic.startDate)#topic.div.offsetLeft
      end_pos   = @dateToPosition(topic.endDate)#topic.div.offsetLeft + topic.text_element.offsetWidth
      @_scaleTopicText topic, start_pos, end_pos, min_pos, max_pos

  _updateDateMarkers: ->

    interval = @getTimeInterval()

    # scale datemarker
    $(".tl_datemarker").css({"max-width": Math.round(interval / @millisPerPixel()) + "px"})

    max_year = @maxVisibleDate().getFullYear()
    min_year = @minVisibleDate().getFullYear()

    # for every year on timeline check if datemarker is needed
    # or can be removed.
    for i in [0..@_config.maxYear - @_config.minYear]
      year = @_config.minYear + i

      # fits year to interval?
      if year % @millisToYears(interval) == 0 and
      year >= min_year and
      year <= max_year

        # show datemarker
        if !@_uiElements.dateMarkers[i]?

          # create new
          @_uiElements.dateMarkers[i] =
            div: document.createElement("div")
            year: year
            months: []
          @_uiElements.dateMarkers[i].div.id = "tl_year_" + year
          @_uiElements.dateMarkers[i].div.className = "tl_datemarker"
          @_uiElements.dateMarkers[i].div.innerHTML = year + '<div class="tl_months"></div>'
          @_uiElements.dateMarkers[i].div.style.left = @dateToPosition(@yearToDate(year)) + "px"
          #@_uiElements.dateMarkers[i].div.style.display = "none"
          @getCanvas().appendChild @_uiElements.dateMarkers[i].div

          # show and create months
          if @millisToYears(interval) == 1
            for month_name, key in MONTH_NAMES
              month =
                div: document.createElement("div")
                startDate: new Date()
                endDate: new Date()
                name: month_name
              month.startDate.setFullYear(year, key, 1)
              month.endDate.setFullYear(year, key + 1, 0)
              month.div.className = "tl_month"
              month.div.innerHTML = month.name
              month.div.style.left = ((month.startDate.getTime() - @yearToDate(year).getTime()) / @millisPerPixel()) + "px"
              month.div.style.width = (@dateToPosition(month.endDate) - @dateToPosition(month.startDate)) + "px"
              $("#tl_year_" + year + " > .tl_months" ).append month.div
              @_uiElements.dateMarkers[i].months[key] = month

          # hide and delete months
          else
            for months in @_uiElements.dateMarkers[i].months
              $(month.div).fadeOut(FADE_ANIMATION_TIME, `function() { $(this).remove(); }`)
            @_uiElements.dateMarkers[i].months.length = 0
          $(@_uiElements.dateMarkers[i].div).fadeIn(FADE_ANIMATION_TIME)
        else

          # update existing datemarker and his months
          @_uiElements.dateMarkers[i].div.style.left = @dateToPosition(@yearToDate(year)) + "px"
          if @millisToYears(interval) == 1

            # show months, create new month divs
            if @_uiElements.dateMarkers[i].months.length == 0
              for month_name, key in MONTH_NAMES
                month =
                  div: document.createElement("div")
                  startDate: new Date()
                  endDate: new Date()
                  name: month_name
                month.startDate.setFullYear(year, key, 1)
                month.endDate.setFullYear(year, key + 1, 0)
                month.div.className = "tl_month"
                month.div.innerHTML = month.name
                month.div.style.left = ((month.startDate.getTime() - @yearToDate(year).getTime()) / @millisPerPixel()) + "px"
                month.div.style.width = (@dateToPosition(month.endDate) - @dateToPosition(month.startDate)) + "px"
                $("#tl_year_" + year + " > .tl_months" ).append month.div
                @_uiElements.dateMarkers[i].months[key] = month

            # update existing month divs
            else
              for month in @_uiElements.dateMarkers[i].months
                month.div.style.left = ((month.startDate.getTime() - @yearToDate(year).getTime()) / @millisPerPixel()) + "px"
                month.div.style.width = (@dateToPosition(month.endDate) - @dateToPosition(month.startDate)) + "px"

          # hide and delete months
          else
            for month in @_uiElements.dateMarkers[i].months
              $(month.div).fadeOut(FADE_ANIMATION_TIME, `function() { $(this).remove(); }`)
            @_uiElements.dateMarkers[i].months.length = 0

      # hide and delete datemarker and their months
      else
        if @_uiElements.dateMarkers[i]?
          @_uiElements.dateMarkers[i].div.style.left = @dateToPosition(@yearToDate(year)) + "px"
          #$(@_uiElements.dateMarkers[i].div).fadeOut(FADE_ANIMATION_TIME, `function() { $(this).remove(); }`)
          $(@_uiElements.dateMarkers[i].div).remove()
          @_uiElements.dateMarkers[i] = null


  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

  _unhighlightTopics: ->
    for topic in @_config.topics
      topic.div.className = "tl_topic tl_topic_row" + topic.row
    @_moveTopicRows(false)
    #@_hgInstance.hiventInfoAtTag?.unsetOption 'event'

  _switchTopic: (topic_tmp) ->

    # calculate date at center of topic
    diff = topic_tmp.endDate.getTime() - topic_tmp.startDate.getTime()
    millisec = diff / 2 + topic_tmp.startDate.getTime()
    middleDate = new Date(millisec)

    # set all topics as default and choosed as highlighted
    @_unhighlightTopics()
    topic_tmp.div.className = "tl_topic_highlighted tl_topic_row" + topic_tmp.row

    # make topic active (also set in url)
    @_activeTopic = topic_tmp

    # move row so that subtopics can be shown
    @_moveTopicRows(true)

    # move timeline to center of topic bar
    # at the end of transition zoom in
    @moveToDate middleDate, 1, =>
      if @_activeTopic.endDate > @maxVisibleDate() || @_activeTopic.startDate < @minVisibleDate()

        # use setInterval to zoom in repeatly
        # if zoom should stop call clearInterval(obj)
        repeatObj = setInterval =>
          if @_activeTopic? and (@_activeTopic.endDate > (new Date(@maxVisibleDate().getTime() - (@maxVisibleDate().getTime() - @minVisibleDate().getTime()) * 0.1)) or
          @_activeTopic.startDate < (new Date(@minVisibleDate().getTime() + (@maxVisibleDate().getTime() - @minVisibleDate().getTime()) * 0.1)))
            @_zoom -1
          else
            clearInterval(repeatObj)
        , 50
      else
        repeatObj = setInterval =>
          if @_activeTopic? and (@_activeTopic.endDate < (new Date(@maxVisibleDate().getTime() - (@maxVisibleDate().getTime() - @minVisibleDate().getTime()) * 0.1)) and
          @_activeTopic.startDate > (new Date(@minVisibleDate().getTime() + (@maxVisibleDate().getTime() - @minVisibleDate().getTime()) * 0.1)))
            @_zoom 1
          else
            clearInterval(repeatObj)
        , 50

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

  _moveTopicRows: (showSubtopics) ->
    if !showSubtopics
      $('.tl_topic_row1').css({'bottom': HGConfig.timeline_row1_position.val + 'px'})
    else if @_activeTopic.row is 0 and showSubtopics
      $('.tl_topic_row1').css({'bottom': HGConfig.timeline_row1_position_up.val + 'px'})

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

  _disableTextSelection : (e) ->  return false
  _enableTextSelection : () ->    return true

  _hideCategories: () ->
    $('.tl_topic, .tl_topic_highlighted ').fadeTo(500,0, () ->
      $('.tl_topic, .tl_topic_highlighted ').css("visibility", "hidden") )
    $('[class*="hivent_marker_timeline"]').css("bottom","45px")
  _showCategories: () ->
    category= @_hgInstance.categoryFilter.getCurrentFilter()
    @_hgInstance.categoryFilter.setCategory "noCategory"
    @_hgInstance.categoryFilter.setCategory category
    $('.tl_topic, .tl_topic_highlighted ').css("visibility", "visible")
    $('.tl_topic, .tl_topic_highlighted').fadeTo(500,1)
