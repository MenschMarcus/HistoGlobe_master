@echo off
rem set PROJECT=sdw
rem set PROJECT=teaser1_countries
rem set PROJECT=teaser2_hivents
rem set PROJECT=teaser3_sidebar
set PROJECT=full

call "C:\Program Files\nodejs\nodevars.bat"

IF not exist build ( mkdir build )

for /R script\ %%a in (*.coffee) do (
	 start /b /REALTIME call coffee -c -o build "%%a"
)

rosetta --jsOut "build/default_config.js" ^
        --jsFormat "flat" ^
        --jsTemplate "var HGConfig;(function() {<%%= preamble %%>HGConfig = <%%= blob %%>;})();" ^
        --cssOut "build/default_config.less" ^
        --cssFormat "less" config/common/default.rose && ^
rosetta --jsOut "build/config.js" ^
        --jsFormat "flat" ^
        --jsTemplate "(function() {<%%= preamble %%> $.extend(HGConfig, <%%= blob %%>);})();" ^
        --cssOut "build/config.less" ^
        --cssFormat "less" config/%PROJECT%/style.rose && ^
lessc --no-color -x config\%PROJECT%\main.less style\histoglobe.min.css && ^
call utils\replace_line.bat config.php 1 "<?php $config_path = '%PROJECT%'; ?>"
