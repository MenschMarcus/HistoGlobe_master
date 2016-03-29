window.HG ?= {}

# ==============================================================================
# UTIL
# load hivents from Database
# ==============================================================================

class HG.HiventLoader

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onFinishLoading'


  # ============================================================================
  loadInit: () ->
    request = {}
    @_loadHiventsFromServer request


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _loadHiventsFromServer: (request) ->

    $.ajax
      url:  'get_initial_hivents/'
      type: 'POST'
      data: JSON.stringify request

      # success callback: load hivents here
      success: (response) =>

        # deserialize string to object
        dataObj = $.parseJSON response

        $.each dataObj, (key, val) =>

          # allow multiple locations per hivent
          # data.location = data.location?.replace(/\s*;\s*/g, ';').split(';')
          # data.lat = "#{data.lat}".replace(/\s*;\s*/g, ';').split(';') if data.lat?
          # data.lng = "#{data.lng}".replace(/\s*;\s*/g, ';').split(';') if data.lng?

          # prepare dara
          hiventData = {
            id :                val.id
            name :              val.name
            startDate :         moment(val.start_date)
            endDate :           moment(val.start_date)
            effectDate :        moment(val.start_date)
            secessionDate :     moment(val.start_date)
            displayDate :       moment(val.start_date)
            locationName :      val.location_name
            locationPoint :     val.location_point    # TODO
            locationArea :      val.location_area     # TODO
            description :       val.description
            content :           '<p>' + val.description ?= '' + '<p>'
            linkUrl :           val.link_url
            linkDate :          moment(val.link_date)
          }

          # error handling: id and name must be given
          return if (not hiventData.id) or (not hiventData.name)

          hivent = new HG.Hivent hiventData
          handle = new HG.HiventHandle hivent
          @notifyAll 'onFinishLoading', handle



      # error callback: print error message
      error: (xhr, errmsg, err) =>
        console.log xhr
        console.log errmsg, err
        console.log xhr.responseText