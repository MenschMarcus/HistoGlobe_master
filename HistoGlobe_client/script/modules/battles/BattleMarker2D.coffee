window.HG ?= {}

class HG.BattleMarker2D

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================

  constructor: (battle, display, map) ->

    @_battle = battle
    @_display = display
    @_map = map
    @_circleMarker = null
    @_circleIcon = null
    @_onMap = false
    @_icon = null

    @_initMarker()

  # ============================================================================
  getBattle: ->
    @_battle

  # ============================================================================
  update: ->

    if @_battle.getStartTime().getTime() > @_battle.getDate().getTime() || @_battle.getEndOfWar().getTime() < @_battle.getDate().getTime()
      if @_onMap
        @_circleIcon.setOpacity 0
        setTimeout @_removeBattle,0 # produces bugs!!!
        @_onMap = false
    
    else
      if @_onMap is false
        @_initMarker()
        @_circleIcon.addTo @_map
        @_circleMarker.addTo @_map
        @_onMap = true
      else
        if @_circleIcon.options.opacity < 1
          @_circleIcon.setOpacity 1
        
    
  
  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _initMarker: ->
    
    if @_icon == null
      @_icon = new L.DivIcon {
        className: "battle_marker_2D_icon"
      }
      @_icon.options.iconSize = new L.Point(25,25)
    if @_circleIcon == null
      @_circleIcon = new L.Marker @_battle.getLocation(), {
          icon: @_icon,
          opacity: 0
        }
      @_circleIcon.bindPopup @_getInfo()
    if @_circleMarker == null
      @_circleMarker = new L.CircleMarker @_battle.getLocation(), {
          color: 'black',
          radius: 8
        }

  # ============================================================================
  _removeBattle: =>
    if @_circleIcon? and @_circleIcon.options.opacity == 0
      @_map.removeLayer @_circleIcon
      @_circleIcon = null
      @_map.removeLayer @_circleMarker
      @_circleMarker = null
      

  # ============================================================================
  _getInfo: ->
    start = @_battle.getStartTime()
    end = @_battle.getEndTime()
    @_battle.getName() + "<br>" + start.getDate() + "." + (start.getMonth()+1) + "." + start.getFullYear() + " - " + end.getDate() + "." + (end.getMonth()+1) + "." + end.getFullYear() 
