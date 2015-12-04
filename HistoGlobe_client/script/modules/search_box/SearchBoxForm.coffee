window.HG ?= {}

class HG.SearchBoxForm

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  #   --------------------------------------------------------------------------
  constructor: () ->
    defaultConfig =
      #method: "get" 
      #action: "http://www.google.com"
      tooltip:  "Suchfeld - Demnächst verfügbar"

    @_config = $.extend {}, defaultConfig

  hgInit: (hgInstance) ->

    hgInstance.search_form = @

    if hgInstance.search_box_area?
      search_form =
        callback: ()-> console.log "Not implmented"

      hgInstance.search_box_area.addSearchBox search_form

    else
      console.error "Failed to add search form: SearchBoxArea module not found!"