"""
  This file contains all the views on the data in the database,
  i.e. this file defines the interface to the client application.
  - on init: get all areas of one time point (snapshot)
  - on run:  get all areas that change at hivent x
  - save hivent + changes
"""

# ==============================================================================
### INCLUDES ###

# Django
from django.http import HttpResponse
from django.shortcuts import render
from django.utils import timezone
from django.forms.models import model_to_dict

# GeoDjango
from django.contrib.gis.geos import Point

# utils
import chromelogger as console
import re
import json
import datetime

# own
from HistoGlobe_server.models import *
from HistoGlobe_server import utils


# ==============================================================================
"""
## INTERFACE ##
basic idea of client-server interaction
POST: client sends data to be processed by the server and awaits an answer
GET:  client requires data from the server and awaits an answer

# data structures
  client -> server (reuqest):
    - stringified JSON of arrays and objects (can be multi-dimensional)
      JSON.stringify request
      ->  access on the server by:
          json.loads(request.body)                    # needs: import json
  client <- server (response):
    - list or dictionary (no tuples or anything else, please!) stringified
      HttpResponse(json.dumps(response))
      ->  access on the client by:
          success: (reponse) =>
            data = $.parseJSON response


# date interoperabiliy: use RFC 3339 (date = 'YYYY-MM-DDTHH:MM:SS.sss+UTC')

  client -> server:
    moment(dateObject).format()           # needs: moment.js
    ->  access on the server by:
        iso8601.parse_date(date_string)   # needs: import iso8601
  client <- server:
    rfc3339(date_object)                  # needs: from rfc3339 import rfc3339
    ->  access on the client by:
        moment(dateString)
"""


# ==============================================================================
# simple view redirecting to index of HistoGlobe
# ==============================================================================

def index(request):
  return render(request, 'HistoGlobe_client/index.htm', {})


# ==============================================================================
# get all initial data (Hivents, Areas, Relations) from Server to Client
# quick and Dirty, but works fine for now
# ==============================================================================

def get_all(empty_request):

  response = {
    'hivents':            [],
    'areas':              [],
    'area_names':         [],
    'area_territories':   [],
    'territory_relation': []
  }

  # 1) get all hivents
  for hivent in Hivent.objects.all():
    response['hivents'].append(hivent.prepare_output())

  # 2) get all areas
  for area in Area.objects.all():
    response['areas'].append(model_to_dict(area))

  # 3) get all Areanamess
  for area_name in AreaName.objects.all():
    response['area_names'].append(model_to_dict(area_name))

  # 4) get all AreaTerritories
  for area_territory in AreaTerritory.objects.all():
    response['area_territories'].append(area_territory.prepare_output())

  # prepare and deliver everything to the client
  return HttpResponse(json.dumps(response))


# ==============================================================================
# save hivent and change to database
# return hivent and newly created area ids to client
# ==============================================================================

