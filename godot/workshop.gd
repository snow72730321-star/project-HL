extends Node3D

const LENGTH := 2.4
var keys: Array = [
 {"t":0.0,"x":-3.0,"y":0.0,"rotation":0.0,"scale":1.0,"pose":"idle","zoom":7.8},
 {"t":0.45,"x":-3.3,"y":0.0,"rotation":-8.0,"scale":1.0,"pose":"windup","zoom":7.2},
 {"t":0.68,"x":0.8,"y":0.15,"rotation":12.0,"scale":1.08,"pose":"strike","zoom":6.2},
 {"t":1.0,"x":1.0,"y":0.0,"rotation":0.0,"scale":1.0,"pose":"strike","zoom":6.4},
 {"t":1.6,"x":-1.0,"y":0.0,"rotation":0.0,"scale":1.0,"pose":"idle","zoom":7.2},
 {"t":2.4,"x":-3.0,"y":0.0,"rotation":0.0,"scale":1.0,"pose":"idle","zoom":7.8}]
var events: Array = [{"t":0.7,"kind":"hit","duration":0.28,"freeze":0.09,"damage":12}]
var actor: Sprite3D
var enemy: Sprite3D
var camera: Camera3D
var effect: MeshInstance3D
var clock := 0.0
var playing := false
var freeze := 0.0
var speed := 1.0
var hp := 100
var battle := false
var fired: Dictionary = {}
var selected := 0
var timeline: HSlider
var key_list: ItemList
var fields: Dictionary = {}
var pose_field: LineEdit
var status: Label
var health: Label
var info: Label
var event_time: SpinBox
var event_damage: SpinBox
var event_freeze: SpinBox
var syncing := false
var textures: Dictionary = {}
var event_list: ItemList
var event_duration: SpinBox
var event_angle: SpinBox
var event_size: SpinBox
var event_color: ColorPickerButton
var clip_name: LineEdit
var easing: OptionButton
var effect_material: StandardMaterial3D
var trail: MeshInstance3D
var flash: ColorRect
var impact_label: Label
var selected_event := 0
var damage_multiplier := 1.0

func _ready() -> void:
 _stage()
 _ui()
 _refresh_list()
 _select(0)
 _sample(0.0)
 if "--smoke" in OS.get_cmdline_user_args():
  _smoke()

func _stage() -> void:
 camera = Camera3D.new()
 camera.position = Vector3(0,4,12)
 camera.look_at_from_position(camera.position,Vector3(0,1,0))
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 7.8
 camera.v_offset = -0.8
 add_child(camera)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-50,-30,0)
 add_child(light)
 var ground := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2(40,24)
 ground.mesh = plane
 var mat := StandardMaterial3D.new()
 mat.albedo_color = Color("23343b")
 ground.material_override = mat
 add_child(ground)
 for i in range(-8,9):
  var marker := MeshInstance3D.new()
  var box := BoxMesh.new()
  box.size = Vector3(0.025,0.012,20)
  marker.mesh = box
  marker.position.x = i * 2
  add_child(marker)
 for i in range(9):
  var pillar := MeshInstance3D.new()
  var box := BoxMesh.new()
  box.size = Vector3(0.7,3.5 + (i % 3),0.8)
  pillar.mesh = box
  pillar.position = Vector3((i-4)*3,box.size.y/2,-5)
  add_child(pillar)
 actor = _sprite("idle")
 enemy = _sprite("guard")
 enemy.position = Vector3(2.3,1.05,0)
 enemy.modulate = Color.WHITE
 enemy.flip_h = false
 effect = MeshInstance3D.new()
 var quad := QuadMesh.new()
 quad.size = Vector2(3.2,0.16)
 effect.mesh = quad
 var fxmat := StandardMaterial3D.new()
 fxmat.cull_mode=BaseMaterial3D.CULL_DISABLED
 fxmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 fxmat.albedo_color = Color("ffe1a1")
 effect.material_override = fxmat
 effect_material=fxmat
 trail=MeshInstance3D.new()
 trail.material_override=fxmat
 add_child(trail)
 effect.position = Vector3(1.6,1.25,0.4)
 effect.rotation_degrees.z = 24
 effect.visible = false
 add_child(effect)

