"""
  This file contains all helper functions for all views that is related to
  hivents, changes and change areas
  - validate hivent
  - save hivent
  - save change + change areas
  - get complete hivent + changes + change areas by hivent id
  - get changes in between start and end date

  hivent  <-1:n->  changes  <-1:n->  change_areas = {old_area, new_area}

"""


# ==============================================================================
### INCLUDES ###

# Django
from django.forms.models import model_to_dict
import datetime

# utils
import chromelogger as console

# own
from HistoGlobe_server.models import *
from HistoGlobe_server import utils


# ==============================================================================
# receive an hivent dictionary with all properties
# validate each property based on their characteristics
# return hivent and validated? True/False
# ==============================================================================

def validate_hivent(hivent):

  ## name

  if utils.validate_string(hivent['name']) is False:
    return [False, ("The name of the Hivent is not valid")]


  ## dates

  # start date has to be valid
  if utils.validate_date(hivent['start_date']) is False:
    return [False, ("The start date of the Hivent is not valid")]
    # else: start_date is OK

  # end date can be either None or valid
  if ('end_date' in hivent) and (hivent['end_date'] is not None):
    if utils.validate_date(hivent['end_date']) is False:
      return [False, ("The end date of the Hivent is not valid")]
    # end date must be later than start date
    if utils.get_date_object(hivent['end_date']) < utils.get_date_object(hivent['start_date']):
      return [False, ("The end date of the Hivent can not be before the start date")]
    # else: end_date is OK

  else:
    hivent['end_date'] = None


  # effect date is either itself or the start date
  if ('effect_date' in hivent) and (hivent['effect_date'] is not None):
    if utils.validate_date(hivent['effect_date']) is False:
      return [False, ("The effect date of the Hivent is not valid")]
    # else: effect_date is OK

  else:
    hivent['effect_date'] = hivent['start_date']


  # end date can be either None or valid
  if ('secession_date' in hivent) and (hivent['secession_date'] is not None):
    if utils.validate_date(hivent['secession_date']) is False:
      return [False, ("The secession date of the Hivent is not valid")]
    # secession date must be later than the effect date
    if utils.get_date_object(hivent['secession_date']) < utils.get_date_object(hivent['effect_date']):
      return [False, ("The secession date of the Hivent can not be before the effect date")]
    # else: secession_date is OK

  else:
    hivent['secession_date'] = None


  ## location

  # location name can be either a string or None
  if 'location_name' in hivent:
    if utils.validate_string(hivent['location_name']) is False:
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
    if utils.validate_string(hivent['description']) is False:
      return [False, ('The description you were giving to the Hivent is not valid')]
    # else: description is ok

  else:
    hivent['description'] = None


  ## link
  # link can be either a valid URL or None
  if 'link_url' in hivent:
    if utils.validate_url(hivent['link_url']) is False:
      return [False, ('The link you were giving to the Hivent is not valid')]

    # link_url is OK, link_date is set to today (= just checked)
    hivent['link_date'] = utils.get_date_string(datetime.date.today())

  else:
    hivent['link_url'] = None
    hivent['link_date'] = None

  # everything is fine => return hivent
  return [hivent, None]


# ==============================================================================
# receive an hivent dictionary with all properties
# save Hivent into database and return
# ==============================================================================

def save_hivent(hivent):

  ## save in database
  new_hivent = Hivent(
      name =            hivent['name'],                 # CharField          (max_length=150)
      start_date =      hivent['start_date'],           # DateTimeField      (default=date.today)
      end_date =        hivent['end_date'],             # DateTimeField      (null=True)
      effect_date =     hivent['effect_date'],          # DateTimeField      (default=start_date)
      secession_date =  hivent['secession_date'],       # DateTimeField      (null=True)
      location_name =   hivent['location_name'],        # CharField          (null=True, max_length=150)
      location_point =  hivent['location_point'],       # PointField         (null=True)
      location_area =   hivent['location_area'],        # MultiPolygonField  (null=True)
      description =     hivent['description'],          # CharField          (null=True, max_length=1000)
      link_url =        hivent['link_url'],             # CharField          (max_length=300)
      link_date =       hivent['link_date']             # DateTimeField      (default=date.today)
    )
  new_hivent.save()

  return new_hivent


