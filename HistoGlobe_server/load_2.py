import HistoGlobe_server
from models import *

def run(verbose=True):

  for area in Area.objects.exclude(territory_of = None):

    home_area = area.territory_of
    change = ChangeAreas.objects.get(new_area=home_area).change
    change_areas = ChangeAreas(
      change =      change,
      old_area =    None,
      new_area =    area
    )
    change_areas.save()

    print(area.short_name + " added to creation hivent of " + home_area.short_name)