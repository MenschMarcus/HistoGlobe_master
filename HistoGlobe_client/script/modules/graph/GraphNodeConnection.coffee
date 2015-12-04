window.HG ?= {}

class HG.GraphNodeConnection

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (latlngA,latlngB,startTime,endTime,info) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @
    @addCallback "onShow"
    @addCallback "onHide"

    @startPoint = [latlngA.lat,latlngA.lng]

    @endPoint = [latlngB.lat,latlngB.lng]

    @_startTime = startTime

    @_endTime = endTime

    @linkedNodes = []

    @_active = true

    @_now = new Date(2000, 1, 1)

    @_info = info

    @isInfoVisible = false

    @_actionQueue = [] # 1 = future insertion; 0 = future deletion

  # ============================================================================
  setDate: (newDate) ->

    @_now = newDate

    new_active = @_isActive()

    if new_active and not @_active

      @_actionQueue.push 1

    if not new_active and @_active

      @_actionQueue.push 0

    @_active = new_active

  # ============================================================================
  drawChanges: () ->

    final_action = null
    final_action = 0 if @_actionQueue.length > 0

    while @_actionQueue.length > 0
      action = @_actionQueue.shift()
      final_action *= action if action is 0
      final_action += action if action is 1

    if final_action isnt null
      if final_action > 0
        for node in @linkedNodes
          node.addConnection(@)
          node.increaseRadius()
        @notifyAll "onShow", @
      if final_action is 0
        for node in @linkedNodes
          node.removeConnection(@)
          node.decreaseRadius()
        @notifyAll "onHide", @

  # ============================================================================
  isActive:()->
    return @_active

  # ============================================================================
  addLinkedNode: (node) =>
    @linkedNodes.push node

  # ============================================================================
  getLinkedNodes: () =>
    
    return @linkedNodes

  # ============================================================================
  getInfoForShow: () =>
    @isInfoVisible = true;
    return @_info

  # ============================================================================
  getDuration: () =>
    return @_endTime - @_startTime

  # ============================================================================
  getColor: () =>

    count = 0
    ret_color = {r:0,g:0,b:0}

    if @_info.defense
      ret_color.r+=0.5
      ret_color.g+=0
      ret_color.b+=0
      ++count
    if @_info.neutrality
      ret_color.r+=0.5
      ret_color.g+=0.5
      ret_color.b+=0
      ++count
    if @_info.nonaggression
      ret_color.r+=0
      ret_color.g+=0.5
      ret_color.b+=0
      ++count
    if @_info.entente
      ret_color.r+=0
      ret_color.g+=0
      ret_color.b+=0.5
      ++count
    if count is not 0
      ret_color.r = ret_color.r/count
      ret_color.g = ret_color.g/count
      ret_color.b = ret_color.b/count
    return new THREE.Vector3(ret_color.r, ret_color.g, ret_color.b)

  # ============================================================================
  _isActive: () =>

    return @_startTime < @_now and @_now < @_endTime

