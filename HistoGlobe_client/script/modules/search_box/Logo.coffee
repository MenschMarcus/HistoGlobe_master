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

  hgInit: (hgInstance) ->

    hgInstance.logo = @

    if hgInstance.hg_logo?
      logo =
        icon:       @_config.icon
        callback: ()-> console.log "Not implmented"

      hgInstance.hg_logo.addLogo logo

    else
      console.error "Failed to add logo: SearchBoxArea module not found!"