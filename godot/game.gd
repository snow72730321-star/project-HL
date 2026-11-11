extends Node3D
const Combat=preload("res://combat.gd")
const ASSETS:="res://assets/extracted/"
var model=Combat.new()
var hero: Sprite3D
var foe: Sprite3D
var camera: Camera3D
var vfx: Sprite3D
var ui: CanvasLayer
var headline: Label
var state_label: Label
var health_label: Label
var log_label: Label
var floating: Label
var flash: ColorRect
var cards:Array[Button]=[]
var execute: Button
var guard: Button
var selected:=0
var busy:=false
var playback_speed:=1.0
var result: Dictionary={}
var phase:="select"
var phase_time:=0.0
var clash_index:=0
var hit_index:=0
var hit_done:=false
var stop_time:=0.0
var pose_cache: Dictionary={}
var fx_cache:Array[Texture2D]=[]
var burst_cache:Array[Texture2D]=[]
var gallery: Window
var custom_clip: RefCounted
var clip_input: LineEdit
var clip_status: Label

func _ready() -> void:
 _stage()
 _interface()
 _update_ui()
 if "--game-smoke" in OS.get_cmdline_user_args(): _smoke()
 if "--capture" in OS.get_cmdline_user_args(): _capture()

func _pose(name: String) -> Texture2D:
 if not pose_cache.has(name): pose_cache[name]=load(ASSETS+name+".png")
 return pose_cache[name]

func _sprite(name: String, pos: Vector3, pixel: float) -> Sprite3D:
 var s:=Sprite3D.new()
 s.texture=_pose(name);s.position=pos;s.pixel_size=pixel
 s.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 s.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
 add_child(s)
 return s

func _stage() -> void:
 camera=Camera3D.new()
 camera.position=Vector3(0,3.2,12)
 camera.look_at_from_position(camera.position,Vector3(0,1.0,0))
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=8.0; camera.v_offset=-0.6
 add_child(camera)
 var environment:=WorldEnvironment.new()
 environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color("0c0c12")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color("b2a7a2")
 environment.environment.ambient_light_energy=0.8
 add_child(environment)
 _block(Vector3(0,-0.13,0),Vector3(32,0.2,20),"floor_patch.png",Color("b0a29b"))
 _block(Vector3(0,2.2,-4.5),Vector3(30,4.4,0.25),"wall_strip.png",Color("b2a9a1"))
 for i in range(-4,5):
  _block(Vector3(i*3.5,2.4,-4.0),Vector3(0.5,4.8,0.65),"floor_patch.png",Color("39322f"))
 hero=_sprite("hero_idle",Vector3(-2.8,1.6,0),0.007)
 foe=_sprite("enemy_idle",Vector3(2.1,1.7,0),0.009)
 # Transparent canvas foot anchor at pixel y480; align to the 3D ground.
 hero.position.y=1.57;foe.position.y=2.01
 for i in range(20):
  fx_cache.append(load(ASSETS+"fx_%02d.png"%i))
  burst_cache.append(load(ASSETS+"burst_%02d.png"%i))
 vfx=Sprite3D.new();vfx.pixel_size=0.016
 vfx.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 vfx.no_depth_test=true;vfx.visible=false
 add_child(vfx)
 var light:=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-45,-25,0);light.light_energy=0.6
 add_child(light)

func _block(pos: Vector3, size_value: Vector3, texture_name: String, tint: Color) -> void:
 var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=size_value;mesh.mesh=box;mesh.position=pos
 var mat:=StandardMaterial3D.new()
 mat.albedo_texture=load(ASSETS+texture_name)
 mat.albedo_color=tint
 mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 mat.uv1_scale=Vector3(4,2,1)
 mesh.material_override=mat;add_child(mesh)