func _texture(pose: String) -> Texture2D:
 var aliases: Dictionary={"idle":"hero_idle","windup":"hero_windup","strike":"hero_strike","guard":"enemy_idle","hurt":"enemy_hurt"}
 if aliases.has(pose): return load("res://assets/extracted/"+aliases[pose]+".png")
 var path := pose if pose.begins_with("res://") or pose.begins_with("user://") else "res://assets/" + pose + ".svg"
 if not textures.has(path):
  if ResourceLoader.exists(path):
   textures[path] = load(path)
  elif FileAccess.file_exists(path):
   var img := Image.load_from_file(path)
   if not img.is_empty(): textures[path] = ImageTexture.create_from_image(img)
 return textures.get(path,load("res://assets/idle.svg"))

func _sprite(pose: String) -> Sprite3D:
 var s := Sprite3D.new()
 s.texture = _texture(pose)
 s.pixel_size = 0.006
 s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 s.no_depth_test = false
 add_child(s)
 return s

func _ui() -> void:
 var layer := CanvasLayer.new()
 add_child(layer)
 var theme:=Theme.new()
 theme.default_font_size=16
 var background:=StyleBoxFlat.new()
 background.bg_color=Color("101922")
 background.content_margin_left=12; background.content_margin_right=12
 background.content_margin_top=10; background.content_margin_bottom=10
 theme.set_stylebox("panel","PanelContainer",background)
 var normal:=StyleBoxFlat.new()
 normal.bg_color=Color("263746")
 normal.content_margin_left=10; normal.content_margin_right=10
 normal.content_margin_top=8; normal.content_margin_bottom=8
 theme.set_stylebox("normal","Button",normal)
 var hover: StyleBoxFlat=normal.duplicate()
 hover.bg_color=Color("58616a")
 theme.set_stylebox("hover","Button",hover)
 theme.set_color("font_color","Button",Color("f1d6a0"))
 var root := VBoxContainer.new()
 root.theme=theme
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.add_theme_constant_override("separation",8)
 layer.add_child(root)
 flash=ColorRect.new()
 flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 flash.color=Color(1,0.8,0.45,0)
 flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
 layer.add_child(flash)
 impact_label=Label.new()
 impact_label.position=Vector2(930,300)
 impact_label.add_theme_font_size_override("font_size",48)
 impact_label.add_theme_color_override("font_color",Color("ffe1a1"))
 layer.add_child(impact_label)
 var title := Label.new()
 title.text = "  HL / COMBAT WORKSHOP                                      MOTION • CAMERA • IMPACT"
 title.add_theme_font_size_override("font_size",24)
 root.add_child(title)
 info = Label.new()
 info.text = "  Video-extracted screen cutouts · Motion editing / return to battle at bottom"
 root.add_child(info)
 var spacer := Control.new()
 spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
 spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
 root.add_child(spacer)
 health = Label.new()
 health.text = "  PROTAGONIST 100 HP                         TARGET 100 HP"
 root.add_child(health)
 var panel := PanelContainer.new()
 root.add_child(panel)
 var body := VBoxContainer.new()
 panel.add_child(body)
 var combat := HBoxContainer.new()
 body.add_child(combat)
 _button(combat,"BACK TO BATTLE",func():get_tree().change_scene_to_file("res://game.tscn"))
 _button(combat,"01 / CUT",func(): _attack(12,0.7))
 _button(combat,"02 / HEAVY",func(): _attack(24,0.8))
 _button(combat,"03 / QUICK",func(): _attack(8,0.55))
 _button(combat,"RESET TARGET",func(): hp=100; health.text="  PROTAGONIST 100 HP                         TARGET 100 HP")
 _button(combat,"PREVIEW",func(): _play(false))
 _button(combat,"PAUSE",func(): playing=false)
 _button(combat,"SAVE JSON",_save)
 _button(combat,"LOAD JSON",_load_motion)
 clip_name=LineEdit.new()
 clip_name.text="motion"
 clip_name.custom_minimum_size.x=130
 combat.add_child(clip_name)
 var speeds := OptionButton.new()
 for s in ["0.25×","0.5×","1×"]: speeds.add_item(s)
 speeds.select(2)
 speeds.item_selected.connect(func(i): speed=[0.25,0.5,1.0][i])
 combat.add_child(speeds)
 timeline = HSlider.new()
 timeline.min_value=0
 timeline.max_value=LENGTH
 timeline.step=0.005
 timeline.value_changed.connect(func(v):
  if not syncing:
   playing=false
   clock=v
   _sample(v))
 body.add_child(timeline)
 var row := HBoxContainer.new()
 body.add_child(row)
 key_list=ItemList.new()
 key_list.custom_minimum_size=Vector2(220,135)
 key_list.item_selected.connect(_select)
 row.add_child(key_list)
 var editor := VBoxContainer.new()
 row.add_child(editor)
 var numbers := HBoxContainer.new()
 editor.add_child(numbers)
 for spec in [["t",0.0,LENGTH,0.01],["x",-8.0,8.0,0.05],["y",-2.0,5.0,0.05],["rotation",-180.0,180.0,1.0],["scale",0.1,3.0,0.05],["zoom",3.0,12.0,0.1]]:
  var col := VBoxContainer.new()
  numbers.add_child(col)
  var label := Label.new()
  label.text=spec[0]
  col.add_child(label)
  var spin := SpinBox.new()
  spin.min_value=spec[1]; spin.max_value=spec[2]; spin.step=spec[3]
  spin.custom_minimum_size.x=105
  col.add_child(spin)
  fields[spec[0]]=spin
 easing=OptionButton.new()
 for mode in ["linear","smooth","snap"]: easing.add_item(mode)
 numbers.add_child(easing)
 pose_field=LineEdit.new()
 pose_field.placeholder_text="idle / windup / strike / hurt / guard / res://custom.png"
 editor.add_child(pose_field)
 var actions := HBoxContainer.new()
 editor.add_child(actions)
 _button(actions,"APPLY KEY",_apply_key)
 _button(actions,"ADD AT PLAYHEAD",_add_key)
 _button(actions,"DELETE KEY",_delete_key)
 var event_row := HBoxContainer.new()
 editor.add_child(event_row)
 for text_value in ["Impact time", "Damage", "Hit stop (s)"]:
  var label := Label.new(); label.text=text_value; event_row.add_child(label)
  var spin := SpinBox.new(); spin.step=0.01; spin.max_value=100
  event_row.add_child(spin)
  match text_value:
   "Impact time": event_time=spin; spin.max_value=LENGTH; spin.value=0.7
   "Damage": event_damage=spin; spin.value=12
   _: event_freeze=spin; spin.max_value=0.5; spin.value=0.09
 var fxrow:=HBoxContainer.new()
 editor.add_child(fxrow)
 event_list=ItemList.new()
 event_list.custom_minimum_size=Vector2(180,60)
 event_list.item_selected.connect(_select_event)
 fxrow.add_child(event_list)
 for label_text in ["Duration","Angle","Size"]:
  var col:=VBoxContainer.new()
  fxrow.add_child(col)
  var label:=Label.new(); label.text=label_text; col.add_child(label)
  var spin:=SpinBox.new(); spin.step=0.01; spin.max_value=10; col.add_child(spin)
  match label_text:
   "Duration": event_duration=spin; spin.min_value=0.01; spin.value=0.28
   "Angle": event_angle=spin; spin.min_value=-180; spin.max_value=180; spin.value=24
   _: event_size=spin; spin.min_value=0.1; spin.value=1
 event_color=ColorPickerButton.new()
 event_color.color=Color("ffe1a1")
 event_color.custom_minimum_size=Vector2(60,30)
 fxrow.add_child(event_color)
 _button(fxrow,"APPLY FX",_apply_event)
 _button(fxrow,"ADD FX",func():
  events.append({"t":clock,"duration":0.28,"freeze":0.09,"damage":12})
  _refresh_events(); _select_event(events.size()-1))
 _button(fxrow,"DELETE FX",func():
  if events.is_empty(): return
  events.remove_at(selected_event)
  _refresh_events()
  if not events.is_empty(): _select_event(mini(selected_event,events.size()-1)))
 _refresh_events()
 _select_event(0)
 status=Label.new()
 status.text="  Select a key → edit → Apply. Scrub to inspect. JSON: user://motion.json"
 body.add_child(status)

