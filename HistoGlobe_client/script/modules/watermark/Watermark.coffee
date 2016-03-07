window.HG ?= {}

class HG.Watermark

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
    @_hgInstance.watermark = @

    # append path
    @_config.image = @_hgInstance.getConfig().configPath + @_config.image

    parentDiv = @_hgInstance._config.container

    if @_config.image?
      image = new HG.Img @_config.id, ['watermark', 'no-text-select'], @_config.image
      image.dom().style.top = @_config.top        if @_config.top?
      image.dom().style.right = @_config.right    if @_config.right?
      image.dom().style.bottom = @_config.bottom  if @_config.bottom?
      image.dom().style.left = @_config.left      if @_config.left?
      parentDiv.appendChild image.dom()

    else
      text = new HG.Div null, 'watermark'
      text.j().html @_config.text

      if @_config.top?
        text.style.top = @_config.top
      if @_config.right?
        text.style.right = @_config.right
      if @_config.bottom?
        text.style.bottom = @_config.bottom
      if @_config.left?
        text.style.left = @_config.left

      parentDiv.appendChild text.dom()
