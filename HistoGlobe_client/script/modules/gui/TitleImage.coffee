window.HG ?= {}

class HG.TitleImage

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      images: []

    @_actualImage = null
    @_config = $.extend {}, defaultConfig, config

  # ============================================================================
  hgInit: (hgInstance) ->
    @hgInstance = hgInstance

    @_div           = document.createElement("div")
    @_div.className = "title_image_container"

    @_images = []


    @_timeline = hgInstance.timeline
    @_timeline.onNowChanged @, @_nowChanged

    for image, index in @_config.images
      @_images.push @_addImage image, index

    $("#histoglobe").append @_div

    @_changeImages @_images[0].div


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _addImage: (image, index) ->

    imageDiv           = document.createElement("img")
    imageDiv.className = "title_image"
    imageDiv.src       = image.path

    $(imageDiv).click () =>
      @hgInstance.timeline.moveToDate new Date(1, 0, @hgInstance._config.minYear), 0.5

    @_div.appendChild imageDiv

    retMessage =
      div: imageDiv
      date: @_timeline.stringToDate image.date

  # ============================================================================
  _nowChanged: (now) =>

    new_image = @_images[0]

    for image in @_images
      if image.date <= now
        new_image = image
      else
        break

    if new_image isnt @_actualImage
      @_changeImages new_image.div

  # ============================================================================
  # compareDates: (date1, date2) ->
    # date1.getFullYear() == date2.getFullYear() && date1.getMonth() == date2.getMonth()


  # ============================================================================
  _changeImages: (div) ->
    $(@_actualImage).toggleClass("visible")
    @_actualImage = div
    $(@_actualImage).toggleClass("visible")




