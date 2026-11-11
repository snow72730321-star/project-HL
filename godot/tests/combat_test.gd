extends SceneTree
const Combat=preload("res://combat.gd")
func _initialize() -> void:
 var wins:=0
 var losses:=0
 for seed_value in range(1,129):
  var m=Combat.new(seed_value)
  for step in range(80):
   if m.finished:break
   var before_player:int=m.player_hp
   var before_enemy:int=m.enemy_hp
   var r:Dictionary=m.resolve(step%3)
   var pc:int=Combat.SKILLS[step%3].coins
   var ec:int=m.enemy_skill().coins
   for clash in r.clashes:
    assert(clash.player_coins<=pc and clash.enemy_coins<=ec)
    assert((pc-clash.player_coins)+(ec-clash.enemy_coins)<=1)
    pc=clash.player_coins;ec=clash.enemy_coins
   assert(not r.hits.is_empty())
   for hit in r.hits:
    assert(hit.damage>0)
    m.apply_hit(hit)
   m.finish_turn(r)
   var after_turn:int=m.turn
   var after_hp:int=m.enemy_hp
   m.finish_turn(r)
   assert(m.turn==after_turn and m.enemy_hp==after_hp,"Turn must only finalize once")
   assert(m.player_hp<=before_player and m.enemy_hp<=before_enemy)
   assert(m.sanity>=-45 and m.sanity<=45)
  assert(m.finished,"Encounter must terminate")
  assert(m.resolve(0).get("blocked",false),"Finished encounters reject new actions")
  if m.enemy_hp==0:wins+=1
  else:losses+=1
 var guard=Combat.new(2)
 var r:Dictionary=guard.resolve(0,true)
 assert(r.clashes.is_empty())
 for hit in r.hits:
  assert(hit.attacker=="enemy" and hit.damage<=6)
 var stagger=Combat.new(1)
 stagger.enemy_hp=211
 stagger.apply_hit({"attacker":"player","damage":2})
 stagger.finish_turn({})
 assert(stagger.staggered)
 var unopposed:Dictionary=stagger.resolve(0)
 assert(unopposed.clashes.is_empty() and unopposed.winner=="player")
 print("COMBAT TEST PASS: 128 seeded full encounters (%d wins / %d losses), coin loss, damage, guard, stagger, turn idempotence, terminal lock"%[wins,losses])
 quit()
