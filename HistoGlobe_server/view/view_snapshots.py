# ==============================================================================
### INCLUDES ###

# Django

# own
import utils
from HistoGlobe_server.models import Snapshot



# ==============================================================================
def get_closest_snapshot(now_date):

  current_snapshot = Snapshot.objects.first()
  current_snapshot_distance = current_snapshot.date - now_date

  for this_snapshot in Snapshot.objects.all():
    this_snaphot_distance = this_snapshot.date - now_date
    if this_snaphot_distance < current_snapshot_distance:
      current_snapshot = this_snapshot
      current_snapshot_distance = this_snaphot_distance

  return current_snapshot


