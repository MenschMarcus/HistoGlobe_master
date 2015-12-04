window.HG ?= {}

class HG.VIPWidget extends HG.TimeGalleryWidget

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      persons : []

    @_config = $.extend {}, defaultConfig, config

    HG.TimeGalleryWidget.call @, @_config

  # ============================================================================
  hgInit: (hgInstance) ->
    super hgInstance

    for person in @_config.persons
      if person.name?
        @addPerson person
      else
        @addMultiPerson person


  # ============================================================================
  addPerson: (config) ->
    defaultConfig =
      name: ""
      date: ""
      displayDate: ""
      image: ""
      description: ""
      copyright: ""

    config = $.extend {}, defaultConfig, config

    div = document.createElement "div"
    div.className = "vip-widget"

    portrait = document.createElement "div"
    # portrait.title = config.name
    # portrait.href = config.image
    portrait.className = "vip-widget-image"
    portrait.style.backgroundImage = "url('#{config.image}')"
    div.appendChild portrait

    # $(portrait).prettyPhoto {
    #   animation_speed:'normal'
    #   theme:'light_square'
    #   slideshow:3000
    #   autoplay_slideshow: false
    #   hideflash: true
    #   allow_resize: false
    #   deeplinking: false
    # }

    name = document.createElement "div"
    name.className = "vip-widget-name"
    name.innerHTML = config.name + "<br/><small>" + config.displayDate + "</small>"
    div.appendChild name

    unless config.copyright is ""
      copyright = document.createElement "div"
      copyright.className = "vip-widget-copyright"
      copyright.innerHTML = config.copyright
      portrait.appendChild copyright

    unless config.description is ""
      text = document.createElement "div"
      text.className = "clear vip-widget-text"
      text.innerHTML = config.description
      div.appendChild text

    @addDivSlide {date: config.date, div: div}

  # ============================================================================
  addMultiPerson: (config) ->
    defaultConfig =
      names: []
      date: ""
      displayDates: []
      images: []
      descriptions: []
      copyrights: []

    config = $.extend {}, defaultConfig, config

    div = document.createElement "div"
    div.className = "vip-widget"

    width = 100.0/config.names.length

    for name, i in config.names
      container = document.createElement "div"
      container.style.width = "#{width}%"
      container.style.verticalAlign = "top"
      container.style.display = "inline-block"
      div.appendChild container

      portrait = document.createElement "div"
      # portrait.title = config.names[i]
      # portrait.href = config.images[i]
      portrait.className = "vip-widget-image"
      portrait.style.backgroundImage = "url('#{config.images[i]}')"
      container.appendChild portrait

      # $(portrait).prettyPhoto {
      #   animation_speed:'normal'
      #   theme:'light_square'
      #   slideshow:3000
      #   autoplay_slideshow: false
      #   hideflash: true
      #   allow_resize: false
      #   deeplinking: false
      # }

      name = document.createElement "div"
      name.className = "vip-widget-name"
      name.innerHTML = config.names[i] + "<br/><small>" + config.displayDates[i] + "</small>"
      container.appendChild name

      if config.copyrights[i]?
        copyright = document.createElement "div"
        copyright.className = "vip-widget-copyright"
        copyright.innerHTML = config.copyrights[i]
        portrait.appendChild copyright

      if config.descriptions[i]?
        text = document.createElement "div"
        text.className = "clear vip-widget-text"
        text.innerHTML = config.descriptions[i]
        container.appendChild text

    @addDivSlide {date: config.date, div: div}
