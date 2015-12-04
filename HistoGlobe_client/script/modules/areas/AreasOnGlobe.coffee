window.HG ?= {}

class HG.AreasOnGlobe

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    @_globe = null
    @_areaController = null
    @_sceneCountries          = new THREE.Scene
    @_countryLight            = null
    @_intersectedMaterials    = []
    #@_visibleAreas            = []
    @_visibleLabels           = []
    @_wholeGeometry           = null
    @_wholeMesh               = null
    @_materials               = []
    @_areasToLoad             = 0
    @_dragStartPos            = null

    # highcontrast hack: swap between normal and "_hc" mode
    @_inHighContrast  = no

    defaultConfig =
      hideAreas: false,
      hideLabels: false

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  hgInit: (hgInstance) ->
    hgInstance.areasOnGlobe = @

    @_aniTime = hgInstance._config.areaAniTime

    @_globeCanvas = hgInstance.mapCanvas

    @_globe = hgInstance.globe

    if @_globe
      @_globe.onLoaded @, @_initAll

    else
      console.log "Unable to show areas on Map: Globe module not detected in HistoGlobe instance!"

    @_areaController = hgInstance.areaController



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _initAll:() ->

    if @_areaController

      @_countryLight         = new THREE.DirectionalLight( 0xffffff, 1.0);
      @_countryLight.position.set 0, 0, -300
      @_sceneCountries.add   @_countryLight
      @_globe.addSceneToRenderer(@_sceneCountries)

      window.addEventListener   "mouseup",  @_onMouseUp,         false #for country intersections
      window.addEventListener   "mousedown",@_onMouseDown,       false #for country intersections
      @_globe.onZoomEnd @, @_filterLabels
      @_globe.onMove @, @_filterLabels
      @_globe.onMove @, @_updateLabelSizes

      if not @_config.hideAreas

        #load all areas and add them to globe:
        all_areas = @_areaController.getAllAreas()
        @_areasToLoad = all_areas.length
        for area in all_areas
          execute_async = (a) =>
            setTimeout () =>
              --@_areasToLoad
              @_addArea a
              @_showArea a if a.isActive()
              if @_areasToLoad is 0
                @_finishLoading()
            , 0

          execute_async area

        ## AREA CALLBACKS
        # change of areas
        @_areaController.onAddArea @, (area) =>
          execute_async = (a) =>
            setTimeout () =>
              @_addArea a
              @_showArea a, @_aniTime if a.isActive()
            , 0

          execute_async area

        @_areaController.onRemoveArea @, (area) =>
          @_hideArea area, @_aniTime

        @_areaController.onUpdateAreaStyle @, (area, isHC) =>
          @_inHighContrast = isHC
          @_updateAreaStyle area, @_aniTime

        # transition areas and borders
        @_areaController.onFadeInArea @, (area, isHighlight) =>
          execute_async = (a,ih) =>
            setTimeout () =>
              @_addArea a
              @_showArea a, @_aniTime, ih if a.isActive()
            , 0

          execute_async area,isHighlight


        @_areaController.onFadeOutArea @, (area) =>
          @_hideArea area, @_aniTime

      @_areaController.onFadeInBorder @, (border) =>
        @_addBorder border
        @_showBorder border, @_aniTime

      @_areaController.onFadeOutBorder @, (border) =>
        @_hideBorder border, @_aniTime

      if not @_config.hideLabels

        #load all labels and add them to globe:
        all_labels = @_areaController.getAllLabels()
        for label in all_labels
          execute_async = (l) =>
            setTimeout () =>
              @_addLabel l
              @_showLabel l if l.isActive()
            , 0

          execute_async label

        # change of labels
        @_areaController.onAddLabel @, (label) =>
          @_addLabel label
          @_showLabel label if label.isActive()
          @_filterLabels()
          @_updateLabelSizes()

        @_areaController.onRemoveLabel @, (label) =>
          @_removeLabel label
          @_filterLabels()
          @_updateLabelSizes()

        @_areaController.onUpdateLabelStyle @, (label, isHC) =>
          @_inHighContrast = isHC
          @_updateLabelStyle label

      # HOVER:
      setInterval(@_animate, 100)

    else
      console.error "Unable to show areas on globe: AreaController module not detected in HistoGlobe instance!"



  # ============================================================================
  _finishLoading:() =>

    if @_wholeGeometry isnt null

      @_wholeMesh = new THREE.Mesh( @_wholeGeometry, new THREE.MeshFaceMaterial( @_materials ) );

      # @_wholeMesh.geometry.verticesNeedUpdate = true;
      # @_wholeMesh.geometry.normalsNeedUpdate = true;
      # @_wholeMesh.geometry.computeVertexNormals();
      # @_wholeMesh.geometry.computeFaceNormals();
      # @_wholeMesh.geometry.computeBoundingSphere();

      @_sceneCountries.add @_wholeMesh

  # ============================================================================
  _animate:() =>
    if @_globe._isRunning
      @_evaluate()

  # ============================================================================
  #taken from http://mjijackson.com/2008/02/rgb-to-hsl-and-rgb-to-hsv-color-model-conversion-algorithms-in-javascript
  _rgbify: (colr) ->

    colr = colr.replace /#/, ''
    if colr.length is 3
      [
        parseInt(colr.slice(0,1) + colr.slice(0, 1), 16)
        parseInt(colr.slice(1,2) + colr.slice(1, 1), 16)
        parseInt(colr.slice(2,3) + colr.slice(2, 1), 16)
      ]
    else if colr.length is 6
      [
        parseInt(colr.slice(0,2), 16)
        parseInt(colr.slice(2,4), 16)
        parseInt(colr.slice(4,6), 16)
      ]
    else
      [0, 0, 0]

  # ============================================================================
  # AREAS
  # ============================================================================

  # ============================================================================
  # physically adds area to the globe, but makes it invisible
  _addArea: (area) ->

    if not (area.Mesh3D or area.VertexID)

      data = area.getGeometry()
      materialData = area.getStyle()

      options = area.getStyle()

      #create flat shape:
      shapeGeometry = null
      mesh = null
      countryShape = null
      borderLines = []
      bounds = null

      for array in data

        #calc bounds
        plArea = L.polyline(array,options)
        if bounds is null
          bounds = plArea.getBounds()
        else
          bounds.extend(plArea.getBounds())

        PtsArea = []

        for point in array
          PtsArea.push new THREE.Vector3(point.lng, point.lat,0)

        countryShape = new THREE.Shape PtsArea ;

        #put all country parts in one shape
        unless shapeGeometry?
          shapeGeometry = new THREE.ShapeGeometry countryShape
          shapeGeometry.dynamic = true
        else
          #shapeGeometry.addShape countryShape
          newGeometry = new THREE.ShapeGeometry countryShape
          THREE.GeometryUtils.merge(shapeGeometry,newGeometry)

        #borderline mapping of single area!!!
        lineGeometry = new THREE.Geometry
        for vertex in PtsArea
          line_coord = @_globe._latLongToCart(
            x:vertex.x
            y:vertex.y,
            @_globe.getGlobeRadius()+BORDER_GLOBE_OFFSET)
          lineGeometry.vertices.push line_coord
        #close line:
        lineGeometry.vertices.push lineGeometry.vertices[0]

        lineWidth = area.getStyle().borderWidth
        opacity = 0
        lineMaterial = new THREE.LineBasicMaterial(
          color: if @_inHighContrast then area.getStyle().borderColor_hc else area.getStyle().borderColor,
          linewidth: lineWidth,
          transparent: true,
          opacity: opacity )
        borderline = new THREE.Line( lineGeometry, lineMaterial)

        borderLines.push borderline

      #operations for the whole country (with all area parts):
      lat_distance = Math.abs(Math.abs(bounds.getSouthWest().lat) - Math.abs(bounds.getNorthEast().lat))
      lng_distance = Math.abs(Math.abs(bounds.getSouthWest().lng) - Math.abs(bounds.getNorthEast().lng))

      max_dist = Math.max(lat_distance,lng_distance)

      #iterations = Math.min(Math.max(0,Math.round(max_dist/3.5)),11)
      iterations = Math.min(Math.max(0,Math.round(max_dist^2/140)),11)
      #iterations = Math.min(Math.max(0,Math.round(max_dist^3/5500)),11)

      tessellateModifier = new THREE.TessellateModifier(7.5)

      for i in [0 .. iterations]
        tessellateModifier.modify shapeGeometry

      #invisible if not active
      opacity = 0.0
      '''opacity = materialData.areaOpacity if @_isAreaActive(area)'''


      countryMaterial = new THREE.MeshLambertMaterial
              color       : if @_inHighContrast then materialData.areaColor_hc else materialData.areaColor
              side        : THREE.BackSide,
              opacity     : opacity,
              transparent : true,
              depthWrite  : false,
              wireframe   : false,


      #for later onclick purposes:
      shapeGeometry.computeBoundingBox()
      countryMaterial.bb = shapeGeometry.boundingBox

      mesh = new THREE.Mesh( shapeGeometry, countryMaterial );

      #gps to cart mapping:
      for vertex in mesh.geometry.vertices
        cart_coords = @_globe._latLongToCart(
            x:vertex.x
            y:vertex.y,
            @_globe.getGlobeRadius()+AREA_GLOBE_OFFSET)
        vertex.x = cart_coords.x
        vertex.y = cart_coords.y
        vertex.z = cart_coords.z
        vertex.id = mesh.id

      mesh.geometry.verticesNeedUpdate = true;
      mesh.geometry.normalsNeedUpdate = true;
      mesh.geometry.computeVertexNormals();
      mesh.geometry.computeFaceNormals();
      mesh.geometry.computeBoundingSphere();

      # borderlines with opacity 0 still visible
      # for line in borderLines
      #   @_sceneCountries.add line

      if @_wholeMesh is null
        #merge geometry
        @_materials.push mesh.material
        unless @_wholeGeometry
          @_wholeGeometry = mesh.geometry
        else
          THREE.GeometryUtils.merge(@_wholeGeometry, mesh , @_materials.length-1);
        area.VertexID = mesh.id
      else
        @_sceneCountries.add mesh
        area.Mesh3D = mesh

      area.Material3D = mesh.material
      
      '''area.onStyleChange @, @_updateAreaStyle'''

      mesh.Area = area

      area.Borderlines3D = borderLines

    else

      @_updateAreaStyle(area,0)


  # ============================================================================
  # physically removes area from the glpbe
  _removeArea: (area) ->
    if area.VertexID
      vertices = @_wholeGeometry.vertices
      for vertex in vertices
        if vertex.id is area.VertexID
          index = vertices.indexOf(5);
          vertices.splice(index, 1) if index >= 0
    if area.Mesh3D
      @_sceneCountries.remove area.Mesh3D
      area.Mesh3D = null
    if area.Borderlines3D
      for line in area.Borderlines3D
        @_sceneCountries.remove line

  # ============================================================================
  _showArea: (area, aniTime, isHighlight) ->

    if not isHighlight
      if area.Material3D
        area.Material3D.opacity = area.getStyle().areaOpacity
        # $({
        #   opacity:area.Material3D.opacity
        # }).animate({
        #   opacity:        area.getStyle().areaOpacity
        # },{
        #   duration: aniTime,
        #   step: ->
        #     area.Material3D.opacity = this.opacity
        # })

      else
        console.log "Error: Cant show area!"

      if area.Borderlines3D
        for line in area.Borderlines3D
          @_sceneCountries.add line
          line.material.opacity = area.getStyle().borderOpacity

    else

      final_color =  @_rgbify TRANS_COLOR

      if area.Material3D

        area.Material3D.color.r = final_color[0]/255
        area.Material3D.color.g = final_color[1]/255
        area.Material3D.color.b = final_color[2]/255
        area.Material3D.opacity = 1.0
        # $({
        #   colorR:area.Material3D.color.r,
        #   colorG:area.Material3D.color.g,
        #   colorB:area.Material3D.color.b,
        #   opacity:area.Material3D.opacity
        # }).animate({
        #   colorR:         final_color[0]/255,
        #   colorG:         final_color[1]/255,
        #   colorB:         final_color[2]/255,
        #   opacity:        1.0
        # },{
        #   duration: aniTime,
        #   step: ->
        #     area.Material3D.color.r = this.colorR
        #     area.Material3D.color.g = this.colorG
        #     area.Material3D.color.b = this.colorB
        #     area.Material3D.opacity = this.opacity
        # })
      else
        console.log "Error: Cant show area!"

      if area.Borderlines3D
        for line in area.Borderlines3D
          @_sceneCountries.add line
          line.material.opacity = 1.0



  # ============================================================================
  _hideArea: (area, aniTime) ->
    
    #@_visibleAreas.splice(@_visibleAreas.indexOf(area), 1)

    if area.Material3D?

      '''area.removeListener "onStyleChange", @'''

      area.Material3D.opacity = 0.0
      #fade out:
      # $({
      #   opacity:area.Material3D.opacity
      # }).animate({
      #   opacity:        0.0
      # },{
      #   duration: aniTime,
      #   step: ->
      #     area.Material3D.opacity = this.opacity
      # })

    if area.Borderlines3D
      for line in area.Borderlines3D
        line.material.opacity = 0.0
        @_sceneCountries.remove line

    #@_removeArea(area)


  # ============================================================================
  _updateAreaStyle: (area, aniTime) =>

    if area.Material3D?

      final_color = @_rgbify if @_inHighContrast then area.getStyle().areaColor_hc else area.getStyle().areaColor
      final_opacity = if area.isActive() then area.getStyle().areaOpacity else 0.0
      
      area.Material3D.color.r = final_color[0]/255
      area.Material3D.color.g = final_color[1]/255
      area.Material3D.color.b = final_color[2]/255
      area.Material3D.opacity = final_opacity

      # $({
      #   colorR:area.Material3D.color.r,
      #   colorG:area.Material3D.color.g,
      #   colorB:area.Material3D.color.b,
      #   opacity:area.Material3D.opacity

      # }).animate({
      #   colorR:         final_color[0]/255,
      #   colorG:         final_color[1]/255,
      #   colorB:         final_color[2]/255,
      #   opacity:        final_opacity
      # },{
      #   #duration: 350,
      #   duration: aniTime,
      #   step: ->
      #     area.Material3D.color.r = this.colorR
      #     area.Material3D.color.g = this.colorG
      #     area.Material3D.color.b = this.colorB
      #     area.Material3D.opacity = this.opacity
      # })

      lineWidth = area.getStyle().borderWidth
      border_opacity = if area.isActive() then area.getStyle().borderOpacity else 0.0
      unless lineWidth > 0.01
        lineWidth = 1
        border_opacity = 0

      if area.Borderlines3D
        for line in area.Borderlines3D

          final_stroke_color = @_rgbify if @_inHighContrast then area.getStyle().borderColor_hc else area.getStyle().borderColor

          line.material.color.r = final_stroke_color[0]/255
          line.material.color.g = final_stroke_color[1]/255
          line.material.color.b = final_stroke_color[2]/255
          line.material.opacity = border_opacity
          line.material.linewidth = lineWidth

          #animation is buggy
          # $({
          #   strokeColorR:line.material.color.r,
          #   strokeColorG:line.material.color.g,
          #   strokeColorB:line.material.color.b,
          #   strokeOpacity:line.material.opacity,
          #   strokeWidth:line.material.linewidth

          # }).animate({
          #   strokeColorR: final_stroke_color[0]/255,
          #   strokeColorG: final_stroke_color[1]/255,
          #   strokeColorB: final_stroke_color[2]/255,
          #   #strokeOpacity: area.getStyle().borderOpacity,
          #   strokeOpacity: border_opacity,
          #   strokeWidth: area.getStyle().borderWidth
          # },{
          #   duration: aniTime,
          #   step: ->
          #     line.material.color.r = this.strokeColorR
          #     line.material.color.g = this.strokeColorG
          #     line.material.color.b = this.strokeColorB
          #     line.material.opacity = this.strokeOpacity
          #     line.material.linewidth = this.strokeWidth
          # })


  # '''# ============================================================================
  # _isAreaActive: (area) =>
  #   index = $.inArray(area, @_areaController.getActiveAreas())
  #   if index >= 0
  #     return true

  #   return false'''


  # ============================================================================
  # BORDERS
  # ============================================================================

  # ============================================================================
  # physically adds border to the globe, but makes it invisible
  _addBorder: (border) ->

    if not border.Borderlines3D

      data = border.getGeometry()
      borderLines = []

      for array in data

        PtsArea = []

        for point in array
          PtsArea.push new THREE.Vector3(point.lng, point.lat,0)

        lineGeometry = new THREE.Geometry
        for vertex in PtsArea
          line_coord = @_globe._latLongToCart(
            x:vertex.x
            y:vertex.y,
            @_globe.getGlobeRadius()+BORDER_GLOBE_OFFSET)
          lineGeometry.vertices.push line_coord

        lineWidth = border.getStyle().borderWidth
        opacity = 0
        lineMaterial = new THREE.LineBasicMaterial(
          color: TRANS_COLOR,
          linewidth: lineWidth,
          transparent: true,
          opacity: opacity )
        borderline = new THREE.Line( lineGeometry, lineMaterial)

        borderLines.push borderline

      border.Borderlines3D = borderLines

  # ============================================================================
  # physically removes area from the globe
  _removeBorder: (border) ->
    if border.Borderlines3D
      for line in border.Borderlines3D
        @_sceneCountries.remove line

  # ============================================================================
  # slowly fades in area and allows interaction with it
  _showBorder: (border, aniTime) ->
    if border.Borderlines3D
      for line in border.Borderlines3D
        @_sceneCountries.add line
        line.material.opacity = 1.0 #TODO: animation

  # ============================================================================
  _hideBorder: (border, aniTime) ->
    if border.Borderlines3D
      for line in border.Borderlines3D
        line.material.opacity = 0.0 #TODO: animation
    @_removeBorder border


  # ============================================================================
  # LABELS
  # ============================================================================


  # ============================================================================
  _addLabel: (label) =>

    unless label.Label3D?

      text = label.getName()
      metrics = TEST_CONTEXT.measureText(text)
      textWidth = metrics.width+(2*(TEXT_HEIGHT/10))
      textHeight = TEXT_HEIGHT+(2*(TEXT_HEIGHT/10))

      canvas = document.createElement('canvas')
      canvas.width = textWidth
      canvas.height = textHeight
      canvas.className = "leaflet-label"

      context = canvas.getContext('2d')
      context.textAlign = 'center'
      context.font = TEXT_FONT

      context.shadowColor = "#ffffff"
      context.shadowOffsetX = -TEXT_HEIGHT/10
      context.shadowOffsetY = -TEXT_HEIGHT/10

      context.fillText(text,textWidth/2,textHeight*0.75)

      context.shadowOffsetX =  TEXT_HEIGHT/10
      context.shadowOffsetY = -TEXT_HEIGHT/10

      context.fillText(text,textWidth/2,textHeight*0.75)

      context.shadowOffsetX = -TEXT_HEIGHT/10
      context.shadowOffsetY =  TEXT_HEIGHT/10

      context.fillText(text,textWidth/2,textHeight*0.75)

      context.shadowOffsetX =  TEXT_HEIGHT/10
      context.shadowOffsetY =  TEXT_HEIGHT/10

      context.fillStyle= if @_inHighContrast then label.getStyle().labelColor_hc else label.getStyle().labelColor
      context.fillText(text,textWidth/2,textHeight*0.75)

      texture = new THREE.Texture(canvas)
      texture.needsUpdate = true
      material = new THREE.SpriteMaterial({
        map: texture,
        transparent:true,
        opacity: 0.0
        useScreenCoordinates: false,
        scaleByViewport: true,
        sizeAttenuation: false,
        depthTest: false,
        affectedByDistance: false
        })

      sprite = new THREE.Sprite(material)

      #position calculation
      textLatLng = label.getPosition()
      cart_coords = @_globe._latLongToCart(
              x:textLatLng[1]
              y:textLatLng[0],
              @_globe.getGlobeRadius()+1.0)

      sprite.scale.set(textWidth,textHeight,1.0)
      sprite.ScaleFac = 1.0
      sprite.position.set cart_coords.x,cart_coords.y,cart_coords.z

      sprite.MaxWidth = textWidth
      sprite.MaxHeight = textHeight

      label.Label3D = sprite

  # ============================================================================
  _removeLabel: (label) ->
    index = @_visibleLabels.indexOf(label)
    @_visibleLabels.splice(index, 1) if index >= 0
    label.Label3DIsVisible = false
    if label.Label3D?
      @_sceneCountries.remove label.Label3D
      label.Label3D = null

  # ============================================================================
  _showLabel: (label) =>
    @_visibleLabels.push label
    label.Label3DIsVisible = true
    if label.Label3D?
      label.Label3D.material.opacity = label.getStyle().labelOpacity
      @_sceneCountries.add label.Label3D

  # ============================================================================
  _hideLabel: (label) =>
    label.Label3DIsVisible = false
    if label.Label3D
      label.Label3D.material.opacity = 0.0

  # ============================================================================
  _computeLabelScreenBB: (label) =>
    if label.Label3D?

      pos = @_globe._getScreenCoordinates(label.Label3D.position)
      width = label.Label3D.MaxWidth * label.Label3D.ScaleFac
      height = label.Label3D.MaxHeight * label.Label3D.ScaleFac

      label.BB = new THREE.Box3(new THREE.Vector3( pos.x-(width/2), pos.y-(height/2), 0),new THREE.Vector3( pos.x+(width/2), pos.y+(height/2), 0.1))


  # ============================================================================
  _isLabelVisible: (label) =>
    if label.BB?
      for l in @_visibleLabels
        if l.Label3DIsVisible and @_visibleLabels.indexOf(label) isnt @_visibleLabels.indexOf(l) and l.BB?
          if label.BB.isIntersectionBox(l.BB)
            if l.getPriority() > label.getPriority()
              return false
            else
              @_hideLabel l

      return true
    return false

  # ============================================================================
  _filterLabels: =>
    for label in @_visibleLabels
      @_computeLabelScreenBB label
    for label in @_visibleLabels
      if label?
        shoulBeVisible = @_isLabelVisible label

        if shoulBeVisible and not label.Label3DIsVisible
          label.Label3DIsVisible = true
          if label.Label3D
            label.Label3D.material.opacity = label.getStyle().labelOpacity
        else if not shoulBeVisible and label.Label3DIsVisible
          @_hideLabel label

  # ============================================================================
  _updateLabelStyle:(label) =>
    @_hideLabel label
    @_removeLabel label
    @_addLabel label
    @_showLabel label if label.isActive()
    @_filterLabels()
    @_updateLabelSizes()


  # ============================================================================
  _updateLabelSizes: ->
    for l in @_visibleLabels
      label = l.Label3D
      if label
        cam_pos = new THREE.Vector3(@_globe._camera.position.x,@_globe._camera.position.y,@_globe._camera.position.z).normalize()
        label_pos = new THREE.Vector3(label.position.x,label.position.y,label.position.z).normalize()
        #perspective compensation
        dot = (cam_pos.dot(label_pos)-0.4)/0.6

        if dot > 0.0
          label.scale.set(label.MaxWidth*dot,label.MaxHeight*dot,1.0)
          label.ScaleFac = dot
        else
          label.scale.set(0.0,0.0,1.0)
          label.ScaleFac = 0.0


  # ============================================================================
  _onMouseDown: (event) =>

    event.preventDefault()
    clickMouse =
      x: (@_globe._mousePos.x - @_globe._canvasOffsetX) / @_globe._width * 2 - 1
      y: (@_globe._mousePos.y - @_globe._canvasOffsetY) / @_globe._myHeight * 2 - 1

    @_dragStartPos = @_globe._pixelToLatLong(clickMouse)


  # ============================================================================
  _onMouseUp: (event) =>

    clickMouse =
      x: (@_globe._mousePos.x - @_globe._canvasOffsetX) / @_globe._width * 2 - 1
      y: (@_globe._mousePos.y - @_globe._canvasOffsetY) / @_globe._myHeight * 2 - 1

    clickPos = @_globe._pixelToLatLong(clickMouse)

    raycaster = @_globe.getRaycaster()

    if clickPos? and @_dragStartPos?
      if (clickPos.x - @_dragStartPos.x is 0) and (clickPos.y - @_dragStartPos.y is 0)
        countryIntersects = raycaster.intersectObjects @_sceneCountries.children
        if countryIntersects.length > 0

          index = countryIntersects[0].face.materialIndex
          mat = countryIntersects[0].object.material.materials[index]
          if mat.opacity > 0.1 #dont select invisible countries (????????)
            bb = mat.bb
            bb_center = bb.center()
            #countryIntersects[0].object.geometry.computeBoundingBox()
            #bb = countryIntersects[0].object.geometry.boundingBox
            #bb_center = bb.center()

            target = @_globe._cartToLatLong(new THREE.Vector3(bb_center.x,bb_center.y,bb_center.z).clone().normalize())

            #set target position:
            @_globe._targetCameraPos = new THREE.Vector2(-1*target.y,target.x)

            pos = @_globe._camera.position
            cam_pos = new THREE.Vector3(pos.x,pos.y,pos.z)
            dist = cam_pos.length() - @_globe.getGlobeRadius()

            height = (bb.max.y - bb.min.y)*2

            #set target fov:
            targetFOV = 2* Math.atan(height/(2* dist)) * (180/Math.PI)
            #@_targetFOV = targetFOV
            if targetFOV < @_globe.getMaxFov()
              if targetFOV > @_globe.getMinFov()
                @_globe._targetFOV = targetFOV
                factor = (targetFOV - @_globe.getMinFov() ) / (@_globe.getMaxFov() - @_globe.getMinFov() )
                targetZoom = ((1-factor) * (@_globe.getMaxZoom() - @_globe.getMinZoom() )) + @_globe.getMinZoom()
                @_globe._currentZoom = targetZoom
              else
                @_globe._targetFOV = @_globe.getMinFov()
                @_globe._currentZoom = @_globe.getMaxZoom()
            else
              @_globe._targetFOV = @_globe.getMaxFov()
              @_globe_currentZoom = @_globe.getMinZoom()


  # ============================================================================
  _evaluate: () =>

    mouseRel =
      x: (@_globe._mousePos.x - @_globe._canvasOffsetX) / @_globe._width * 2 - 1
      y: (@_globe._mousePos.y - @_globe._canvasOffsetY) / @_globe._myHeight * 2 - 1

    # picking ------------------------------------------------------------------
    vector = new THREE.Vector3 mouseRel.x, -mouseRel.y, 0.5
    projector = @_globe.getProjector()
    projector.unprojectVector vector, @_globe._camera

    raycaster = @_globe.getRaycaster()

    raycaster.set @_globe._camera.position, vector.sub(@_globe._camera.position).normalize()

    countryIntersects = raycaster.intersectObjects(@_sceneCountries.children)

    if countryIntersects.length > 0
      HG.Display.CONTAINER.style.cursor = "pointer"
    else
      HG.Display.CONTAINER.style.cursor = "auto"

    for mat in @_intersectedMaterials
      mat.opacity = mat.opacity - 0.2

    #hover countries
    for intersect in countryIntersects
      matIndex = intersect.face.materialIndex
      mat = intersect.object.material.materials[matIndex]

      index = @_intersectedMaterials.indexOf(mat)
      @_intersectedMaterials.splice index, 1  if index >= 0
    # unmark previous countries

    '''for intersect in @_intersectedMaterials
      if intersect.Area?
        #intersect.material.color.setHex 0x5b309f
        ##intersect.material.opacity =  intersect.oldOpacity
        if intersect.Area.Label3DIsVisible
          @_hideLabel intersect.Area'''


    @_intersectedMaterials = []
    # hover intersected countries
    for intersect in countryIntersects

      index = intersect.face.materialIndex
      to_change = intersect.object.material.materials[index]
      if to_change.opacity > 0.01
        to_change.opacity = to_change.opacity + 0.2
        @_intersectedMaterials.push to_change


      #if intersect.object.Area?
      #  #console.log intersect.object.id,intersect.object.Label
      #  #intersect.object.oldOpacity = intersect.object.material.opacity
      #  intersect.object.material.opacity = intersect.object.material.opacity + 0.2
      #  '''unless intersect.object.Area.Label3DIsVisible
      #    @_showLabel intersect.object.Area'''
      #  @_intersectedMaterials.push intersect.object
      #  #intersect.object.material.color.setHex 0x04ba67


  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

  TRANS_COLOR = '#D5C900'

  AREA_GLOBE_OFFSET = 0.40
  BORDER_GLOBE_OFFSET = 0.45

  TEXT_HEIGHT = 14
  TEXT_FONT = "#{TEXT_HEIGHT}px Lobster"

  #testCanvas for Sprites
  TEST_CANVAS = document.createElement('canvas')
  TEST_CANVAS.width = 1
  TEST_CANVAS.height = 1
  TEST_CONTEXT = TEST_CANVAS.getContext('2d')
  TEST_CONTEXT.textAlign = 'center'
  TEST_CONTEXT.font = TEXT_FONT
