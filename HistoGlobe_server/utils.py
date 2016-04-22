"""
  This file contains all kinds of universal helper functions
  - date object <-> date string conversion
  - date, string, url and geometry validation
"""

# ==============================================================================
### INCLUDES ###

# Django
from django.core.validators import URLValidator
from django.core.exceptions import ValidationError
from django.forms.models import model_to_dict

# GeoDjango
from django.contrib.gis.geos import WKTReader, MultiPolygon, Point
from django.contrib.gis import measure

# date & time
import datetime
import rfc3339      # for date object -> date string
import iso8601      # for date string -> date object

# utils
import chromelogger as console

# own
from HistoGlobe_server.models import *



################################################################################
#                    APPLICATION SPECIFIC UTIL FUNCTIONS                       #
################################################################################

# ==============================================================================
# receive an hivent dictionary with all properties
# validate each property based on their characteristics
# return hivent and validated? True/False
# ==============================================================================

def validate_hivent(hivent):

  ## name

  if validate_string(hivent['name']) is False:
    return [False, ("The name of the Hivent is not valid")]


  ## dates

  # start date has to be valid
  if validate_date(hivent['start_date']) is False:
    return [False, ("The start date of the Hivent is not valid")]
    # else: start_date is OK

  # end date can be either None or valid
  if ('end_date' in hivent) and (hivent['end_date'] is not None):
    if validate_date(hivent['end_date']) is False:
      return [False, ("The end date of the Hivent is not valid")]
    # end date must be later than start date
    if get_date_object(hivent['end_date']) < get_date_object(hivent['start_date']):
      return [False, ("The end date of the Hivent can not be before the start date")]
    # else: end_date is OK

  else:
    hivent['end_date'] = None


  # effect date is either itself or the start date
  if ('effect_date' in hivent) and (hivent['effect_date'] is not None):
    if validate_date(hivent['effect_date']) is False:
      return [False, ("The effect date of the Hivent is not valid")]
    # else: effect_date is OK

  else:
    hivent['effect_date'] = hivent['start_date']


  # end date can be either None or valid
  if ('secession_date' in hivent) and (hivent['secession_date'] is not None):
    if validate_date(hivent['secession_date']) is False:
      return [False, ("The secession date of the Hivent is not valid")]
    # secession date must be later than the effect date
    if get_date_object(hivent['secession_date']) < get_date_object(hivent['effect_date']):
      return [False, ("The secession date of the Hivent can not be before the effect date")]
    # else: secession_date is OK

  else:
    hivent['secession_date'] = None


  ## location

  # location name can be either a string or None
  if 'location_name' in hivent:
    if validate_string(hivent['location_name']) is False:
      return [False, ('The location name you were giving to the Hivent is not valid')]
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
      return [False, ('The description you were giving to the Hivent is not valid')]
    # else: description is ok

  else:
    hivent['description'] = None


  ## link
  # link can be either a valid URL or None
  if 'link_url' in hivent:
    if validate_url(hivent['link_url']) is False:
      return [False, ('The link you were giving to the Hivent is not valid')]

    # link_url is OK, link_date is set to today (= just checked)
    hivent['link_date'] = get_date_string(datetime.date.today())

  else:
    hivent['link_url'] = None
    hivent['link_date'] = None

  # everything is fine => return hivent
  return [hivent, None]


# ==============================================================================
# given AreaTerritory / AreaName data, validate each datum
# ==============================================================================

def validate_territory(area_territory):

  # geometry
  area_territory['geometry'] = validate_geometry(area_territory['geometry'])
  if area_territory['geometry'] == False:
    return [False, ('The geometry of the AreaTerritory is not valid')]

  # representative point
  area_territory['representative_point'] = validate_point(area_territory['representative_point'])
  if area_territory['representative_point'] == False:
    return [False, ('The representative point of the AreaTerritory is not valid')]

  return [area_territory, None]


# ------------------------------------------------------------------------------
def validate_name(area_name):

  # short name
  area_name['short_name'] = validate_string(area_name['short_name'])
  if area_name['formal_name'] == False:
    return [False, ('The short name of the AreaName is not valid')]

  # formal name
  area_name['formal_name'] = validate_string(area_name['formal_name'])
  if area_name['short_name'] == False:
    return [False, ('The formal name of the AreaName is not valid')]



################################################################################
#                           GENERAL UTIL FUNCTIONS                             #
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
  return date_string


# ==============================================================================
# strings and urls: validation

# ------------------------------------------------------------------------------
def validate_string(in_string):
  if not isinstance(in_string, basestring):
    return ("Not a string")
  if (in_string == ''):
    return False

  # everything is fine
  return in_string

# ------------------------------------------------------------------------------
def validate_url(in_url):
  validate = URLValidator()
  try:
    validate(in_url)
  except ValidationError:
    return False

  # everything is fine
  return in_url

# ==============================================================================
# area: id validation

# ------------------------------------------------------------------------------
def validate_area_id(in_num):
  if not isinstance(in_num, (int, long)):
    return False
  if (len(Area.objects.filter(id=in_num)) != 1):
    return False

  # everything is fine
  return in_num


# ==============================================================================
# geometry: validation

# ------------------------------------------------------------------------------
# problem: output MUST be a MultiPolygon!
def validate_geometry(in_geom):
  wkt_reader = WKTReader()
  try:
    geom = wkt_reader.read(in_geom)
    if geom.geom_type != 'MultiPolygon':
      geom = MultiPolygon(geom)

  except ValueError:
    return False

  # everything is fine
  return geom


# ------------------------------------------------------------------------------
def validate_point(in_point):
  wkt_reader = WKTReader()
  try:
    point = wkt_reader.read(in_point)
  except ValueError:
    return [False]

  lng = point.x
  lat = point.y

  # check for correct interval
  if (lat < -90) or (lat > 90):
    return [False]
  if (lng < -180) or (lng > 180):
    return [False]

  # everything is fine
  return point

# ==============================================================================
# timestamp framework
# import time
# t1 = time.time()
# t2 = time.time()
# t3 = time.time()
# t4 = time.time()

# console.log(
#   t2-t1,
#   t3-t2,
#   t4-t3,
# )