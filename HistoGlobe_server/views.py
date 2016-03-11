"""
  This file contains all the views on the data in the database,
  i.e. this file defines the interface to the client application.

"""


### INCLUDES ###

from django.http import HttpResponse
from django.shortcuts import render
from django.contrib.gis.geos import *
import chromelogger as console

from django.contrib.gis import measure
from django.contrib.gis.geos import Point
from django.contrib.gis.measure import D # ``D`` is a shortcut for ``Distance``

from datetime import datetime, date
import time
import re
import json

from HistoGlobe_server.models import *

# dictionary passed to each template engine as its context.
context_dict = {}


# ==============================================================================
### INTERFACE ###
# basic idea of client-server interaction
# POST: client sends data to be processed by the server and awaits an answer
# GET:  client requires data from the server and awaits an answer
#
### data structures
#   client -> server (reuqest):
#     - stringified JSON of arrays and objects (can be multi-dimensional)
#       JSON.stringify request
#       ->  access on the server by:
#           json.loads(request.body)                    # needs: import json
#   client <- server (response):
#     - list or dictionary (no tuples or anything else, please!) stringified
#       HttpResponse(json.dumps(response_data))
#       ->  access on the client by:
#           success: (reponse) =>
#             data = $.parseJSON response
#
#
### date interoperabiliy: use RFC 3339 (date = '%Y-%m-%dT%H:%M:%S')
#   client -> server:
#     moment(date).format()                             # needs: third-party script moment.js
#     ->  access on the server by:
#         datetime.strptime(date_string, DATE_FORMAT)   # needs: from datetime import datetime
#   client <- server:
#     date_object.strftime(DATE_FORMAT)
#     date_string.strftime(DATE_FORMAT)
#     ->  access on the client by:
#         moment(dateString)

# ValueError

# ------------------------------------------------------------------------------
# simple view redirecting to index of HistoGlobe
def index(request):
  return render(request, 'HistoGlobe_client/index.htm', context_dict)

# ------------------------------------------------------------------------------
# initial set of areas
def get_initial_areas(request):

  # deserialize object string -> dictionary
  data_dict = json.loads(request.body)

  viewport_center = Point(
      float(data_dict['centerLat']),
      float(data_dict['centerLng'])
    )

  request_date = get_date_object(data_dict['date'])

  chunk_id = int(data_dict['chunkId'])
  chunk_size = int(data_dict['chunkSize'])

  # look for snapshot closest to the requested date
  closest_snapshot = get_closest_snapshot(request_date)

  # accumulate all changes in events since this date
  start_date = max(request_date, closest_snapshot.date)
  end_date =   min(request_date, closest_snapshot.date)
  # changes = get_changes(start_date, end_date)

  # do more magic I do not want to think about now...

  # get set of areas for this part of the request
  # areas = closest_snapshot.areas.filter(name='Germany')
  [areas, chunk_size, chunks_complete] = get_output_chunk(closest_snapshot, viewport_center, chunk_id, chunk_size)

  out = prepare_output(areas, chunk_size, chunks_complete)

  return HttpResponse(out)


# ------------------------------------------------------------------------------
# save hivent and change to database
def save_hivent(request):

  # console.log(request.body)
  data_dict = json.loads(request.body)

  # decide: existing or new hivent?

  ### existing hivent
  # TODO
  # get hivent from model

  ### new hivent
  hivent = data_dict['hivent']


  # TODO: validate by try .. catch

  ## name
  if validate_string(hivent['name']) is False:
    return HttpResponse("The name of the Hivent is not valid")


  ## dates

  # start date has to be valid
  if validate_date(hivent['start_date']) is False:
    return HttpResponse("The start date of the Hivent is not valid")

  # end date can be either None or valid -> but then it must be later than the end date
  if ('end_date' in hivent) and (hivent['end_date'] is not None):
    if validate_date(hivent['end_date']) is False:
      return HttpResponse("The end date of the Hivent is not valid")
    if get_date_object(hivent['end_date']) < get_date_object(hivent['start_date']):
      return HttpResponse("The end date of the Hivent can not be before the start date")

  # effect date is either itself or the start date
  if ('effect_date' in hivent) and (hivent['effect_date'] is not None):
    if validate_date(hivent['effect_date']) is False:
      return HttpResponse("The effect date of the Hivent is not valid")
  else:
    hivent['effect_date'] = hivent['start_date']

  # end date can be either None or valid -> but then it must be later than the effect date
  if ('secession_date' in hivent) and (hivent['secession_date'] is not None):
    if validate_date(hivent['secession_date']) is False:
      return HttpResponse("The secession date of the Hivent is not valid")
    if get_date_object(hivent['secession_date']) < get_date_object(hivent['effect_date']):
      return HttpResponse("The secession date of the Hivent can not be before the effect date")


  ## location

  # location name can be either a string or None
  if 'location_name' in hivent:
    if validate_string(hivent['location_name']) is False:
      return HttpResponse('The location name you were giving to the Hivent is not valid')


  # TODO: location point
  # TODO: location area

  ## description
  # description can be either a string or None

  if 'description' in hivent:
    if validate_string(hivent['description']) is False:
      return HttpResponse('The description you were giving to the Hivent is not valid')

  ## link
  # link can be either a string or None

  if 'link' in hivent:
    # TODO: check if it is a valid url
    if validate_string(hivent['link']) is False:
      return HttpResponse('The link you were giving to the Hivent is not valid')
    # if it is valid, it gets today as the date
    hivent['link_date'] = get_date_string(date.today())


  ### save in database
  console.log(hivent)


  ### add hivent id as an output
  out = {}
  out['id'] = 42

  ## add change to hivent

  # return whole hivent including its changes in a list of lists

  return HttpResponse(json.dumps(out))  # N.B: mind the HttpResponse(function)


