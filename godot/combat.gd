extends RefCounted
## Small playable ruleset. Parameters are prototype values, not verified original formulas.
const SKILLS := [
 {"name":"Quick cut", "base":5,"coin":3,"coins":2,"damage":13,"bleed":2,"color":"65c8db"},
 {"name":"Crimson arc", "base":4,"coin":4,"coins":3,"damage":12,"bleed":3,"color":"ee665e"},
 {"name":"Finisher", "base":8,"coin":5,"coins":1,"damage":35,"bleed":0,"color":"deb878"}]
var rng:=RandomNumberGenerator.new()
var player_hp:=260
var enemy_hp:=420
var sanity:=0
var turn:=1
var bleed:=0
var staggered:=false
var stagger_used:=false
var player_speed:=4
var enemy_speed:=3
var finished:=false

func _init(seed_value: int=0) -> void:
 if seed_value==0: rng.randomize()
 else: rng.seed=seed_value

func enemy_skill() -> Dictionary:
 return {"name":"Rending embrace" if turn%2==1 else "Crushing blow","base":4+turn/4,"coin":3,"coins":2 if turn%2==1 else 3,"damage":15+turn}

func _roll(skill: Dictionary, count: int, sp: int) -> int:
 var value:int=skill.base
 for i in count:
  if rng.randf()<clampf(0.5+sp/100.0,0.05,0.95): value+=int(skill.coin)
 return value

func resolve(skill_index: int, defend: bool=false) -> Dictionary:
 if finished: return {"blocked":true}
 var skill: Dictionary=SKILLS[clampi(skill_index,0,2)]
 var foe:=enemy_skill()
 var a:int=skill.coins
 var b:int=foe.coins
 var clashes:Array=[]
 if not defend and not staggered:
  for attempt in 64:
   if a==0 or b==0: break
   var pa:=_roll(skill,a,sanity)
   var pb:=_roll(foe,b,0)
   if pa>pb: b-=1
   elif pb>pa: a-=1
   clashes.append({"player":pa,"enemy":pb,"player_coins":a,"enemy_coins":b})
  # Bounded tie breaker uses speed; avoids endless ties with pathological inputs.
  if a>0 and b>0:
   if player_speed>=enemy_speed: b=0
   else: a=0
 var winner:="enemy" if defend or a==0 else "player"
 var hits:Array=[]
 if winner=="player":
  sanity=mini(45,sanity+10)
  for i in a:
   var damage:int=skill.damage+_roll(skill,i+1,sanity)/3
   if staggered: damage*=2
   hits.append({"attacker":"player","damage":damage})
  bleed+=int(skill.bleed)
 else:
  sanity=maxi(-45,sanity-10)
  for i in b:
   hits.append({"attacker":"enemy","damage":maxi(1,int(foe.damage)* (0.35 if defend else 1.0))})
 var result:={"winner":winner,"clashes":clashes,"hits":hits,"defend":defend,"skill":skill.name,"enemy_skill":foe.name,"applied":false}
 return result

func apply_hit(hit: Dictionary) -> void:
 if hit.attacker=="player":
  enemy_hp=maxi(0,enemy_hp-int(hit.damage))
 else:
  player_hp=maxi(0,player_hp-int(hit.damage))

func finish_turn(result: Dictionary) -> void:
 if result.get("applied",false): return
 result.applied=true
 if bleed>0:
  enemy_hp=maxi(0,enemy_hp-bleed)
  bleed=maxi(0,bleed-1)
 if staggered: staggered=false
 elif not stagger_used and enemy_hp<=210:
  staggered=true
  stagger_used=true
 finished=player_hp<=0 or enemy_hp<=0
 turn+=1
 player_speed=rng.randi_range(3,7)
 enemy_speed=rng.randi_range(2,6)
