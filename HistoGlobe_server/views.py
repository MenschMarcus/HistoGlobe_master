"""
  This file contains all the views on the data in the database,
  i.e. this file defines the interface to the client application.

"""


### INCLUDES ###

from django.http import HttpResponse
from django.shortcuts import render
from django.core.validators import URLValidator
from django.core.exceptions import ValidationError
from datetime import datetime, date
import rfc3339    # for date object -> date string
import iso8601    # for date string -> date object

import chromelogger as console
import re
import json


from django.contrib.gis import measure
from django.contrib.gis.geos import *
from django.contrib.gis.measure import D # ``D`` is a shortcut for ``Distance``


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
### date interoperabiliy: use RFC 3339 (date = 'YYYY-MM-DDTHH:MM:SS.sss+UTC')
#
#   client -> server:
#     moment(dateObject).format()           # needs: moment.js
#     ->  access on the server by:
#         iso8601.parse_date(date_string)   # needs: import iso8601
#   client <- server:
#     rfc3339(date_object)                  # needs: from rfc3339 import rfc3339
#     ->  access on the client by:
#         moment(dateString)


# ------------------------------------------------------------------------------
# simple view redirecting to index of HistoGlobe
def index(request):
  return render(request, 'HistoGlobe_client/index.htm', context_dict)

