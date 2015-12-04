window.HG ?= {}

class HG.EventTicker

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      icon: ""
      name: ""
      messages: []

    @_config = $.extend {}, defaultConfig, config

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    HG.Widget.call @, @_config

  # ============================================================================
  hgInit: (hgInstance) ->
    #super hgInstance

    @_timeline = hgInstance.timeline
    @_timeline.onNowChanged @, @_nowChanged

    @_div           = document.createElement("div")
    @_div.id        = "event_ticker_container"
    @_div.className = "event_ticker_container"

    @_messages = []

    for message, index in @_config.messages
      @_messages.push @_addMessage message, index

    $("body").append @_div

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _addMessage: (message, index) ->

    messageDiv           = document.createElement("div")
    messageDiv.id        = "event_ticker_message_" + index
    messageDiv.className = "event_ticker_message"
    messageDiv.innerHTML = message.text

    @_div.appendChild messageDiv

    retMessage =
      div: messageDiv
      text: message.text
      date: @_timeline.stringToDate message.date

  # ============================================================================
  _nowChanged: (now) =>
    for message in @_messages
      if @compareDates message.date, now
        $(message.div).fadeIn(1500)
      else
        $(message.div).fadeOut(1500)

  # ============================================================================
  compareDates: (date1, date2) ->
    if date1.getFullYear() == date2.getFullYear() && date1.getMonth() == date2.getMonth()
      return true
    else
      return false