# ==============================================================================
### HELPER FUNCTIONS ###

# ==============================================================================
# dates: date string <-> date object, date string validation
DATE_FORMAT = '%Y-%m-%dT%H:%M:%S'

# ------------------------------------------------------------------------------
def get_date_object(date_string):
  return datetime.strptime(date_string, DATE_FORMAT)

# ------------------------------------------------------------------------------
def get_date_string(date_object):
  return date_object.strftime(DATE_FORMAT)

# ------------------------------------------------------------------------------
def validate_date(date_string):
  try:
    datetime.strptime(date_string, DATE_FORMAT)
  except ValueError:
    return False

  # everything is fine
  return True


# ==============================================================================
# strings: validation

# ------------------------------------------------------------------------------
def validate_string(in_string):
  if not isinstance(in_string, basestring):
    return ("Not a string")
  if (in_string == ''):
    return False

  # everything is fine
  return True

# ==============================================================================
# output for init areas
# ------------------------------------------------------------------------------
def get_closest_snapshot(request_date):

  current_snapshot = Snapshot.objects.first()
  current_snapshot_distance = current_snapshot.date - request_date

  for this_snapshot in Snapshot.objects.all():
    this_snaphot_distance = this_snapshot.date - request_date
    if this_snaphot_distance < current_snapshot_distance:
      current_snapshot = this_snapshot
      current_snapshot_distance = this_snaphot_distance

  return current_snapshot


# ------------------------------------------------------------------------------
def get_changes(start_date, end_date):

  for hivent in Hivent.objects.all():
    if (hivent.effect_date >= start_date) and (hivent.effect_date < start_date):
      print("Horst")

  return []


# ------------------------------------------------------------------------------
def get_output_chunk(snapshot, viewport_center, chunk_id, chunk_size):

  # assign a distance value to the viewport center for all areas
  # ->  find all areas that are in a distance of 42000 km (= earths diameter)
  #     to the viewport center = find all areas
  ref_pt = viewport_center
  dist = {'km': 42000}
  areas = Area.objects.filter(repr_point__distance_lte=(ref_pt, measure.D(**dist)))

  # sort areas by their new distance value
  areas_sorted = areas.distance(ref_pt).order_by('distance')


  # check if total number of areas reached
  chunks_complete = False
  num_areas =       areas_sorted.count()
  start_id =        chunk_id
  end_id =          chunk_id + chunk_size

  # if so, reset variables and state that chunks are complete
  if end_id >= num_areas:
    chunks_complete = True
    end_id = num_areas
    chunk_size = end_id-start_id

  return [
    areas_sorted[start_id:end_id],
    chunk_size,
    chunks_complete
  ]

# ------------------------------------------------------------------------------
def prepare_output(areas, chunk_size, chunks_complete):

  # javascript  python
  # object      dictionary
  # array       list
  # crap... write my own serializer, this thing is a regex pain in the ass !!!
  # it looks horrible, but it is the only way I could see while avoiding
  # serializing and deserializing the geometry (see #1 geometry as json string)

  json_str  = '{'
  json_str +=   '"type":"FeatureCollection",'
  json_str +=   '"crs":{"type": "name","properties":{"name":"EPSG:4326"}},'
  json_str +=   '"loadingComplete":'  + str(chunks_complete).lower() + ','
  json_str +=   '"features":['          # 'True' -> 'true' resp. 'False' -> 'false'

  area_counter = 0
  for area in areas:
    json_str += '{'
    json_str +=   '"type":"Feature",'
    json_str +=   '"properties":'
    json_str +=   '{'
    json_str +=     '"id":'           + str(area.id)                     + ','
    json_str +=     '"name":"'        + str(area.name.encode('utf-8'))   + '",'   # N.B: encode with utf-8
    json_str +=     '"repr_point":'
    json_str +=     '{'
    json_str +=       '"lat":'        + str(area.repr_point.coords[0]) + ','
    json_str +=       '"lng":'        + str(area.repr_point.coords[1])
    json_str +=    '}'
    json_str +=   '},'
    json_str += '"geometry":'         + area.geom.json  #1 geometry as json string
    json_str += '}'

    # decide if final ',' has to be appended
    area_counter += 1
    if area_counter < chunk_size:
      json_str += ','

  json_str +=   ']'
  json_str += '}'

  return json_str



# ------------------------------------------------------------------------------
# timestamp framework

# timestamp_1 = time.time()
# timestamp_2 = time.time()
# ...
# timestamp_n = time.time()

# console.log(
#   timestamp_2-timestamp_1,
#   timestamp_3-timestamp_2,
#   timestamp_4-timestamp_3,)