# ------------------------------------------------------------------------------
# initial set of areas
def get_initial_areas(request):

  # deserialize object string -> dictionary
  request_data = json.loads(request.body)

  viewport_center = Point(
      float(request_data['centerLat']),
      float(request_data['centerLng'])
    )

  now_date = get_date_object(request_data['date'])

  chunk_id = int(request_data['chunkId'])
  chunk_size = int(request_data['chunkSize'])

  # look for snapshot closest to the requested date
  closest_snapshot = get_closest_snapshot(now_date)

  # accumulate all changes in events since this date
  start_date = max(now_date, closest_snapshot.date)
  end_date =   min(now_date, closest_snapshot.date)
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

  request_data = json.loads(request.body)
  response_data = {}

  ### create new areas and save their id's on the client
  response_data['new_areas'] = []

  for area in request_data['change']['new_areas']:
    old_area_id = area['id']
    new_area_id = create_area(area)

    # update id and prepare for output
    area['id'] = new_area_id
    response_data['new_areas'].append({
        'old_id': old_area_id,
        'new_id': new_area_id
      })


  # decide: existing or new hivent?

  ### existing hivent
  # TODO
  # get hivent from model


  ### new hivent
  hivent = request_data['hivent']

  ## name
  if validate_string(hivent['name']) is False:
    return HttpResponse("The name of the Hivent is not valid")


  ## dates

  # start date has to be valid
  if validate_date(hivent['start_date']) is False:
    return HttpResponse("The start date of the Hivent is not valid")
    # else: start_date is OK

  # end date can be either None or valid
  if ('end_date' in hivent) and (hivent['end_date'] is not None):
    if validate_date(hivent['end_date']) is False:
      return HttpResponse("The end date of the Hivent is not valid")
    # end date must be later than start date
    if get_date_object(hivent['end_date']) < get_date_object(hivent['start_date']):
      return HttpResponse("The end date of the Hivent can not be before the start date")
    # else: end_date is OK

  else:
    hivent['end_date'] = None


  # effect date is either itself or the start date
  if ('effect_date' in hivent) and (hivent['effect_date'] is not None):
    if validate_date(hivent['effect_date']) is False:
      return HttpResponse("The effect date of the Hivent is not valid")
    # else: effect_date is OK

  else:
    hivent['effect_date'] = hivent['start_date']


  # end date can be either None or valid
  if ('secession_date' in hivent) and (hivent['secession_date'] is not None):
    if validate_date(hivent['secession_date']) is False:
      return HttpResponse("The secession date of the Hivent is not valid")
    # secession date must be later than the effect date
    if get_date_object(hivent['secession_date']) < get_date_object(hivent['effect_date']):
      return HttpResponse("The secession date of the Hivent can not be before the effect date")
    # else: secession_date is OK

  else:
    hivent['secession_date'] = None


  ## location

  # location name can be either a string or None
  if 'location_name' in hivent:
    if validate_string(hivent['location_name']) is False:
      return HttpResponse('The location name you were giving to the Hivent is not valid')
    # else: location_name is ok

  else:
    hivent['location_name'] = None


  # TODO: location point
  hivent['location_point'] = None
  # TODO: location area
  hivent['location_area'] = None


  ## description
  # description can be either a string or None

  if 'description' in hivent:
    if validate_string(hivent['description']) is False:
      return HttpResponse('The description you were giving to the Hivent is not valid')
    # else: description is ok

  else:
    hivent['description'] = None


  ## link
  # link must be a valid URL
  if 'link_url' in hivent:
    if validate_url(hivent['link_url']) is False:
      return HttpResponse('The link you were giving to the Hivent is not valid')

    # link_url is OK, link_date is set to today (= just checked)
    hivent['link_date'] = get_date_string(date.today())


  ## save in database
  new_hivent = Hivent(
      name =            hivent['name'],                 # CharField          (max_length=150)
      start_date =      hivent['start_date'],           # DateTimeField      (default=date.today)
      end_date =        hivent['end_date'],             # DateTimeField      (null=True)
      effect_date =     hivent['effect_date'],          # DateTimeField      (default=start_date)
      secession_date =  hivent['secession_date'],       # DateTimeField      (null=True)
      location_name =   hivent['location_name'],        # CharField          (null=True, max_length=150)
      location_point =  hivent['location_point'],       # PointField         (null=True)
      location_area =   hivent['location_area'],        # MultiPolygonField  (null=True)
      description =     hivent['description'],          # CharField          (null=True, max_length=1000)
      link_url =        hivent['link_url'],             # CharField          (max_length=300)
      link_date =       hivent['link_date']             # DateTimeField      (default=date.today)
    )
  new_hivent.save()

  ### add change to hivent
  operation = request_data['change']['type']
  old_areas = request_data['change']['old_areas']
  new_areas = request_data['change']['new_areas']

  ## in Change table
  new_change = Change(
      hivent =          new_hivent,                     # models.ForeignKey   (Hivent)
      operation =       operation                       # models.CharField   (max_length=3)
    )
  new_change.save()


  ## in ChangeAreas table

  # depending on the kind of operation, there are differently many old/new areas
  num_changes = max(len(request_data['change']['old_areas']), len(request_data['change']['new_areas']))
  idx = 0
  while idx < num_changes:

    # initital entry (for all operations)
    new_change_areas = ChangeAreas(
        change =        new_change,                     # models.ForeignKey   (Change, related_name='change')
        old_area =      None,                           # models.ForeignKey   (Area, related_name='old_area')
        new_area =      None                            # models.ForeignKey   (Area, related_name='new_area')
      )

    # special treatment of old/new areas (for operations)
    if operation is 'ADD':      #   0  ->  1
      new_change_areas.new_area = new_areas[0]

    elif operation is 'UNI':    #   2+ ->  1
      new_change_areas.old_area = old_areas[idx]
      new_change_areas.new_area = new_areas[0]

    elif operation is 'SEP':    #   1  ->  2+
      new_change_areas.old_area = old_areas[0]
      new_change_areas.new_area = new_areas[idx]

    elif operation is 'CHB':    #   2  ->  2
      new_change_areas.old_area = old_areas[idx]
      new_change_areas.new_area = new_areas[idx]

    elif operation is 'CHN':    #   1  ->  1  => = CHB case
      new_change_areas.old_area = old_areas[idx]
      new_change_areas.new_area = new_areas[idx]

    elif operation is 'DEL':    #   1  ->  0
      new_change_areas.old_area = old_areas[0]


    # go to next change area pair
    new_change_areas.save()
    idx += 1

  ## get whole hivent, including change(areas) as response to the client
  # (stores id's = handles of change areas)
  response_data['hivent'] = get_hivent(new_hivent.id)

  return HttpResponse(json.dumps(response_data))  # N.B: mind the HttpResponse(function)



