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


# ------------------------------------------------------------------------------
class Hivent(models.Model):

  name =            models.CharField                (max_length=150, default='')
  date =            models.DateTimeField            (default=timezone.now)
  location =        models.CharField                (null=True, max_length=150)
  description =     models.CharField                (null=True, max_length=1000)
  link =            models.CharField                (null=True, max_length=300)


  # ============================================================================
  def __unicode__(self):
    return self.name


  # ============================================================================
  # givent set of validated (!) hivent data, update the Hivent properties
  # ============================================================================

  def update(self, hivent_data):

    ## save in database
    self.name =             hivent_data['name']                 # CharField          (max_length=150)
    self.date =             hivent_data['date']                 # DateTimeField      (default=timezone.now)
    self.location =         hivent_data['location']             # CharField          (null=True, max_length=150)
    self.description =      hivent_data['description']          # CharField          (null=True, max_length=1000)
    self.link =             hivent_data['link']                 # CharField          (max_length=300)

    hivent.save()

    return hivent


  # ============================================================================
  # return Hivent with all its associated
  # Changes, ChangeAreas, ChangeNames and ChangeTerritories
  # ============================================================================

  def prepare_output(self):

    from HistoGlobe_server.models import HistoricalChange, AreaChange, OldArea, NewArea, UpdateArea
    from HistoGlobe_server import utils
    import chromelogger as console


    # get original Hivent with all properties
    # -> except for change
    hivent = model_to_dict(self)

    # get all HistoricalChanges associated to the Hivent
    hivent['historical_changes'] = []
    for historical_change_model in HistoricalChange.objects.filter(hivent=self):
      historical_change = model_to_dict(historical_change_model)

      # get all AreaChanges associated to the HistoricalChange
      historical_change['area_changes'] = []
      for area_change_model in AreaChange.objects.filter(historical_change=historical_change_model):
        area_change = model_to_dict(area_change_model)

        # get all OldAreas, NewAreas and UpdateArea associated to the AreaChange
        area_change['old_areas'] = []
        area_change['new_areas'] = []
        area_change['update_area'] = None
        for old_area_model in OldArea.objects.filter(area_change=area_change_model):
          area_change['old_areas'].append(model_to_dict(old_area_model))
        for new_area_model in NewArea.objects.filter(area_change=area_change_model):
          area_change['new_areas'].append(model_to_dict(new_area_model))
        for update_area_model in UpdateArea.objects.filter(area_change=area_change_model):
          area_change['update_area'] = model_to_dict(update_area_model)

        historical_change['area_changes'].append(area_change)
      hivent['historical_changes'].append(historical_change)

    # prepare date for output
    hivent['date'] = utils.get_date_string(hivent['date'])

    return hivent


  # ============================================================================
  class Meta:
    ordering = ['-date']  # descending order (2000 -> 0 -> -2000 -> ...)
    app_label = 'HistoGlobe_server'
