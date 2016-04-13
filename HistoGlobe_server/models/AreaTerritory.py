# ==============================================================================
# AreaTerritory stores the spatial dimension of an Area.
#
# ------------------------------------------------------------------------------
# AreaTerritory n:1 Area
#
# ------------------------------------------------------------------------------
#
# TODO: calculate reasonable name position with intelligent algorithm
# ==============================================================================

from django.db import models
from django.contrib import gis
from djgeojson.fields import *

#------------------------------------------------------------------------------
class AreaTerritory(models.Model):
  area =                  models.ForeignKey               ('Area',   related_name='territory_area', default='0')
  start_change =          models.ForeignKey               ('AreaChange', related_name='territory_start_change', null=True)
  end_change =            models.ForeignKey               ('AreaChange', related_name='territory_end_change', null=True)
  geometry =              gis.db.models.MultiPolygonField (default='MULTIPOLYGON EMPTY')
  representative_point =  gis.db.models.PointField        (null=True)

  # overriding the default manager with a GeoManager instance.
  # didn't quite understand what this is for...
  objects =               gis.db.models.GeoManager        ()

  def __unicode__(self):
    return str(self.id)

  class Meta:
    app_label = 'HistoGlobe_server'