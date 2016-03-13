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

# datetime
import rfc3339      # for date object -> date string
import iso8601      # for date string -> date object

from django.contrib.gis.geos import WKTReader



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
# geometry: validation

# ------------------------------------------------------------------------------
def validate_geometry(in_geom):
  wkt_reader = WKTReader()
  try:
    geom = wkt_reader.read(in_geom)
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
# timestamp framework

# timestamp_1 = time.time()
# timestamp_2 = time.time()
# ...
# timestamp_n = time.time()

# console.log(
#   timestamp_2-timestamp_1,
#   timestamp_3-timestamp_2,
#   timestamp_4-timestamp_3,)