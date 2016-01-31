window.HG ?= {}

class HG.Logo

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  #   --------------------------------------------------------------------------
  constructor: () ->
    defaultConfig =
      icon:     "fa-search"

    @_config = $.extend {}, defaultConfig

  #   --------------------------------------------------------------------------
  hgInit: (@_hgInstance) ->
    @_hgInstance.logo = @

    if @_hgInstance.hg_logo?
      logo =
        icon:       @_config.icon
        callback: ()-> console.log "Not implmented"

      @_hgInstance.hg_logo.addLogo logo

    else
      console.error "Failed to add logo: SearchBoxArea module not found!"