################################################################################
#                               HELPER FUNCTIONS                               #
################################################################################


# ==============================================================================
# dates: date string <-> date object, date string validation

# ------------------------------------------------------------------------------
def get_date_object(date_string):
  return iso8601.parse_date(date_string)

# ------------------------------------------------------------------------------
def get_date_string(date_object):
  return rfc3339.rfc3339(date_object)

# ------------------------------------------------------------------------------
def validate_date(date_string):
  try:
    get_date_object(date_string)
  except ValueError:
    return False

  # everything is fine
  return True


# ==============================================================================
# strings and urls: validation

# ------------------------------------------------------------------------------
def validate_string(in_string):
  if not isinstance(in_string, basestring):
    return ("Not a string")
  if (in_string == ''):
    return False

  # everything is fine
  return True

# ------------------------------------------------------------------------------
def validate_url(in_url):
  validate = URLValidator()
  try:
    validate(in_url)
  except ValidationError:
    return False

  # everything is fine
  return True


# ==============================================================================
# geometry

# ------------------------------------------------------------------------------
def validate_geometry(in_geom):
  try:
    geom = MultiPolygon(in_geom)
  except ValueError:
    return False

  # everything is fine
  return geom


# ------------------------------------------------------------------------------
def validate_coordinates(lat, lng):
  try:
    isinstance(lat, (int, long, float, complex))
    isinstance(lng, (int, long, float, complex))
  except ValueError:
    return [False]

  # check for correct interval
  if (lat < -90) or (lat > 90):
    return [False]
  if (lng < -180) or (lng > 180):
    return [False]

  # everything is fine
  return [lat, lng]


# ==============================================================================
# snapshots

# ------------------------------------------------------------------------------
def get_closest_snapshot(now_date):

  current_snapshot = Snapshot.objects.first()
  current_snapshot_distance = current_snapshot.date - now_date

  for this_snapshot in Snapshot.objects.all():
    this_snaphot_distance = this_snapshot.date - now_date
    if this_snaphot_distance < current_snapshot_distance:
      current_snapshot = this_snapshot
      current_snapshot_distance = this_snaphot_distance

  return current_snapshot


# ==============================================================================
# hivents + changes

# ------------------------------------------------------------------------------
def get_hivent(hivent_id):

  # hivent  <-1:n->  changes  <-1:n->  change_areas = {old_area, new_area}

  hivent  = Hivent.objects.filter(id = hivent_id)
  changes = []
  for change in Change.objects.filter(hivent = hivent):
    change_areas = []
    for change_area in ChangeAreas.objects.filter(change = change):
      change_area.append(change_area)
    changes.append(change_area)
  hivent['changes'] = changes

  return hivent


# ------------------------------------------------------------------------------
def get_changes(start_date, end_date):

  for hivent in Hivent.objects.all():
    if (hivent.effect_date >= start_date) and (hivent.effect_date < start_date):
      print("Horst")

  return []


# ==============================================================================
# areas

# ------------------------------------------------------------------------------
def create_area(area):

  # name
  if validate_string(area['name']) is False:
    return False
  else:
    name = area['name']

  # geometry
  geom = validate_geometry(area['geometry'])
  if geom is False:
    return False

  # representative point
  [lat, lng] = validate_coordinates(area['repr_point']['lat'], area['repr_point']['lng'])
  if lat is False:
    return False
  repr_point = Point(lat, lng)

  new_area = Area(
      name =        name,
      geom =        geom,
      repr_point =  repr_point
    )
  new_area.save()

  return new_area.id



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
    json_str +=     '"repr_point":'   + area.repr_point.json    #1 geometry as json string
    json_str +=   '},'
    json_str +=   '"geometry":'       + area.geom.json          #1 geometry as json string
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
