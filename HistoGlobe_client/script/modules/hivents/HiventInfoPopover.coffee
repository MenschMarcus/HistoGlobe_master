window.HG ?= {}

class HG.HiventInfoPopover

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (hiventHandle, container, hgInstance, hiventIndex, showArrow) ->

    @_hiventHandle = hiventHandle
    @_hgInstance = hgInstance
    @_visible = false
    @_multimediaController = hgInstance.multimediaController

    @_description_length = 285

    #@_hivent_ID = @_hiventHandle.getHivent().id.substring(2)
    #@_multimedia_ID = @_hiventHandle.getHivent().multimedia.substring(2)

    # generate content
    body = document.createElement "div"
    body.className = "hivent-body"

    titleDiv = document.createElement "h4"
    titleDiv.className = "guiPopoverTitle"
    titleDiv.innerHTML = @_hiventHandle.getHivent().name
    body.appendChild titleDiv

    text = document.createElement "div"
    text.className = "hivent-content"

    description = @_hiventHandle.getHivent().description
    if description.length > @_description_length
      desc_output = description.substring(0,@_description_length)
      text.innerHTML = desc_output + "... "
    else
      text.innerHTML = description

    body.appendChild text

    # ============================================================================

    locationString = ''
    if hiventIndex? and @_hiventHandle.getHivent().locationName?
      locationString = @_hiventHandle.getHivent().locationName[hiventIndex] + ', '

    date = document.createElement "span"
    date.className = "date"
    date.innerHTML = ' - ' + locationString + @_hiventHandle.getHivent().displayDate

    gotoDate = document.createElement "i"
    gotoDate.className = "fa fa-clock-o"
    $(gotoDate).tooltip {title: "Springe zum Ereignisdatum", placement: "right", container:"#histoglobe"}
    $(gotoDate).click () =>
      @_hgInstance.timeline.moveToDate @_hiventHandle.getHivent().startDate, 0.5
    date.appendChild gotoDate

    text.appendChild date

    # ============================================================================

    # if !showArrow
    #   container = window.body

    # create popover
    @_popover = new HG.Popover
      hgInstance: hgInstance
      hiventHandle: hiventHandle
      placement:  "top"
      content:    body
      title:      @_hiventHandle.getHivent().name
      container:  container
      showArrow:  showArrow
      fullscreen: !showArrow

    @_popover.onClose @, () =>
      @_hiventHandle.inActiveAll()


    # @_multimedia = @_hiventHandle.getHivent().multimedia

    # if @_multimedia != "" and @_multimediaController?
    #   mmids = @_multimedia.split ","
    #   gallery = new HG.Gallery
    #     interactive : true
    #     showPagination : (mmids.length >= 2)

    #   gallery.mainDiv.style.marginLeft = -HGConfig.widget_body_padding.val + "px"
    #   gallery.mainDiv.style.marginRight = -HGConfig.widget_body_padding.val + "px"

    #   body.insertBefore gallery.mainDiv, text

    #   gallery.init()

    #   @_popover.onResize @, () =>
    #     gallery.reInit()

      # @_multimediaController.onMultimediaLoaded () =>

      #   for id in mmids
      #     mm = @_multimediaController.getMultimediaById id
      #     if mm?

      #       if mm.type is "WEBIMAGE"
      #         elem = document.createElement "a"

      #         elem.href = mm.thumbnail
      #         elem.link = mm.link
      #         console.log elem.link
      #         elem.title = mm.description
      #         elem.alt = mm.description
      #         elem.style.backgroundImage = "url( #{mm.thumbnail})"
      #         elem.className = "gallery-image"
      #         $(elem).colorbox
      #           title: "<p class='gallery-copyright'>" + mm.source + "</p>" + mm.description
      #           maxWidth: "90%"
      #           maxHeight: "80%"
      #           # rel: gallery.id
      #           # current: "Bild {current} von {total}"
      #           # loop: false

      #         if mm.crop
      #           $(elem).addClass("cropped")

      #         gallery.addDivSlide elem

      #       else if mm.type is "YOUTUBE"
      #         elem = document.createElement "div"
      #         elem.innerHTML = "<iframe width='100%' height='240px' src='#{mm.link}' frameborder='0' allowfullscreen> </iframe>"
      #         gallery.addDivSlide elem

      #       else if mm.type is "AUDIO"
      #         elem = document.createElement "div"
      #         elem.style.marginTop = "150px"
      #         audio = document.createElement "audio"
      #         audio.className = "swiper-no-swiping"
      #         audio.controls = true

      #         linkData = mm.link.split(",")

      #         mp3 = ""

      #         for link in linkData
      #           source = document.createElement "source"
      #           source.src = link
      #           audio.appendChild source

      #           type = link.split(".")
      #           type = type[type.length-1]

      #           if type is "mp3"
      #             source.type = "audio/mpeg"
      #             mp3 = link
      #           else if type is "ogg"
      #             source.type = "audio/ogg"

      #         if mp3 isnt ""
      #           source = document.createElement "embed"
      #           source.src = link
      #           source.height = "50px"
      #           source.width = "150px"
      #           audio.appendChild source

      #         elem.appendChild audio

      #         text = document.createElement "div"
      #         text.innerHTML = mm.description
      #         elem.appendChild text

      #         gallery.addDivSlide elem


            #   elem = document.createElement "div"
            #   gallery.addDivSlide elem

            #   link = mm.link

            #   elem.innerHTML = '<div id="jp_container_1" class="jp-video ">
            #     <div class="jp-type-single">
            #       <div id="jquery_jplayer_1" class="jp-jplayer"></div>
            #       <div class="jp-gui">
            #         <div class="jp-video-play">
            #           <a href="javascript:;" class="jp-video-play-icon" tabindex="1">play</a>
            #         </div>
            #         <div class="jp-interface">
            #           <div class="jp-progress">
            #             <div class="jp-seek-bar">
            #               <div class="jp-play-bar"></div>
            #             </div>
            #           </div>
            #           <div class="jp-current-time"></div>
            #           <div class="jp-duration"></div>
            #           <div class="jp-controls-holder">
            #             <ul class="jp-controls">
            #               <li><a href="javascript:;" class="jp-play" tabindex="1">play</a></li>
            #               <li><a href="javascript:;" class="jp-pause" tabindex="1">pause</a></li>
            #               <li><a href="javascript:;" class="jp-stop" tabindex="1">stop</a></li>
            #               <li><a href="javascript:;" class="jp-mute" tabindex="1" title="mute">mute</a></li>
            #               <li><a href="javascript:;" class="jp-unmute" tabindex="1" title="unmute">unmute</a></li>
            #               <li><a href="javascript:;" class="jp-volume-max" tabindex="1" title="max volume">max volume</a></li>
            #             </ul>
            #             <div class="jp-volume-bar">
            #               <div class="jp-volume-bar-value"></div>
            #             </div>
            #             <ul class="jp-toggles">
            #               <li><a href="javascript:;" class="jp-full-screen" tabindex="1" title="full screen">full screen</a></li>
            #               <li><a href="javascript:;" class="jp-restore-screen" tabindex="1" title="restore screen">restore screen</a></li>
            #               <li><a href="javascript:;" class="jp-repeat" tabindex="1" title="repeat">repeat</a></li>
            #               <li><a href="javascript:;" class="jp-repeat-off" tabindex="1" title="repeat off">repeat off</a></li>
            #             </ul>
            #           </div>
            #           <div class="jp-details">
            #             <ul>
            #               <li><span class="jp-title"></span></li>
            #             </ul>
            #           </div>
            #         </div>
            #       </div>
            #       <div class="jp-no-solution">
            #         <span>Update Required</span>
            #         To play the media you will need to either update your browser to a recent version or update your <a href="http://get.adobe.com/flashplayer/" target="_blank">Flash plugin</a>.
            #       </div>
            #     </div>
            #   </div>'

            #   $('#jquery_jplayer_1').jPlayer
            #     ready: () ->
            #       $(this).jPlayer "setMedia",
            #         m4v: link,
            #         poster: "data/video.png"
            #     ,
            #     swfPath: "script/third-party/",
            #     size:
            #       width: "320px",
            #       height: "180px"
            #       # cssClass: "jp-video-360p"
            #     ,
            #     preload: 'metadata',
            #     smoothPlayBar: true,
            #     keyEnabled: true,
            #     remainingDuration: true,
            #     toggleDuration: true
            #     supplied: "m4v"




    @_hiventHandle.onDestruction @, @_popover.destroy


  # ============================================================================
  show: (position) =>
    @_popover.show
      x: position.at(0)
      y: position.at(1)
      @_visible = true
      @_hgInstance.hiventInfoAtTag?.setOption("event", @_hiventHandle._hivent.id)

  # ============================================================================
  hide: =>
    @_popover.hide()
    @_hiventHandle._activated = false
    @_visible = false
    @_hgInstance.hiventInfoAtTag?.unsetOption("event")

  # ============================================================================
  isVisible: =>
    @_visible

  # ============================================================================
  updatePosition: (position) ->
    @_popover.updatePosition

  # ============================================================================
  destroy: () ->
    @_popover.destroy()

