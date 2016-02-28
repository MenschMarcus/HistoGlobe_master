window.HG ?= {}

class HG.HiventsOnGlobe

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    @_globe                   = null

    @_hiventController        = null
    @_hiventMarkers           = []
    @_hiventMarkerGroups      = []
    @_onMarkerAddedCallbacks  = []

    @_hiventLogos             = []

    @_lastIntersected         = []

    @_sceneInterface          = new THREE.Scene

    @_backupFOV               = null
    @_backupZoom              = null
    @_backupCenter            = null

    @_hgInstance              = null

    @_intersected             = false

  # ============================================================================
  hgInit: (hgInstance) ->

    @_hgInstance = hgInstance

    hgInstance.hiventsOnGlobe = @

    if hgInstance.categoryIconMapping
      for category in hgInstance.categoryIconMapping.getCategories()
        icons = hgInstance.categoryIconMapping.getIcons(category)
        @_hiventLogos[category] = THREE.ImageUtils.loadTexture(icons["default"])
        @_hiventLogos[category+"_highlighted"] = THREE.ImageUtils.loadTexture(icons["highlighted"])
        @_hiventLogos["group_default"] = THREE.ImageUtils.loadTexture(icons["group_default"])
        @_hiventLogos["group_highlighted"] = THREE.ImageUtils.loadTexture(icons["group_highlighted"])

    #console.log "@_hiventLogos ",@_hiventLogos


    @_globeCanvas = hgInstance._map_canvas

    @_globe = hgInstance.globe

    @_hiventController = hgInstance.hiventController

    if @_globe
      @_globe.onLoaded @, @_initHivents

    else
      console.log "Unable to show hivents on Globe: Globe module not detected in HistoGlobe instance!"

  # ============================================================================
  onMarkerAdded: (callbackFunc) ->
    if callbackFunc and typeof(callbackFunc) == "function"
      @_onMarkerAddedCallbacks.push callbackFunc

      if @_markersLoaded
        callbackFunc marker for marker in @_hiventMarkers

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################
  # ============================================================================
  _initHivents: ->

    if @_hiventController

      @_globe.addSceneToRenderer(@_sceneInterface)

      @_globe.onMove @, @_updateHiventSizes
      window.addEventListener   "mouseup",  @_onMouseUp,         false #for hivent intersections
      window.addEventListener   "mousedown",@_onMouseDown,       false #for hivent intersections

      @_hiventController.getHivents @, (handle) =>
        @_markersLoaded = @_hiventController._hiventsLoaded
        handle.onVisiblePast @, (self) =>
          logos =
            default:@_hiventLogos[handle.getHivent().category]
            highlight:@_hiventLogos[handle.getHivent().category+"_highlighted"]
            group_default: @_hiventLogos["group_default"]
            group_highlighted: @_hiventLogos["group_highlighted"]

          marker    = new HG.HiventMarker3D(handle, @_globe, HG.Display.CONTAINER, @_sceneInterface, logos, @_hgInstance)
          position  =  @_globe._latLongToCart(
            x:handle.getHivent().long
            y:handle.getHivent().lat,
            @_globe.getGlobeRadius()+0.2)

          marker.sprite.position.set(position.x,position.y,position.z)

          foundGroup = false
          # search for already existing groups
          for group in @_hiventMarkerGroups
            if group.getGPS()[0] == parseFloat(handle.getHivent().lat[0]) and group.getGPS()[1] == parseFloat(handle.getHivent().long[0])
              group.addMarker(marker)
              foundGroup = true
          # search for marker building a new group
          unless foundGroup
            for m in @_hiventMarkers
              if m.getHiventHandle().getHivent().lat[0] == handle.getHivent().lat[0] and m.getHiventHandle().getHivent().long[0] == handle.getHivent().long[0]
                markerGroup = new HG.HiventMarker3DGroup([marker,m],@_globe, HG.Display.CONTAINER, @_sceneInterface, logos, @_hgInstance)

                markerGroup.onMarkerDestruction @, (marker_group) =>
                  #remove group and add last/remaining element to map
                  index = @_hiventMarkerGroups.indexOf(marker_group)
                  @_hiventMarkerGroups.splice index,1 if index >= 0
                  @_sceneInterface.remove marker_group.sprite

                  remaining_handle = marker_group.getHiventMarkers()[0].getHiventHandle()
                  if remaining_handle.isActive()
                    @_hiventMarkers.push marker_group.getHiventMarkers()[0]
                    @_sceneInterface.add marker_group.getHiventMarkers()[0]
                  marker_group.removeListener "onMarkerDestruction", @
                  marker_group.destroy()

                markerGroup.onSplitGroup @, (marker_group,children) =>

                  #split group on click
                  gps = marker_group.getGPS()

                  #@_sceneInterface.remove marker_group.sprite
                  #index = @_hiventMarkerGroups.indexOf(marker_group)
                  #@_hiventMarkerGroups.splice index,1 if index >= 0

                  child_count = 0
                  for marker in children
                    @_sceneInterface.add marker.sprite
                    @_hiventMarkers.push marker

                    #star split
                    new_long = parseFloat(gps[1])+(0.5*Math.sin(2*Math.PI*(child_count/children.length))) #0.5 degree aberration in gps
                    new_lat = parseFloat(gps[0])+(0.5*Math.cos(2*Math.PI*(child_count/children.length))) #0.5 degree aberration in gps

                    position  =  @_globe._latLongToCart(
                      x:new_long
                      y:new_lat,
                      @_globe.getGlobeRadius()+0.2)

                    marker.sprite.position.set(position.x,position.y,position.z)

                    ++child_count


                  markerGroup.onCollapseGroup @, (marker_group,children) =>

                    gps = marker_group.getGPS()
                    position  =  @_globe._latLongToCart(
                      x:new_long
                      y:new_lat,
                      @_globe.getGlobeRadius()+0.2)
                    for marker in children
                      marker.sprite.position.set(position.x,position.y,position.z)
                      index = @_hiventMarkers.indexOf(marker)
                      @_hiventMarkers.splice index,1 if index >= 0
                      @_sceneInterface.remove marker.sprite



                markerGroup.sprite.position.set(position.x,position.y,position.z)
                @_sceneInterface.add(markerGroup.sprite)
                @_hiventMarkerGroups.push markerGroup
                @_sceneInterface.remove(m.sprite)
                index = @_hiventMarkers.indexOf(m)
                @_hiventMarkers.splice index,1 if index >=0
                markerGroup.addHiventCallbacks()

                foundGroup = true
                break

          unless foundGroup
            @_sceneInterface.add(marker.sprite)
            @_hiventMarkers.push marker

          callback marker for callback in @_onMarkerAddedCallbacks

          # #HiventRegion NEW
          # @region=self.getHivent().region
          # if @region? and Array.isArray(@region) and @region.length>0
          #   region = new HG.HiventMarkerRegion self, hgInstance.map, @_map

          #   @_hiventMarkers.push region
          #   callback region for callback in @_onMarkerAddedCallbacks
          #   region.onDestruction @,() =>
          #       index = $.inArray(region, @_hiventMarkers)
          #       @_hiventMarkers.splice index, 1  if index >= 0

          marker.onMarkerDestruction @,() =>
            index = @_hiventMarkers.indexOf(marker)
            @_hiventMarkers.splice index, 1  if index >= 0


          @_updateHiventSizes()



      @_hiventController.showVisibleHivents() # force all hivents to show

      setInterval(@_animate, 100)

    else
      console.error "Unable to show hivents on Globe: HiventController module not detected in HistoGlobe instance!"


  # ============================================================================
  _deactivateAllHivents:() =>
    HG.HiventHandle.DEACTIVATE_ALL_HIVENTS()

  # ============================================================================
  _animate:() =>
    if @_globe._isRunning
      @_evaluate()


  # ============================================================================
  _updateHiventSizes:->
    #for hivent in @_markerGroup.getVisibleHivents()
    for hivent in @_hiventMarkers.concat(@_hiventMarkerGroups)
      cam_pos = new THREE.Vector3(@_globe._camera.position.x,@_globe._camera.position.y,@_globe._camera.position.z).normalize()
      hivent_pos = new THREE.Vector3(hivent.sprite.position.x,hivent.sprite.position.y,hivent.sprite.position.z).normalize()
      #perspective compensation
      dot = (cam_pos.dot(hivent_pos)-0.4)/0.6

      if dot > 0.0
        hivent.sprite.scale.set(hivent.sprite.MaxWidth*dot,hivent.sprite.MaxHeight*dot,1.0)
      else
        hivent.sprite.scale.set(0.0,0.0,1.0)

  # ============================================================================
  _onMouseDown: (event) =>

    @_backupFOV = @_globe._currentFOV
    @_backupZoom = @_globe._currentZoom
    @_backupCenter = @_globe._targetCameraPos

    # if @_lastIntersected.length is 0
    #     HG.HiventHandle.DEACTIVATE_ALL_HIVENTS()
    #     for group in @_hiventMarkerGroups
    #       group.onUnClick()


  # ============================================================================
  _onMouseUp: (event) =>

    if @_lastIntersected.length > 0

      for hivent in @_lastIntersected
        pos =
          x: @_globe._mousePos.x - @_globe._canvasOffsetX
          y: @_globe._mousePos.y - @_globe._canvasOffsetY

        #hivent.getHiventHandle().active pos
        hivent.onClick(pos)

      #freeze globe because of area intersection etc
      @_globe._targetFOV = @_backupFOV
      @_globe._currentZoom = @_backupZoom
      @_globe._targetCameraPos =  @_backupCenter

  # ============================================================================
  _evaluate: () =>

    #offset = 0
    #rightOffset = parseFloat($(@_globeCanvas).css("right").replace('px',''))
    #offset = rightOffset if rightOffset

    mouseRel =
      x: (@_globe._mousePos.x - @_globe._canvasOffsetX) / @_globe._width * 2 - 1
      y: (@_globe._mousePos.y - @_globe._canvasOffsetY) / @_globe._myHeight * 2 - 1


    # picking ------------------------------------------------------------------
    vector = new THREE.Vector3 mouseRel.x, -mouseRel.y, 0.5
    projector = @_globe.getProjector()
    projector.unprojectVector vector, @_globe._camera

    raycaster = @_globe.getRaycaster()

    raycaster.set @_globe._camera.position, vector.sub(@_globe._camera.position).normalize()



    tmp_intersects = []
    #for hivent in @_markerGroup.getVisibleHivents()
    for hivent in @_hiventMarkers.concat(@_hiventMarkerGroups)

      if hivent.sprite.visible and hivent.sprite.scale.x isnt 0.0 and hivent.sprite.scale.y isnt 0.0

        ScreenCoordinates = @_globe._getScreenCoordinates(hivent.sprite.position)

        if ScreenCoordinates
          hivent.ScreenCoordinates = ScreenCoordinates
          x = ScreenCoordinates.x
          y = ScreenCoordinates.y

          h = hivent.sprite.scale.y
          w = hivent.sprite.scale.x

          if @_globe._mousePos.x > x - (w/2) and @_globe._mousePos.x < x + (w/2) and
          @_globe._mousePos.y > y - (h/2) and @_globe._mousePos.y < y + (h/2)
            index = $.inArray(hivent, @_lastIntersected)
            @_lastIntersected.splice index, 1  if index >= 0
            if index < 0
              hivent.onMouseOver(x,y)

            tmp_intersects.push hivent
            HG.Display.CONTAINER.style.cursor = "pointer"
            @_intersected = true

    for hivent in @_lastIntersected
      hivent.onMouseOut()


    if tmp_intersects.length is 0
      HG.Display.CONTAINER.style.cursor = "auto" if @_intersected
      @_intersected = false
    @_lastIntersected = tmp_intersects


    #intersects = RAYCASTER.intersectObjects @_sceneGlobe.children
    #intersects2 = RAYCASTER.intersectObjects @_sceneInterface.children

    #newIntersects = []

    '''for intersect in intersects2
      if intersect.object instanceof HG.HiventMarker3D
        index = $.inArray(intersect.object, @_lastIntersected)
        @_lastIntersected.splice index, 1  if index >= 0

    # unmark previous hits
    for intersect in @_lastIntersected
      intersect.getHiventHandle().unMark intersect
      intersect.getHiventHandle().unLinkAll()

    @_lastIntersected = []

    # hover intersected objects
    for intersect in intersects2

      console.log intersect

      if intersect.object instanceof HG.HiventMarker3D
        @_lastIntersected.push intersect.object
        pos =
          x: @_mousePos.x - @_canvasOffsetX
          y: @_mousePos.y - @_canvasOffsetY

        intersect.object.getHiventHandle().mark intersect.object, pos
        intersect.object.getHiventHandle().linkAll pos'''
