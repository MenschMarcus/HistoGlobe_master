window.HG ?= {}

class HG.GraphOnGlobe

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->
    @_globe = null
    @_graphNodeController = null

    @_sceneGraphNode              = new THREE.Scene
    @_sceneGraphNodeConnection    = new THREE.Scene

    @_graphLight             = null

    @_intersectedNodes       = []

    @_visibleNodes           = []

    @_dragStartPos           = null

    @_blockHighlighting      = false

    @_nodeOfInterest         = null

    @_secondNodeOfInterest   = null

    @_highlightedConnections = []

    @_hgInstance = null


    # bundle tests:
    @_connectionMaterials = []
    @_controlPoints = []
    @_controlPoints.push(191.0) # pivot element
    @_controlSize = 20.0
    @_controlFunction = 0.0 # 0 = sine; 1 = square power

    #info tag
    @_infoTag = document.createElement "div"
    @_infoTag.className = "leaflet-label"

    @_infoTag.style.position = "absolute"
    @_infoTag.style.top = "0px"
    @_infoTag.innerHTML = "Hello World"
    @_infoTag.style.visibility = "hidden"
    @_infoTag.style.background = "#fff"
    @_infoTag.style.borderColor = "grey";
    @_infoTag.style.borderWidth = "thin";
    document.body.appendChild(@_infoTag);



  # ============================================================================
  hgInit: (hgInstance) ->
    hgInstance.areasOnGlobe = @

    @_hgInstance = hgInstance

    @_globe = hgInstance.globe

    @_globeCanvas = hgInstance.mapCanvas

    @_graphController = hgInstance.graphController


    if @_globe
      @_globe.onLoaded @, @_initGraph

    else
      console.log "Unable to show areas on Map: Globe module not detected in HistoGlobe instance!"


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _initGraph:() ->

    if @_graphController


      @_graphLight         = new THREE.DirectionalLight( 0xffffff, 1.0);
      @_graphLight.position.set 0, 0, 300
      @_sceneGraphNode.add   @_graphLight
      @_sceneGraphNodeConnection.add   @_graphLight

      if @_hgInstance.graph_button?
        button = @_hgInstance.graph_button
        button.onShowGraph @, () =>
          @_globe.addSceneToRenderer(@_sceneGraphNodeConnection)
          @_globe.addSceneToRenderer(@_sceneGraphNode)
        button.onHideGraph @, () =>
          @_globe.removeSceneFromRenderer(@_sceneGraphNodeConnection)
          @_globe.removeSceneFromRenderer(@_sceneGraphNode)

      else
        @_globe.addSceneToRenderer(@_sceneGraphNodeConnection)
        @_globe.addSceneToRenderer(@_sceneGraphNode)

      window.addEventListener   "mouseup",  @_onMouseUp,         false #for node intersections
      window.addEventListener   "mousedown",@_onMouseDown,       false #for node intersections

      # bundle tests
      window.addEventListener   "keydown",@_onKeyDown,       false
      
      @_graphController.onShowGraphNodeConnection @, (c) =>
        @_showGraphNodeConnection c

      @_graphController.onHideGraphNodeConnection @, (c) =>
        @_hideGraphNodeConnection c

      nodelist = @_graphController.getAllGraphNodes()
      for key,node of nodelist
        node.onShow @, (node) =>
          @_showGraphNode node
        node.onHide @, (node) =>
          @_hideGraphNode node

      
      conlist = @_graphController.getActiveGraphNodeConnections()
      for c in conlist
        @_showGraphNodeConnection c

      node_list = @_graphController.getActiveGraphNodes()
      for n in node_list
        @_showGraphNode(n)
        
      #@_graphController.onShowGraphNode @, (node) =>
      #  @_showGraphNode node

      #@_graphController.onHideGraphNode @, (node) =>
      #  @_hideGraphNode node

      setInterval(@_animate, 100)

    else
      console.error "Unable to show graph on globe: GraphController module not detected in HistoGlobe instance!"

  # ============================================================================
  _animate:() =>
    if @_globe._isRunning
      @_evaluate()

  # ============================================================================
  _showGraphNode: (node) ->

    material = new THREE.MeshBasicMaterial({
      #color: 0x0000ff,
      color: 0x000000,
      side: THREE.DoubleSide,
      opacity     : 0.25,
      transparent : true,
    })

    radius = node._radius
    segments = 32

    circleGeometry = new THREE.CircleGeometry( radius, segments );
    
    circleGeometry.applyMatrix( new THREE.Matrix4().makeScale( Math.pow(1.0 + (Math.abs(node._position[0])/3500),25), 1.0, 1.0) );
    
    mesh = new THREE.Mesh( circleGeometry, material );

    #gps to cart mapping:
    random_height_offset = Math.random()

    for vertex in mesh.geometry.vertices
      cart_coords = @_globe._latLongToCart(
          x:vertex.x + node._position[1]
          y: (2.0 * Math.atan(Math.exp(vertex.y)))-(0.5*Math.PI) + node._position[0],
          @_globe.getGlobeRadius()+random_height_offset) #remove z fighting
      vertex.x = cart_coords.x
      vertex.y = cart_coords.y
      vertex.z = cart_coords.z

    mesh.geometry.verticesNeedUpdate = true;
    mesh.geometry.normalsNeedUpdate = true;
    mesh.geometry.computeVertexNormals();
    mesh.geometry.computeFaceNormals();
    mesh.geometry.computeBoundingSphere();
    
    @_sceneGraphNode.add( mesh );

    node.Mesh3D = mesh
    mesh.Node = node

    node.Mesh3D.Radius = node._radius

    @_visibleNodes.push node

    #add control point displacing edges:
    @_addControlPoint(@_controlFunction,radius*3.0,node._position[1],node._position[0])
    # latLong =
    #   x: node._position[0]
    #   y: node._position[1]
    # mercator = @_globe._normalizedLatLongToNormalizedMercatus(@_globe._normalizeLatLong(latLong))
    # @_addControlPoint(@_controlFunction,radius*3.0,mercator.y,mercator.x)

    node.onRadiusChange @, (node) =>
        @_onGraphNodeChanged node


  # ============================================================================
  _hideGraphNode: (node) ->
    @_sceneGraphNode.remove node.Mesh3D
    index = @_visibleNodes.indexOf(node)
    @_visibleNodes.splice(index, 1) if index >= 0
    @_removeControlPoint(node._position[1],node._position[0])

  # ============================================================================
  _onGraphNodeChanged: (node) =>

    index = @_visibleNodes.indexOf(node)
    if node.Mesh3D.Radius isnt node._radius and index >= 0
      old_color = node.Mesh3D.material.color
      @_hideGraphNode node
      @_showGraphNode node
      node.Mesh3D.material.color=old_color
  
  # ============================================================================
  _showGraphNodeConnection: (connection) ->

    connectionOpacity = OPACITY_MIN
    #connectionOpacity = connection.getDuration()/(1000*60*60*24*365*100)

    showConnection = true

    isHighlightedConnection = false

    if @_secondNodeOfInterest

      linkedNodes = connection.getLinkedNodes()
      if linkedNodes[0] is @_nodeOfInterest and linkedNodes[1] is @_secondNodeOfInterest or
      linkedNodes[1] is @_nodeOfInterest and linkedNodes[0] is @_secondNodeOfInterest

        connectionOpacity = OPACITY_MAX
        linkedNodes[0].Mesh3D.material.opacity = OPACITY_MAX
        linkedNodes[1].Mesh3D.material.opacity = OPACITY_MAX

        isHighlightedConnection = true

      else
        showConnection = false

    else

      if @_nodeOfInterest
        linkedNodes = connection.getLinkedNodes()
        if(linkedNodes[0] isnt @_nodeOfInterest and linkedNodes[1] isnt @_nodeOfInterest)
           showConnection = false
        else
          connectionOpacity = OPACITY_MAX
          linkedNodes[0].Mesh3D.material.opacity = OPACITY_MAX
          linkedNodes[1].Mesh3D.material.opacity = OPACITY_MAX

    latLongA =
      x: connection.startPoint[0]
      y: connection.startPoint[1]

    latLongB =
      x: connection.endPoint[0]
      y: connection.endPoint[1]


    # mercatorA = @_globe._normalizedLatLongToNormalizedMercatus(@_globe._normalizeLatLong(latLongA))
    # mercatorB = @_globe._normalizedLatLongToNormalizedMercatus(@_globe._normalizeLatLong(latLongB))

    lineGeometry = new THREE.Geometry

    currentPosLat = latLongA.x
    currentPosLng = latLongA.y


    # equidistant interpolation:
    # location range
    lat_diff = latLongB.x-latLongA.x
    lng_diff = latLongB.y-latLongA.y

    if Math.abs(lng_diff)>180
      lng_diff =(360 - Math.abs(latLongA.y) - Math.abs(latLongB.y))/-1


    # location interpolation direction
    dir = new THREE.Vector2 lat_diff,lng_diff
    dir.normalize()

    stepLat = dir.x*CONNECTION_STEP_SIZE
    stepLng = dir.y*CONNECTION_STEP_SIZE

    alphaLat = Math.abs(stepLat)
    alphaLng = Math.abs(stepLng)
    #counter = 0
    while(not((currentPosLat<(latLongB.x+alphaLat) and currentPosLat>(latLongB.x-alphaLat)) or 
              (currentPosLng<(latLongB.y+alphaLng) and currentPosLng>(latLongB.y-alphaLng))))
      
      # forward coordinate transformation to shader:
      
      # mercator =
      #   x: currentPosLat
      #   y: currentPosLng
      # latlong = mercator
      # lineGeometry.vertices.push new THREE.Vector3(latlong.x,latlong.y, 1.0)
      lineGeometry.vertices.push new THREE.Vector3(currentPosLat,currentPosLng, 1.0)

      currentPosLat+= stepLat
      currentPosLng+= stepLng

      if currentPosLng > 180.0 
        currentPosLng = -180.0 + (currentPosLng-180.0)
      if currentPosLng < -180.0
        currentPosLng = 180.0 - (currentPosLng+180.0)

      #break if counter > 100
      #++counter

    shader = SHADERS.bundle

    uniforms      = THREE.UniformsUtils.clone shader.uniforms
    uniforms.opacity.value  = connectionOpacity

    uniforms.line_begin.value = lineGeometry.vertices[0]
    uniforms.line_end.value = lineGeometry.vertices[lineGeometry.vertices.length-1]

    # arc:
    uniforms.max_offset.value = 0.0
    line_center = lineGeometry.vertices[Math.round(lineGeometry.vertices.length/2)]
    uniforms.line_center.value = line_center

    # connection group offset:
    linked_nodes = connection.getLinkedNodes()
    connection_group = linked_nodes[0].getConnectionsWithNode(linked_nodes[1])
    index = 0
    for c in connection_group
      if c is connection
        uniforms.group_offset.value = index
        break
      ++index if c.Mesh3D isnt null


    lineMaterial = new THREE.ShaderMaterial(
      vertexShader:   shader.vertexShader
      fragmentShader: shader.fragmentShader
      uniforms:       uniforms
      transparent:    true
    )

    uniforms.color.value = connection.getColor()

    #reduce number of potential/nearest control points:
    personalPoints = []
    personalPoints.push(191.0) # pivot element
    lineMaterial.maxLat = Math.max(latLongA.x,latLongB.x)
    lineMaterial.minLat = Math.min(latLongA.x,latLongB.x)
    lineMaterial.maxLng = Math.max(latLongA.y,latLongB.y)
    lineMaterial.minLng = Math.min(latLongA.y,latLongB.y)
    for i in [0..@_controlPoints.length] by CONTROL_POINT_BUFFER_LAYOUT_LENGTH
      lat = @_controlPoints[i]
      lng = @_controlPoints[i+1]
      size = @_controlPoints[i+2]
      func = @_controlPoints[i+3]

      if(lat < lineMaterial.maxLat+BUNDLE_TOLERANCE and
      lat > lineMaterial.minLat-BUNDLE_TOLERANCE and
      lng < lineMaterial.maxLng+BUNDLE_TOLERANCE and
      lng > lineMaterial.minLng-BUNDLE_TOLERANCE)
        personalPoints.unshift(func)
        personalPoints.unshift(size)
        personalPoints.unshift(lng)
        personalPoints.unshift(lat)

    lineMaterial.uniforms.control_points.value = personalPoints

    @_connectionMaterials.push(lineMaterial)
  
    connectionLine = new THREE.Line( lineGeometry, lineMaterial)
    if showConnection
      @_sceneGraphNodeConnection.add connectionLine
      connection.isVisible = true
    else
      connection.isVisible = false

    connection.Mesh3D = connectionLine

    if isHighlightedConnection
       @_highlightedConnections.push connection
       @_showGraphNodeConnectionInfo connection

  # ============================================================================
  _hideGraphNodeConnection: (connection) ->
    
    connection.isVisible = false
    if @_secondNodeOfInterest
      linkedNodes = connection.getLinkedNodes()
      linkedNodes[0].Mesh3D.material.opacity = OPACITY_MIN
      linkedNodes[1].Mesh3D.material.color.opacity = OPACITY_MIN

      @_nodeOfInterest.Mesh3D.material.opacity = OPACITY_MAX
      @_secondNodeOfInterest.Mesh3D.material.opacity = OPACITY_MAX
    else
      if @_nodeOfInterest
        linkedNodes = connection.getLinkedNodes()
        if linkedNodes[0] is @_nodeOfInterest
          linkedNodes[1].Mesh3D.material.opacity = OPACITY_MIN
          for c in linkedNodes[1].getConnections()
            if c.isVisible
              linkedNodes[1].Mesh3D.material.opacity = OPACITY_MAX
              break
        if linkedNodes[1] is @_nodeOfInterest
          linkedNodes[0].Mesh3D.material.opacity = OPACITY_MIN
          for c in linkedNodes[0].getConnections()
            if c.isVisible
              linkedNodes[0].Mesh3D.material.opacity = OPACITY_MAX
              break

    if connection.Mesh3D
      index = @_connectionMaterials.indexOf(connection.Mesh3D.material)
      @_connectionMaterials.splice(index, 1) if index > -1
    @_sceneGraphNodeConnection.remove connection.Mesh3D
    connection.Mesh3D = null

    for c in @_highlightedConnections
      if c is connection
        @_sceneGraphNodeConnection.remove c.Label3D

    # update connection group offset:
    linked_nodes = connection.getLinkedNodes()
    connection_group = linked_nodes[0].getConnectionsWithNode(linked_nodes[1])
    index = 0
    for c in connection_group
      if c.Mesh3D isnt null
        c.Mesh3D.material.uniforms.group_offset.value = index
        ++index

  # ============================================================================
  _showGraphNodeConnectionInfo: (connection) ->

    if connection.Mesh3D

      unless connection.Label3D

        text = "Alliance Type: "
        for t,v of connection.getInfoForShow()
          text+=t if v
          text+=" " if v

        metrics = TEST_CONTEXT.measureText(text)
        textWidth = metrics.width+(2*(TEXT_HEIGHT/10))
        textHeight = TEXT_HEIGHT+(2*(TEXT_HEIGHT/10))

        canvas = document.createElement('canvas')
        canvas.width = textWidth
        canvas.height = textHeight

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

        rgb_color = connection.getColor()
        three_color = new THREE.Color();
        three_color.setRGB(rgb_color.x,rgb_color.y,rgb_color.z)
        hex = three_color.getHexString()
        #context.fillStyle="#000000";
        context.fillStyle= "##{hex}";
        context.fillText(text,textWidth/2,textHeight*0.75)

        texture = new THREE.Texture(canvas)
        texture.needsUpdate = true
        material = new THREE.SpriteMaterial({
          map: texture,
          transparent:false,
          useScreenCoordinates: false,
          scaleByViewport: true,
          sizeAttenuation: false,
          depthTest: false,
          affectedByDistance: false
          })

        sprite = new THREE.Sprite(material)
        sprite.textWidth = textWidth

        @_sceneGraphNodeConnection.add sprite
        sprite.scale.set(textWidth,textHeight,1.0)
        #sprite.position.set position.x,position.y,position.z

        # position
        vertices = connection.Mesh3D.geometry.vertices
        index = @_highlightedConnections.indexOf(connection)
        #position = vertices[Math.round(vertices.length*((index+1.0)/(@_highlightedConnections.length+1.0)))]
        position = vertices[Math.round(vertices.length/2)]
        cart_coords = @_globe._latLongToCart(
          x:position.y
          y:position.x-(index*1.0),# list of infos with 1.0 gps degree distance
          @_globe.getGlobeRadius())
        sprite.position.set cart_coords.x,cart_coords.y,cart_coords.z

        sprite.MaxWidth = textWidth
        sprite.MaxHeight = textHeight

        connection.Label3D = sprite
      
      else
        @_sceneGraphNodeConnection.add connection.Label3D
        # update position
        vertices = connection.Mesh3D.geometry.vertices
        index = @_highlightedConnections.indexOf(connection)
        #position = vertices[Math.round(vertices.length*((index+1.0)/(@_highlightedConnections.length+1.0)))]
        position = vertices[Math.round(vertices.length/2)]
        cart_coords = @_globe._latLongToCart(
          x:position.y
          y:position.x-(index*1.0),# list of infos with 1.0 gps degree distance
          @_globe.getGlobeRadius())
        connection.Label3D.position.set cart_coords.x,cart_coords.y,cart_coords.z

  # ============================================================================
  _addControlPoint: (functionID,size,lng,lat) =>

    # remove potential old one
    for i in [0 .. @_controlPoints.length-1] by CONTROL_POINT_BUFFER_LAYOUT_LENGTH
      if @_controlPoints[i] is lat and @_controlPoints[i+1] is lng
        @_controlPoints.splice(i, CONTROL_POINT_BUFFER_LAYOUT_LENGTH);
        #break

    # interactive point:
    interactive_point = null
    if @_controlPoints.length >= CONTROL_POINT_BUFFER_LAYOUT_LENGTH
      interactive_point = @_controlPoints.splice(0,CONTROL_POINT_BUFFER_LAYOUT_LENGTH)

    #new point
    new_point = [lat,lng,size,functionID]
    @_controlPoints = new_point.concat(@_controlPoints)

    # individual cp lists of connections
    for mat in @_connectionMaterials

      if(lat < mat.maxLat+BUNDLE_TOLERANCE and
      lat > mat.minLat-BUNDLE_TOLERANCE and
      lng < mat.maxLng+BUNDLE_TOLERANCE and
      lng > mat.minLng-BUNDLE_TOLERANCE)

        mat.uniforms.control_points.value.splice(0,CONTROL_POINT_BUFFER_LAYOUT_LENGTH) if mat.uniforms.control_points.value.length >= CONTROL_POINT_BUFFER_LAYOUT_LENGTH
        # search for old one
        found_old = false
        for i in [0 .. mat.uniforms.control_points.value.length-1] by CONTROL_POINT_BUFFER_LAYOUT_LENGTH
          if mat.uniforms.control_points.value[i] is lat and mat.uniforms.control_points.value[i+1] is lng
            mat.uniforms.control_points.value[i+2] = size
            mat.uniforms.control_points.value[i+3] = functionID
            found_old = true
            #mat.uniforms.control_points.value.splice(i, CONTROL_POINT_BUFFER_LAYOUT_LENGTH);
            break
        mat.uniforms.control_points.value = new_point.concat(mat.uniforms.control_points.value) if not found_old
        mat.uniforms.control_points.value = interactive_point.concat(mat.uniforms.control_points.value) if interactive_point isnt null

    # interactive point:
    if interactive_point != null
      @_controlPoints = interactive_point.concat(@_controlPoints)

    
  # ============================================================================
  _removeControlPoint: (lng,lat) =>

    for i in [0 .. @_controlPoints.length-1] by CONTROL_POINT_BUFFER_LAYOUT_LENGTH
      if @_controlPoints[i] is lat and @_controlPoints[i+1] is lng
        @_controlPoints.splice(i, CONTROL_POINT_BUFFER_LAYOUT_LENGTH);
        break

    for mat in @_connectionMaterials
      if(lat < mat.maxLat+BUNDLE_TOLERANCE and
      lat > mat.minLat-BUNDLE_TOLERANCE and
      lng < mat.maxLng+BUNDLE_TOLERANCE and
      lng > mat.minLng-BUNDLE_TOLERANCE)
        for i in [0 .. mat.uniforms.control_points.value.length-1] by CONTROL_POINT_BUFFER_LAYOUT_LENGTH
            if mat.uniforms.control_points.value[i] is lat and mat.uniforms.control_points.value[i+1] is lng
              mat.uniforms.control_points.value.splice(i, CONTROL_POINT_BUFFER_LAYOUT_LENGTH);


  # ============================================================================
  #bundle tests
  _onKeyDown: (key) =>
    if key.keyCode is 187 # +
      @_controlSize += 1
    if key.keyCode is 189 # -
      @_controlSize -= 1
    if key.keyCode is 13 # ENTER
      @_addControlPoint(@_controlPoints[3],@_controlPoints[2],@_controlPoints[1],@_controlPoints[0])
    if key.keyCode is 70 # F
      @_controlFunction += 1.0
      @_controlFunction = @_controlFunction % 2
      console.log @_controlFunction


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

        nodeIntersects = raycaster.intersectObjects @_sceneGraphNode.children
        
        if nodeIntersects.length is 0 or @_secondNodeOfInterest
          #show all
          for c in @_graphController.getActiveGraphNodeConnections()
             @_sceneGraphNodeConnection.add c.Mesh3D if not c.isVisible and c.Mesh3D
             c.isVisible = true
          @_blockHighlighting = false
          @_nodeOfInterest = null
          @_secondNodeOfInterest = null

          for c in @_highlightedConnections
            @_sceneGraphNodeConnection.remove c.Label3D
          @_highlightedConnections = []

          @_evaluate()
        
        #hide uninvolved
        if nodeIntersects.length > 0

          if @_nodeOfInterest and nodeIntersects[0].object.Node isnt @_nodeOfInterest
            @_secondNodeOfInterest = @_nodeOfInterest
            @_intersectedNodes.push nodeIntersects[0].object
            @_nodeOfInterest = nodeIntersects[0].object.Node
            for c in @_secondNodeOfInterest.getConnections()

              #info:
              if c.isActive() and c.getLinkedNodes()[0] is @_nodeOfInterest and c.getLinkedNodes()[1] is @_secondNodeOfInterest or
              c.getLinkedNodes()[1] is @_nodeOfInterest and c.getLinkedNodes()[0] is @_secondNodeOfInterest
                @_highlightedConnections.push c

              for node in c.getLinkedNodes()
                if node isnt @_nodeOfInterest and node isnt @_secondNodeOfInterest
                  #c_color = c.getColor()
                  c.Mesh3D.material.uniforms.max_offset.value = 0.0 if c.Mesh3D
                  c.Mesh3D.material.uniforms.opacity.value = OPACITY_MIN if c.Mesh3D
                  #c.Mesh3D.material.uniforms.opacity.value = c.getDuration()/(1000*60*60*24*365*100) if c.Mesh3D
                  node.Mesh3D.material.opacity = OPACITY_MIN if node.Mesh3D

            @_nodeOfInterest.Mesh3D.material.opacity = OPACITY_MAX

            for hc in @_highlightedConnections 
              @_showGraphNodeConnectionInfo(hc)

          @_nodeOfInterest = nodeIntersects[0].object.Node

          to_be_removed = [].concat(@_graphController.getActiveGraphNodeConnections())
          for c in nodeIntersects[0].object.Node.getConnections()

            index = $.inArray(c, to_be_removed)
            to_be_removed.splice index, 1  if index >= 0
            c.Mesh3D.material.uniforms.max_offset.value = c.getDuration()/(1000*60*60*24*365) if c.Mesh3D

          @_blockHighlighting = true

          for c in to_be_removed
            @_sceneGraphNodeConnection.remove c.Mesh3D if c.Mesh3D
            c.isVisible = false


  # ============================================================================
  _evaluate: () =>

    unless @_blockHighlighting

      mouseRel =
      x: (@_globe._mousePos.x - @_globe._canvasOffsetX) / @_globe._width * 2 - 1
      y: (@_globe._mousePos.y - @_globe._canvasOffsetY) / @_globe._myHeight * 2 - 1


      # ###############
      # # bundle tests:
      # # interactive mouse lense
      # latLongCurr = @_globe._pixelToLatLong mouseRel
      # if latLongCurr isnt null
      #   if @_controlPoints.length > 1
      #     @_controlPoints.slice(0,CONTROL_POINT_BUFFER_LAYOUT_LENGTH)

      #   updated_point = [latLongCurr.x,-latLongCurr.y,@_controlSize,@_controlFunction]
      #   @_controlPoints = updated_point.concat(@_controlPoints)
      #   for mat in @_connectionMaterials
      #     mat.uniforms.control_points.value.splice(0,CONTROL_POINT_BUFFER_LAYOUT_LENGTH)
      #     mat.uniforms.control_points.value = updated_point.concat(mat.uniforms.control_points.value)
      #     #mat.uniforms.control_points.value = @_controlPoints
      # ###############


      # picking ------------------------------------------------------------------
      # test for mark and highlight hivents
      vector = new THREE.Vector3 mouseRel.x, -mouseRel.y, 0.5
      projector = @_globe.getProjector()
      projector.unprojectVector vector, @_globe._camera

      raycaster = @_globe.getRaycaster()

      raycaster.set @_globe._camera.position, vector.sub(@_globe._camera.position).normalize()

      nodeIntersects = raycaster.intersectObjects @_sceneGraphNode.children

      if nodeIntersects.length > 0
        HG.Display.CONTAINER.style.cursor = "pointer"
      else
        HG.Display.CONTAINER.style.cursor = "auto"

      for intersect in @_intersectedNodes

        for c in intersect.Node.getConnections()
          c.Mesh3D.material.uniforms.max_offset.value = 0.0  if c.Mesh3D
          c.Mesh3D.material.uniforms.opacity.value =  OPACITY_MIN if c.Mesh3D
          #c.Mesh3D.material.uniforms.opacity.value =  c.getDuration()/(1000*60*60*24*365*100) if c.Mesh3D
          for node in c.getLinkedNodes()
            node.Mesh3D.material.opacity = OPACITY_MIN if node.Mesh3D
        intersect.Node.Mesh3D.material.opacity = OPACITY_MIN

      if nodeIntersects.length is 0
        @_infoTag.style.visibility = "hidden"

      #hover countries
      for intersect in nodeIntersects 
        index = $.inArray(intersect.object, @_intersectedNodes)
        @_intersectedNodes.splice index, 1  if index >= 0

      @_intersectedNodes = []
      # hover intersected countries
      for intersect in nodeIntersects

        name = intersect.object.Node.getName()
        x = @_globe._mousePos.x - @_globe._canvasOffsetX + 10;
        y = @_globe._mousePos.y - @_globe._canvasOffsetY + 10;
        @_infoTag.style.visibility = "visible"
        @_infoTag.style.top = "#{y}px"
        @_infoTag.style.left = "#{x}px"
        @_infoTag.innerHTML = "#{name}"

        for c in intersect.object.Node.getConnections()
          if c.isVisible
            c.Mesh3D.material.uniforms.opacity.value = OPACITY_MAX if c.Mesh3D

            for node in c.getLinkedNodes()
              node.Mesh3D.material.opacity = OPACITY_MAX if node.Mesh3D

        intersect.object.material.opacity = OPACITY_MAX
      
        @_intersectedNodes.push intersect.object

    else

      mouseRel =
        x: (@_globe._mousePos.x - @_globe._canvasOffsetX) / @_globe._width * 2 - 1
        y: (@_globe._mousePos.y - @_globe._canvasOffsetY) / @_globe._myHeight * 2 - 1
      # picking ------------------------------------------------------------------
      vector = new THREE.Vector3 mouseRel.x, -mouseRel.y, 0.5
      projector = @_globe.getProjector()
      projector.unprojectVector vector, @_globe._camera

      raycaster = @_globe.getRaycaster()

      raycaster.set @_globe._camera.position, vector.sub(@_globe._camera.position).normalize()

      nodeIntersects = raycaster.intersectObjects @_sceneGraphNode.children

      if nodeIntersects.length > 0
        HG.Display.CONTAINER.style.cursor = "pointer"
      else
        HG.Display.CONTAINER.style.cursor = "auto"
      @_infoTag.style.visibility = "hidden"

      if nodeIntersects.length is 0
        @_infoTag.style.visibility = "hidden"
        
      for intersect in nodeIntersects

        name = intersect.object.Node.getName()
        x = @_globe._mousePos.x - @_globe._canvasOffsetX + 10;
        y = @_globe._mousePos.y - @_globe._canvasOffsetY + 10;
        @_infoTag.style.visibility = "visible"
        @_infoTag.style.top = "#{y}px"
        @_infoTag.style.left = "#{x}px"
        @_infoTag.innerHTML = "#{name}"

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################
  TEXT_HEIGHT = 14
  TEXT_FONT = "#{TEXT_HEIGHT}px Lobster"

  #testCanvas for Sprites
  TEST_CANVAS = document.createElement('canvas')
  TEST_CANVAS.width = 1
  TEST_CANVAS.height = 1
  TEST_CONTEXT = TEST_CANVAS.getContext('2d')
  TEST_CONTEXT.textAlign = 'center'
  TEST_CONTEXT.font = TEXT_FONT

  OPACITY_MIN = 0.1
  OPACITY_MAX = 0.6

  BUNDLE_TOLERANCE = 10.0 # degree
  CONNECTION_STEP_SIZE = 0.1 # degree

  # control_points BUFFER_LAYOUT:
  # n:    lat
  # n+1:  lng
  # n+2:  size
  # n+3:  functionID
  CONTROL_POINT_BUFFER_LAYOUT_LENGTH = 4

  # shaders for the graph node connections
  SHADERS =
    # arc:
    #   uniforms:

    #     max_offset:
    #       type: "f"
    #       value: 0.0

    #     line_center:
    #       type: "v3"
    #       value: null

    #     line_begin:
    #       type: "v3"
    #       value: null

    #     line_end:
    #       type: "v3"
    #       value: null  

    #     opacity:
    #       type: "f"
    #       value: 0.0

    #   vertexShader: ''

    #   fragmentShader: ''

    bundle:
      uniforms:

        color:
          type: "v3"
          value: null

        control_points:
          type: "fv1"
          value: []

        opacity:
          type: "f"
          value: 0.0

        line_begin:
          type: "v3"
          value: null

        line_end:
          type: "v3"
          value: null

        group_offset:
          type: "f"
          value: 0.0

        max_offset:
          type: "f"
          value: 0.0

        line_center:
          type: "v3"
          value: null

      vertexShader: ''

      fragmentShader: ''

  bundle_vs_request = new XMLHttpRequest()
  bundle_vs_request.open('GET', 'script/modules/graph/bundle.vs')
  bundle_vs_request.onreadystatechange = () =>
    SHADERS.bundle.vertexShader =  bundle_vs_request.responseText
  bundle_vs_request.send()

  bundle_fs_request = new XMLHttpRequest()
  bundle_fs_request.open('GET', 'script/modules/graph/bundle.fs')
  bundle_fs_request.onreadystatechange = () =>
    SHADERS.bundle.fragmentShader = bundle_fs_request.responseText
  bundle_fs_request.send()