func _button(parent: Node, text_value: String, action: Callable) -> void:
 var b := Button.new()
 b.text=text_value
 b.pressed.connect(action)
 parent.add_child(b)

func _refresh_list() -> void:
 key_list.clear()
 for key in keys: key_list.add_item("%.2fs   %s" % [key.t,key.pose])

func _select(index: int) -> void:
 selected=index
 for field in fields: fields[field].value=keys[index][field]
 pose_field.text=keys[index].pose
 easing.select(["linear","smooth","snap"].find(keys[index].get("ease","linear")))
 key_list.select(index)

func _apply_key() -> void:
 playing=false
 var k: Dictionary={"pose":pose_field.text,"ease":easing.get_item_text(easing.selected)}
 for field in fields: k[field]=fields[field].value
 keys[selected]=k
 keys.sort_custom(func(a,b): return a.t<b.t)
 selected=keys.find(k)
 _refresh_list(); _select(selected)
 clock=k.t; _sample(clock)

func _add_key() -> void:
 var k: Dictionary=keys[selected].duplicate(true)
 k.t=clock
 keys.append(k)
 keys.sort_custom(func(a,b): return a.t<b.t)
 _refresh_list(); _select(keys.find(k))

func _delete_key() -> void:
 if keys.size()<=2: return
 keys.remove_at(selected)
 _refresh_list(); _select(mini(selected,keys.size()-1))
 _sample(clock)

