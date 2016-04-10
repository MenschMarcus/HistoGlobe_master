# ==============================================================================
# Hivent represents a significant historical happening (historical event)
# An Hivent may contain changes to the countries of the world
# ==============================================================================

#------------------------------------------------------------------------------
from django.db import models
from django.utils import timezone
from django.contrib import gis
from djgeojson.fields import *


#------------------------------------------------------------------------------
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

  def __unicode__(self):
    return self.name

  class Meta:
    ordering = ['-effect_date']  # descending order (2000 -> 0 -> -2000 -> ...)
    app_label = 'HistoGlobe_server'
