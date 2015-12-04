
window.HG ?= {}

class HG.CrowdMarker2D

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================

  constructor: (crowd, display, map, timeline) ->

    @_crowd = crowd
    @_display = display
    @_map = map
    @_timeline = timeline
    @_flag = null
    @_startCircle = null
    @_circle = null
    @_line = null
    @_lines = []
    @_ghostLine = null
    @_ghostCircles = []
    @_visitedLocationsDrawn = [] # ?
    @_onMap = false
    @_fadingOut = false
    @_drawnLocations = []
    @_lineDrawn = false
    @_circleDrawn = false
    @_isActive = false

    @_initMarker()
    @.update()

    @_icon = new L.Marker @_crowd.getLocations()[0], {
          icon: @_currentIcon,
          opacity: 0
        }
    @_icon.on "drag", @_onMouseMove
    @_icon.on "mousedown", @_onMouseDown
    @_icon.on "dragend", @_onMouseUp
    #@_icon.on "click", @_onMouseUp
    @_icon.options.draggable = true

  # ============================================================================
  getCrowd: ->
    @_crowd

  # ============================================================================

  update: ->

    # crowd not visible
    if @_crowd.getStartTime().getTime() > @_crowd.getDate().getTime() || @_crowd.getEndTime().getTime() < @_crowd.getDate().getTime()
      if @_onMap

        fadeOut = (opacity) =>
          @_fadingOut = true
          if opacity>=0.000001
            if @_crowd.getStartTime().getTime() > @_crowd.getDate().getTime() || @_crowd.getEndTime().getTime() < @_crowd.getDate().getTime()
              @_flag.setOpacity opacity
              @_icon.setOpacity opacity
              @_line.setStyle({opacity:@_line.options.opacity/1.5}) if @_line

              for line in @_lines
                line.setStyle({opacity:line.options.opacity/1.5}) if line

              @_circle.setStyle({opacity:@_circle.options.opacity/1.5, fillOpacity:@_circle.options.fillOpacity/1.5})
              @_startCircle.setStyle({opacity:@_startCircle.options.opacity/1.5, fillOpacity:@_startCircle.options.fillOpacity/1.5})
              setTimeout -> 
                fadeOut(opacity/1.5)
              ,50
            else @_fadingOut = false
          else
            @_removeCrowd()
            @_fadingOut = false

        # translate to end point before fading out
        locations =  @_crowd.getLocations()
        if @_crowd.getEndTime().getTime() > @_crowd.getDate().getTime()
          cur_loc = locations[0]
          @_translateCrowd cur_loc
        else
          cur_loc = locations[locations.length-1]
          @_translateCrowd cur_loc

        fadeOut(1/1.5) if not @_fadingOut

        #@_flag.setOpacity 0
        #@_icon.setOpacity 0
        ##setTimeout @_removeCrowd,0 # produces bugs!!!
        #@_removeCrowd()
        #@_onMap = false

    else
      # crowd visible
      @_currentLocation = @_crowd.getLocation()
      @_setActualSizes()
      
      if @_onMap is false

        @_flag = new L.Marker @_currentLocation, {
          icon: @_currentFlag,
          opacity: 0
        }
        @_flag.addTo @_map

        if @_icon == null
          @_icon = new L.Marker @_currentLocation, {
            icon: @_currentIcon,
            opacity: 0,
            draggable: true
          }
          @_icon.on "drag", @_onMouseMove
          @_icon.on "mousedown", @_onMouseDown
          @_icon.on "dragend", @_onMouseUp
          @_icon.options.draggable = true
        #@_icon.bindPopup @_getInfo()
        @_icon.addTo @_map

        @_startCircle = new L.circleMarker @_crowd.getLocations()[0], {
          color: 'grey',
          radius: @_crowd.getRadius(0)
        }
        @_startCircle.addTo @_map
        @_startCircle.bindPopup @_getStartInfo()

        @_circle = new L.circleMarker @_currentLocation, {
          color: 'grey',
          radius: @_crowd.getRadius()
        }
        @_circle.addTo @_map
        #@_circleDrawn = true

        CROWDS_ON_MAP.push @_crowd
        @_onMap = true

      else # set to new position

        #if @_isActive
          #@_circle.setStyle {fillColor: 'red', color: 'red'}
        #else
          #@_circle.setStyle {fillColor: 'grey', color: 'grey'}

        if @_flag.options.opacity < 1
          @_flag.setOpacity 1
          @_icon.setOpacity 1
          @_line.setStyle({opacity:1.0}) if @_line

          for line in @_lines
            line.setStyle({opacity:1.0}) if line

          @_circle.setStyle({opacity:0.5, fillOpacity:0.2})
          @_startCircle.setStyle({opacity:0.5, fillOpacity:0.2})

        @_translateCrowd @_currentLocation
        #@_icon.bindPopup @_getInfo()
        
  
  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _onMouseDown: (e) =>
    #if @_isActive
    #  @_circle.setStyle {fillColor: 'grey', color: 'grey'}
    #  @_isActive = false
    #else
    #  @_circle.setStyle {fillColor: 'red', color: 'red'}
    #  @_isActive = true
    @_drawGhostPolyline()

    @_drawGhostCircles()

    @_icon.on "drag", @_onMouseMove

  # ============================================================================
  _onMouseUp: (e) =>

    @_icon.off "drag", @_onMouseMove
    @_icon.off "mousedown", @_onMouseDown
    @_icon.off "dragend", @_onMouseUp
    # set to next real location
    index = @_crowd._getNearestIndex()

    goal_time = @_crowd.getTimesForRealLocations()[index]

    goToNextLocation = (goal_time, dir) =>
      index = @_crowd._getIndexForInterpolated()
      next_time = @_crowd.getTimesForLocations()[index+dir]
      if next_time*dir < goal_time*dir
        @_timeline.moveToDate(next_time)
        setTimeout -> 
          goToNextLocation(goal_time,dir)
        ,50
      else
        @_timeline.moveToDate(goal_time)
        @_icon.on "mousedown", @_onMouseDown
        @_icon.on "dragend", @_onMouseUp
        @_removeGhostPolyline()
        @_removeGhostCircles()

    if goal_time <= @_timeline.getNowDate()
      goToNextLocation(goal_time,-1)
    else
      goToNextLocation(goal_time,+1)


  # ============================================================================
  _onMouseMove: (e) =>

    location_ids = []
    locations = @_crowd.getLocations()

    #cur_index = null
    #if @_lastLocationIndex is null
    cur_index =  @_crowd.getInterpolatedTimeIndex()
    #else
    #  cur_index = @_lastLocationIndex

    #just check direct neighborhood:
    if cur_index > 0
      location_ids.push(cur_index-1)
    location_ids.push(cur_index)
    if cur_index < locations.length-1
      location_ids.push(cur_index+1)
    
    min_dist = 999999
    nearestLocationID = null
    cur_latlng = @_icon._latlng

    for i in location_ids
      candidatePos = locations[i]
      dist = Math.sqrt(Math.pow(cur_latlng.lat-candidatePos.lat,2) + Math.pow(cur_latlng.lng-candidatePos.lng,2))
      
      if dist < min_dist
        min_dist = dist
        nearestLocationID = i

    if nearestLocationID != null
      times = @_crowd.getTimesForLocations()

      @_timeline.moveToDate(times[nearestLocationID])
      @_lastLocationIndex = nearestLocationID


  # ============================================================================
  _initMarker: ->

    if @_crowd.getNation() == "Deutschland"
      @_currentFlag = new L.DivIcon {
        className: "crowd_marker_2D_flag"
      }
    if @_crowd.getNation() == "Frankreich"
      @_currentFlag = new L.DivIcon {
        className: "crowd_marker_2D_flag2"
      }

    @_currentIcon = new L.DivIcon {
      className: "crowd_marker_2D_soldier"
    }

    locations = @_crowd.getLocations()
    @_ghostLine = new L.polyline locations, { color: 'grey', opacity: 1, weight: 2, clickable: false, dashArray:"1, 5" }

    for i in [0...@_crowd.getRealLocations().length]
      @_ghostCircles.push new L.circleMarker @_crowd.getRealLocations()[i], {
                            color: 'grey',
                            radius: @_crowd.getRadius(i),
                            dashArray:"1, 5"
                          }

  # ============================================================================
  _getInfo: ->
    info = @_crowd.getInfo() + "<br> (" + @_crowd.getNation() + ") <br> Truppenstärke: " + @_crowd.getSize()

  # ============================================================================
  _getStartInfo: -> # info popup for start circle
    day = @_crowd.getStartTime().getDate()
    if day < 10
      day = "0" + day
    month = @_crowd.getStartTime().getMonth() + 1
    if month < 10
      month = "0" + month
    year = @_crowd.getStartTime().getFullYear()
    info = @_crowd.getInfo() + "<br> (" + @_crowd.getNation() + ") <br> Truppenstärke: " + @_crowd.getSizes()[0] + "<br> " + day + "." + month + "." + year + " (" + @_crowd.getStartLocation() + ")"

  # ============================================================================
  _removeCrowd: =>
    #if @_icon? and @_icon.options.opacity == 0
    @_map.removeLayer @_icon if @_icon?
    @_icon = null
    @_map.removeLayer @_flag if @_flag?
    @_flag = null
    @_removeLine()
    @_drawnLocations = []
    @_map.removeLayer @_startCircle if @_startCircle?
    @_map.removeLayer @_circle if @_circle?
    @_circle = null
    @_crowd.clearVisitedLocations()
    @_visitedLocationsDrawn = []
    index = 0
    for crowd in CROWDS_ON_MAP
      if crowd is @_crowd
        CROWDS_ON_MAP.splice(index,1)
      index++
    @_circleDrawn = false
    #@_removeCounter = 0
    @_onMap = false
    #else
    #   setTimeout @_removeCrowd,10

  # ============================================================================
  _removeLine: =>
    @_map.removeLayer @_line if @_line?
    @_line = null

    for line in @_lines
      @_map.removeLayer line if line?
    @_lines = []
    @_lineDrawn = false

  # ============================================================================
  _setActualSizes: ->
    size = @_crowd.getPercentageSize() * MAX_ICON_SIZE
    size = MIN_ICON_SIZE if size < MIN_ICON_SIZE
    radius = Math.max size/2,5
    if !isNaN(radius) and @_circle?
      @_circle.setRadius radius
    actualSize = new L.Point(size, size)
    @_currentFlag.options.iconSize = actualSize
    @_currentIcon.options.iconSize = actualSize

  # ============================================================================
  _drawGhostPolyline: ->
    @_ghostLine.addTo @_map

  # ============================================================================
  _drawGhostCircles: ->
    for circle in @_ghostCircles
      circle.addTo @_map

  # ============================================================================
  _removeGhostPolyline: ->
    @_map.removeLayer @_ghostLine if @_ghostLine?

  # ============================================================================
  _removeGhostCircles: ->
    for circle in @_ghostCircles
      @_map.removeLayer circle if circle?

  # ============================================================================
  _drawPolyline: ->
    locations = @_crowd.getLocations()
    times = @_crowd.getTimesForLocations()
    drawnLocations = 0
    date = @_crowd.getDate()

    if @_drawnLocations.length < 2
      @_removeLine()
      index = 0
      while index < times.length and times[index].getTime() <= date.getTime() 
        if locations[index] not in @_drawnLocations
          @_drawnLocations.push locations[index]
        index++    

    if @_drawnLocations.length >= 2
      if not @_lineDrawn
        @_line = new L.polyline @_drawnLocations, { color: 'grey', opacity: 1, weight: 2, clickable: false }
        @_line.addTo @_map
        @_lineDrawn = true

        # line segments:
        for i in [1..@_drawnLocations.length-1]
          #size = @_crowd.getInterpolatedSizes()[i-1]/2400 # minard line segments
          size = 2
          tmp_line = new L.polyline [@_drawnLocations[i-1],@_drawnLocations[i]], { color: 'grey', opacity: 1, weight: size, clickable: false }
          tmp_line.addTo @_map
          @_lines.push tmp_line
        
      index = 0
      while index < times.length and times[index].getTime() <= date.getTime()
        if locations[index] not in @_drawnLocations
          @_line.addLatLng locations[index]
          @_drawnLocations.push locations[index]

          # line segments:
          if index>0
            #size = @_crowd.getInterpolatedSizes()[index-1]/2400 # minard line segments
            size = 2
            tmp_line =  new L.polyline [@_drawnLocations[index-1],@_drawnLocations[index]], { color: 'grey', opacity: 1.0, weight: size, clickable: false }
            tmp_line.addTo @_map
            @_lines.push tmp_line

        index++

      if index < @_drawnLocations.length
        @_line.spliceLatLngs(index, @_drawnLocations.length-index)

        # line segments:
        for i in [index-1 .. @_lines.length-1]
          @_map.removeLayer @_lines[i] if @_lines[i]?
        @_lines.splice(index-1, @_lines.length-index+1)

        @_drawnLocations.splice(index, @_drawnLocations.length-index)

  # ============================================================================
  _translateCrowd: (location) ->
    
    @_flag.setIcon @_currentFlag
    @_icon.setIcon @_currentIcon
    @_flag.setLatLng location
    @_icon.setLatLng location
    @_circle.setLatLng location
    @_crowd.getRadius() ? @_circle.setRadius @_crowd.getRadius()
    visitedLocations = @_crowd.getVisitedLocations()
    actualLocation = visitedLocations[visitedLocations.length-1]
    if actualLocation not in @_visitedLocationsDrawn
      #@_line.addLatLng actualLocation
      @_visitedLocationsDrawn.push actualLocation

    @_drawPolyline()

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

  CROWDS_ON_MAP = []
  MIN_ICON_SIZE = 20
  MAX_ICON_SIZE = 500