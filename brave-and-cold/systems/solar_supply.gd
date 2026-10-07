class_name SolarSupply
extends RefCounted
## Local DC source. Calendar daylight matches the existing 06:00–18:00 sun.
## Gameplay energy model, not a geographic photovoltaic forecast.
const RATED_W := 120.0
const EFFICIENCY := .78
const SNOW_PER_PRECIP_H := .03
var enabled := false
var controller_ok := true
var snow_cover := 0.0

func weather_factor(overcast: float) -> float:
	return (1.0-.94*clampf(overcast,0,1))*pow(1.0-snow_cover,2)

func watts(absolute_game_s: float, overcast: float) -> float:
	if not enabled or not controller_ok:return 0
	var hour:=fposmod(absolute_game_s/3600,24)
	if hour<=6 or hour>=18:return 0
	return RATED_W*EFFICIENCY*weather_factor(overcast)*sin(PI*(hour-6)/12)

func _daylight_integral(absolute_game_s: float) -> float:
	var h:=absolute_game_s/3600
	var days:=floorf(h/24)
	var phase:=clampf(fposmod(h,24)-6,0,12)
	return days*24/PI+12/PI*(1-cos(PI*phase/12))

func energy_wh(from_s: float, to_s: float, calendar_origin_s: float, overcast: float) -> float:
	if not enabled or not controller_ok or to_s<=from_s:return 0
	return maxf(0,_daylight_integral(to_s+calendar_origin_s)-_daylight_integral(from_s+calendar_origin_s))*RATED_W*EFFICIENCY*weather_factor(overcast)

func accumulate_snow(game_s: float, precipitation: float) -> void:
	snow_cover=clampf(snow_cover+maxf(0,game_s)/3600*clampf(precipitation,0,1)*SNOW_PER_PRECIP_H,0,1)

func clear_snow() -> void:snow_cover=0
func to_dict() -> Dictionary:return {"enabled":enabled,"controller_ok":controller_ok,"snow_cover":snow_cover}
func restore(d: Dictionary, legacy_site := false) -> void:
	enabled=bool(d.get("enabled",legacy_site))
	controller_ok=bool(d.get("controller_ok",true))
	snow_cover=clampf(float(d.get("snow_cover",0)),0,1)
