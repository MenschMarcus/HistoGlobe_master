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
    @_buttonArea = new HG.ButtonArea @_hgInstance,
    {
      'id':           'controlButtons',
      'positionX':    'left',
      'positionY':    'bottom',
      'orientation':  'vertical'
    }

    @_hgInstance.controlButtons = @_buttonArea

    # init predefined buttons
    for id, enable of @_config
      if enable
        switch id                 # selects class of required button
          when 'zoom' then (
            new HG.Button @_hgInstance,
              {
                'parentArea':   @_hgInstance.controlButtons,
                'groupName':    'zoom'
                'id':           'zoomIn',
                'states': [
                  {
                    'id':       'normal',
                    'tooltip':  "Zoom In",
                    'iconFA':   'plus',
                    'callback': 'onClick'
                  }
                ]
              }
            new HG.Button @_hgInstance,
              {
                'parentArea':   @_hgInstance.controlButtons,
                'groupName':    'zoom'
                'id':           'zoomOut',
                'states': [
                  {
                    'id':       'normal',
                    'tooltip':  "Zoom Out",
                    'iconFA':   'minus',
                    'callback': 'onClick'
                  }
                ]
              }
          )

          # fullscreen mode
          when 'fullscreen' then (
            # 1. init button
            new HG.Button @_hgInstance,
              {
                'parentArea':   @_hgInstance.controlButtons,
                'id':           'fullscreen',
                'states': [
                  {
                    'id':       'normal',
                    'tooltip':  "Fullscreen",
                    'iconFA':   'expand',
                    'callback': 'onEnter'
                  },
                  {
                    'id':       'fullscreen',
                    'tooltip':  "Leave Fullscreen",
                    'iconFA':   'compress',
                    'callback': 'onLeave'
                  }
                ]
              }
          )

          # high contrast mode
          when 'highContrast' then (
            # 1. init button
            new HG.Button @_hgInstance,
              {
                'parentArea':   @_hgInstance.controlButtons,
                'id':           'highContrast',
                'states': [
                  {
                    'id':       'normal',
                    'tooltip':  "High-Contrast Mode",
                    'iconFA':   'adjust',
                    'callback': 'onEnter'
                  },
                  {
                    'id':       'high-contrast',
                    'tooltip':  "Normal Color Mode",
                    'iconFA':   'adjust',
                    'callback': 'onLeave'
                  }
                ]
              }
          )

          # minimal layout mode
          when 'minLayout' then (
            # 1. init button
            new HG.Button @_hgInstance,
              {
                'parentArea':   @_hgInstance.controlButtons,
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
                'parentArea':   @_hgInstance.controlButtons,
                'id':           'graph',
                'states': [
                  {
                    'id':       'normal',
                    'tooltip':  "Show Alliances",
                    'iconFA':   'share-alt',
                    'callback': 'onShow'
                  },
                  {
                    'id':       'graph',
                    'tooltip':  "Hide Alliances",
                    'iconFA':   'share-alt',
                    'callback': 'onHide'
                  }
                ]
              }
          )

    # listen to show/hide of HistoGraph
    @_hgInstance.histoGraph.onShow @, (elem) =>
      @moveUp elem.height()

    @_hgInstance.histoGraph.onHide @, (elem) =>
      @moveDown elem.height()

  # ============================================================================
  moveUp: (height) ->
    @_buttonArea.moveVertical height

  moveDown: (height) ->
    @_buttonArea.moveVertical -height
