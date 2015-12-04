window.HG ?= {}

class HG.VideoPlayer

  constructor: (divID) ->
    @_player = new YT.Player(divID, {events: {'onReady': @_onPlayerReady}})

  stopVideo: ->
    @_player.pauseVideo()

  _onPlayerReady: (event) ->
    event.target.playVideo()