# ==============================================================================
# receive an hivent and an operation
# save Change into database and return
# ==============================================================================

def save_change(hivent, operation):
  new_change = Change(
      hivent =          hivent,       # models.ForeignKey   (Hivent)
      operation =       operation     # models.CharField    (max_length=3)
    )
  new_change.save()

  return new_change


# ==============================================================================
# receive a change, an operation and a set of old and new areas
# save ChangeAreas into database and return
# ==============================================================================

def save_change_areas(change, operation, old_areas, new_areas):

  # output: area models
  old_area_models = []
  new_area_models = []

  # depending on the kind of operation, there are differently many old/new areas
  num_changes = max(len(old_areas), len(new_areas))
  idx = 0
  while idx < num_changes:

    # initital entry (for all operations)
    new_change_areas = ChangeAreas(
        change =        change,   # models.ForeignKey   (Change, related_name='change')
        old_area =      None,     # models.ForeignKey   (Area, related_name='old_area')
        new_area =      None      # models.ForeignKey   (Area, related_name='new_area')
      )

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
    old_area.end_hivent = change.hivent
    old_area.save()
    new_area.start_hivent = change.hivent
    new_area.save()

    # go to next change area pair
    idx += 1


# ==============================================================================
# return all hivents that are not in the list of existing_hivents
# ==============================================================================

def get_rest_hivents(existing_hivents):
  hivent_models = Hivent.objects.exclude(id__in=existing_hivents)

  hivents = []
  for hivent_model in hivent_models:
    hivents.append(prepare_hivent(hivent_model))

  return hivents


# ==============================================================================
# return Hivent with all its associated
# Changes, ChangeAreas, ChangeNames and ChangeTerritories
# ==============================================================================

def prepare_hivent(hivent_model):

  # get original Hivent with all properties
  # -> except for change
  hivent = model_to_dict(hivent_model)

  # get all Changes associated to the Hivent
  changes = []
  for change_model in Change.objects.filter(hivent=hivent_model):
    change = model_to_dict(change_model)

    # get all ChangeAreas associated to the Change
    change['change_areas'] = []
    for change_areas_model in ChangeAreas.objects.filter(change=change_model):
      change_area = model_to_dict(change_areas_model)
      change['change_areas'].append(change_area)

    # get all ChangeAreaNames associated to the Change
    change['change_area_names'] = []
    for change_area_names_model in ChangeAreaNames.objects.filter(change=change_model):
      change_area_names = model_to_dict(change_area_names_model)
      change['change_area_names'].append(change_area_names)

    # get all ChangeAreaTerritories associated to the Change
    change['change_area_territories'] = []
    for change_area_territories_model in ChangeAreaTerritories.objects.filter(change=change_model):
      change_area_territories = model_to_dict(change_area_territories_model)
      change['change_area_territories'].append(change_area_territories)

    changes.append(change)
  hivent['changes'] = changes

  # prepare dates for output
  hivent['start_date'] =        utils.get_date_string(hivent['start_date'])
  if hivent['end_date'] != None:
    hivent['end_date'] =        utils.get_date_string(hivent['start_date'])
  hivent['effect_date'] =       utils.get_date_string(hivent['effect_date'])
  if hivent['secession_date'] != None:
    hivent['secession_date'] =  utils.get_date_string(hivent['effect_date'])
  if hivent['link_date'] != None:
    hivent['link_date'] =       utils.get_date_string(timezone.now())

  return hivent


# ==============================================================================
# return all Changes that lie in between a start_ and an end_date
# ==============================================================================

def get_changes(start_date, end_date):

  change_direction = 1   # +1 (forward) or -1 (backward)
  if start_date > end_date:
    change_direction = -1
    # backward direction:
    # swap old and new date, so it can be assumed that always oldDate < newDate
    temp_date = end_date
    end_date = start_date
    start_date = temp_date
    temp_date = None # = delete

  # stores all changes in between
  changes = []
  console.log(start_date, end_date)

  for hivent in Hivent.objects.all():
    # N.B. > and <= !
    if (hivent.effect_date > start_date) and (hivent.effect_date <= start_date):
      change = Change.objects.get(hivent=hivent)
      changes.append(change)

  return changes