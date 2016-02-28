#include Extendable.coffee
#include HiventMarker.coffee

window.HG ?= {}

class HG.HiventMarker3D extends HG.HiventMarker

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  #constructor: (hiventHandle, display, parent, scene, markerGroup, logos, latlng) ->
  constructor: (hiventHandle, display, parent, scene, logos, hgInstance) ->

    #HG.mixin @, HG.HiventMarker

    HG.HiventMarker.call @, hiventHandle, parent



    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onMarkerDestruction"

    @_globe = display
    
    @_scene = scene

    @_hgInstance = hgInstance

    @ScreenCoordinates = null

    #new
    #hiventTexture = THREE.ImageUtils.loadTexture('data/hivent_icons/icon_join.png')
    #@_hiventTexture = THREE.ImageUtils.loadTexture(@_getIcon(hiventHandle.getHivent().category))
    #@_hiventTextureHighlight = THREE.ImageUtils.loadTexture(@_getIcon(hiventHandle.getHivent().category+"_highlight"))
    @_hiventTexture = logos.default
    @_hiventTextureHighlight = logos.highlight
    hiventMaterial = new THREE.SpriteMaterial({
        map: @_hiventTexture,
        transparent:true,
        opacity: 1.0,
        useScreenCoordinates: false,
        scaleByViewport: true,
        sizeAttenuation: false,
        depthTest: false,
        affectedByDistance: true

        })
    @sprite = new THREE.Sprite(hiventMaterial)

    @sprite.MaxWidth = HGConfig.hivent_marker_2D_width.val
    @sprite.MaxHeight = HGConfig.hivent_marker_2D_height.val

    @sprite.scale.set(HGConfig.hivent_marker_2D_width.val,HGConfig.hivent_marker_2D_height.val,1.0)

    @getHiventHandle().onFocus(@, (mousePos) =>
      if display.isRunning()
        display.focus @getHiventHandle().getHivent()
    )

    @getHiventHandle().onMark @, (mousePos) =>
      #hiventTexture = THREE.ImageUtils.loadTexture(@_getIcon(hiventHandle.getHivent().category+"_highlight"))
      @sprite.material.map = @_hiventTextureHighlight

    @getHiventHandle().onUnMark @, (mousePos) =>
      #hiventTexture = THREE.ImageUtils.loadTexture(@_getIcon(hiventHandle.getHivent().category))
      @sprite.material.map = @_hiventTexture

    @getHiventHandle().onLink @, (mousePos) =>
      @sprite.material.map = @_hiventTextureHighlight

    @getHiventHandle().onUnLink @, (mousePos) =>
      @sprite.material.map = @_hiventTexture

    @getHiventHandle().onAgeChanged @, (age) =>
      #no more Opacity
      #@sprite.material.opacity = age
      0


    @getHiventHandle().onDestruction @, @destroy
    @getHiventHandle().onVisibleFuture @, @destroy
    @getHiventHandle().onInvisible @, @destroy

    '''@enableShowName()
    @enableShowInfo()'''

  '''getLatLng:() ->#for clustering purposes only
    return @_latlng'''

  # ============================================================================
  onMouseOver:(x,y) ->
    @getHiventHandle().mark @, {x:x, y:y}
    #@getHiventHandle().mark hivent, getPosition()
    @getHiventHandle().linkAll {x:x, y:y}

  # ============================================================================
  onMouseOut:() ->
    @getHiventHandle().unMark @
    @getHiventHandle().unLinkAll()

  # ============================================================================
  onClick:(pos) ->
    #@getHiventHandle().toggleActive @,pos
    @_hgInstance.hiventInfoAtTag?.setOption "event", @_hiventHandle.getHivent().id

  # ============================================================================
  getPosition: ->
    unless @ScreenCoordinates
      @ScreenCoordinates = @_globe._getScreenCoordinates(@sprite.position)

    @ScreenCoordinates

  # ============================================================================
  getDisplayPosition:->
    return @getPosition()

  # ============================================================================
  destroy: ->
    @notifyAll "onMarkerDestruction"
    @_destroy()


  # ============================================================================
  _destroy: ->

    #@_markergroup.removeLayer @
    @getHiventHandle().inActiveAll()
    @_scene.remove @sprite

    #@_onMarkerDestructionCallbacks = []
    @_hiventHandle.removeListener "onFocus", @
    @_hiventHandle.removeListener "onActive", @
    @_hiventHandle.removeListener "onInActive", @
    @_hiventHandle.removeListener "onLink", @
    @_hiventHandle.removeListener "onUnLink", @
    @_hiventHandle.removeListener "onVisibleFuture", @
    @_hiventHandle.removeListener "onInvisible", @
    @_hiventHandle.removeListener "onDestruction", @

    super()
    delete @;
    return

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################