func _sample(t: float) -> void:
 var a: Dictionary=keys[0]
 var b: Dictionary=keys[-1]
 for k in keys:
  if k.t<=t: a=k
  if k.t>t:
   b=k
   break
 var weight: float=clampf((t-float(a.t))/maxf(0.001,float(b.t)-float(a.t)),0,1)
 if a.get("ease")=="smooth": weight=weight*weight*(3-2*weight)
 if a.get("ease")=="snap": weight=0
 actor.position=Vector3(lerpf(a.x,b.x,weight),1.05+lerpf(a.y,b.y,weight),0)
 actor.rotation_degrees.z=lerpf(a.rotation,b.rotation,weight)
 actor.scale=Vector3.ONE*lerpf(a.scale,b.scale,weight)
 actor.texture=_texture(a.pose)
 camera.size=lerpf(a.zoom,b.zoom,weight)
 camera.position.x=actor.position.x*0.12
 effect.visible=false
 trail.visible=false
 flash.color.a=0
 impact_label.text=""
 enemy.texture=_texture("guard")
 for e in events:
  if t>=e.t and t<e.t+e.duration:
   effect.visible=true
   var age: float=(t-e.t)/e.duration
   var fx_size: float=e.get("size",1.0)
   effect.rotation_degrees.z=e.get("angle",24.0)
   effect_material.albedo_color=Color.from_string(e.get("color","ffe1a1"),Color.WHITE)
   effect.scale=Vector3((1.0+(t-e.t)*3)*fx_size,1,1)
   enemy.texture=_texture("hurt")
   flash.color.a=maxf(0,0.12-age*0.6)
   impact_label.text=str(int(e.damage))
   impact_label.position.y=300-age*55
   trail.visible=true
   _arc(age,fx_size)
   camera.position.x+=sin((t-e.t)*95)*0.065*(1-(t-e.t)/e.duration)
 syncing=true
 timeline.value=t
 syncing=false

func _process(delta: float) -> void:
 if not playing: return
 if freeze>0:
  freeze=maxf(0,freeze-delta)
  return
 var old:=clock
 clock=minf(LENGTH,clock+delta*speed)
 for i in events.size():
  var e: Dictionary=events[i]
  if old<=e.t and clock>=e.t and not fired.has(i):
   fired[i]=true
   freeze=e.freeze
   if battle:
    var damage:=int(round(e.damage*damage_multiplier))
    hp=maxi(0,hp-damage)
    health.text="  PROTAGONIST 100 HP                         TARGET %d HP   |   HIT %d" % [hp,damage]
 _sample(clock)
 if clock>=LENGTH:
  playing=false
  status.text="Playback complete · edit keys or choose a skill"

func _play(as_battle: bool) -> void:
 clock=0; freeze=0; fired.clear(); battle=as_battle; playing=true
 status.text="Playing / battle" if battle else "Playing / preview (no damage)"

func _attack(damage: int, _impact: float) -> void:
 if playing or hp<=0: return
 damage_multiplier=float(damage)/12.0
 _play(true)

func _save() -> void:
 var file:=FileAccess.open(_clip_path(),FileAccess.WRITE)
 if file==null:
  status.text="Save failed: %s" % FileAccess.get_open_error()
  return
 file.store_string(JSON.stringify({"version":1,"length":LENGTH,"keys":keys,"events":events},"  "))
 status.text="Saved: "+ProjectSettings.globalize_path(_clip_path())

