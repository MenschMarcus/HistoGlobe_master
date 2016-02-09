window.HG ?= {}

# ==============================================================================
# Base class for displays, i.e. 2D Map and 3D Globe. Provides basic interface
# which is implemented in the derived classes.
# ==============================================================================
class HG.Display

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # hgInit is called by the central HistoGlobe object.
  # Stores basic information and registeres callback listeners.
  # ============================================================================
  hgInit: (hgInstance) ->
    # Store the DOM element reserved for displaying map/globe
    HG.Display.CONTAINER ?= hgInstance.mapCanvas
    @overlayContainer = null

    # If all modules are loaded, check whether the module "HiventInfoAtTag" is
    # present and if so, register for notification on URL hash changes.
    hgInstance.onAllModulesLoaded @, () =>

      hgInstance.hiventInfoAtTag?.onHashChanged @, (key, value) =>
        # If the passed URL hash key is "bounds", zoom to the specified area.
        if key is "bounds"
          minMax = value.split ";"
          mins = minMax[0].split ","
          maxs = minMax[1].split ","
          @zoomToBounds(mins[0], mins[1], maxs[0], maxs[1])

      # fullscreen
      @_hgInstance.buttons.fullscreen?.onEnter @, (btn) =>
        body = document.body
        if (body.requestFullscreen)
          body.requestFullscreen()
        else if (body.msRequestFullscreen)
          body.msRequestFullscreen()
        else if (body.mozRequestFullScreen)
          body.mozRequestFullScreen()
        else if (body.webkitRequestFullscreen)
          body.webkitRequestFullscreen()
        btn.changeState 'fullscreen'

      @_hgInstance.buttons.fullscreen?.onLeave @, (btn) =>
        body = document.body
        if (body.requestFullscreen)
          document.cancelFullScreen()
        else if (body.msRequestFullscreen)
          document.msExitFullscreen()
        else if (body.mozRequestFullScreen)
          document.mozCancelFullScreen()
        else if (body.webkitRequestFullscreen)
          document.webkitCancelFullScreen()
        btn.changeState 'normal'

      # high contrast mode
      @_hgInstance.buttons.highContrast?.onEnter @, (btn) =>
        $(@_hgInstance._config.container).addClass 'highContrast'
        btn.changeState 'high-contrast'

      @_hgInstance.buttons.highContrast?.onLeave @, (btn) =>
        $(@_hgInstance._config.container).removeClass 'highContrast'
        btn.changeState 'normal'

      # graph on globe
      @_hgInstance.buttons.graph?.onShow @, (btn) =>
        $(hgInstance._config.container).addClass 'minGUI'
        btn.changeState 'min-layout'

      @_hgInstance.buttons.graph?.onHide @, (btn) =>
        $(hgInstance._config.container).removeClass 'minGUI'
        btn.changeState 'normal'


  # ============================================================================
  # Focus a specific Hivent. "setCenter" is implemented by derived classes.
  # ============================================================================
  focus: (hivent) -> # hivent coords and offset coords
    @setCenter {x: hivent.long, y: hivent.lat}, {x: 0.07, y: 0.2}

  # ============================================================================
  # Interface for zooming to specific bounds. The actual implementation can be
  # found in the derived classes
  # ============================================================================
  zoomToBounds: (minLong, minLat, maxLong, maxLat) ->

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

  @Z_INDEX = 0
  @CONTAINER = null
