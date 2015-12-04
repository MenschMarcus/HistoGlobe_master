window.HG ?= {}

class HG.GraphNode

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (name,latlng) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @


    @addCallback "onShow"
    @addCallback "onHide"
    @addCallback "onStyleChange"
    @addCallback "onRadiusChange"

    @_initMembers()

    @_name = name
    @_position = [latlng.lat,latlng.lng]

  # ============================================================================
  increaseRadius: ->
    if @_active
      @_radius = @_radius+0.02
      @_radius_changed = true
      #@notifyAll "onRadiusChange", @

  # ============================================================================
  decreaseRadius: ->
    if @_active
      @_radius = @_radius-0.02
      @_radius_changed = true
      #@notifyAll "onRadiusChange", @

  # ============================================================================
  drawChanges: ->
    if @_radius_changed and @_active
      @_radius_changed = false
      @notifyAll "onRadiusChange", @

  # ============================================================================
  getName: ->
    return @_name

  # # ============================================================================
  # setDate: (newDate) ->

  #   @_now = newDate

  # ============================================================================
  isActive:()->
    return @_active

  # ============================================================================
  addConnection:(connection)->
    if @_connections.length is 0
      @notifyAll "onShow", @
      @_active = true
    @_connections.push connection

  # ============================================================================
  removeConnection:(connection)->
    index = $.inArray(connection, @_connections)
    @_connections.splice index, 1  if index >= 0
    if @_connections.length is 0
      @notifyAll "onHide", @
      @_active = false

  # ============================================================================
  getConnections:()->
    return @_connections

  # ============================================================================
  getConnectionsWithNode:(node)->
    connections_with_node = []
    for c in @_connections
      linked_nodes = c.getLinkedNodes()
      if linked_nodes[0] is node or linked_nodes[1] is node
        connections_with_node.push c
    return connections_with_node



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  _initMembers: ->

    @_radius = 0.2
    @_radius_changed = false

    @_color = "#D2CDC3"

    @_now = new Date(2000, 1, 1)
    @_active = false

    @_connections = []