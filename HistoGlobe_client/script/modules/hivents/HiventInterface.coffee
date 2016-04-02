window.HG ?= {}

# ==============================================================================
# UTIL
# load hivents from Database
# ==============================================================================

class HG.HiventInterface

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onSaveHivent'


  # ============================================================================
  loadInit: () ->
    request = {}

    $.ajax
      url:  'get_hivents/'
      type: 'POST'
      data: JSON.stringify request

      # success callback: load hivents here
      success: (response) =>

        # deserialize string to object
        dataObj = $.parseJSON response

        $.each dataObj, (key, val) =>
          @loadFromServerModel val

      # error callback: print error message
      error: (xhr, errmsg, err) =>
        console.log xhr
        console.log errmsg, err
        console.log xhr.responseText


  # ============================================================================
  loadFromServerModel: (hiventFromServer) ->
    hiventData = @_prepareHiventServerToClient hiventFromServer
    # create hivents + handle and tell everyone!
    if hiventData
      hivent = new HG.Hivent hiventData
      handle = new HG.HiventHandle hivent
      @notifyAll 'onSaveHivent', handle


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _prepareHiventServerToClient: (hiventFromServer) ->

    # error handling: id and name must be given
    return null if (not hiventFromServer.id) or (not hiventFromServer.name)

    hiventData = {
      id :                hiventFromServer.id
      name :              hiventFromServer.name
      startDate :         moment(hiventFromServer.start_date)
      endDate :           moment(hiventFromServer.end_date?)
      effectDate :        moment(hiventFromServer.effect_date)
      secessionDate :     moment(hiventFromServer.secession_date?)
      displayDate :       moment(hiventFromServer.display_date?)
      locationName :      hiventFromServer.location_name          ?= null
      locationPoint :     hiventFromServer.location_point         ?= null
      locationArea :      hiventFromServer.location_area          ?= null
      description :       hiventFromServer.description            ?= null
      content :           '<p>' + hiventFromServer.description ?= '' + '<p>'
      linkUrl :           hiventFromServer.link_url               ?= null
      linkDate :          moment(hiventFromServer.link_date?)
      changes :           []
    }

    # prepare changes
    for change in hiventFromServer.changes
      changeData = {
        operation:  change.operation
        oldAreas:   []
        newAreas:   []
      }
      # create unique array (each area is only once in the old/newArea array)
      for area in change.change_areas
        changeData.oldAreas.push area.old_area if (area.old_area?) and (changeData.oldAreas.indexOf(area.old_area) is -1)
        changeData.newAreas.push area.new_area if (area.new_area?) and (changeData.newAreas.indexOf(area.new_area) is -1)
      # add change to hivent
      hiventData.changes.push changeData

    return hiventData

  # ============================================================================
  # _prepareHiventClientToServer: (hiventFromServer) ->


  # ============================================================================
  # TODO:
  # allow multiple locations per hivent
  # data.location = data.location?.replace(/\s*;\s*/g, ';').split(';')
  # data.lat = "#{data.lat}".replace(/\s*;\s*/g, ';').split(';') if data.lat?
  # data.lng = "#{data.lng}".replace(/\s*;\s*/g, ';').split(';') if data.lng?