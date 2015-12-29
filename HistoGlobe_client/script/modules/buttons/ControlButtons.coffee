window.HG ?= {}

class HG.ControlButtons

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # for new control button:
  #   define identifier (id) for control (e.g. 'fullscreen')
  #   -> new entry in default config in constructor (default set false 'false')
  #   set class / file for control (e.g. 'FullscreenButton')
  #   -> new intry in switch-when-then control in hgInit
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
  hgInit: (hgInstance) ->

    @_hgInstance = hgInstance

    # idea: module "ControlButtons" is instance of class "ButtonArea"
    @_hgInstance.control_buttons = new HG.ButtonArea 'bottom-left', 'vertical'
    @_hgInstance.control_buttons.hgInit @_hgInstance

    # init predefined buttons
    for button, enable of @_config
      if enable
        btn = null
        switch button                 # selects class of required button
          when 'zoom' then          btn = new HG.ZoomButtons
          when 'fullscreen' then    btn = new HG.FullscreenButton
          when 'highContrast' then  btn = new HG.HighContrastButton
          when 'minLayout' then     btn = new HG.MinLayoutButton

        btn.hgInit @_hgInstance if btn # initializes button
