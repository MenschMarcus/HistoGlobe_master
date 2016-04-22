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
      HttpResponse(json.dumps(response_data))
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

  # HARDCODE CLEANUP
  # if len(Hivent.objects.filter(name="The Creation of the Baltic Union")) == 1:
  # from HistoGlobe_server.models import *
  #   h = Hivent.objects.get(name="The Creation of the Baltic Union")
  #   h.delete()
  #   a = Area.objects.get(short_name="Baltic Union")
  #   a.delete()


  ### INIT VARIABLES ###

  # prepare output to response
  response = {
    hivent:   {} ,   # dictionary of properties
    historical_change: {
      new_id: None,  # int
      area_changes: [
      # {
      #   old_id:                 int
      #   new_id:                 int
      #   area_id:                int
      #   new_area_name_id:       int
      #   new_area_territory_id:  int
      # }
      ]
    }
  }

  # load input from request
  request_data = json.loads(request.body)

  hivent_data =             request_data['hivent']
  hivent_status =           request_data['hivent_status']
  historical_change_data =  request_data['historical_change']
  new_areas =               request_data['new_areas']
  new_area_names =          request_data['new_area_names']
  new_area_territories =    request_data['new_area_territories']


  ### PROCESS HIVENT ###

  hivent = None

  # create new hivent
  if hivent_status == 'new':
    [validated_hivent_data, error_message] = utils.validate_hivent(hivent_data)
    # error handling
    if validated_hivent_data is False: return HttpResponse(error_message)
    hivent = Hivent(
        name =            validated_hivent_data['name'],                 # CharField          (max_length=150)
        start_date =      validated_hivent_data['start_date'],           # DateTimeField      (default=date.today)
        end_date =        validated_hivent_data['end_date'],             # DateTimeField      (null=True)
        effect_date =     validated_hivent_data['effect_date'],          # DateTimeField      (default=start_date)
        secession_date =  validated_hivent_data['secession_date'],       # DateTimeField      (null=True)
        location_name =   validated_hivent_data['location_name'],        # CharField          (null=True, max_length=150)
        location_point =  validated_hivent_data['location_point'],       # PointField         (null=True)
        location_area =   validated_hivent_data['location_area'],        # MultiPolygonField  (null=True)
        description =     validated_hivent_data['description'],          # CharField          (null=True, max_length=1000)
        link_url =        validated_hivent_data['link_url'],             # CharField          (max_length=300)
        link_date =       validated_hivent_data['link_date']             # DateTimeField      (default=date.today)
      )
    hivent.save()

  # or update existing hivent
  elif hivent_status == 'upd':
    hivent = Hivent.objects.get(id=hivent_data['id'])
    [validated_hivent_data, error_message] = utils.validate_hivent(hivent_data)
    # error handling
    if validated_hivent_data is False: return HttpResponse(error_message)
    # update hivent
    hivent.update(validated_hivent_data)

  # add to output
  response['hivent'] = hivent


  ### PROCESS HISTORICAL CHANGE ###


  '''
    # init old / new area
    old_area = None
    new_area = None

    # get old/new areas for operations
    if operation == 'ADD':      #   0  ->  1
      new_area = Area.objects.get(id=new_areas[idx])

    elif operation == 'UNI':    #   2+ ->  1
      old_area = Area.objects.get(id=old_areas[idx])
      new_area = Area.objects.get(id=new_areas[0])

    elif operation == 'SEP':    #   1  ->  2+
      old_area = Area.objects.get(id=old_areas[0])
      new_area = Area.objects.get(id=new_areas[idx])

    elif operation == 'CHB':    #   2  ->  2
      old_area = Area.objects.get(id=old_areas[idx])
      new_area = Area.objects.get(id=new_areas[idx])

    elif operation == 'CHN':    #   1  ->  1  => = CHB case
      old_area = Area.objects.get(id=old_areas[idx])
      new_area = Area.objects.get(id=new_areas[idx])

    elif operation == 'DEL':    #   1  ->  0
      old_area = Area.objects.get(id=old_areas[idx])

    # update ChangeAreas <- Area
    new_change_areas.old_area = old_area
    new_change_areas.new_area = new_area
    new_change_areas.save()

    # update Area <- Hivent
    if old_area:
      old_area.end_hivent = change.hivent
      old_area.save()
    if new_area:
      new_area.start_hivent = change.hivent
      new_area.save()
  '''

  # return HttpResponse(json.dumps(response))  # N.B: mind the HttpResponse(function)