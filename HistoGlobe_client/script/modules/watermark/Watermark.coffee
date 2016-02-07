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

    parentDiv = @_hgInstance._config.container

    if @_config.image?
      image = document.createElement "img"
      image.src = @_config.image
      image.id = @_config.id
      image.className = "watermark"
      if @_config.top?
        image.style.top = @_config.top
      if @_config.right?
        image.style.right = @_config.right
      if @_config.bottom?
        image.style.bottom = @_config.bottom
      if @_config.left?
        image.style.left = @_config.left
      parentDiv.appendChild image

    else
      text = document.createElement 'div'
      text.innerHTML = @_config.text
      text.className = "watermark"

      if @_config.top?
        text.style.top = @_config.top
      if @_config.right?
        text.style.right = @_config.right
      if @_config.bottom?
        text.style.bottom = @_config.bottom
      if @_config.left?
        text.style.left = @_config.left

      parentDiv.appendChild text
