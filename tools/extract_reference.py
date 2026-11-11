"""Extract visible screen-space assets; never claims to recover original game resources.
Usage: python tools/extract_reference.py video1.mp4 video2.mp4
Requires opencv-python-headless==4.11.0.86, numpy, Pillow.
"""
import argparse, hashlib, json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw

OUT=Path(__file__).resolve().parents[1]/'godot/assets/extracted'

def main():
 ap=argparse.ArgumentParser();ap.add_argument('videos',nargs=2);args=ap.parse_args()
 OUT.mkdir(parents=True,exist_ok=True)
 caps=[cv2.VideoCapture(p) for p in args.videos]
 entries=[]
 def frame(v,t):
  c=caps[v-1];c.set(cv2.CAP_PROP_POS_MSEC,t*1000);ok,f=c.read()
  if not ok: raise RuntimeError((v,t))
  return f
 def record(name,v,t,kind,**kw): entries.append(dict(file=name,video=v,time=t,kind=kind,**kw))
 def cut(name,v,t,points,flip=False):
  f=frame(v,t);poly=np.array(points,np.int32)
  # Polygon annotation preserves dark costume pixels that automatic background removal loses.
  alpha=np.zeros(f.shape[:2],np.uint8);cv2.fillPoly(alpha,[poly],255)
  alpha=cv2.GaussianBlur(alpha,(3,3),0.45)
  x,y,w,h=cv2.boundingRect(poly);rgba=cv2.cvtColor(f[y:y+h,x:x+w],cv2.COLOR_BGR2RGBA)
  rgba[:,:,3]=alpha[y:y+h,x:x+w]
  im=Image.fromarray(rgba)
  if flip: im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
  # Normalize foot position, not bitmap size, for pose switching.
  height=280 if name.startswith('hero') else 360
  im=im.resize((round(im.width*height/im.height),height),Image.Resampling.LANCZOS)
  canvas=Image.new('RGBA',(512,512));canvas.alpha_composite(im,((512-im.width)//2,480-height))
  canvas.save(OUT/(name+'.png'))
  record(name+'.png',v,t,'polygon_cutout',polygon=points,mirror=flip,foot_pixel=[256,480],limitations='Screen pixels; some background fringe and baked lighting remain. Occluded detail is unavailable.')
 cut('hero_idle',1,17,[(721,273),(750,257),(768,259),(778,280),(776,298),(791,299),(799,305),(810,301),(817,311),(790,325),(783,330),(795,397),(784,402),(767,399),(759,384),(750,399),(733,400),(733,360),(715,375),(706,372),(725,352),(688,367),(684,362),(730,334),(735,307),(742,288)],True)
 cut('hero_windup',1,7,[(448,219),(461,214),(472,220),(479,237),(477,251),(489,262),(501,282),(493,288),(480,275),(482,299),(494,322),(478,329),(459,322),(448,328),(440,320),(446,285),(427,268),(422,254),(434,249),(449,252),(454,239)],True)
 cut('hero_strike',1,15,[(651,240),(674,234),(685,223),(715,227),(724,242),(716,251),(730,262),(739,283),(733,292),(731,302),(725,311),(716,308),(703,303),(690,292),(661,302),(659,297),(693,278),(686,266),(669,270),(656,264),(648,255)])
 cut('enemy_idle',1,17,[(541,124),(552,109),(583,112),(598,124),(616,117),(633,124),(635,144),(651,146),(662,161),(655,184),(657,211),(638,228),(618,242),(606,260),(616,288),(622,322),(607,352),(601,394),(579,402),(560,394),(548,402),(515,399),(510,383),(486,390),(464,381),(435,387),(445,367),(430,373),(447,343),(468,329),(483,316),(496,295),(506,261),(520,241),(533,229),(519,208),(517,185),(524,165),(534,152),(534,134)])
 cut('enemy_hurt',1,22,[(460,135),(469,118),(493,120),(505,130),(524,121),(537,131),(539,151),(548,158),(553,181),(540,203),(536,218),(550,244),(561,271),(571,307),(557,333),(541,327),(532,315),(524,331),(506,334),(497,320),(481,333),(458,331),(449,320),(436,323),(415,328),(421,307),(396,318),(401,294),(416,277),(424,252),(440,234),(448,215),(448,196),(452,176),(451,151)])
 # Background crop + explicitly marked inpainting. This is a reconstructed plate, not an original texture.
 f=frame(1,7);mask=np.zeros(f.shape[:2],np.uint8)
 for x,y,w,h in [(305,128,596,290),(490,440,70,70)]: cv2.rectangle(mask,(x,y),(x+w,y+h),255,-1)
 repaired=cv2.inpaint(f,mask,9,cv2.INPAINT_TELEA)
 cv2.imwrite(str(OUT/'courtyard_reconstructed.png'),repaired[45:425,40:1070])
 cv2.imwrite(str(OUT/'courtyard_repair_mask.png'),mask[45:425,40:1070])
 record('courtyard_reconstructed.png',1,7,'crop_and_inpaint',crop=[40,45,1030,380],limitations='Large masked areas are algorithmic fill, not recovered scene detail.')
 cv2.imwrite(str(OUT/'wall_strip.png'),frame(1,3)[90:170,120:970])
 record('wall_strip.png',1,3,'crop',crop=[120,90,850,80])
 # Clean floor patch remains an actual crop for the 3D ground.
 cv2.imwrite(str(OUT/'floor_patch.png'),frame(1,17)[275:355,75:235])
 record('floor_patch.png',1,17,'crop',crop=[75,275,160,80])
 # Screen-space FX candidates, chroma masks exclude most gray scene / white HUD.
 for v,begin,prefix,roi in [(1,7.85,'fx_', (300,210,270,187)),(2,27.65,'burst_', (250,210,440,210))]:
  for i in range(20):
   t=begin+i/60
   x,y,w,h=roi
   f=frame(v,t)[y:y+h,x:x+w]
   hsv=cv2.cvtColor(f,cv2.COLOR_BGR2HSV)
   a=(((hsv[:,:,0]<18)|(hsv[:,:,0]>165))&(hsv[:,:,1]>95)&(hsv[:,:,2]>125)).astype(np.uint8)*255
   # Reject compact HUD glyphs and feather crop boundaries to avoid hard rectangles.
   if v==1:
    a[:55,:]=0
    a[115:145,80:120]=0
   count,labels,stats,_=cv2.connectedComponentsWithStats(a)
   clean=np.zeros_like(a)
   for component in range(1,count):
    if stats[component,cv2.CC_STAT_AREA]>=45:clean[labels==component]=255
   yy,xx=np.indices(a.shape)
   feather=np.minimum.reduce([xx,yy,w-1-xx,h-1-yy]).clip(0,12)/12
   a=(cv2.GaussianBlur(clean,(3,3),0.6)*feather).astype(np.uint8)
   rgba=cv2.cvtColor(f,cv2.COLOR_BGR2RGBA);rgba[:,:,3]=a
   Image.fromarray(rgba).save(OUT/f'{prefix}{i:02}.png')
   record(f'{prefix}{i:02}.png',v,round(t,4),'chroma_mask',crop=list(roi),limitations='Red-only FX candidate. May include red HUD/character pixels; not a clean original VFX layer. 60 Hz sampling of 30 fps video repeats some frames.')
 # UI ornaments are catalogued but the game uses its own bottom skill UI.
 f=frame(1,17)
 for name,box in [('border_top',(10,5,910,37)),('border_bottom',(10,427,1080,453))]:
  x1,y1,x2,y2=box;rgb=f[y1:y2,x1:x2];hsv=cv2.cvtColor(rgb,cv2.COLOR_BGR2HSV)
  alpha=((hsv[:,:,2]>150)&(hsv[:,:,0]<50)).astype(np.uint8)*255
  rgba=cv2.cvtColor(rgb,cv2.COLOR_BGR2RGBA);rgba[:,:,3]=alpha
  Image.fromarray(rgba).save(OUT/(name+'.png'));record(name+'.png',1,17,'luminance_mask',crop=list(box))
 # Both videos contribute original-resolution frame indexes for review, not playback stand-ins.
 sheets=[]
 for v in [1,2]:
  duration=caps[v-1].get(cv2.CAP_PROP_FRAME_COUNT)/caps[v-1].get(cv2.CAP_PROP_FPS)
  times=list(np.arange(0,duration-1,2))
  sheet=Image.new('RGB',(4*334,((len(times)+3)//4)*174),'#101218');draw=ImageDraw.Draw(sheet)
  for i,t in enumerate(times):
   im=Image.fromarray(cv2.cvtColor(frame(v,float(t)),cv2.COLOR_BGR2RGB));im.thumbnail((334,154))
   x=i%4*334;y=i//4*174;sheet.paste(im,(x,y));draw.text((x+8,y+155),f'video {v} / {t:.2f}s',fill='white')
  sheet.save(OUT/f'video{v}_contact.jpg',quality=90)
  record(f'video{v}_contact.jpg',v,0,'contact_sheet',interval_seconds=2)
 manifest={'schema':1,'sources':[{'file':Path(p).name,'sha256':hashlib.sha256(Path(p).read_bytes()).hexdigest()} for p in args.videos], 'assets':entries,'unrecoverable':['original layered sprites','occluded poses and body parts','original 3D map geometry','original VFX node graphs','isolated voice/music/effects audio']}
 (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
 # Alpha checker preview.
 sheet=Image.new('RGB',(5*256,300),'#263439')
 for i,name in enumerate(['hero_idle','hero_windup','hero_strike','enemy_idle','enemy_hurt']):
  im=Image.open(OUT/(name+'.png'));im.thumbnail((256,256));sheet.paste(im,(i*256,0),im)
  ImageDraw.Draw(sheet).text((i*256+8,265),name,fill='white')
 sheet.save(OUT/'cutout_preview.jpg',quality=95)
 print(f'Extracted {len(entries)} catalog entries to {OUT}')
 for c in caps:c.release()

if __name__=='__main__': main()
