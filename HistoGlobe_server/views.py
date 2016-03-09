"""
  This file contains all the views on the data in the database,
  i.e. this file defines the interface to the client application.

"""


### INCLUDES ###

from django.http import HttpResponse
from django.shortcuts import render
from django.contrib.gis.geos import *
from django.core.serializers import serialize

from django.contrib.gis import measure
from django.contrib.gis.geos import Point
from django.contrib.gis.measure import D # ``D`` is a shortcut for ``Distance``

from datetime import date
import re

import chromelogger as console
console.log("HELLO")
console.get_header()

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

  chunk_id = 1

  # look for snapshot closest to the requested date
  closest_snapshot = get_closest_snapshot(request_date)

  # accumulate all changes in events since this date
  start_date = max(request_date, closest_snapshot.date)
  end_date =   min(request_date, closest_snapshot.date)
  # changes = get_changes(start_date, end_date)

  # do more magic I do not want to think about now...

  # get set of areas for this part of the request
  # areas = closest_snapshot.areas.filter(name='Germany')
  areas = get_output_chunk(closest_snapshot, viewport_center, chunk_id)

  out = prepare_areas_output(areas)

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
def get_output_chunk(snapshot, viewport_center, chunk_id):
  ref_pt = viewport_center
  dist = {'km': 2000}
  areas = Area.objects.filter(repr_point__distance_lte=(ref_pt, measure.D(**dist)))
  areas_sortes = areas.distance(ref_pt).order_by('distance')

  return areas

# ------------------------------------------------------------------------------
def prepare_areas_output(areas):

  # transformation to json string
  json_str = serialize(
    'geojson',
    areas,
    geometry_field='geom',
    fields=('id', 'name', 'repr_point')
  )

  # TODO: Why does it serialize the id??? why is this such a pain???

  # replacement of POINT wkt string to array
  # complicated (?) regex explained here
  # 1) overhead           "SRID=4326;POINT\s\(
  # 2) lng coordinate     (-?(?:\.\d+|\d+(?:\.\d*)?))
  # 3) whitespace         \s
  # 4) lat coordinate     (-?(?:\.\d+|\d+(?:\.\d*)?))
  # 5) overhead           \)"
  # -> replace by object: {lat lng}
  # N.B: flip groups around, because notion of lat/lng is (again) flipped

  return re.sub(
    r'"SRID=4326;POINT\s\((-?(?:\.\d+|\d+(?:\.\d*)?))\s(-?(?:\.\d+|\d+(?:\.\d*)?))\)"',
    '{"lat":\g<1>, "lng":\g<2>}',
    json_str
  )

  return json_str