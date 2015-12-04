window.HG ?= {}

class HG.Globe extends HG.Display

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->
    HG.Display.call @

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onZoomEnd"
    @addCallback "onMoveEnd"
    @addCallback "onZoom"
    @addCallback "onMove"
    @addCallback "onLoaded"

    @_globeCanvas = null

    @_tile_path = ""


  # ============================================================================
  hgInit: (hgInstance) ->
    super hgInstance

    unless hgInstance.browserDetector
      console.error "Failed to initialize Globe: Module browserDetector not detected!"
      return

    if hgInstance.browserDetector.webglSupported
      hgInstance.globe = @
      @_tile_path = hgInstance._config.tiles
      @_globeCanvas = hgInstance.mapCanvas
      @_areaController = hgInstance.areaController

      @_initMembers()
      @_initWindowGeometry()
      @_initRenderer()

      @center x: 10, y: 50

      hgInstance.onAllModulesLoaded @, () =>
        if hgInstance.zoom_buttons?
          hgInstance.zoom_buttons.onZoomIn @, @_zoomIn
          hgInstance.zoom_buttons.onZoomOut @, @_zoomOut

        if hgInstance.highcontrast_button?
          hgInstance.highcontrast_button.onEnterHighContrast @, () =>
            @_tile_path = hgInstance._config.tilesHighContrast

          hgInstance.highcontrast_button.onLeaveHighContrast @, () =>
            @_tile_path = hgInstance._config.tiles


        if hgInstance.control_button_area?
          state_a = {}
          state_b = {}

          state_a =
            icon: "fa-globe"
            tooltip: "Zur 3D-Ansicht wechseln"
            callback: () =>
              $(hgInstance.map.getCanvas()).animate({opacity: 0.0}, 1000, 'linear')
              hgInstance.map.stop()
              $(@getCanvas()).css({opacity: 0.0})
              @start();
              $(@getCanvas()).animate({opacity: 1.0}, 1000, 'linear')

              # find a better place:
              hgInstance.graph_button.show_button() if hgInstance.graph_button?

              return state_b

          state_b =
            icon: "fa-calendar"
            tooltip: "Zur 2D-Ansicht zurückkehren"
            callback: () =>
              $(@getCanvas()).animate({opacity: 0.0}, 1000, 'linear')
              @stop()
              $(@getCanvas()).css({opacity: 0.0})
              hgInstance.map.start();
              $(hgInstance.map.getCanvas()).animate({opacity: 1.0}, 1000, 'linear')

              # find a better place:
              hgInstance.graph_button.hide_button() if hgInstance.graph_button?

              return state_a

          hgInstance.control_button_area.addButton state_a

        else
          console.error "Failed to add globe button: ControlButtons module not found!"

    else
      console.warn "Failed to initialize Globe: Webgl not supported!"

      hgInstance.onAllModulesLoaded @, () =>
        if hgInstance.control_button_area?

          elem_title = 'Entschuldigung!';
          elem_content = '';
          if hgInstance.browserDetector.webglContextSupported
            if hgInstance.browserDetector.browser isnt "unknown"
              elem_content = 'Obwohl Ihr Browser 3D-Grafiken anzeigen kann, treten ' +
                             'auf Ihrem Rechner leider Probleme auf. Eventuell ist der ' +
                             'Treiber Ihrer Grafikkarte nicht aktuell. Weitere Hilfe '+
                             'erhalten Sie hier: <br><br> <a target="_blank" ' +
                             'class="btn btn-block btn-success" href ="' +
                             hgInstance.browserDetector.helpUrl+ '">' +
                             hgInstance.browserDetector.browser + ' & WebGL</a>'


          else
            if hgInstance.browserDetector.browser isnt "unknown" and hgInstance.browserDetector.upgradeUrl
              elem_content = 'Ihre Version von ' + hgInstance.browserDetector.browser +
                             ' ist nicht aktuell! Wenn Sie <span class="hg">HistoGlobe</span>' +
                             ' auf einem Globus genießen wollen, aktualisieren Sie bitte' +
                             ' Ihren Browser. <br><br><a target="_blank" class="btn btn-block btn-success" ' +
                              'href ="' + hgInstance.browserDetector.upgradeUrl + '">' +
                              hgInstance.browserDetector.browser + ' aktualisieren' + '</a>'
            else
              elem_content = hgInstance.browserDetector.browser + ' unterstützt leider ' +
              'noch keine 3D-Grafiken. Wenn Sie <span class="hg">HistoGlobe</span> auf ' +
              'einem Globus genießen wollen, installieren Sie bitte zum Beispiel Google Chrome:' +
              ' <br><br><a target="_blank" class="btn btn-block btn-success" ' +
              'href ="https://www.google.com/intl/de/chrome/browser/"> Chrome herunterladen </a>'

          popover = new HG.Popover
            contentHTML: elem_content
            title:       elem_title

          state =
            icon: "fa-globe"
            tooltip: "Zur 3D-Ansicht wechseln"
            callback: (button) =>
              offset = $(button).offset()
              width  = $(button).width()
              height = $(button).height()

              popover.toggle
                x: offset.left + width
                y: offset.top + height*0.5

          hgInstance.control_button_area.addButton state

        else
          console.error "Failed to add globe button: ControlButtons module not found!"


  # ============================================================================
  start: ->


    unless @_sceneGlobe

      #update initial container size
      @_onWindowResize()

      @_initGlobe()

      @_initEventHandling()
      @_zoom()

      @notifyAll "onLoaded"

    unless @_isRunning
      @_isRunning = true
      @_renderer.domElement.style.display = "inline"

      animate = =>
        if @_isRunning
          @_render()
          requestAnimationFrame animate

      animate()



  # ============================================================================
  stop: ->
    @_isRunning = false
    '''HG.HiventHandle.DEACTIVATE_ALL_HIVENTS()'''
    @_renderer.domElement.style.display = "none"

  # ============================================================================
  isRunning: -> @_isRunning

  # ============================================================================
  getCanvas: -> @_renderer.domElement

  # ============================================================================
  center: (latLong) ->
    @_targetCameraPos.x = latLong.x
    @_targetCameraPos.y = latLong.y

  # ============================================================================
  # also focus on this place
  setCenter: (latLong) ->
    @_targetCameraPos.x = latLong.x
    @_targetCameraPos.y = latLong.y

    @_currentZoom =CAMERA_MAX_ZOOM
    @_zoom()

  # ============================================================================
  centerCart: (point) ->
    # console.log "center cart!!!!!!!!!!!!!",point
    #@center @_cartToLatLong(point.clone())
    target = @_cartToLatLong(new THREE.Vector3(point.x,point.y,point.z).clone().normalize())
    @_targetCameraPos = new THREE.Vector2(-1*target.y,target.x)
    @_targetFOV = CAMERA_MIN_FOV;
    @_currentZoom = CAMERA_MAX_ZOOM


  # ============================================================================
  #new
  getZoom:() ->
    return @_currentZoom

  # ============================================================================
  #new
  getMaxZoom:() ->
    return CAMERA_MAX_ZOOM

  # ============================================================================
  #new
  getMinZoom:() ->
    return CAMERA_MIN_ZOOM

  # ============================================================================
  #new
  getMaxFov:() ->
    return CAMERA_MAX_FOV
  # ============================================================================
  #new
  getMinFov:() ->
    return CAMERA_MIN_FOV

  # ============================================================================
  getRaycaster:() ->
    return RAYCASTER

  # ============================================================================
  getProjector:() ->
    return PROJECTOR

  # ============================================================================
  getGlobeRadius:() ->
    return EARTH_RADIUS




  # ============================================================================
  #new
  getNormZoom: ->
    return (@_currentZoom - CAMERA_MIN_ZOOM)/(CAMERA_MAX_ZOOM - CAMERA_MIN_ZOOM)


  # ============================================================================
  #new - not tested yet!!!!!!!!
  getBounds:() ->
    #just check one corner, if whole centered globe is visible
    latlng = @_pixelToLatLong {x:0+1,y:0+1}
    console.log "latlng of 0 0: ",latlng
    if latlng is null
      centerLatLng = @_pixelToLatLong {x:@_width/2,y:@_myHeight/2}

      console.log "centerlatlng", centerLatLng

      if centerLatLng isnt null
        southWestL = L.latLng(centerLatLng.lat+90.0, centerLatLng.lng-90.0)
        northEastL = L.latLng(centerLatLng.lat-90.0, centerLatLng.lng+90.0)
        return L.latLngBounds(southWestL, northEastL);
      else
        console.log "quickhack???????????????????"
        #quickhack!!!!
        southWestL = L.latLng(-180.0, -180.0)
        northEastL = L.latLng(180.0, 180.0)
        return L.latLngBounds(southWestL, northEastL);

    else
      southWest = @_pixelToLatLong {x:0,y:@_myHeight-1}
      northEast = @_pixelToLatLong {x:@_width-1,y:0}

      southWestL = L.latLng(southWest.lat, southWest.lng)
      northEastL = L.latLng(northEast.lat, northEast.lng)
      return L.latLngBounds(southWestL, northEastL);


  # ============================================================================
  addSceneToRenderer:(scene) ->
    @_addedScenes.push scene

  # ============================================================================
  removeSceneFromRenderer:(scene) ->
    index = @_addedScenes.indexOf(scene);
    @_addedScenes.splice(index, 1) if index >= 0


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _initMembers: ->
    @_width                = null
    @_height               = null
    @_camera               = null

    @_renderer             = null
    @_sceneGlobe           = null
    @_sceneAtmosphere      = null

    @_addedScenes          = []


    @_canvasOffsetX        = null
    @_canvasOffsetY        = null


    @_currentCameraPos     = x: 0, y: 0
    @_targetCameraPos      = x: 0, y: 0
    @_mousePos             = x: 0, y: 0
    @_mousePosLastFrame    = x: 0, y: 0
    @_mouseSpeed           = x: 0, y: 0
    @_dragStartPos         = null
    @_springiness          = 0.9
    @_currentFOV           = 0
    @_targetFOV            = 0
    @_globeTextures        = []
    @_globeUniforms        = null
    @_isRunning            = false
    @_currentZoom          = CAMERA_MIN_ZOOM
    #@_currentZoom          = CAMERA_MAX_ZOOM
    @_isZooming            = false


  # ============================================================================
  _initWindowGeometry: ->
    @_width                = HG.Display.CONTAINER.parentNode.offsetWidth
    @_myHeight             = HG.Display.CONTAINER.parentNode.offsetHeight
    @_canvasOffsetX        = HG.Display.CONTAINER.parentNode.offsetLeft
    @_canvasOffsetY        = HG.Display.CONTAINER.parentNode.offsetTop

  # ============================================================================
  _initGlobe: ->
    # build texture quad tree
    initTile = (minLatLong, size, zoom, x, y) =>
      node =
        textures: null
        loadedTextureCount: 0
        opacity: 1.0
        x: x * 4
        y: y * 4
        z: zoom
        minLatLong: x: minLatLong.x,        y: minLatLong.y
        maxLatLong: x: minLatLong.x + size, y: minLatLong.y + size
        children: null
        path: ""

      unless zoom is CAMERA_MAX_ZOOM
        node.children = []

        node.children.push initTile(
          x: minLatLong.x
          y: minLatLong.y + size*0.5,
        size*0.5, zoom+1, x*2, y*2)

        node.children.push initTile(
          x: minLatLong.x + size*0.5
          y: minLatLong.y + size*0.5,
        size*0.5, zoom+1, x*2+1, y*2)

        node.children.push initTile(
          x: minLatLong.x
          y: minLatLong.y,
        size*0.5, zoom+1, x*2, y*2+1)

        node.children.push initTile(
          x: minLatLong.x + size*0.5
          y: minLatLong.y,
        size*0.5, zoom+1, x*2+1, y*2+1)

      return node

    # create globe -------------------------------------------------------------
    geometry = new THREE.SphereGeometry EARTH_RADIUS, 64, 132
    shader = SHADERS.earth


    @_sceneGlobe         = new THREE.Scene
    @_sceneAtmosphere    = new THREE.Scene


    @_globeUniforms      = THREE.UniformsUtils.clone shader.uniforms
    @_globeTextures      = initTile {x: 0.0, y: 0.0}, 1.0, 2, 0, 0

    material = new THREE.ShaderMaterial(
      vertexShader:   shader.vertexShader
      fragmentShader: shader.fragmentShader
      uniforms:       @_globeUniforms
      transparent:    true
    )

    globe = new THREE.Mesh geometry, material
    globe.matrixAutoUpdate = false

    @_sceneGlobe.add globe

    # create atmosphere --------------------------------------------------------
    shader = SHADERS.atmosphere
    uniforms = THREE.UniformsUtils.clone shader.uniforms
    uniforms.bgColor.value = new THREE.Vector3 BACKGROUND.r,
                                               BACKGROUND.g,
                                               BACKGROUND.b
    material = new THREE.ShaderMaterial(
      uniforms:       uniforms
      vertexShader:   shader.vertexShader
      fragmentShader: shader.fragmentShader
    )

    atmosphere                  = new THREE.Mesh geometry, material
    atmosphere.scale.x          = atmosphere.scale.y = atmosphere.scale.z = 1.5
    atmosphere.flipSided        = true
    atmosphere.matrixAutoUpdate = false
    atmosphere.updateMatrix()

    @_sceneAtmosphere.add atmosphere

  # ============================================================================
  _initRenderer: ->
    @_renderer = new THREE.WebGLRenderer(antialias: true)
    @_renderer.autoClear                 = false
    @_renderer.setClearColor             BACKGROUND, 1.0
    @_renderer.setSize                   @_width, @_myHeight
    @_renderer.domElement.style.position = "absolute"
    @_renderer.domElement.style.zIndex = "#{HG.Display.Z_INDEX}"

    HG.Display.CONTAINER.appendChild @_renderer.domElement

    @_camera               = new THREE.PerspectiveCamera @_currentFOV,
                                                        @_width / @_myHeight,
                                                        1, 10000
    @_camera.useQuaternion = true

    @_camera.position.z    = CAMERA_DISTANCE

  # ============================================================================
  _initEventHandling: ->
    @_renderer.domElement.addEventListener "mousedown", @_onMouseDown, false
    @_renderer.domElement.addEventListener "mousemove", @_onMouseMove, false

    @_renderer.domElement.addEventListener "mousewheel", ((event) =>
      event.preventDefault()
      @_onMouseWheel event.wheelDelta
      return false
    ), false

    @_renderer.domElement.addEventListener "DOMMouseScroll", ((event) =>
      event.preventDefault()
      @_onMouseWheel -event.detail * 30
      return false
    ), false

    window.addEventListener   "resize",   @_onWindowResize,   false
    window.addEventListener   "mouseup",  @_onMouseUp,         false



  ############################# MAIN FUNCTIONS #################################



  # ============================================================================
  _render: ->

    #offset = 0
    #rightOffset = parseFloat($(@_globeCanvas).css("right").replace('px',''))
    #offset = rightOffset if rightOffset

    mouseRel =
      x: (@_mousePos.x - @_canvasOffsetX) / @_width * 2 - 1
      y: (@_mousePos.y - @_canvasOffsetY) / @_myHeight * 2 - 1

    # globe rotation -----------------------------------------------------------
    # if there is a drag going on - rotate globe
    if @_dragStartPos

      # update mouse speed
      @_mouseSpeed =
        x: 0.5 * @_mouseSpeed.x + 0.5 * (@_mousePos.x - @_mousePosLastFrame.x)
        y: 0.5 * @_mouseSpeed.y + 0.5 * (@_mousePos.y - @_mousePosLastFrame.y)

      @_mousePosLastFrame =
        x: @_mousePos.x
        y: @_mousePos.y

      latLongCurr = @_pixelToLatLong mouseRel

      # if mouse is still over the globe
      if latLongCurr
        offset =
          x: @_dragStartPos.x - latLongCurr.x
          y: @_dragStartPos.y - latLongCurr.y

        if offset.y > 180
          offset.y -= 360
        else if offset.y < -180
          #yOffset += 360 # bug?
          offset.y += 360

        @_targetCameraPos.y += 0.5 * offset.x
        @_targetCameraPos.x -= 0.5 * offset.y

        @_clampCameraPos()

      else
        @_dragStartPos = null
        HG.Display.CONTAINER.style.cursor = "auto"

    else if @_mouseSpeed.x isnt 0.0 and @_mouseSpeed.y isnt 0.0

      # if the globe has been "thrown" --- for "flicking"
      @_targetCameraPos.x -= @_mouseSpeed.x*@_currentFOV*0.02
      @_targetCameraPos.y += @_mouseSpeed.y*@_currentFOV*0.02

      @_clampCameraPos()

      @_mouseSpeed =
        x: 0.0
        y: 0.0

    @_currentCameraPos =
      x: @_currentCameraPos.x * (@_springiness) +
         @_targetCameraPos.x * (1.0 - @_springiness)
      y: @_currentCameraPos.y * (@_springiness) +
         @_targetCameraPos.y * (1.0 - @_springiness)

    rotation =
      x: @_currentCameraPos.x * Math.PI / 180
      y: @_currentCameraPos.y * Math.PI / 180

    @_camera.position =
      x: CAMERA_DISTANCE * Math.sin(rotation.x+Math.PI*0.5)*Math.cos(rotation.y)
      y: CAMERA_DISTANCE * Math.sin(rotation.y)
      z: CAMERA_DISTANCE * Math.cos(rotation.x+Math.PI*0.5)*Math.cos(rotation.y)

    @_camera.lookAt new THREE.Vector3 0, 0, 0

    # moving -------------------------------------------------------------------
    #new:
    alpha = 0.01
    if (@_currentCameraPos.x + alpha < @_targetCameraPos.x or @_currentCameraPos.x - alpha > @_targetCameraPos.x) and (@_currentCameraPos.y + alpha < @_targetCameraPos.y or @_currentCameraPos.y - alpha > @_targetCameraPos.y)

      @notifyAll "onMove"


    # zooming ------------------------------------------------------------------
    unless @_currentFOV is @_targetFOV

      @notifyAll "onZoom"

      smoothness = 0.8
      @_currentFOV = @_currentFOV * smoothness + @_targetFOV * (1.0-smoothness)
      @_camera.fov = @_currentFOV
      @_camera.updateProjectionMatrix()
      @_isZooming = true

      #zoom end!!!
      if Math.abs(@_currentFOV - @_targetFOV) < 0.05

        @notifyAll "onZoomEnd"

        @_currentFOV = @_targetFOV
        @_isZooming  = false


    # rendering ----------------------------------------------------------------
    @_renderer.clear()
    @_renderer.setFaceCulling  THREE.CullFaceBack
    @_renderer.setDepthTest    false
    @_renderer.setBlending     THREE.AlphaBlending
    @_renderTile                 @_globeTextures
    @_renderer.setDepthTest    true
    @_renderer.setFaceCulling  THREE.CullFaceFront
    @_renderer.render          @_sceneAtmosphere, @_camera


    for scene in @_addedScenes
      @_renderer.render          scene, @_camera


  # ============================================================================
  _zoom: ->
    @_targetFOV = (CAMERA_MAX_ZOOM - @_currentZoom) /
                        (CAMERA_MAX_ZOOM - CAMERA_MIN_ZOOM) *
                        (CAMERA_MAX_FOV - CAMERA_MIN_FOV) + CAMERA_MIN_FOV



  # ============================================================================
  _zoomOut: ->
    #@_targetFOV = Math.max(CAMERA_MIN_FOV,--@_currentFOV)
    @_currentZoom = Math.max(CAMERA_MIN_ZOOM,--@_currentZoom)
    @_zoom()

  # ============================================================================
  _zoomIn: ->
    #@_targetFOV = Math.min(CAMERA_MAX_FOV,++@_currentFOV)
    @_currentZoom = Math.min(CAMERA_MAX_ZOOM,++@_currentZoom)
    @_zoom()




  ############################ EVENT FUNCTIONS #################################

  # ============================================================================
  _onMouseDown: (event) =>

    if @_isRunning

      offset = 0
      rightOffset = parseFloat($(@_globeCanvas).css("right").replace('px',''))
      offset = rightOffset if rightOffset

      event.preventDefault()
      clickMouse =
        x: (event.clientX - @_canvasOffsetX - offset) / @_width * 2 - 1
        y: (event.clientY - @_canvasOffsetY) / @_myHeight * 2 - 1


      @_dragStartPos = @_pixelToLatLong(clickMouse)
      #@_dragStartTime = new Date()

      if @_dragStartPos?
        HG.Display.CONTAINER.style.cursor = "move"
        @_springiness = 0.1
        @_targetCameraPos.x = @_currentCameraPos.x
        @_targetCameraPos.y = @_currentCameraPos.y
        @_mousePosLastFrame.x = @_mousePos.x
        @_mousePosLastFrame.y = @_mousePos.y

  # ============================================================================
  _onMouseMove: (event) =>
    if @_isRunning

      offset = 0
      rightOffset = parseFloat($(@_globeCanvas).css("right").replace('px',''))
      offset = rightOffset if rightOffset

      @_mousePos =
        x: event.clientX - offset
        y: event.clientY


  # ============================================================================
  _onMouseUp: (event) =>
    if @_isRunning

      event.preventDefault()
      HG.Display.CONTAINER.style.cursor = "auto"
      @_springiness = 0.9
      @_dragStartPos = null
      @_myDragStartCamera = null

      return true

  # ============================================================================
  _onMouseWheel: (delta) =>
    if @_isRunning
      @_currentZoom = Math.max(Math.min(
                        @_currentZoom + delta * 0.005,
                        CAMERA_MAX_ZOOM),
                      CAMERA_MIN_ZOOM)
      @_zoom()

    return true

  # ============================================================================
  _onWindowResize: (event) =>
    @_camera.aspect = HG.Display.CONTAINER.parentNode.offsetWidth /
                      HG.Display.CONTAINER.parentNode.offsetHeight
    @_camera.updateProjectionMatrix()
    @_renderer.setSize HG.Display.CONTAINER.parentNode.offsetWidth,
                       HG.Display.CONTAINER.parentNode.offsetHeight
    @_initWindowGeometry()




  '''# ============================================================================
  #new:
  _onClick: (event) =>
    @_map.fitBounds event.target.getBounds()'''


  ############################ HELPER FUNCTIONS ################################

  # ============================================================================
  #new:
  _getScreenCoordinates:(position) ->
    vector = position.clone()

    PROJECTOR.projectVector vector, @_camera

    x = ( vector.x * (@_width/2) ) + (@_width/2);
    y = - ( vector.y * (@_myHeight/2) ) + (@_myHeight/2);

    if x and y
      return {x:x,y:y}
    else
      return null

  # # ============================================================================
  # #new:
  # _getScreenCoordinates:(position,zoom) ->

  #   testCamera = new THREE.PerspectiveCamera @_camera

  #   fov = (CAMERA_MAX_ZOOM - zoom) /
  #         (CAMERA_MAX_ZOOM - CAMERA_MIN_ZOOM) *
  #         (CAMERA_MAX_FOV - CAMERA_MIN_FOV) + CAMERA_MIN_FOV

  #   testCamera.fov = fov

  #   vector = position.clone()

  #   PROJECTOR.projectVector vector, @_camera

  #   x = ( vector.x * (@_width/2) ) + (@_width/2);
  #   y = - ( vector.y * (@_myHeight/2) ) + (@_myHeight/2);

  #   if x and y
  #     return {x:x,y:y}
  #   else
  #     return null


  # ============================================================================
  _clampCameraPos: ->
    @_targetCameraPos.y = Math.max(
                            -CAMERA_MAX_LONG,
                            Math.min(CAMERA_MAX_LONG, @_targetCameraPos.y)
                          )

  # ============================================================================
  _isTileVisible: (minNormalizedLatLong, maxNormalizedLatLong) ->
    if @_isFrontFacingTile(minNormalizedLatLong, maxNormalizedLatLong)
      min = @_normalizedMercatusToNormalizedLatLong(minNormalizedLatLong)
      max = @_normalizedMercatusToNormalizedLatLong(maxNormalizedLatLong)
      a = @_latLongToPixel(@_unNormalizeLatLong(
        x: min.x
        y: min.y
      ))
      b = @_latLongToPixel(@_unNormalizeLatLong(
        x: max.x
        y: min.y
      ))
      c = @_latLongToPixel(@_unNormalizeLatLong(
        x: max.x
        y: max.y
      ))
      d = @_latLongToPixel(@_unNormalizeLatLong(
        x: min.x
        y: max.y
      ))
      minX = Math.min(Math.min(Math.min(a.x, b.x), c.x), d.x)
      maxX = Math.max(Math.max(Math.max(a.x, b.x), c.x), d.x)
      minY = Math.min(Math.min(Math.min(a.y, b.y), c.y), d.y)
      maxY = Math.max(Math.max(Math.max(a.y, b.y), c.y), d.y)
      return not (minX > 1.0 or minY > 1.0 or maxX < -1.0 or maxY < -1.0)
    false

  # ============================================================================
  _isFrontFacingTile: (minNormalizedLatLong, maxNormalizedLatLong) ->
    isOnFrontSide = (pos) =>
      diff = Math.acos(Math.sin((pos.y - 0.5) * Math.PI) *
             Math.sin((@_currentCameraPos.y) * Math.PI / 180.0) +
             Math.cos((pos.y-0.5)*Math.PI) * Math.cos((@_currentCameraPos.y) *
             Math.PI / 180.0) * Math.cos(-(pos.x - 0.5) * 2.0 * Math.PI +
             (@_currentCameraPos.x) * Math.PI / 180.0))

      Math.PI * 0.5 > diff
    a =
      x: minNormalizedLatLong.x
      y: minNormalizedLatLong.y

    b =
      x: maxNormalizedLatLong.x
      y: minNormalizedLatLong.y

    c =
      x: maxNormalizedLatLong.x
      y: maxNormalizedLatLong.y

    d =
      x: minNormalizedLatLong.x
      y: maxNormalizedLatLong.y

    return isOnFrontSide(a) or isOnFrontSide(b) or
           isOnFrontSide(c) or isOnFrontSide(d)

  # ============================================================================
  _tileChildrenLoaded: (tile) ->
    for child in tile.children
      return false if child.loadedTextureCount < 16

    return true

  # ============================================================================
  _tileLoad: (tile) ->
    tile.textures = []
    tile.path = @_tile_path
    dx = 0

    while dx < 4
      dy = 0

      while dy < 4
        x = tile.x + dx
        y = tile.y + (3 - dy)
        file = @_tile_path + tile.z + "/" + x + "/" + y + ".png"
        tex = THREE.ImageUtils.loadTexture(file, new THREE.UVMapping(), ->
          tile.loadedTextureCount++
        )
        tile.textures.push tex
        ++dy

      ++dx

  # ============================================================================
  _tileLoadChildren: (tile) ->
    for child in tile.children
      @_tileLoad child unless child.textures?

  # ============================================================================
  _renderTile: (tile) ->
    if @_isTileVisible tile.minLatLong, tile.maxLatLong
      if tile.z < @_currentZoom - 0.5 and tile.children?
        if @_tileChildrenLoaded tile

          unless tile.opacity is 1.0
            for child in tile.children
              @_renderTile child

          if tile.opacity < 0.05
            tile.opacity = 0.0
            return

          tile.opacity = tile.opacity * 0.9 unless @_isZooming

        @_tileLoadChildren tile unless @_isZooming

      else tile.opacity = 1.0

      @_tileLoad tile if tile.textures is null or tile.path isnt @_tile_path

      @_globeUniforms.tiles.value    = tile.textures
      @_globeUniforms.opacity.value  = tile.opacity
      @_globeUniforms.minUV.value    = tile.minLatLong
      @_globeUniforms.maxUV.value    = tile.maxLatLong

      @_renderer.render @_sceneGlobe, @_camera

  # ============================================================================
  _pixelToLatLong: (inPixel) ->
    vector = new THREE.Vector3(inPixel.x, -inPixel.y, 0.5)
    PROJECTOR.unprojectVector vector, @_camera
    RAYCASTER.set @_camera.position, vector.sub(@_camera.position).normalize()
    intersects = RAYCASTER.intersectObjects(@_sceneGlobe.children)
    return @_cartToLatLong(intersects[0].point.clone().normalize()) if intersects.length > 0
    return null

  # ============================================================================
  _latLongToCart: (latLong,Radius) ->
    x = Radius * Math.cos(latLong.y * Math.PI / 180) * Math.cos(-latLong.x * Math.PI / 180)
    y = Radius * Math.sin(latLong.y * Math.PI / 180)
    z = Radius * Math.cos(latLong.y * Math.PI / 180) * Math.sin(-latLong.x * Math.PI / 180)
    new THREE.Vector3(x, y, z)

  # ============================================================================
  _latLongToPixel: (latLong) ->
    pos = @_latLongToCart(latLong,EARTH_RADIUS)
    PROJECTOR.projectVector pos, @_camera
    return pos

  # ============================================================================
  _cartToLatLong: (coordinates) ->
    lat = Math.asin(coordinates.y) / Math.PI * 180
    long = -Math.atan(coordinates.x / coordinates.z) / Math.PI * 180 - 90
    long += 180  if coordinates.z > 0
    new THREE.Vector2(lat, long)

  # ============================================================================
  _normalizedLatLongToNormalizedMercatus: (latLong) ->
    #return new THREE.Vector2(latLong.x, 0.0) if latLong.y is 0.0
    #return new THREE.Vector2(latLong.x, 1.0) if latLong.y is 1.0

    # new THREE.Vector2(latLong.x,
    #                   Math.log(Math.tan(latLong.y * 0.5 * Math.PI)) /
    #                           (Math.PI * 2.0) + 0.5)

    new THREE.Vector2(latLong.x,
                      Math.log(Math.tan((0.25*Math.PI) + (0.5*latLong.y))))

  # ============================================================================
  _normalizedMercatusToNormalizedLatLong: (mercatus) ->
    #return new THREE.Vector2(mercatus.x, 0.0) if mercatus.y is 0.0
    #return new THREE.Vector2(mercatus.x, 1.0) if mercatus.y is 1.0

    #new THREE.Vector2(mercatus.x, 2.0 / Math.PI * Math.atan(Math.exp(2 * Math.PI * (mercatus.y - 0.5))))
    new THREE.Vector2(mercatus.x, 2.0 * Math.atan(Math.exp(mercatus.y))-(0.5*Math.PI))

  # ============================================================================
  _normalizeLatLong: (latLong) ->
    new THREE.Vector2(latLong.x / 360.0 + 0.5, latLong.y / 180.0 + 0.5)

  # ============================================================================
  _unNormalizeLatLong: (normalizedLatLong) ->
    new THREE.Vector2(normalizedLatLong.x * 360.0 - 180.0, normalizedLatLong.y * 180.0 - 90.0)




  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################


  # used for picking
  PROJECTOR = new THREE.Projector()
  RAYCASTER = new THREE.Raycaster()

  # background color
  BACKGROUND = new THREE.Color(0xCCCCCC)

  # radius of the globe
  EARTH_RADIUS = 200

  # camera parameters
  CAMERA_DISTANCE = 500
  CAMERA_MAX_ZOOM = 6
  CAMERA_MIN_ZOOM = 3
  CAMERA_MAX_FOV = 60
  CAMERA_MIN_FOV = 8
  CAMERA_MAX_LONG = 80
  CAMERA_ZOOM_SPEED = 0.1


  # shaders for the globe and its atmosphere
  SHADERS =
    earth:
      uniforms:
        tiles:
          type: "tv"
          value: []

        opacity:
          type: "f"
          value: 0.0

        minUV:
          type: "v2"
          value: null

        maxUV:
          type: "v2"
          value: null

      vertexShader: '''
        varying vec3 vNormal;
        varying vec2 vTexcoord;

        float convertCoords(float lat) {
          if (lat == 0.0) return 0.0;
          if (lat == 1.0) return 1.0;
          const float pi = 3.1415926535897932384626433832795;
          return log(tan(lat*0.5 * pi)) / (pi * 2.0) + 0.5;
        }

        void main() {
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
          vNormal = normalize( normalMatrix * normal );
          vTexcoord = vec2(uv.x, convertCoords(uv.y));
        }
      '''

      fragmentShader: '''
        uniform sampler2D tiles[16];
        uniform float opacity;
        uniform vec2 minUV;
        uniform vec2 maxUV;
        varying vec3 vNormal;
        varying vec2 vTexcoord;

        void main() {

          if (minUV.x > vTexcoord.x || maxUV.x < vTexcoord.x ||
              minUV.y > vTexcoord.y || maxUV.y < vTexcoord.y)
                discard;

          vec2 uv = (vTexcoord - minUV)/(maxUV - minUV);
          vec3 diffuse = vec3(0);
          float size = 0.25;

          if      (uv.x < 1.0*size && uv.y < 1.0*size)
            diffuse = texture2D( tiles[ 0], uv * 4.0 - vec2(1, 1) + vec2(1, 1)).xyz;
          else if (uv.x < 1.0*size && uv.y < 2.0*size)
            diffuse = texture2D( tiles[ 1], uv * 4.0 - vec2(1, 2) + vec2(1, 1)).xyz;
          else if (uv.x < 1.0*size && uv.y < 3.0*size)
            diffuse = texture2D( tiles[ 2], uv * 4.0 - vec2(1, 3) + vec2(1, 1)).xyz;
          else if (uv.x < 1.0*size && uv.y < 4.0*size)
            diffuse = texture2D( tiles[ 3], uv * 4.0 - vec2(1, 4) + vec2(1, 1)).xyz;
          else if (uv.x < 2.0*size && uv.y < 1.0*size)
            diffuse = texture2D( tiles[ 4], uv * 4.0 - vec2(2, 1) + vec2(1, 1)).xyz;
          else if (uv.x < 2.0*size && uv.y < 2.0*size)
            diffuse = texture2D( tiles[ 5], uv * 4.0 - vec2(2, 2) + vec2(1, 1)).xyz;
          else if (uv.x < 2.0*size && uv.y < 3.0*size)
            diffuse = texture2D( tiles[ 6], uv * 4.0 - vec2(2, 3) + vec2(1, 1)).xyz;
          else if (uv.x < 2.0*size && uv.y < 4.0*size)
            diffuse = texture2D( tiles[ 7], uv * 4.0 - vec2(2, 4) + vec2(1, 1)).xyz;
          else if (uv.x < 3.0*size && uv.y < 1.0*size)
            diffuse = texture2D( tiles[ 8], uv * 4.0 - vec2(3, 1) + vec2(1, 1)).xyz;
          else if (uv.x < 3.0*size && uv.y < 2.0*size)
            diffuse = texture2D( tiles[ 9], uv * 4.0 - vec2(3, 2) + vec2(1, 1)).xyz;
          else if (uv.x < 3.0*size && uv.y < 3.0*size)
            diffuse = texture2D( tiles[10], uv * 4.0 - vec2(3, 3) + vec2(1, 1)).xyz;
          else if (uv.x < 3.0*size && uv.y < 4.0*size)
            diffuse = texture2D( tiles[11], uv * 4.0 - vec2(3, 4) + vec2(1, 1)).xyz;
          else if (uv.x < 4.0*size && uv.y < 1.0*size)
            diffuse = texture2D( tiles[12], uv * 4.0 - vec2(4, 1) + vec2(1, 1)).xyz;
          else if (uv.x < 4.0*size && uv.y < 2.0*size)
            diffuse = texture2D( tiles[13], uv * 4.0 - vec2(4, 2) + vec2(1, 1)).xyz;
          else if (uv.x < 4.0*size && uv.y < 3.0*size)
            diffuse = texture2D( tiles[14], uv * 4.0 - vec2(4, 3) + vec2(1, 1)).xyz;
          else
            diffuse = texture2D( tiles[15], uv * 4.0 - vec2(4, 4) + vec2(1, 1)).xyz;

          float phong      = max(0.0, pow(dot( vNormal, normalize(vec3( -0.3, 0.4, 0.7))), 0.6))*0.4 + 0.65;
          float specular   = max(0.0, pow(dot( vNormal, normalize(vec3( -0.3, 0.4, 0.7)) ), 60.0));
          float atmosphere = pow(1.0 - dot( vNormal, vec3( 0.0, 0.0, 1.0 ) ), 2.0) * 0.7;
          gl_FragColor     = vec4( phong * diffuse + atmosphere + specular * 0.1, opacity );
        }
      '''

    atmosphere:
      uniforms:
        bgColor:
          type: "v3"
          value: BACKGROUND

      vertexShader: '''
        varying vec3 vNormal;
        void main() {
          vNormal = normalize( normalMatrix * normal );
          gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
        }
      '''

      fragmentShader: '''
        uniform vec3 bgColor;
        varying vec3 vNormal;

        void main() {
          float intensity = max(0.0, -0.05 + pow( -dot( vNormal, vec3( 0, 0, 1.0 ) ) + 0.5, 5.0 ));
          gl_FragColor = vec4(vec3( 1.0, 1.0, 1.0) * intensity + bgColor * (1.0-intensity), 1.0 );
        }
      '''