func _interface() -> void:
 ui=CanvasLayer.new();add_child(ui)
 var root:=VBoxContainer.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(root)
 var top:=PanelContainer.new();_panel_style(top);root.add_child(top)
 var topbox:=HBoxContainer.new();top.add_child(topbox)
 headline=_label("HL / CRIMSON COURTYARD",26);topbox.add_child(headline)
 var fill:=Control.new();fill.size_flags_horizontal=Control.SIZE_EXPAND_FILL;topbox.add_child(fill)
 _button(topbox,"ASSET GALLERY",_gallery)
 _button(topbox,"MOTION EDITOR",func(): get_tree().change_scene_to_file("res://main.tscn"))
 _button(topbox,"RESTART",_restart)
 state_label=_label("",20);root.add_child(state_label)
 var space:=Control.new();space.size_flags_vertical=Control.SIZE_EXPAND_FILL;space.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(space)
 var bottom:=PanelContainer.new();_panel_style(bottom);root.add_child(bottom)
 var col:=VBoxContainer.new();bottom.add_child(col)
 health_label=_label("",20);col.add_child(health_label)
 var cliprow:=HBoxContainer.new();col.add_child(cliprow)
 clip_input=LineEdit.new();clip_input.text="motion";clip_input.custom_minimum_size.x=150;cliprow.add_child(clip_input)
 _button(cliprow,"LOAD EDITOR CLIP",_load_editor_clip)
 _button(cliprow,"DEFAULT MOTION",func():custom_clip=null;clip_status.text="Built-in motion")
 clip_status=_label("Built-in motion / saved editor clip can replace player motion",14);cliprow.add_child(clip_status)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);col.add_child(row)
 for i in 3:
  var skill: Dictionary=Combat.SKILLS[i]
  var card:=Button.new()
  card.text="%02d / %s\nBase %d + %d × %d coins\nDamage %d / Bleed %d"%[i+1,skill.name,skill.base,skill.coin,skill.coins,skill.damage,skill.bleed]
  card.custom_minimum_size=Vector2(240,100)
  card.toggle_mode=true
  card.pressed.connect(_select.bind(i))
  row.add_child(card);cards.append(card)
 var actions:=VBoxContainer.new();row.add_child(actions)
 execute=_button(actions,"EXECUTE / SPACE",func(): _start(false))
 guard=_button(actions,"GUARD",func(): _start(true))
 var speedbox:=OptionButton.new()
 for v in ["1× speed","0.5× speed","0.25× speed"]: speedbox.add_item(v)
 speedbox.item_selected.connect(func(i):playback_speed=[1.0,0.5,0.25][i])
 actions.add_child(speedbox)
 log_label=_label("Choose a fixed skill. No E.G.O / no random skill draw.",16);col.add_child(log_label)
 var note:=_label("Video-extracted cutouts / reconstructed 3D stage · Prototype rules · Original-resource recovery is incomplete",14)
 note.modulate=Color("b5a28a");col.add_child(note)
 floating=_label("",48);floating.position=Vector2(850,260);ui.add_child(floating)
 flash=ColorRect.new();flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);flash.mouse_filter=Control.MOUSE_FILTER_IGNORE;flash.color=Color(1,0.3,0.2,0);ui.add_child(flash)
 _select(0)

func _label(value: String, size_value: int) -> Label:
 var l:=Label.new();l.text=value;l.add_theme_font_size_override("font_size",size_value);l.add_theme_color_override("font_color",Color("edddbd"));return l

func _panel_style(panel: PanelContainer) -> void:
 var s:=StyleBoxFlat.new();s.bg_color=Color("11151e");s.border_color=Color("7f6546");s.set_border_width_all(1)
 s.content_margin_left=22;s.content_margin_right=22;s.content_margin_top=14;s.content_margin_bottom=14
 panel.add_theme_stylebox_override("panel",s)

func _button(parent: Node, title: String, call: Callable) -> Button:
 var b:=Button.new();b.text=title;b.custom_minimum_size.y=38;b.pressed.connect(call);parent.add_child(b);return b

func _select(index: int) -> void:
 if busy:return
 selected=index
 for i in cards.size():cards[i].button_pressed=i==index

func _update_ui() -> void:
 health_label.text="PROTAGONIST   %d / 260 HP     SP %+d     SPEED %d         |         TEDDY   %d / 420 HP     SPEED %d     BLEED %d"%[model.player_hp,model.sanity,model.player_speed,model.enemy_hp,model.enemy_speed,model.bleed]
 if model.finished:
  state_label.text="VICTORY — encounter cleared" if model.enemy_hp==0 else "DEFEAT — restart to try again"
 else:
  state_label.text="TURN %02d   /   %s   %s"%[model.turn,model.enemy_skill().name,"[ENEMY STAGGERED / DOUBLE DAMAGE]" if model.staggered else ""]
 for c in cards:c.disabled=busy or model.finished
 execute.disabled=busy or model.finished;guard.disabled=busy or model.finished

