"""
  This file contains all helper functions for all views that is related to
  areas
  - create areas

"""

# ==============================================================================
### INCLUDES ###

# GeoDjango
from django.contrib.gis.geos import Point

# own
from HistoGlobe_server.models import Area
import utils


# ==============================================================================
def create_area(area):

  # name
  if utils.validate_string(area['name']) == False:
    return False
  else:
    name = area['name']

  # geometry
  geom = utils.validate_geometry(area['geometry'])
  if geom == False:
    return False

  # representative point
  [lat, lng] = utils.validate_coordinates(area['repr_point']['lat'], area['repr_point']['lng'])
  if lat == False:
    return False
  repr_point = Point(lat, lng)

  new_area = Area(
      name =        name,
      geom =        geom,
      repr_point =  repr_point
    )
  new_area.save()

  return new_area


# ------------------------------------------------------------------------------
def get_area_chunk(viewport_center, chunk_id, chunk_size):

  # assign a distance value to the viewport center for all areas
  # ->  find all areas that are in a distance of 42000 km (= earths diameter)
  #     to the viewport center = find all areas
  dist = {'km': 42000}
  areas = Area.objects.filter(repr_point__distance_lte=(viewport_center, measure.D(**dist)))

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