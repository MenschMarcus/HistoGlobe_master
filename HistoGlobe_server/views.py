from django.http import HttpResponse
from django.shortcuts import render
from django.contrib.gis.geos import *
from djgeojson.serializers import Serializer as GeoJSONSerializer
from HistoGlobe_server.models import *

# dictionary passed to each template engine as its context.
context_dict = {}

# simple index view redirecting to index of HistoGlobe
def index(request):
  return render(request, 'HistoGlobe_client/index.htm', context_dict)

# send country data back to user
def get_countries(request):
  countries = WorldBorder.objects.all()
  # countries = WorldBorder.objects.filter(name='France')
  out = GeoJSONSerializer().serialize(countries, use_natural_keys=True, with_modelname=False)

  # for country in countries:
  return HttpResponse(out)

'''
  # for some fucking reason that does not work
  # -> geometry is always 'null'
  # c = serialize('geojson',
  #   obj,
  #   geometry_field='geom',
  #   fields=('name',)
  # )
'''