func _start(defend: bool) -> void:
 if busy or model.finished:return
 result=model.resolve(selected,defend)
 busy=true;phase="clash";phase_time=0;clash_index=0;hit_index=0;hit_done=false;stop_time=0
 _update_ui()
 if result.clashes.is_empty():phase="attack"

func _process(delta: float) -> void:
 if not busy:return
 if stop_time>0:
  stop_time=maxf(0,stop_time-delta)
  return
 phase_time+=delta*playback_speed
 if phase=="clash":
  var c:Dictionary=result.clashes[clash_index]
  log_label.text="CLASH %d     %d vs %d     Remaining coins %d : %d"%[clash_index+1,c.player,c.enemy,c.player_coins,c.enemy_coins]
  camera.size=lerpf(camera.size,7.2,0.12)
  hero.texture=_pose("hero_windup")
  if phase_time>=0.38:
   phase_time=0;clash_index+=1
   if clash_index>=result.clashes.size():phase="attack"
 elif phase=="attack":
  var hit:Dictionary=result.hits[hit_index]
  var attacking:bool=hit.attacker=="player"
  var t:=phase_time
  hero.rotation=Vector3.ZERO;hero.scale=Vector3.ONE;hero.position.y=1.57
  var dash:=smoothstep(0.04,0.18,t)
  var retreat:=smoothstep(0.42,0.62,t)
  var offset:=dash*(1-retreat)
  hero.position.x=-2.8+offset*(3.55 if attacking else 0.15)
  foe.position.x=2.1-offset*(0.0 if attacking else 3.25)
  hero.texture=_pose("hero_windup" if t<0.18 else "hero_strike" if attacking and t<0.48 else "hero_idle")
  foe.texture=_pose("enemy_hurt" if attacking and t>=0.2 and t<0.5 else "enemy_idle")
  camera.size=8.0-offset*1.0
  camera.position.x=offset*0.25
  if custom_clip!=null and attacking:
   var authored:Dictionary=custom_clip.sample(clampf(t/0.65,0,1)*custom_clip.length)
   var alias:Dictionary={"idle":"hero_idle","windup":"hero_windup","strike":"hero_strike","hurt":"hero_idle","guard":"hero_windup"}
   if authored.pose.begins_with("res://") or authored.pose.begins_with("user://"):
    hero.texture=load(authored.pose) if ResourceLoader.exists(authored.pose) else _pose("hero_idle")
   else:
    hero.texture=_pose(alias.get(authored.pose,"hero_idle"))
   hero.position.x=authored.x
   hero.position.y=1.57+authored.y
   hero.rotation_degrees.z=authored.rotation
   hero.scale=Vector3.ONE*authored.scale
   camera.size=authored.zoom
  vfx.visible=t>=0.18 and t<0.50
  if vfx.visible:
   var frames:Array[Texture2D]=burst_cache if attacking and selected>0 else fx_cache
   vfx.texture=frames[clampi(int((t-0.18)*60),0,19)]
   vfx.position=Vector3(1.1 if attacking else -1.9,1.1,0.7)
   vfx.flip_h=not attacking
  if t>=0.2 and not hit_done:
   hit_done=true;model.apply_hit(hit);stop_time=0.065
   floating.text=str(hit.damage);floating.position.x=900 if attacking else 440
   floating.modulate=Color("ffe1ad") if attacking else Color("ff6969")
   _update_ui()
  floating.position.y=260-maxf(0,t-0.2)*100
  flash.color.a=maxf(0,0.16-(t-0.2)*2) if t>=0.2 else 0
  if t>=0.2 and t<0.35:camera.position.x+=sin(t*120)*0.045
  log_label.text="%s · %s · HIT %d / %d"%[result.skill if attacking else result.enemy_skill,"UNOPPOSED" if result.clashes.is_empty() else "CLASH WIN",hit_index+1,result.hits.size()]
  if t>=0.65:
   hit_index+=1;phase_time=0;hit_done=false
   if hit_index>=result.hits.size() or model.player_hp==0 or model.enemy_hp==0:
    model.finish_turn(result);busy=false;phase="select";_reset_stage();_update_ui()

