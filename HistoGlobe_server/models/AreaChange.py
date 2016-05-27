# ==============================================================================
# An AreaChange is one explicit Historical Geographic Operation (HGOp)
# that actually changes the Areas and their AreaNames and AreaTerritorires on
# the map. Each AreaChange is part of exactly one HistoricalChange
# To this AreaChange will be referenced:
#   - A set of old Areas, AreaNames and AreaTerritories that are deleted
#   - A set of new Areas, AreaNames and AreaTerritories that are created
#
# ------------------------------------------------------------------------------
# AreaChange n:1 HistoricalChange
# AreaChange 1:n OldArea
# AreaChange 1:n NewArea
# AreaChange 1:1 UpdateArea
#
# ------------------------------------------------------------------------------
# Historical Geographic Operations
#
#      UNI             INC             SEP             SEC             NCH
#  Unification    Incorporation     Separation      Secession       Name Change
#
# Ai ---|         A0 ---O--- A0         |--- Bi   A0 ---O--- A0   A0 ---O--- A0
# ..    O--- B1   Ai ---|         A1 ---O    ..         |--- Bi
# An ---|         An ---|               |--- Bn         |--- Bn
# ==============================================================================


from django.db import models
from django.forms.models import model_to_dict

# ==============================================================================
class AreaChange(models.Model):

  # superordinate: HistoricalChange
  historical_change   = models.ForeignKey ('HistoricalChange', related_name='historical_change', default=0)

  # own attribute
  hg_operation        = models.CharField  (default='XXX', max_length=3)

  # ----------------------------------------------------------------------------
  def __unicode__(self):
    return self.operation

  # ----------------------------------------------------------------------------
  class Meta:
    app_label = 'HistoGlobe_server'