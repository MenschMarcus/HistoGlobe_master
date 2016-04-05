"""
  This file contains all helper functions for all views that is related to
  areas
  - create areas

"""

# ==============================================================================
### INCLUDES ###

# GeoDjango
from django.contrib.gis.geos import Point
from django.contrib.gis import measure
from django.contrib.gis.measure import D # ``D`` is a shortcut for ``Distance``

# utils
import chromelogger as console


# own
from HistoGlobe_server.models import Area
import utils


# ==============================================================================
def create_area(area):

  # geometry
  geometry = utils.validate_geometry(area['geometry'])
  if geometry == False: return False

  # representative point
  representative_point = utils.validate_point(area['representative_point'])
  if representative_point == False: return False

  # name
  short_name = utils.validate_string(area['short_name'])
  formal_name = utils.validate_string(area['formal_name'])
  if (short_name == False) or (formal_name == False): return False

  # sovereignty status
  sovereignty_status = utils.validate_string(area['sovereignty_status'])
  if not any(sovereignty_status in char for char in ['F', 'P', 'N']):
    sovereignty_status = 'F' # default fallback value: fully sovereign entity

  # territory of
  # EITHER None OR id of an area
  territory_of = None
  if (hasattr(area, 'territory_of') and (utils.validate_area_id(area['territory_of']) != False)):
    territory_of = Area.objects.get(id=area['territory_of'])

  new_area = Area(
    geom =                  geometry,
    representative_point =  representative_point,
    short_name =            short_name,
    formal_name =           formal_name,
    sovereignty_status =    sovereignty_status,
    territory_of =          territory_of
  )
  new_area.save()

  return new_area


# ------------------------------------------------------------------------------
def get_area_chunk(required_areas, viewport_center, chunk_id, chunk_size):

  # assign a distance value to the viewport center for all areas
  # ->  find all areas that are in a distance of 42000 km (= earths diameter)
  #     to the viewport center = find all areas
  # dist = {'km': 2800}  # DEBUG
  dist = {'km': 42000}
  areas = required_areas.filter(
    representative_point__distance_lte=(viewport_center, measure.D(**dist))
  )

  # sort areas by their new distance value
  areas_sorted = areas.distance(viewport_center).order_by('distance')

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