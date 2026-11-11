extends RefCounted
## Shared read-only clip sampling for the editor's JSON and the playable battle.
var keys:Array=[]
var events:Array=[]
var length:=2.4

func read_file(path: String) -> bool:
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:return false
 var data:Variant=JSON.parse_string(file.get_as_text())
 if not data is Dictionary or data.get("version")!=1:return false
 if not data.get("keys") is Array or data["keys"].size()<2:return false
 if not data.get("events") is Array:return false
 var duration:Variant=data.get("length",2.4)
 if not duration is float and not duration is int:return false
 if not is_finite(duration) or duration<=0 or duration>60:return false
 for k in data["keys"]:
  if not k is Dictionary or not k.get("pose") is String:return false
  for field in ["t","x","y","rotation","scale","zoom"]:
   var value:Variant=k.get(field)
   if not value is float and not value is int:return false
   if not is_finite(value):return false
  if k.t<0 or k.t>duration or k.scale<=0 or k.zoom<=0:return false
 keys=data["keys"].duplicate(true);events=data["events"].duplicate(true);length=duration
 keys.sort_custom(func(a,b):return a.t<b.t)
 return true

func sample(time_value: float) -> Dictionary:
 if keys.is_empty():return {}
 var a:Dictionary=keys[0];var b:Dictionary=keys[-1]
 for k in keys:
  if k.t<=time_value:a=k
  else:
   b=k
   break
 var u:float=clampf((time_value-a.t)/maxf(0.001,b.t-a.t),0,1)
 if a.get("ease")=="smooth":u=u*u*(3-2*u)
 if a.get("ease")=="snap":u=0
 var out:Dictionary={"pose":a.pose}
 for field in ["x","y","rotation","scale","zoom"]:out[field]=lerpf(a[field],b[field],u)
 return out
