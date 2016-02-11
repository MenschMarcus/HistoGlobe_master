window.HG ?= {}

# currently trash place for everything related to topics
# TODO: cleanup in the end if time

class HG.TopicController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->

    defaultConfig =
      topics: []
      dsvPaths: []
      rootDirs: []
      ignoredLines : []
      indexMappings: []
      delimiter: ","

    @_config = $.extend {}, defaultConfig, config

    # this part was in Timeline.coffee
      # show or hide topic
      # @_hgInstance.categoryFilter?.onFilterChanged @, (categoryFilter) =>
      #   @_unhighlightTopics()
      #   for topic in @_config.topics
      #     if categoryFilter[0] is topic.id
      #       @_switchTopic(topic)
      #       break

    @_uiElements.tl.style.display = "none"
    # @_loadTopicsFromDSV( =>
    @_updateLayout()
    @_updateDateMarkers()
    # @_updateTopics()
    # @_updateTextInTopics()
    @_updateNowDate()
    # categoryFilter = @_hgInstance.categoryFilter.getCurrentFilter()
    # for topic in @_config.topics
    #   if categoryFilter[0] is topic.id

    #     #   switch topic
    #     #   Params: name of topic, setHash in URL?, move to Topic?
    #     @_switchTopic(topic)
    #     break
    # @notifyAll "OnTopicsLoaded"
    # @_topicsLoaded = true
    $(@_uiElements.tl).fadeIn()
    # )

    # DIRTY HACK: at the end of everything, init now date again
    # and move the timeline, so the markers on the timeline are initially at the correct position
    setTimeout () =>
        @_updateNowDate()
      , 3000  # happy magic timeout


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



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================

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


  _updateTopics:()->
    max_pos   = @_dateToPosition(@_maxVisibleDate())
    min_pos   = @_dateToPosition(@_minVisibleDate())

    for topic in @_config.topics
      end_pos   = @_dateToPosition(topic.endDate)
      start_pos = @_dateToPosition(topic.startDate)

      if !topic.div?
        topic.div = document.createElement("div")
        topic.div.id = "topic" + topic.id
        topic.div.className = "tl_topic tl_topic_row" + topic.row
        @getSlider().dom().appendChild topic.div

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
          subtopic.div.style.left = ((subtopic.startDate.getTime() - topic.startDate.getTime()) / @_millisPerPixel()) + "px"
          subtopic.div.style.width = (@_dateToPosition(subtopic.endDate) - @_dateToPosition(subtopic.startDate)) + "px"

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
    max_pos   = @_dateToPosition(@_maxVisibleDate())
    min_pos   = @_dateToPosition(@_minVisibleDate())

    for topic in @_config.topics
      start_pos = @_dateToPosition(topic.startDate)#topic.div.offsetLeft
      end_pos   = @_dateToPosition(topic.endDate)#topic.div.offsetLeft + topic.text_element.offsetWidth
      @_scaleTopicText topic, start_pos, end_pos, min_pos, max_pos



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
    @_moveToDate middleDate, 1, =>
      if @_activeTopic.endDate > @_maxVisibleDate() || @_activeTopic.startDate < @_minVisibleDate()

        # use setInterval to zoom in repeatly
        # if zoom should stop call clearInterval(obj)
        repeatObj = setInterval =>
          if @_activeTopic? and (@_activeTopic.endDate > (new Date(@_maxVisibleDate().getTime() - (@_maxVisibleDate().getTime() - @_minVisibleDate().getTime()) * 0.1)) or
          @_activeTopic.startDate < (new Date(@_minVisibleDate().getTime() + (@_maxVisibleDate().getTime() - @_minVisibleDate().getTime()) * 0.1)))
            @_zoom -1
          else
            clearInterval(repeatObj)
        , 50
      else
        repeatObj = setInterval =>
          if @_activeTopic? and (@_activeTopic.endDate < (new Date(@_maxVisibleDate().getTime() - (@_maxVisibleDate().getTime() - @_minVisibleDate().getTime()) * 0.1)) and
          @_activeTopic.startDate > (new Date(@_minVisibleDate().getTime() + (@_maxVisibleDate().getTime() - @_minVisibleDate().getTime()) * 0.1)))
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



  _hideTopicBars: () ->
    $('.tl_topic, .tl_topic_highlighted ').fadeTo(500,0, () ->
      $('.tl_topic, .tl_topic_highlighted ').css("visibility", "hidden") )
    $('[class*="hivent_marker_timeline"]').css("bottom","45px")
  _showTopicBars: () ->
    category= @_hgInstance.categoryFilter.getCurrentFilter()
    @_hgInstance.categoryFilter.setCategory "noCategory"
    @_hgInstance.categoryFilter.setCategory category
    $('.tl_topic, .tl_topic_highlighted ').css("visibility", "visible")
    $('.tl_topic, .tl_topic_highlighted').fadeTo(500,1)