def save_operation(request):

  ### INIT VARIABLES ###

  # prepare output to response
  response = {
    'hivent':   {} ,   # dictionary of properties
    'historical_change_id': None,  # int
    'area_changes': [
    # {
    #   'old_id':                 int
    #   'new_id':                 int
    #   'area_id':                int
    #   'new_area_name_id':       int
    #   'new_area_territory_id':  int
    # }
    ]
  }

  # load input from request
  request_data = json.loads(request.body)

  hivent_data =             request_data['hivent']
  hivent_is_new =           request_data['hivent_is_new']
  historical_change_data =  request_data['historical_change']
  new_areas =               request_data['new_areas']
  new_area_names =          request_data['new_area_names']
  new_area_territories =    request_data['new_area_territories']


  ### PROCESS HIVENT ###

  hivent = None

  # create new hivent
  if hivent_is_new == True:
    [validated_hivent_data, error_message] = utils.validate_hivent(hivent_data)
    # error handling
    if validated_hivent_data is False: return HttpResponse(error_message)
    hivent = Hivent(
        name =            validated_hivent_data['name'],           # CharField          (max_length=150)
        date =            validated_hivent_data['date'],           # DateTimeField      (default=timezone.now)
        location =        validated_hivent_data['location'],       # CharField          (null=True, max_length=150)
        description =     validated_hivent_data['description'],    # CharField          (null=True, max_length=1000)
        link =            validated_hivent_data['link'],           # CharField          (max_length=300)
      )
    hivent.save()

  # or update existing hivent
  else:
    hivent = Hivent.objects.get(id=hivent_data['id'])
    [validated_hivent_data, error_message] = utils.validate_hivent(hivent_data)
    # error handling
    if validated_hivent_data is False: return HttpResponse(error_message)
    # update hivent
    hivent.update(validated_hivent_data)

  # add to output
  hivent_output = model_to_dict(hivent)
  hivent_output['date'] = utils.get_date_string(hivent_output['date'])
  response['hivent'] = hivent_output


  ### PROCESS HISTORICAL CHANGE ###
  [h_operation, error_message] = utils.validate_historical_operation_id(historical_change_data['operation'])
  historical_change = HistoricalChange (
      hivent =    hivent,
      operation = h_operation
    )
  historical_change.save()

  # add to output
  response['historical_change_id'] = historical_change.id


  ### PROCESS AREA CHANGES ###

  for area_change_data in historical_change_data['area_changes']:

    [operation, error_message] = utils.validate_area_operation_id(area_change_data['operation'])

    ## get Area of the AreaChange
    area = None

    # for 'ADD' changes, it is a new Area
    if operation == 'ADD':
      area = Area()
      area.save()
    # for all other changes, the Area already existed
    else:
      area = Area.objects.get(id=area_change_data['area'])


    ## get AreaName of old and new AreaChanges

    old_area_name = None
    new_area_name = None

    # for 'DEL' and 'NCH' => old AreaName
    if (operation == 'DEL') or (operation == 'NCH'):
      old_area_name = AreaName.objects.get(id=area_change_data['old_area_name'])

    # for 'ADD' and 'NCH' => new AreaName
    if (operation == 'ADD') or (operation == 'NCH'):
      # find the new AreaName
      for area_name_data in new_area_names:
        if area_name_data['id'] == area_change_data['new_area_name']:
          # validate and save it
          [area_name_data, error_message] = utils.validate_name(area_name_data)
          new_area_name = AreaName (
              area          = area,
              short_name    = area_name_data['short_name'],
              formal_name   = area_name_data['formal_name']
            )
          new_area_name.save()


    ## get AreaTerritory of old and new AreaChanges

    old_area_territory = None
    new_area_territory = None

    # for 'DEL' and 'TCH' => old AreaTerritory
    if (operation == 'DEL') or (operation == 'TCH'):
      old_area_territory = AreaTerritory.objects.get(id=area_change_data['old_area_territory'])

    # for 'ADD' and 'TCH' => new AreaTerritory
    if (operation == 'ADD') or (operation == 'TCH'):
      # find the new AreaTerritory
      for area_territory_data in new_area_territories:
        if area_territory_data['id'] == area_change_data['new_area_territory']:
          # validate and save it
          [area_territory_data, error_message] = utils.validate_territory(area_territory_data)
          new_area_territory = AreaTerritory (
              area                  = area,
              geometry              = area_territory_data['geometry'],
              representative_point  = area_territory_data['representative_point']
            )
          new_area_territory.save()

    # create new AreaChange
    area_change = AreaChange(
        historical_change =   historical_change,
        operation =           operation,
        area =                area,
        old_area_name =       old_area_name,
        new_area_name =       new_area_name,
        old_area_territory =  old_area_territory,
        new_area_territory =  new_area_territory
      )
    area_change.save()

    # AreaChange <- Area
    if operation == 'ADD':
      area.start_change = area_change
      area.save()

    elif operation == 'DEL':
      area.end_change = area_change
      area.save()

    # AreaChange <- AreaName
    if old_area_name:
      old_area_name.end_change = area_change
      old_area_name.save()

    if new_area_name:
      new_area_name.start_change = area_change
      new_area_name.save()

    # AreaChange <- AreaTerritory
    if old_area_territory:
      old_area_territory.end_change = area_change
      old_area_territory.save()

    if new_area_territory:
      new_area_territory.start_change = area_change
      new_area_territory.save()

    # add to output

    # this is so ugly... doesn't that go easier?
    new_area_name_id = None
    if new_area_name: new_area_name_id = new_area_name.id
    new_area_territory_id = None
    if new_area_territory: new_area_territory_id = new_area_territory.id

    area_change_dict = {
      'old_id':                 area_change_data['id'],
      'new_id':                 area_change.id,
      'area_id':                area.id,
      'new_area_name_id':       new_area_name_id,
      'new_area_territory_id':  new_area_territory_id
    }
    response['area_changes'].append(area_change_dict)


  ### OUTPUT ###

  return HttpResponse(json.dumps(response))  # N.B: mind the HttpResponse(function)