func _valid_motion(data: Variant) -> bool:
 if not data is Dictionary or data.get("version")!=1: return false
 if not data.get("keys") is Array or data.keys.size()<2: return false
 if not data.get("events") is Array: return false
 for k in data.keys:
  if not k is Dictionary or not k.get("pose") is String: return false
  for field in ["t","x","y","rotation","scale","zoom"]:
   if not k.get(field) is float and not k.get(field) is int: return false
  if k.t<0 or k.t>LENGTH or k.scale<=0 or k.zoom<=0: return false
 for e in data.events:
  if not e is Dictionary: return false
  for field in ["t","duration","freeze","damage"]:
   if not e.get(field) is float and not e.get(field) is int: return false
  if e.t<0 or e.t>LENGTH or e.duration<=0 or e.freeze<0 or e.damage<0: return false
 return true

func _load_motion() -> void:
 var file:=FileAccess.open(_clip_path(),FileAccess.READ)
 if file==null:
  status.text="No saved motion. Save first."
  return
 var data: Variant=JSON.parse_string(file.get_as_text())
 if not _valid_motion(data):
  status.text="Invalid motion JSON; current work preserved"
  return
 playing=false
 keys=data["keys"]; events=data["events"]
 keys.sort_custom(func(a,b): return a.t<b.t)
 _refresh_list(); _select(0); _refresh_events(); clock=0; _sample(0)
 status.text="Loaded "+_clip_path()

func _smoke() -> void:
 _sample(0.7)
 assert(effect.visible)
 assert(actor.position.x>0)
 _save()
 var before:=keys.duplicate(true)
 _load_motion()
 assert(keys==before)
 assert(not _valid_motion({"version":1,"keys":[],"events":[]}))
 hp=100
 _play(true)
 for i in 300: _process(0.01)
 assert(hp==88,"Exactly one damage event must fire")
 assert(not playing)
 _play(false)
 for i in 300: _process(0.01)
 assert(hp==88,"Preview must not damage target")
 events.append({"t":1.2,"duration":0.2,"freeze":0.04,"damage":5})
 hp=100
 _attack(12,0.7)
 for i in 300: _process(0.01)
 assert(hp==83,"All authored hits must survive skill selection")
 assert(events.size()==2)
 _add_key()
 assert(keys.size()==7)
 _delete_key()
 assert(keys.size()==6)
 print("SMOKE PASS: timeline, impact, JSON roundtrip, invalid input, damage once, preview isolation, authored multi-hit, key add/delete")
 get_tree().quit()

func _clip_path() -> String:
 var safe_name:=clip_name.text.validate_filename().strip_edges()
 if safe_name.is_empty(): safe_name="motion"
 return "user://"+safe_name+".json"

func _refresh_events() -> void:
 event_list.clear()
 for e in events: event_list.add_item("%.2fs / %d damage" % [e.t,e.damage])

func _select_event(index: int) -> void:
 selected_event=index
 var e: Dictionary=events[index]
 event_time.value=e.t; event_damage.value=e.damage; event_freeze.value=e.freeze
 event_duration.value=e.duration; event_angle.value=e.get("angle",24)
 event_size.value=e.get("size",1)
 event_color.color=Color.from_string(e.get("color","ffe1a1"),Color.WHITE)
 event_list.select(index)

func _apply_event() -> void:
 playing=false
 if events.is_empty(): return
 events[selected_event]={"t":event_time.value,"kind":"hit","duration":event_duration.value,
 "freeze":event_freeze.value,"damage":int(event_damage.value),"angle":event_angle.value,
 "size":event_size.value,"color":event_color.color.to_html()}
 _refresh_events(); _select_event(selected_event); _sample(clock)
 status.text="Impact updated · multiple impacts supported"

func _arc(age: float, radius: float) -> void:
 var mesh:=ImmediateMesh.new()
 mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
 for i in range(33):
  var angle: float=lerpf(-2.7,0.7,float(i)/32)+age*0.8
  for r in [radius*1.1,radius*1.1+0.07*(1-age)]:
   mesh.surface_add_vertex(Vector3(cos(angle)*r+1.9,sin(angle)*r+1.5,0.5))
 mesh.surface_end()
 trail.mesh=mesh
