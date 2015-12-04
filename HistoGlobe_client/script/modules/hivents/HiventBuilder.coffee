window.HG ?= {}

# ==============================================================================
# HiventBuilder is a simple class to encapsulate reading Hivent data from an
# array according to a given index mapping.
# ==============================================================================

class HG.HiventBuilder

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config, multimediaController) ->
    @_config = config
    @_multimediaController = multimediaController

  # ============================================================================
  constructHiventFromArray: (dataArray, successCallback) ->
    if dataArray isnt []
      successCallback?= (hivent) -> console.log hivent

      id          = dataArray[@_config.indexMapping.id]           ?= ""
      name        = dataArray[@_config.indexMapping.name]         ?= ""
      description = dataArray[@_config.indexMapping.description]  ?= ""
      startYear   = dataArray[@_config.indexMapping.startYear]    ?= ""
      startMonth  = dataArray[@_config.indexMapping.startMonth]   ?= ""
      startDay    = dataArray[@_config.indexMapping.startDay]     ?= ""
      endYear     = dataArray[@_config.indexMapping.endYear]      ?= ""
      endMonth    = dataArray[@_config.indexMapping.endMonth]     ?= ""
      endDay      = dataArray[@_config.indexMapping.endDay]       ?= ""
      displayDate = dataArray[@_config.indexMapping.displayDate]  ?= ""
      location    = dataArray[@_config.indexMapping.location]     ?= ""
      lat         = dataArray[@_config.indexMapping.lat]          ?= ""
      long        = dataArray[@_config.indexMapping.long]         ?= ""
      region      = dataArray[@_config.indexMapping.region]       ?= ""
      isImp       = dataArray[@_config.indexMapping.isImp]        ?= ""
      category    = dataArray[@_config.indexMapping.category]     ?= ""
      parentTopic = dataArray[@_config.indexMapping.parentTopic]  ?= ""
      subTopic    = dataArray[@_config.indexMapping.subTopic]     ?= ""
      multimedia  = dataArray[@_config.indexMapping.multimedia]   ?= ""
      link        = dataArray[@_config.indexMapping.link]         ?= ""

      successCallback @_createHivent( id, name,
                                      startYear, startMonth, startDay,
                                      endYear, endMonth, endDay,
                                      displayDate,
                                      location, lat, long,
                                      region,
                                      isImp,
                                      category, parentTopic, subTopic
                                      description,
                                      multimedia, link)


  # ============================================================================
  # constructHiventFromDBString: (dataString, successCallback) ->
  #   if dataString != ""
  #     successCallback?= (hivent) -> console.log hivent

  #     columns = dataString.split("|")

  #     hiventID          = columns[0]
  #     hiventName        = columns[1]
  #     hiventDescription = columns[2]
  #     hiventStartDate   = columns[3]
  #     hiventEndDate     = columns[4]
  #     hiventDisplayDate = columns[5]
  #     hiventLocation    = columns[6]
  #     hiventLat         = columns[7]
  #     hiventLong        = columns[8]
  #     hiventCategory    = if columns[9] == '' then 'default' else columns[9]
  #     hiventMultimedia  = columns[10]

  #     mmHtmlString = ''

  #     #get related multimedia
  #     if hiventMultimedia != ""
  #       galleryID = hiventID + "_gallery"
  #       mmHtmlString = '\t<ul class=\"gallery clearfix\">\n'
  #       hiventMMIDs = hiventMultimedia.split(",")
  #       galleryTag = ""
  #       if hiventMMIDs.length > 1
  #         galleryTag = "[" + galleryID + "]"

  #       #get all related entries from multimedia database and concatenate html string
  #       loadedIds = []
  #       somethingWentWrong = false
  #       for id in hiventMMIDs
  #         $.ajax({
  #             url: "php/query_database.php?"+
  #                   "serverName=#{@_config.multimediaServerName}"+
  #                   "&dbName=#{@_config.multimediaDatabaseName}"+
  #                   "&tableName=#{@_config.multimediaTableName}"+
  #                   "&condition=id=" + "'#{id}'",
  #             success: (data) =>
  #               cols = data.split "|"
  #               mm = @_createMultiMedia cols[1], cols[2], cols[3]
  #               mmHtmlString +=  '\t\t<li><a href=\"' +
  #                                 mm.link + '\" rel=\"prettyPhoto' +
  #                                 galleryTag + '\" title=\"' +
  #                                 mm.description + '\"> <img src=\"' +
  #                                 mm.thumbnail + '\" width=\"60px\" /></a></li>\n'

  #               loadedIds.push id

  #             error: () =>
  #               somethingWentWrong = true
  #           })

  #       loadFinished = () ->
  #         (loadedIds.length is hiventMMIDs.length) or somethingWentWrong

  #       loadSuccessFunction = () =>
  #         mmHtmlString += "\t</ul>\n"
  #         successCallback @_createHivent(hiventID, hiventName, hiventDescription, hiventStartDate,
  #                                 hiventEndDate, hiventDisplayDate, hiventLocation, hiventLong, hiventLat,
  #                                 hiventCategory, hiventMultimedia, mmHtmlString)

  #       @_waitFor loadFinished, loadSuccessFunction


  #     else
  #       successCallback @_createHivent(hiventID, hiventName, hiventDescription, hiventStartDate,
  #                                   hiventEndDate, hiventDisplayDate, hiventLocation, hiventLong, hiventLat,
  #                                   hiventCategory, hiventMultimedia, '')

  # # ============================================================================
  # constructHiventFromJSON: (jsonHivent, successCallback) ->
  #   if jsonHivent?
  #     successCallback?= (hivent) -> console.log hivent

  #     hiventID          = jsonHivent.id
  #     hiventName        = jsonHivent.name
  #     hiventDescription = jsonHivent.description
  #     hiventStartDate   = jsonHivent.startDate
  #     hiventEndDate     = jsonHivent.endDate
  #     hiventDisplayDate = jsonHivent.displayDate
  #     hiventLocation    = jsonHivent.location
  #     hiventLat         = jsonHivent.lat
  #     hiventLong        = jsonHivent.long
  #     hiventCategory    = if jsonHivent.category == '' then 'default' else jsonHivent.category
  #     hiventMultimedia  = jsonHivent.multimedia

  #     mmDatabase = {}
  #     multimediaLoaded = false
  #     if @_config.multimediaJSONPaths?
  #       for multimediaJSONPath in @_config.multimediaJSONPaths
  #         $.getJSON(multimediaJSONPath, (multimedia) =>

  #           for mm in multimedia
  #             mmDatabase["#{mm.id}"] = mm

  #           multimediaLoaded = true
  #         )
  #     else
  #       multimediaLoaded = true

  #     mmLoadFinished = () ->
  #       multimediaLoaded

  #     parseMultimedia = () =>

  #       mmHtmlString = ''
  #       #get related multimedia
  #       if hiventMultimedia != ""
  #         galleryID = hiventID + "_gallery"
  #         mmHtmlString = '\t<ul class=\"gallery clearfix\">\n'
  #         hiventMMIDs = hiventMultimedia.split(",")
  #         galleryTag = ""
  #         if hiventMMIDs.length > 1
  #           galleryTag = "[" + galleryID + "]"

  #         #get all related entries from multimedia database and concatenate html string
  #         somethingWentWrong = false
  #         loadedIds = []
  #         for id in hiventMMIDs
  #           if mmDatabase.hasOwnProperty id
  #             entry = mmDatabase["#{id}"]
  #             mm = @_createMultiMedia entry.type, entry.description, entry.link
  #             mmHtmlString +=  '\t\t<li><a href=\"' +
  #                               mm.link + '\" rel=\"prettyPhoto' +
  #                               galleryTag + '\" title=\"' +
  #                               mm.description + '\"> <img src=\"' +
  #                               mm.thumbnail + '\" width=\"60px\" /></a></li>\n'

  #             loadedIds.push id
  #           else
  #             console.error "A multimedia entry with the id #{id} does not exist!"
  #             somethingWentWrong = true

  #         loadFinished = () ->
  #           (loadedIds.length is hiventMMIDs.length) or somethingWentWrong

  #         loadSuccessFunction = () =>
  #           mmHtmlString += "\t</ul>\n"
  #           successCallback @_createHivent(hiventID, hiventName, hiventDescription, hiventStartDate,
  #                                   hiventEndDate, hiventDisplayDate, hiventLocation, hiventLong, hiventLat,
  #                                   hiventCategory, hiventMultimedia, mmHtmlString)

  #         @_waitFor loadFinished, loadSuccessFunction

  #       else
  #         successCallback @_createHivent(hiventID, hiventName, hiventDescription, hiventStartDate,
  #                                     hiventEndDate, hiventDisplayDate, hiventLocation, hiventLong, hiventLat,
  #                                     hiventCategory, hiventMultimedia, '')

  #     @_waitFor mmLoadFinished, parseMultimedia


  ############################# MAIN FUNCTIONS #################################
  _createHivent: (id, name,
                  startYear, startMonth, startDay,
                  endYear, endMonth, endDay,
                  displayDate,
                  location, lat, long,
                  region,
                  isImp
                  category, parentTopic, subTopic
                  description,
                  multimedia, link) ->

    if id != "" and name != ""

      #concatenate content
      content = '<p>' + description + '<p>'

      # allow multiple locations per hivent
      location = location?.replace(/\s*;\s*/g, ';').split(';')
      lat = "#{lat}".replace(/\s*;\s*/g, ';').split(';') if lat?
      long = "#{long}".replace(/\s*;\s*/g, ';').split(';') if long?

      # set end date to start date if unless differently specified
      if endYear is ''
        endYear = startYear
        endMonth = startMonth
        endDay = startDay

      # create hivent region
      regionPolygon = undefined

      if region.length > 1
        regionPolygon = JSON.parse region
        for index in regionPolygon
          tmp=index[0]
          index[0]=index[1]
          index[1]=tmp

      # set hivent category
      category = parentTopic

      hivent = new HG.Hivent(
        id,
        name,
        startYear,
        startMonth,
        startDay,
        endYear,
        endMonth,
        endDay,
        displayDate,
        location,
        long,
        lat,
        regionPolygon,
        isImp,
        category,
        parentTopic,
        subTopic,
        content,
        description,
        multimedia,
        link
      )

      hivent
