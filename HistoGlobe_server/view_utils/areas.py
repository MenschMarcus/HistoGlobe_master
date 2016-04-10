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

# utils
import chromelogger as console


# own
from HistoGlobe_server.models import Area
from HistoGlobe_server import utils


# ==============================================================================
# given area data, validate each datum
# return created Area object
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


# ==============================================================================
# extract a chunk of size X from the areas
# return chunk, the current size and if it was the last chunk
# ==============================================================================

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



# ==============================================================================
# send area and chunk data as large json string
# assemble string directly
# it looks horrible, but it is the only way I could see to avoid
# serializing and deserializing the geometry (see #1 json string)
# ==============================================================================

  json_str  = '{'
  json_str +=   '"type":"FeatureCollection",'
  json_str +=   '"crs":{"type": "name","properties":{"name":"EPSG:4326"}},'
  json_str +=   '"loadingComplete":'          + str(chunks_complete).lower() + ','
  json_str +=   '"features":['          # 'True' -> 'true' resp. 'False' -> 'false'

  area_counter = 0
  for area in areas:
    json_str += '{'
    json_str +=   '"type":"Feature",'
    json_str +=   '"properties":'
    json_str +=   '{'
    json_str +=     '"id":'                   + str(area.id)                          + ','
    json_str +=     '"short_name":"'          + str(area.short_name.encode('utf-8'))  + '",'   # N.B: encode with utf-8!
    json_str +=     '"formal_name":"'         + str(area.formal_name.encode('utf-8')) + '",'   # N.B: encode with utf-8!
    json_str +=     '"representative_point":' + area.representative_point.json        + ','
    json_str +=     '"sovereignty_status":"'  + str(area.sovereignty_status)          + '",'
    json_str +=     '"territory_of":"'        + str(area.territory_of)                + '"'
    json_str +=   '},'
    json_str +=   '"geometry":'               + area.geom.json    #1 json string
    json_str += '}'

    # decide if final ',' has to be appended
    area_counter += 1
    if area_counter < chunk_size:
      json_str += ','

  json_str +=   ']'
  json_str += '}'

  return json_str