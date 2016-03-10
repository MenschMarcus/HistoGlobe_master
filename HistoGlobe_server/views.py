"""
  This file contains all the views on the data in the database,
  i.e. this file defines the interface to the client application.

"""


### INCLUDES ###

from django.http import HttpResponse
from django.shortcuts import render
from django.contrib.gis.geos import *
from django.core.serializers import serialize
import chromelogger as console

from django.contrib.gis import measure
from django.contrib.gis.geos import Point
from django.contrib.gis.measure import D # ``D`` is a shortcut for ``Distance``

from datetime import date
import re
import json

from HistoGlobe_server.models import *

# dictionary passed to each template engine as its context.
context_dict = {}


# ==============================================================================
### INTERFACE ###

# ------------------------------------------------------------------------------
# simple index view redirecting to index of HistoGlobe
def index(request):
  return render(request, 'HistoGlobe_client/index.htm', context_dict)


# ------------------------------------------------------------------------------
# initial set of areas
def get_initial_areas(request):

  viewport_center = Point(
      float(request.POST.get('centerLat')),
      float(request.POST.get('centerLng'))
    )

  request_date = date(
      int(request.POST.get('dateY')),
      int(request.POST.get('dateM')),
      int(request.POST.get('dateD'))
    )

  chunk_id = int(request.POST.get('chunkId'))
  chunk_size = int(request.POST.get('chunkSize'))

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


# ==============================================================================
### HELPER FUNCTIONS ###

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

    console.log(area.name)

    json_str += '{'
    json_str +=   '"type":"Feature",'
    json_str +=   '"properties":'
    json_str +=   '{'
    json_str +=     '"id":'           + str(area.id)     + ','
    json_str +=     '"name":"'        + str(area.name)   + '",'
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