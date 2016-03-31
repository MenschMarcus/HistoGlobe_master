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
import utils
from HistoGlobe_server.models import Hivent, Change, ChangeAreas, Area


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


# ------------------------------------------------------------------------------
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


# ------------------------------------------------------------------------------
def save_change(hivent, operation):
  new_change = Change(
      hivent =          hivent,   # models.ForeignKey   (Hivent)
      operation =       operation     # models.CharField   (max_length=3)
    )
  new_change.save()

  return new_change


# ------------------------------------------------------------------------------
def save_change_areas(change, operation, old_areas, new_areas):

  # depending on the kind of operation, there are differently many old/new areas
  num_changes = max(len(old_areas), len(new_areas))
  idx = 0
  while idx < num_changes:

    # initital entry (for all operations)
    new_change_areas = ChangeAreas(
        change =        change,   # models.ForeignKey   (Change, related_name='change')
        old_area =      None,         # models.ForeignKey   (Area, related_name='old_area')
        new_area =      None          # models.ForeignKey   (Area, related_name='new_area')
      )

    # special treatment of old/new areas (for operations)
    if operation == 'ADD':      #   0  ->  1
      new_change_areas.new_area = Area.objects.get(id=new_areas[idx])

    elif operation == 'UNI':    #   2+ ->  1
      new_change_areas.old_area = Area.objects.get(id=old_areas[idx])
      new_change_areas.new_area = Area.objects.get(id=new_areas[0])

    elif operation == 'SEP':    #   1  ->  2+
      new_change_areas.old_area = Area.objects.get(id=old_areas[0])
      new_change_areas.new_area = Area.objects.get(id=new_areas[idx])

    elif operation == 'CHB':    #   2  ->  2
      new_change_areas.old_area = Area.objects.get(id=old_areas[idx])
      new_change_areas.new_area = Area.objects.get(id=new_areas[idx])

    elif operation == 'CHN':    #   1  ->  1  => = CHB case
      new_change_areas.old_area = Area.objects.get(id=old_areas[idx])
      new_change_areas.new_area = Area.objects.get(id=new_areas[idx])

    elif operation == 'DEL':    #   1  ->  0
      new_change_areas.old_area = Area.objects.get(id=old_areas[idx])


    # go to next change area pair
    new_change_areas.save()
    idx += 1



# ------------------------------------------------------------------------------
def get_all_hivents():
  hivent_models = Hivent.objects.all()

  hivents = []
  for hivent_model in hivent_models:
    hivents.append(prepare_hivent(hivent_model))

  return hivents

# ------------------------------------------------------------------------------
def get_hivent(hivent_id):

  # N.B: Model.objects.filter() does not return exact match
  # => need to use .get()
  return prepare_hivent(Hivent.objects.get(id=hivent_id))


# ------------------------------------------------------------------------------
def prepare_hivent(hivent_model):

  hivent = model_to_dict(hivent_model)
  changes = []
  for change_model in Change.objects.filter(hivent=hivent_model):
    change = model_to_dict(change_model)
    change['change_areas'] = []
    for change_area_model in ChangeAreas.objects.filter(change=change_model):
      change_area = model_to_dict(change_area_model)
      change['change_areas'].append(change_area)
    changes.append(change)
  hivent['changes'] = changes

  # prepare dates for output
  hivent['start_date'] =        utils.get_date_string(hivent['start_date'])
  if hivent['end_date'] != None:
    hivent['end_date'] =        utils.get_date_string(hivent['end_date'])
  hivent['effect_date'] =       utils.get_date_string(hivent['effect_date'])
  if hivent['secession_date'] != None:
    hivent['secession_date'] =  utils.get_date_string(hivent['secession_date'])
  if hivent['link_date'] != None:
    hivent['link_date'] =         utils.get_date_string(hivent['link_date'])

  return hivent


# ------------------------------------------------------------------------------
def get_changes(start_date, end_date):

  for hivent in Hivent.objects.all():
    if (hivent.effect_date >= start_date) and (hivent.effect_date < start_date):
      print("Horst")

  return []
