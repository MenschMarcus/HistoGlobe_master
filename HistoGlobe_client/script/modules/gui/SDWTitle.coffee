window.HG ?= {}

class HG.SDWTitle

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      title: "Title"
      elements: []

    @_config = $.extend {}, defaultConfig, config

  # ============================================================================
  init: (hgInstance, parentDiv) ->

    @_categoryFilter = hgInstance.categoryFilter

    hgInstance.sdwTitle = @

    @_text_div               = document.createElement("div")
    @_text_div.className     = "title-text"
    @_text_div.innerHTML     = @_config.title
    parentDiv.appendChild @_text_div

    @_back_div               = document.createElement("div")
    @_back_div.className     = "title-back"
    parentDiv.appendChild @_back_div

    @_back_div_inner               = document.createElement("a")
    @_back_div_inner.href          = "#categories=sdwEvent+projektstart&bounds=9.09,47;12.09,55"
    @_back_div_inner.innerHTML     = "<i class='fa fa-caret-left'></i> Zurück"
    @_back_div.appendChild @_back_div_inner

    @_select_div               = document.createElement("div")
    @_select_div.className     = "title-select"
    parentDiv.appendChild @_select_div

    $(@_select_div).tooltip {title: "Wählen Sie ein Projekt der sdw, um mehr darüber zu erfahren!", placement: "bottom", container:"body"}

    $(@_back_div_inner).tooltip {title: "Kehren Sie zur Geschichte der sdw zurück!", placement: "bottom", container:"body"}
    $(@_back_div_inner).tooltip "disable"

    select = document.createElement "select"
    @_select_div.appendChild select

    @_allCategories = []

    for element in @_config.elements
      @_addElement element, select

    $(select).select2()
    $(select).on "change", (e) =>
      window.location.hash = "#categories=" + e.val.replace(",", "+")

    @_categoryFilter?.onFilterChanged @, (categories) =>
      $(select).select2("val", categories[0])

      if "sdwEvent" in categories
        $(@_back_div).removeClass "visible"
        $(@_back_div_inner).tooltip "hide"
        $(@_back_div_inner).tooltip "disable"
      else
        $(@_back_div).addClass "visible"
        $(@_back_div_inner).tooltip "enable"


  # ============================================================================
  _addElement: (element, parent) ->
    if element.type is "category"
      option = document.createElement "option"
      option.value = element.categories
      option.innerHTML = element.name
      parent.appendChild option
      for c in element.categories
        @_allCategories.push c
    else
      group = document.createElement "optgroup"
      group.label = element.name
      parent.appendChild group

      for e in element.elements
        @_addElement e, group








