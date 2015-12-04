from django.conf.urls import url, include, patterns
from django.contrib.gis import admin
from HistoGlobe_server import views

urlpatterns = patterns('',
  url(r'^$', views.index, name='index'),
  url(r'^get_countries/', views.get_countries, name="get_categories"),

  url(r'^admin/', include(admin.site.urls)),
)
