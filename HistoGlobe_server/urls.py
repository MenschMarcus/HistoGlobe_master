from django.conf.urls import url, include, patterns
from django.contrib.gis import admin
from HistoGlobe_server import views

urlpatterns = [
  url(r'^$',                    views.index,                name='index'),

  url(r'^get_initial_areas/',   views.get_initial_areas,    name="get_initial_areas"),
  url(r'^get_initial_hivents/', views.get_initial_hivents,  name="get_initial_hivents"),
  url(r'^save_operation/',      views.save_operation,       name="save_operation"),

  url(r'^admin/',               include(admin.site.urls))
]
