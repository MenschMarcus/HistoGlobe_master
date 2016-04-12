"""
  This file contains all the views on the data in the database,
  i.e. this file defines the interface to the client application.
  - on init: get all areas of one time point (snapshot)
  - on run:  get all areas that change at hivent x
  - save hivent + changes
"""

# ==============================================================================
### INCLUDES ###

# Django
from django.http import HttpResponse
from django.shortcuts import render
from django.utils import timezone

# GeoDjango
from django.contrib.gis.geos import Point

# utils
import chromelogger as console
import re
import json
import datetime

# own
from HistoGlobe_server.models import *
from HistoGlobe_server import utils
from HistoGlobe_server import view_utils


# ==============================================================================
"""
## INTERFACE ##
basic idea of client-server interaction
POST: client sends data to be processed by the server and awaits an answer
GET:  client requires data from the server and awaits an answer

# data structures
  client -> server (reuqest):
    - stringified JSON of arrays and objects (can be multi-dimensional)
      JSON.stringify request
      ->  access on the server by:
          json.loads(request.body)                    # needs: import json
  client <- server (response):
    - list or dictionary (no tuples or anything else, please!) stringified
      HttpResponse(json.dumps(response_data))
      ->  access on the client by:
          success: (reponse) =>
            data = $.parseJSON response


# date interoperabiliy: use RFC 3339 (date = 'YYYY-MM-DDTHH:MM:SS.sss+UTC')

  client -> server:
    moment(dateObject).format()           # needs: moment.js
    ->  access on the server by:
        iso8601.parse_date(date_string)   # needs: import iso8601
  client <- server:
    rfc3339(date_object)                  # needs: from rfc3339 import rfc3339
    ->  access on the client by:
        moment(dateString)
"""


# ==============================================================================
# simple view redirecting to index of HistoGlobe
# ==============================================================================

def index(request):
  return render(request, 'HistoGlobe_client/index.htm', {})


# ==============================================================================
# get set of all areas (their ids, start and end hivents)
# not their names or geometries
# ==============================================================================

def get_init_area_ids(request):

  ## INPUT

  # deserialize object string -> dictionary
  request_data = json.loads(request.body)

  now_date = utils.get_date_object(request_data['date'])

  ## PROCESSING
  # N.B: each area can only exist ONCE => once it is deleted, it never comes back!

  areas = []
  for in_area in Area.objects.all():
    out_area = {}
    out_area['id'] = in_area.id

    # extract creation date for area from hivent that created it
    # N.B: can be None, if there is no change that ever created them
    start_hivent = in_area.start_change.hivent
    if (start_hivent):
      start_date = start_hivent.effect_date
      out_area['start_hivent'] = start_hivent.id

    # error handling: areas without a start date do not make sense
    else: continue

    # extract secession date from area from hivent that deleted it
    # N.B: if there is no change ever deleted it, it is valid until today
    end_change = in_area.end_change
    if (end_change):
      end_hivent = end_change.hivent
      end_date = end_hivent.effect_date
      out_area['end_hivent'] = end_hivent.id
    else:
      end_date = timezone.now()
      out_area['end_hivent'] = None

    # area is visible if current date is in between start and end date of area
    out_area['visible'] = (start_date <= now_date) and (now_date < end_date)

    # add predecessors and successors to area information
    out_area['predecessors'] = in_area.get_predecessors()
    out_area['successors'] = in_area.get_successors()

    # add territorial relations to area information
    out_area['sovereignt'] = in_area.get_sovereignt()
    out_area['dependencies'] = in_area.get_dependencies()

    areas.append(out_area)

  ## OUTPUT
  return HttpResponse(json.dumps(areas))


# ==============================================================================
# get all attribute data of areas (from Territory and Name)
# send data in chunks
# ==============================================================================

def get_init_areas(request):

  ## INPUT

  # deserialize object string -> dictionary
  request_data = json.loads(request.body)

  viewport_center = Point(
      float(request_data['centerLat']),
      float(request_data['centerLng'])
    )

  chunk_id =    int(request_data['chunkId'])
  chunk_size =  int(request_data['chunkSize'])
  area_ids =    request_data['areaIds']


  ## OUTPUT
  return HttpResponse(
    # get set of areas for this part of the request
    view_utils.areas.get_area_chunk(
      area_ids,
      viewport_center,
      chunk_id,
      chunk_size
    )
  )


# ==============================================================================
# get all hivents that were not included in the initial area ids sending
# -> all hivents without changes
# ==============================================================================

def get_rest_hivents(request):

  ## INPUT
  request_data = json.loads(request.body)
  existing_hivents = request_data['hiventIds']

  ## PROCESSING
  rest_hivents = view_utils.hivents.get_rest_hivents(existing_hivents)

  ## OUTPUT
  return HttpResponse(json.dumps(rest_hivents))


# ==============================================================================
# save hivent and change to database
# return hivent and newly created area ids to client
# ==============================================================================

def save_operation(request):

  # HARDCODE CLEANUP
  # if len(Hivent.objects.filter(name="The Creation of the Baltic Union")) == 1:
  # from HistoGlobe_server.models import *
  #   h = Hivent.objects.get(name="The Creation of the Baltic Union")
  #   h.delete()
  #   a = Area.objects.get(short_name="Baltic Union")
  #   a.delete()


  ### init variables
  request_data = json.loads(request.body)
  response_data = {}

  operation = request_data['change']['operation']
  old_areas = request_data['change']['old_areas']
  new_areas = []


  ### create new areas and save their id's
  # -> so they can be updated on the client

  response_data['old_areas'] = old_areas
  response_data['new_areas'] = []

  for area in request_data['change']['new_areas']:
    old_area_id = area['id']
    area = view_utils.areas.create_area(area)
    new_area_id = area.id

    # update id and prepare for output
    new_areas.append(new_area_id)
    response_data['new_areas'].append({
      'old_id': old_area_id,
      'new_id': new_area_id
    })


  ### existing hivent?
  # TODO
  # get hivent from model


  ### new hivent?
  [hivent, error_message] = view_utils.hivents.validate_hivent(request_data['hivent'])
  if hivent is False:
    return HttpResponse(error_message)

  # else: hivent is valid and filled with data
  # =>  create hivent + changes + change_areas
  #     and update start / end hivent for areas
  new_hivent = view_utils.hivents.save_hivent(hivent)
  new_change = view_utils.hivents.save_change(new_hivent, operation)
  view_utils.hivents.save_change_areas(new_change, operation, old_areas, new_areas)

  ## get whole hivent, including change(areas) as response to the client
  response_data['hivent'] = view_utils.hivents.prepare_hivent(Hivent.objects.get(new_hivent.id))


  return HttpResponse(json.dumps(response_data))  # N.B: mind the HttpResponse(function)