window.HG ?= {}


class HG.HiventMarkerRegion extends HG.HiventMarker
	constructor: (hiventHandle, display, map) ->

    #Call HiventMarker Constructor
    HG.HiventMarker.call @, hiventHandle, map.getPanes()["popupPane"]

    @hivent=hiventHandle.getHivent()
    @hiventHandle=hiventHandle
    @hiventHandle.regionMarker=@
    @_locationName = @hivent.locactionName

    @_map =display._map
    @_display=display
    @_marker= L.polygon @hivent.region
    @_marker.options.stroke=false
    @_marker.addTo @_map
    #set opacity to 0 as default, so it can be shown when hivent activates
    @_marker.setStyle({fillOpacity:0})
    @_marker.myHiventMarkerRegion = @
    @_position = new L.Point @hivent.long[0],@hivent.lat[0]
    @_updatePosition()

  	#Event Listeners
    @_marker.on "mouseover", @_onMouseOver
    @_marker.on "mouseout", @_onMouseOut
    @_marker.on "click", @_onClick
    @_map.on "zoomend", @_updatePosition
    @_map.on "dragend", @_updatePosition
    @_map.on "viewreset", @_updatePosition

    @getHiventHandle().onFocus(@, (mousePos) =>
      if @_display.isRunning()
        @_display.focus @getHiventHandle().getHivent()
    )

    @getHiventHandle().onActive(@, (mousePos) =>      
      @_map.on "drag", @_updatePosition
      @makeVisible()
    )

    @getHiventHandle().onInActive(@, (mousePos) =>
      @_map.off "drag", @_updatePosition
      @makeInvisible
    )

    @getHiventHandle().onLink(@, (mousePos) =>
     
      #@_marker.setIcon icon_higlighted
    )

    @getHiventHandle().onUnLink(@, (mousePos) =>
      #@_marker.setIcon icon_default
    )

    @getHiventHandle().onAgeChanged @, (age) =>
      #opacityRegulator=0.5
      #regionOpacity=age*opacityRegulator
      #@_marker.setStyle({fillOpacity:regionOpacity})
      0

    @getHiventHandle().onDestruction @, @_destroy
    @getHiventHandle().onVisibleFuture @, @_destroy
    @getHiventHandle().onInvisible @, @_destroy

    @addCallback "onMarkerDestruction"

  # ============================================================================
  getPosition: ->
    {
      long: @hivent.long[0]
      lat: @hivent.lat[0]
    }

  # ============================================================================
  getDisplayPosition: ->
    @pos = @_map.layerPointToContainerPoint(new L.Point @_position.x, @_position.y )
    return @pos

  makeVisible:->    
    @_marker.setStyle({fillOpacity:0.5})

  makeInvisible:->
    @_marker.setStyle({fillOpacity:0})

  highlight: ->
    @_marker.setStyle({fillColor: "#ff33ff"})


  unHiglight: ->
    @_marker.setStyle({fillColor:"#0033ff"})
  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _onMouseOver: (e) =>
    @highlight()
    @getHiventHandle().mark @, @_position
    @getHiventHandle().linkAll @_position

  # ============================================================================
  _onMouseOut: (e) =>
    @unHiglight()
    @getHiventHandle().unMark @, @_position
    @getHiventHandle().unLinkAll @_position

  # ============================================================================
  _onClick: (e) =>
    @getHiventHandle().toggleActive @, @getDisplayPosition()

  # ======================re======================================================
  _updatePosition: =>
    helperMarker=L.marker([@hivent.long[0],@hivent.lat[0]])
    @_position = @_map.latLngToLayerPoint helperMarker.getLatLng()
    displayPosition=@getDisplayPosition()
    @notifyAll "onPositionChanged", displayPosition

  # ============================================================================
  _destroy: =>

    @notifyAll "onMarkerDestruction"
    @_map.removeLayer @_marker
    @getHiventHandle().inActiveAll()
    @_marker.off "mouseover", @_onMouseOver
    @_marker.off "mouseout", @_onMouseOut
    @_marker.off "click", @_onClick
    @_map.off "zoomend", @_updatePosition
    @_map.off "dragend", @_updatePosition
    @_map.off "drag", @_updatePosition
    @_map.off "viewreset", @_updatePosition
    @_hiventHandle.removeListener "onFocus", @
    @_hiventHandle.removeListener "onActive", @
    @_hiventHandle.removeListener "onInActive", @
    @_hiventHandle.removeListener "onLink", @
    @_hiventHandle.removeListener "onUnLink", @
    @_hiventHandle.removeListener "onInvisible", @
    @_hiventHandle.removeListener "onVisibleFuture", @
    @_hiventHandle.removeListener "onDestruction", @

    super()
    delete @

    return


