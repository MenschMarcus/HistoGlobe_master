"""
  This file does all the initialization work for the database:
  - create inital set of Areas of the world in in year 2015.
  - create initial snapshot for the year 2015
  - populate repr_point field in area table

  Caution: This can be performed ONLY in the beginning, when it is clear that
  all areas in the database are actually active in 2015. As soon as the first
  historical country is added, this script is not usable anymore.

  how to run:
    in the root folder of the project
    $ python manage.py shell
    >>> from HistoGlobe_server import load
    >>> load.run()
"""


# ==============================================================================
### INCLUDES ###

import os
from django.contrib.gis.utils import LayerMapping
from django.contrib.gis.geos import *

import HistoGlobe_server
from models import Area
from models import Snapshot


# ==============================================================================
### VARIABLES ###

area_mapping = {
  'geom' :      'MULTIPOLYGON',
  'lng' :       'LON',
  'lat' :       'LAT',
  'name' :      'NAME',
}

world_shp = os.path.abspath(os.path.join(
  os.path.dirname(HistoGlobe_server.__file__),
  'data', 'TM_WORLD_BORDERS-0.3.shp')
)


# ==============================================================================
### MAIN FUNCTION ###

def run(verbose=True):

  ### INIT AREAS ###

  areas = LayerMapping(
    Area,
    world_shp,
    area_mapping,
    transform=False,
    encoding='utf-8'
  )
  areas.save(strict=True, verbose=verbose)


  ### CREATE FIRST SNAPSHOT ###

  # save initial snapshot
  s1 = Snapshot(date='2015-01-01')
  s1.save()

  # populate snapshot with all areas in the database
  for area in Area.objects.all():
    s1.areas.add(area);


  ### POPULATE REPRESENTATIVE POINT ###

  for area in Area.objects.all():
    area.repr_point = Point(area.lat, area.lng)
    area.save()