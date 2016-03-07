window.HG ?= {}

class HG.ControlButtonsMap

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

    # idea: module "ControlButtons" a "ButtonArea" consisting of buttons
    @_buttonArea = new HG.ButtonArea @_hgInstance,
    {
      'id':           'controlButtons',
      'posX':         'left',
      'posY':         'bottom',
      'orientation':  'vertical'
    }
    @_hgInstance._top_area.appendChild @_buttonArea.dom()

    # init predefined buttons
    for id, enable of @_config
      if enable
        switch id                 # selects class of required button

          when 'zoom' then (
            @_buttonArea.addButton new HG.Button(@_hgInstance,
              'zoomIn', null,
              [
                {
                  'id':       'normal',
                  'tooltip':  "Zoom In",
                  'iconFA':   'plus',
                  'callback': 'onClick'
                }
              ]), 'zoom-group'  # group name
            @_buttonArea.addButton new HG.Button(@_hgInstance,
              'zoomOut', [],
              [
                {
                  'id':       'normal',
                  'tooltip':  "Zoom Out",
                  'iconFA':   'minus',
                  'callback': 'onClick'
                }
              ]), 'zoom-group' # group name
            )

            # fullscreen mode
          when 'fullscreen' then (
            @_buttonArea.addButton new HG.Button @_hgInstance,
              'fullscreen', [],
              [
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
          )

          # high contrast mode
          when 'highContrast' then (
            @_buttonArea.addButton new HG.Button @_hgInstance,
              'highContrast', [],
              [
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
          )

          # minimal layout mode
          when 'minLayout' then (
            @_buttonArea.addButton new HG.Button @_hgInstance,
              'minLayoutButton', [],
              [
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
          )

          # graph mode
          when 'graph' then (
            # 1. init button
            @_buttonArea.addButton new HG.Button @_hgInstance,
              'graph', [],
              [
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
          )

    # listen to show/hide of HistoGraph
    @_hgInstance.histoGraph?.onShow @, (elem) =>
      @moveUp elem.height()

    @_hgInstance.histoGraph?.onHide @, (elem) =>
      @moveDown elem.height()

  # ============================================================================
  moveUp: (height) ->
    @_buttonArea.moveVertical height

  moveDown: (height) ->
    @_buttonArea.moveVertical -height