func _reset_stage() -> void:
 hero.position=Vector3(-2.8,1.57,0);hero.rotation=Vector3.ZERO;hero.scale=Vector3.ONE;foe.position.x=2.1;hero.texture=_pose("hero_idle");foe.texture=_pose("enemy_idle")
 camera.size=8;camera.position.x=0;vfx.visible=false;flash.color.a=0;floating.text=""

func _load_editor_clip() -> void:
 if busy:return
 var candidate=preload("res://motion_clip.gd").new()
 var path:="user://"+clip_input.text.validate_filename()+".json"
 if candidate.read_file(path):
  custom_clip=candidate
  clip_status.text="Loaded "+path+" / player motion per surviving coin"
 else:
  clip_status.text="Cannot load "+path+". Save a valid clip in Motion Editor first."

func _restart() -> void:
 model=Combat.new();busy=false;phase="select";_reset_stage();_update_ui()
 log_label.text="New encounter. Choose a skill or guard."

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  match event.keycode:
   KEY_1:_select(0)
   KEY_2:_select(1)
   KEY_3:_select(2)
   KEY_SPACE:_start(false)
   KEY_R:_restart()

func _gallery() -> void:
 if is_instance_valid(gallery):gallery.popup_centered();return
 gallery=Window.new();gallery.title="Extracted assets / source provenance";gallery.size=Vector2i(1050,660)
 gallery.close_requested.connect(func():gallery.hide());add_child(gallery)
 var scroll:=ScrollContainer.new();scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);gallery.add_child(scroll)
 var col:=VBoxContainer.new();scroll.add_child(col)
 col.add_child(_label("Visible pixels only. Polygon crops / chroma masks. See assets/extracted/manifest.json.",16))
 var grid:=GridContainer.new();grid.columns=4;col.add_child(grid)
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"manifest.json"))
 for entry in manifest.assets:
  var name:String=entry.file
  var box:=VBoxContainer.new();grid.add_child(box)
  var tex:=TextureRect.new();tex.texture=load(ASSETS+name);tex.custom_minimum_size=Vector2(230,210);tex.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tex.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;box.add_child(tex)
  box.add_child(_label(name,16))
  box.add_child(_label("V%d / %.2fs / %s"%[entry.video,entry.time,entry.kind],12))
 gallery.popup_centered()

func _smoke() -> void:
 model=Combat.new(42)
 _start(false)
 var once:Dictionary=result.duplicate(true)
 _start(true)
 assert(result==once,"Busy input must not resolve a second action")
 for i in 2000:
  _process(0.01)
  if not busy:break
 assert(not busy)
 assert(model.turn==2)
 assert(model.player_hp<260 or model.enemy_hp<420)
 assert(hero.texture!=null and fx_cache.size()==20)
 _restart();assert(model.player_hp==260 and model.enemy_hp==420)
 var authored=preload("res://motion_clip.gd").new()
 var file:=FileAccess.open("user://test_clip.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"version":1,"length":2.4,"keys":[
 {"t":0,"x":-3,"y":0,"rotation":0,"scale":1,"zoom":8,"pose":"idle"},
 {"t":2.4,"x":1,"y":1,"rotation":20,"scale":1.5,"zoom":6,"pose":"strike"}],"events":[]}))
 file.close()
 assert(authored.read_file("user://test_clip.json"))
 assert(is_equal_approx(authored.sample(1.2).x,-1))
 custom_clip=authored
 model=Combat.new(1);_start(false)
 for i in 2000:
  _process(0.01)
  if not busy:break
 assert(not busy and model.turn==2)
 custom_clip=null
 print("GAME SMOKE PASS: full turn, clash, animation events, health, reset, extracted textures")
 get_tree().quit()

func _capture() -> void:
 if "--capture-action" in OS.get_cmdline_user_args():
  model=Combat.new(42)
  _start(false)
  while phase=="clash":_process(0.39)
  # Capture a rendered hit frame while preserving normal runtime event handling.
  _process(0.23)
 await get_tree().process_frame
 await get_tree().process_frame
 get_viewport().get_texture().get_image().save_png("user://battle.png")
 get_tree().quit()
