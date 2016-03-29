window.HG ?= {}

class HG.Watermark

  # TODO: create "real" watermark (not draggable and selectable background image)

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    defaultConfig =
      id: ''
      top: null
      right: null
      bottom: null
      left: null
      image: null
      text: ""
      opacity: 1.0

    @_config = $.extend {}, defaultConfig, config

  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add module to HG instance
    @_hgInstance.watermark = @

    # includes
    domElemCreator = new HG.DOMElementCreator

    # append path
    @_config.image = @_hgInstance.config.configPath + @_config.image

    if @_config.image?
      image = domElemCreator.create 'img', @_config.id, ['watermark', 'no-text-select'], [['src', @_config.image]]
      image.style.top = @_config.top        if @_config.top?
      image.style.right = @_config.right    if @_config.right?
      image.style.bottom = @_config.bottom  if @_config.bottom?
      image.style.left = @_config.left      if @_config.left?
      @_hgInstance.getTopArea().appendChild image

    else
      text = domElemCreator.create 'div', null, 'watermark'
      $(text).html @_config.text

      if @_config.top?
        text.style.top = @_config.top
      if @_config.right?
        text.style.right = @_config.right
      if @_config.bottom?
        text.style.bottom = @_config.bottom
      if @_config.left?
        text.style.left = @_config.left

      @_hgInstance.getTopArea().appendChild text