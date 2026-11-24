# Genera TODOS los sonidos propios del juego (sin samples externos).
# Requisitos: pip install numpy scipy  +  ffmpeg en el PATH.
# Uso (desde la carpeta del proyecto): python tools/generar_audio.py
# Genera los sonidos de Nights of Tec de forma procedural (sin samples externos).
import numpy as np, scipy.signal as sg, subprocess, os
SR=44100
rng=np.random.default_rng(7)
# Los .ogg se guardan directo en assets/audio del proyecto
OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','assets','audio')
def save(name,x,loop_xfade=0.0):
    x=np.asarray(x,dtype=np.float64)
    if x.ndim==1: x=np.stack([x,x],1)
    if loop_xfade>0:  # mezcla el final con el inicio para que el loop no "brinque"
        n=int(loop_xfade*SR); a=np.linspace(0,1,n)[:,None]
        head=x[:n].copy(); x[:n]=head*a + x[-n:]*(1-a); x=x[:-n]
    x=x/ (np.max(np.abs(x))+1e-9)*0.89
    wav=f'{OUT}/{name}.wav'
    import wave
    with wave.open(wav,'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x*32767).astype('<i2').tobytes())
    subprocess.run(['ffmpeg','-y','-loglevel','error','-i',wav,'-c:a','libvorbis','-q:a','5',f'{OUT}/{name}.ogg'],check=True)
    os.remove(wav)
def t(d): return np.arange(int(d*SR))/SR
def lp(x,f,o=2): b,a=sg.butter(o,f/(SR/2)); return sg.lfilter(b,a,x,axis=0)
def hp(x,f,o=2): b,a=sg.butter(o,f/(SR/2),'high'); return sg.lfilter(b,a,x,axis=0)
def bp(x,f1,f2,o=2): b,a=sg.butter(o,[f1/(SR/2),f2/(SR/2)],'band'); return sg.lfilter(b,a,x,axis=0)
def reverb(x,dur=3.0,mix=0.35,damp=3000):
    n=int(dur*SR); ir=rng.standard_normal((n,2))*np.exp(-np.arange(n)/SR*6.0/dur)[:,None]
    ir=lp(ir,damp); ir/=np.sqrt((ir**2).sum(0))
    if x.ndim==1: x=np.stack([x,x],1)
    wet=np.stack([sg.fftconvolve(x[:,c],ir[:,c])[:len(x)] for c in range(2)],1)
    return x*(1-mix)+wet*mix*3
def brown(n):
    w=rng.standard_normal(n); b=np.cumsum(w); b=hp(b,15); return b/np.max(np.abs(b))

# 1) Música del menú: drone grave + notas de piano lejanas en menor, con reverb
D=96.0; tt=t(D); n=len(tt)
drone=np.zeros(n)
for f,a in [(36.71,1),(36.71*1.004,0.8),(55.0,0.5),(73.42*0.997,0.35)]:  # D1, A1, D2
    drone+=a*sg.sawtooth(2*np.pi*f*tt)
drone=lp(drone,180,3)*(0.6+0.4*np.sin(2*np.pi*tt/24))
air=lp(hp(rng.standard_normal(n),300),1200)*0.08*(0.5+0.5*np.sin(2*np.pi*tt/31+1))
piano=np.zeros((n,2))
notes=[62,65,69,64, 62,60,57,58, 62,65,70,69, 67,65,64,62]   # re menor
for i,m in enumerate(notes):
    st=4.0+i*5.5+rng.uniform(-0.3,0.3)
    if st+5>D: break
    f=440*2**((m-69)/12); d=t(5.0)
    env=np.exp(-d*1.1)*(1-np.exp(-d*200))
    tone=sum(a*np.sin(2*np.pi*f*k*d)*np.exp(-d*k*0.6) for k,a in [(1,1),(2,0.35),(3,0.18),(4.02,0.08)])
    s=tone*env*0.5; pan=rng.uniform(0.3,0.7); a0=int(st*SR)
    piano[a0:a0+len(s),0]+=s*(1-pan); piano[a0:a0+len(s),1]+=s*pan
# caja de música desafinada (notas agudas esporádicas)
for st in [20.5,47.3,71.9]:
    for j,m in enumerate([81,77,74]):
        f=440*2**((m-69)/12)*1.006; d=t(2.5); s=np.sin(2*np.pi*f*d)*np.exp(-d*2.5)*0.12
        a0=int((st+j*0.45)*SR); piano[a0:a0+len(s)]+=s[:,None]
mix=np.stack([drone*0.5+air,drone*0.5+air*0.9],1)+piano
save('menu_musica',reverb(mix,4.5,0.45,2500),loop_xfade=4.0)

# 2) Ambiente del edificio: zumbido de lámparas, ventilación, crujidos lejanos
D=64.0; tt=t(D); n=len(tt)
hum=sum(a*np.sin(2*np.pi*f*tt+rng.uniform(0,6)) for f,a in [(120,1),(240,0.4),(360,0.2),(60,0.5)])*0.05
hvac=brown(n)*0.35
wind=lp(rng.standard_normal(n),400)*(0.5+0.5*np.sin(2*np.pi*tt/17)**2)*0.6
amb=np.stack([hum+hvac+wind*0.8, hum+hvac*0.95+wind],1)
for k in range(9):   # crujidos/golpes lejanos
    st=rng.uniform(2,D-4); d=t(rng.uniform(0.3,1.2))
    f0=rng.uniform(80,260); s=np.sin(2*np.pi*f0*d*(1+0.3*np.sin(d*30)))*np.exp(-d*6)*0.25
    s=s+lp(rng.standard_normal(len(d)),900)*np.exp(-d*12)*0.3
    a0=int(st*SR); p=rng.uniform(0,1); amb[a0:a0+len(s),0]+=s*(1-p); amb[a0:a0+len(s),1]+=s*p
save('ambiente_edificio',reverb(amb,2.5,0.3,2000),loop_xfade=3.0)

# 3) Latido (un solo "pum-pum"; el script lo repite más rápido con el peligro)
d=t(0.7)
def thump(st,a,f=48):
    e=np.zeros_like(d); m=d>=st; dd=d[m]-st
    e[m]=a*np.sin(2*np.pi*f*dd*(1+0.6*np.exp(-dd*30)))*np.exp(-dd*14)*(1-np.exp(-dd*400))
    return e
hb=thump(0.0,1.0)+thump(0.22,0.7,42)
hb=lp(hb,160)
save('latido',hb)

# 4) Respiración agitada (loop: 2 ciclos inhala/exhala); pitch_scale controla la velocidad
def breath(dur,inhale,amp):
    d=t(dur); x=rng.standard_normal(len(d))
    if inhale:
        x=bp(x,900,4200)*0.6+bp(x,350,900)*0.25
        env=np.sin(np.pi*np.clip(d/dur,0,1))**1.5
    else:
        x=bp(x,500,2600)*0.8+bp(x,150,500)*0.3
        env=(1-np.exp(-d*25))*np.exp(-d*3.2)
    return x*env*amp
seq=[]
for i in range(2):
    seq+= [breath(0.55,True,0.7),np.zeros(int(0.05*SR)),breath(0.75,False,1.0),np.zeros(int(0.12*SR))]
br=np.concatenate(seq)
save('respiracion',reverb(br,0.5,0.12,5000))

# 5) Zumbido de lámpara fluorescente (loop 3D cerca de las luces que parpadean)
D=6.0; tt=t(D)
bz=sum(a*sg.square(2*np.pi*f*tt,0.5) for f,a in [(120,0.6)])
bz=bp(bz,100,3000)*0.4+np.sin(2*np.pi*120*tt)*0.5
bz*= (0.85+0.15*np.sin(2*np.pi*0.7*tt))
save('zumbido_lampara',bz)

# 6) Chasquido eléctrico (cuando la lámpara se apaga de golpe)
d=t(0.25); cl=hp(rng.standard_normal(len(d)),1500)*np.exp(-d*40)+np.sin(2*np.pi*120*d)*np.exp(-d*20)*0.4
save('chispa_lampara',cl)

# 7) UI: hover (golpecito grave) y click (golpe metálico)
d=t(0.18); save('ui_hover',np.sin(2*np.pi*180*d)*np.exp(-d*35)+lp(rng.standard_normal(len(d)),2000)*np.exp(-d*60)*0.2)
d=t(0.9); clk=sum(a*np.sin(2*np.pi*f*d)*np.exp(-d*dk) for f,a,dk in [(92,1,5),(184.7,0.5,7),(311,0.3,9),(523,0.15,12)])
save('ui_click',reverb(clk,1.5,0.3,3000))

# 8) Aguijón (stinger) cuando el guardia te ve por primera vez
d=t(2.5); st=np.zeros(len(d))
for f in [146.8,155.6,220,233.1,293.7]:
    st+=sg.sawtooth(2*np.pi*f*d*(1+0.02*d))*0.2
st=lp(st,1800)*(1-np.exp(-d*30))*np.exp(-d*1.4)
st+=lp(rng.standard_normal(len(d)),3000)*np.exp(-d*8)*0.6
save('aguijon_visto',reverb(st,2.5,0.4,4000))
print(sorted(os.listdir(OUT)))

# 9) Pasos sobre piso de terrazo (zapato): golpe de talón + punta, 6 variaciones
for v in range(6):
    d=t(0.32); n=len(d)
    def hit(st,amp,bright):
        e=np.zeros(n); m=d>=st; dd=d[m]-st
        noise=rng.standard_normal(m.sum())
        click=hp(noise,bright)*np.exp(-dd*90)
        thud=np.sin(2*np.pi*rng.uniform(70,95)*dd)*np.exp(-dd*35)
        e[m]=amp*(click*0.6+thud*0.9)
        return e
    x=hit(0.0,1.0,rng.uniform(1800,2600))+hit(rng.uniform(0.07,0.1),0.45,rng.uniform(2500,3500))
    x+=bp(rng.standard_normal(n),300,1500)*np.exp(-d*25)*0.08   # roce de suela
    save(f'paso_piso_{v}',lp(x,7000))
# 10) Pasos sobre pasto: crujido suave de hojas
for v in range(4):
    d=t(0.4); n=len(d)
    env=(1-np.exp(-d*80))*np.exp(-d*9)
    x=bp(rng.standard_normal(n),800,5000)*env*(0.6+0.4*(rng.random(n)>0.7))
    x+=np.sin(2*np.pi*60*d)*np.exp(-d*30)*0.4
    save(f'paso_pasto_{v}',x)
print('pasos ok')
