window.HG ?= {}

class HG.ControlButtons

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # for new control button:
  #   define identifier (id) for control (e.g. 'fullscreen')
  #   -> new entry in default config in constructor (default set false 'false')
  #   set config in switch-when with new id
  #     1. init button itself
  #     2. set functionality of the button (listen to own callback)
  # if control button is used:
  #   in modules.json in module 'ControlButtons' set id to true
  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      zoom :          true
      fullscreen :    true
      highContrast :  false
      minLayout :     false
      graphButton :   false

    @_config = $.extend {}, defaultConfig, config

  # ============================================================================
  hgInit: (@_hgInstance) ->

    # idea: module "ControlButtons" is instance of class "ButtonArea"
    @_hgInstance.control_buttons = new HG.ButtonArea 'controlButtons', 'bottom-left', 'vertical'
    @_hgInstance.control_buttons.hgInit @_hgInstance

    # init predefined buttons
    for id, enable of @_config
      if enable
        switch id                 # selects class of required button
          when 'zoom' then (
            new HG.Button @_hgInstance,
              {
                'parentArea':   @_hgInstance.control_buttons,
                'groupName':    'zoom'
                'id':           'zoomInButton',
                'states': [
                  {
                    'id':       'normal',
                    'tooltip':  "Zoom In",
                    'iconFA':   'plus',
                    'callback': 'onZoomIn'
                  }
                ]
              }
            new HG.Button @_hgInstance,
              {
                'parentArea':   @_hgInstance.control_buttons,
                'groupName':    'zoom'
                'id':           'zoomOutButton',
                'states': [
                  {
                    'id':       'normal',
                    'tooltip':  "Zoom Out",
                    'iconFA':   'minus',
                    'callback': 'onZoomOut'
                  }
                ]
              }
          )

          # fullscreen mode
          when 'fullscreen' then (
            # 1. init button
            new HG.Button @_hgInstance,
              {
                'parentArea':   @_hgInstance.control_buttons,
                'id':           'fullscreenButton',
                'states': [
                  {
                    'id':       'normal',
                    'tooltip':  "Fullscreen",
                    'iconFA':   'expand',
                    'callback': 'onEnterFullscreen'
                  },
                  {
                    'id':       'fullscreen',
                    'tooltip':  "Leave Fullscreen",
                    'iconFA':   'compress',
                    'callback': 'onLeaveFullscreen'
                  }
                ]
              }

            # 2. set functionality
            @_hgInstance.buttons.fullscreenButton.onEnterFullscreen @, (btn) =>
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

            @_hgInstance.buttons.fullscreenButton.onLeaveFullscreen @, (btn) =>
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
          )

          # high contrast mode
          when 'highContrast' then (
            # 1. init button
            new HG.Button @_hgInstance,
              {
                'parentArea':   @_hgInstance.control_buttons,
                'id':           'highContrastButton',
                'states': [
                  {
                    'id':       'normal',
                    'tooltip':  "High-Contrast Mode",
                    'iconFA':   'adjust',
                    'callback': 'onEnterHighContrast'
                  },
                  {
                    'id':       'high-contrast',
                    'tooltip':  "Normal Color Mode",
                    'iconFA':   'adjust',
                    'callback': 'onLeaveHighContrast'
                  }
                ]
              }

            # 2. set functionality
            @_hgInstance.buttons.highContrastButton.onEnterHighContrast @, (btn) =>
              $(@_hgInstance._config.container).addClass 'highContrast'
              btn.changeState 'high-contrast'

            @_hgInstance.buttons.highContrastButton.onLeaveHighContrast @, (btn) =>
              $(@_hgInstance._config.container).removeClass 'highContrast'
              btn.changeState 'normal'

          )

          # minimal layout mode
          when 'minLayout' then (
            # 1. init button
            new HG.Button @_hgInstance,
              {
                'parentArea':   @_hgInstance.control_buttons,
                'id':           'minLayoutButton',
                'states': [
                  {
                    'id':       'normal',
                    'tooltip':  "Simplify User Interface",
                    'iconFA':   'sort-desc',
                    'callback': 'onRemoveGUI'
                  },
                  {
                    'id':       'min-layout',
                    'tooltip':  "Restore Interface",
                    'iconFA':   'sort-asc',
                    'callback': 'onOpenGUI'
                  }
                ]
              }

            # 2. set functionality
            @_hgInstance.buttons.minLayoutButton.onRemoveGUI @, (btn) =>
              $(@_hgInstance._config.container).addClass 'minGUI'
              btn.changeState 'min-layout'

            @_hgInstance.buttons.minLayoutButton.onOpenGUI @, (btn) =>
              $(@_hgInstance._config.container).removeClass 'minGUI'
              btn.changeState 'normal'
          )

          # graph mode
          when 'graph' then (
            # 1. init button
            new HG.Button @_hgInstance,
              {
                'parentArea':   @_hgInstance.control_buttons,
                'id':           'graphButton',
                'states': [
                  {
                    'id':       'normal',
                    'tooltip':  "Show Alliances",
                    'iconFA':   'share-alt',
                    'callback': 'onShowGraph'
                  },
                  {
                    'id':       'graph',
                    'tooltip':  "Hide Alliances",
                    'iconFA':   'share-alt',
                    'callback': 'onHideGraph'
                  }
                ]
              }

            # 2. set functionality
            @_hgInstance.buttons.graphButton.onShowGraph @, (btn) =>
              $(hgInstance._config.container).addClass 'minGUI'
              btn.changeState 'min-layout'

            @_hgInstance.buttons.graphButton.onHideGraph @, (btn) =>
              $(hgInstance._config.container).removeClass 'minGUI'
              btn.changeState 'normal'
          )
