# ==============================================================================
# Hivent represents a significant historical happening (historical event).
# It is the only representation of the temporal dimension in the data model
# and therefore the main organisational dimension.
# An Hivent may contain one or many HistoricalChanges to the areas of the world.
#
# ------------------------------------------------------------------------------
# Hivent 1:n HistoricalChange
#
# ==============================================================================

from django.db import models
from django.utils import timezone
from django.contrib import gis
from djgeojson.fields import *
from django.forms.models import model_to_dict

import chromelogger as console



# ------------------------------------------------------------------------------
class Hivent(models.Model):

  name =            models.CharField                (max_length=150, default='')
  start_date =      models.DateTimeField            (null=True)
  end_date =        models.DateTimeField            (null=True)
  effect_date =     models.DateTimeField            (default=timezone.now)
  secession_date =  models.DateTimeField            (null=True)
  location_name =   models.CharField                (null=True, max_length=150)
  location_point =  gis.db.models.PointField        (null=True)
  location_area =   gis.db.models.MultiPolygonField (null=True)
  description =     models.CharField                (null=True, max_length=1000)
  link_url =        models.CharField                (null=True, max_length=300)
  link_date =       models.DateTimeField            (null=True, default=timezone.now)


  # ============================================================================
  def __unicode__(self):
    return self.name


  # ============================================================================
  # givent set of validated (!) hivent data, update the Hivent properties
  # ============================================================================

  def update(self, hivent_data):

    ## save in database
    self.name =            hivent_data['name']                 # CharField          (max_length=150)
    self.start_date =      hivent_data['start_date']           # DateTimeField      (default=date.today)
    self.end_date =        hivent_data['end_date']             # DateTimeField      (null=True)
    self.effect_date =     hivent_data['effect_date']          # DateTimeField      (default=start_date)
    self.secession_date =  hivent_data['secession_date']       # DateTimeField      (null=True)
    self.location_name =   hivent_data['location_name']        # CharField          (null=True, max_length=150)
    self.location_point =  hivent_data['location_point']       # PointField         (null=True)
    self.location_area =   hivent_data['location_area']        # MultiPolygonField  (null=True)
    self.description =     hivent_data['description']          # CharField          (null=True, max_length=1000)
    self.link_url =        hivent_data['link_url']             # CharField          (max_length=300)
    self.link_date =       hivent_data['link_date']            # DateTimeField      (default=date.today)

    hivent.save()

    return hivent


  # ============================================================================
  # return Hivent with all its associated
  # Changes, ChangeAreas, ChangeNames and ChangeTerritories
  # ============================================================================

  def prepare_output(self):

    from HistoGlobe_server.models import HistoricalChange, AreaChange
    from HistoGlobe_server import utils

    # get original Hivent with all properties
    # -> except for change
    hivent = model_to_dict(self)

    # get all HistoricalChanges associated to the Hivent
    hivent['historical_changes'] = []
    for historical_change_model in HistoricalChange.objects.filter(hivent=self):
      historical_change = model_to_dict(historical_change_model)

      # get all AreaChanges associated to the Hivent
      historical_change['area_changes'] = []
      for area_change_model in AreaChange.objects.filter(historical_change=historical_change_model):
        historical_change['area_changes'].append(model_to_dict(area_change_model))

      hivent['historical_changes'].append(historical_change)

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


  # ============================================================================
  class Meta:
    ordering = ['-effect_date']  # descending order (2000 -> 0 -> -2000 -> ...)
    app_label = 'HistoGlobe_server'
