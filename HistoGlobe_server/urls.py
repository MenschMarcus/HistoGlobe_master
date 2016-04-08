from django.conf.urls import url, include, patterns
from django.contrib.gis import admin
from HistoGlobe_server import views

urlpatterns = [
  url(r'^$',                    views.index,                name='index'),

  url(r'^get_init_area_ids/',   views.get_init_area_ids,    name="get_init_area_ids"),
  url(r'^get_init_areas/',      views.get_init_areas,       name="get_init_areas"),
  url(r'^get_rest_hivents/',    views.get_rest_hivents,     name="get_rest_hivents"),
  url(r'^save_operation/',      views.save_operation,       name="save_operation"),

  url(r'^admin/',               include(admin.site.urls))
]
