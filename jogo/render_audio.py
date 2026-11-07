import numpy as np, wave, os, sys
from scipy import signal
SR = 44100
OUT = '/home/claude/sinuca/sounds'
rng = np.random.default_rng(7)

def t_(d): return np.arange(int(SR*d))/SR
def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype='band', fs=SR, output='sos'); return signal.sosfilt(sos, x)
def lp(x, f, order=2):
    sos = signal.butter(order, f, btype='low', fs=SR, output='sos'); return signal.sosfilt(sos, x)
def hp(x, f, order=2):
    sos = signal.butter(order, f, btype='high', fs=SR, output='sos'); return signal.sosfilt(sos, x)
def noise(n): return rng.standard_normal(n)
def place(buf, x, at, gain=1.0):
    i = int(at*SR); n = min(len(x), len(buf)-i)
    if n > 0: buf[i:i+n] += x[:n]*gain
def save(name, x, stereo=False):
    x = np.atleast_2d(x)
    if x.shape[0] == 1 and stereo: x = np.vstack([x, x])
    pk = np.max(np.abs(x)); x = x/pk*0.92 if pk > 0 else x
    d = (x.T*32767).astype('<i2')
    w = wave.open(os.path.join(OUT, name+'.wav'), 'wb'); w.setnchannels(x.shape[0]); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes()); w.close()

def room(x, taps):
    y = x.copy()
    for d, g in taps:
        place(y, lp(x, 5000), d, g)
    return y

def ball_click(var=0, vol=1.0, dur=0.28, soft=0.0):
    r = np.random.default_rng(100+var)
    t = t_(dur); n = len(t)
    j = lambda s: 1+r.uniform(-s, s)
    modes = [(2150*j(.07), .55, .0105), (3320*j(.07), .45, .0075), (4950*j(.06), .30, .0048), (7400*j(.06), .20, .0030),
             (1280*j(.08), .50, .0160), (880*j(.08), .30, .0220), (11200*j(.04), .10, .0015)]
    x = np.zeros(n)
    for f, a, tau in modes:
        x += a*np.sin(2*np.pi*f*t + r.uniform(0, 6.28))*np.exp(-t/tau)
    # contato: pulso agudo de ruído
    tick = hp(noise(n), 2500)*np.exp(-t/0.00055)*1.4
    mid = bp(noise(n), 700, 4500)*np.exp(-t/0.0035)*0.5
    thud = np.sin(2*np.pi*(190*j(.1))*t*(1-0.6*t))*np.exp(-t/0.028)*0.35
    x = x*(1-soft*0.6)+tick*(1-soft)+mid+thud
    x *= np.minimum(1, t/0.00012)
    x = room(x, [(0.0042, .12), (0.0091, .08), (0.017, .05)])
    return x*vol

def rail(var=0):
    r = np.random.default_rng(300+var)
    t = t_(0.35); n = len(t)
    x = np.sin(2*np.pi*(95+12*var)*t*(1-0.9*t))*np.exp(-t/0.055)*1.0
    x += np.sin(2*np.pi*(310+30*var)*t)*np.exp(-t/0.028)*0.45
    x += lp(noise(n), 1800)*np.exp(-t/0.014)*0.8
    x += hp(noise(n), 3000)*np.exp(-t/0.0008)*0.35
    x += np.sin(2*np.pi*720*t)*np.exp(-t/0.01)*0.15
    x *= np.minimum(1, t/0.0006)
    return room(x, [(0.011, .1), (0.023, .06)])

def wood_tok(dur=0.2, f=420, a=1.0, tau=0.02):
    t = t_(dur)
    x = np.sin(2*np.pi*f*t*(1-0.5*t*8))*np.exp(-t/tau)
    x += 0.5*np.sin(2*np.pi*f*1.82*t)*np.exp(-t/(tau*0.6))
    x += 0.3*bp(noise(len(t)), 600, 3500)*np.exp(-t/0.004)
    return x*a*np.minimum(1, t/0.0005)

def pocket():
    dur = 1.9; buf = np.zeros(int(SR*dur)); n = len(buf); t = t_(dur)
    # boca de couro + queda na madeira
    place(buf, wood_tok(0.2, 520, 0.5, 0.012), 0.0)
    place(buf, ball_click(1, 0.35, 0.15, soft=0.6), 0.002)
    place(buf, wood_tok(0.35, 190, 1.0, 0.05), 0.075)
    place(buf, wood_tok(0.3, 330, 0.6, 0.03), 0.082)
    # rolando pela calha: ruído grave modulado, acelera e some
    s0, s1 = 0.17, 1.15
    m = (t >= s0) & (t <= s1); u = np.clip((t-s0)/(s1-s0), 0, 1)
    contour = np.sin(np.pi*u)**0.8*(1-0.35*u)
    rumble = bp(noise(n), 120, 700)
    rate = 9 + 11*u
    phase = np.cumsum(rate)/SR*2*np.pi
    am = 0.62+0.38*np.sin(phase)
    buf += rumble*contour*am*m*1.25
    buf += lp(noise(n), 2200)*contour*m*0.18*(0.5+0.5*np.sin(phase*1.7))
    # batidas da bola nas emendas da madeira
    for at, f, a in [(0.36, 410, .55), (0.52, 360, .45), (0.68, 330, .42), (0.83, 300, .35), (0.97, 280, .3)]:
        place(buf, wood_tok(0.2, f, a, 0.016), at)
    # chegada na bandeja: estalos contra as outras bolas
    for k, (at, g) in enumerate([(1.13, .75), (1.215, .5), (1.27, .32), (1.31, .2)]):
        place(buf, ball_click(10+k, g, 0.25, soft=0.15), at)
    place(buf, lp(noise(n), 900)*np.exp(-t/0.25), 0)  if False else None
    buf = room(buf, [(0.02, .14), (0.045, .09), (0.09, .05)])
    return buf

def cue_shot():
    t = t_(0.3); n = len(t)
    x = hp(noise(n), 2200)*np.exp(-t/0.0009)*1.1
    x += bp(noise(n), 900, 3800)*np.exp(-t/0.006)*0.7
    x += np.sin(2*np.pi*1900*t)*np.exp(-t/0.006)*0.3 + np.sin(2*np.pi*3100*t)*np.exp(-t/0.004)*0.2
    x += np.sin(2*np.pi*(260)*t*(1-0.8*t))*np.exp(-t/0.035)*0.7
    x *= np.minimum(1, t/0.0002)
    return room(x, [(0.008, .1)])

def click_ui():
    t = t_(0.08); n = len(t)
    return (np.sin(2*np.pi*1600*t)*np.exp(-t/0.008)*0.5 + hp(noise(n), 2500)*np.exp(-t/0.001)*0.5)

# ---- efeitos
for i in range(6):
    save('s_hit%d' % (i+1), ball_click(i))
for i in range(2):
    save('s_rail%d' % (i+1), rail(i))
save('s_pocket', pocket())
save('s_shot', cue_shot())
save('s_click', click_ui())

# ---- trilha do menu: jazz lounge (84 bpm, swing)
BPM = 84; BEAT = 60/BPM; BAR = 4*BEAT
CH = {
 'Cmaj9': (36, [52,55,59,62], [0,4,7,11]), 'Am9': (33, [55,59,60,64], [0,3,7,10]),
 'Dm9': (38, [53,57,60,64], [0,3,7,10]), 'G13': (43, [53,59,62,64], [0,4,7,10]),
 'A7b9': (33, [55,58,61,64], [0,4,7,10]), 'Em7': (40, [55,59,62,66], [0,3,7,10]),
 'Fmaj9': (41, [57,60,64,67], [0,4,7,11]), 'Fm6': (41, [56,60,62,65], [0,3,7,9]),
}
PROG = ['Cmaj9','Am9','Dm9','G13','Cmaj9','A7b9','Dm9','G13','Em7','A7b9','Dm9','G13','Fmaj9','Fm6','Cmaj9','G13']
SCALE = {'Cmaj9':[0,2,4,7,9,11],'Am9':[0,2,3,5,7,10],'Dm9':[0,2,3,5,7,9,10],'G13':[0,2,4,5,7,9,10],'A7b9':[0,1,4,5,7,10],
         'Em7':[0,2,3,5,7,10],'Fmaj9':[0,2,4,7,9,11],'Fm6':[0,2,3,5,7,9],}
def mtof(m): return 440*2**((m-69)/12)
TOTAL = BAR*len(PROG)
LEN = TOTAL*2  # 2 passes; usa a segunda para a cauda do reverb fechar o loop
def swing(b):
    f = b % 1
    return int(b) + (f if f < 0.5 else 0.5+ (f-0.5)*0.0) if False else b

def rhodes(f, dur, vel):
    t = t_(dur+0.6); n = len(t)
    idx = 1.6*vel*np.exp(-t/0.22)+0.25
    car = np.sin(2*np.pi*f*t + idx*np.sin(2*np.pi*f*t))
    bell = 0.12*np.sin(2*np.pi*f*4*t)*np.exp(-t/0.06)
    env = np.exp(-t/1.1)*np.minimum(1, t/0.004)
    rel = np.where(t < dur, 1.0, np.exp(-(t-dur)/0.12))
    return (car+bell)*env*rel*vel*0.5

def vibes(f, dur, vel):
    t = t_(dur+1.0)
    env = np.exp(-t/0.9)*np.minimum(1, t/0.003)
    trem = 1+0.25*np.sin(2*np.pi*5.2*t)
    x = np.sin(2*np.pi*f*t)+0.35*np.sin(2*np.pi*f*4*t)*np.exp(-t/0.15)+0.1*np.sin(2*np.pi*f*10*t)*np.exp(-t/0.04)
    rel = np.where(t < dur+0.4, 1.0, np.exp(-(t-dur-0.4)/0.25))
    return x*env*trem*rel*vel*0.45

def bass(f, dur, vel):
    t = t_(dur+0.2)
    env = np.exp(-t/0.38)*np.minimum(1, t/0.006)
    x = np.sin(2*np.pi*f*t)+0.45*np.sin(2*np.pi*f*2*t)*np.exp(-t/0.2)+0.2*np.sin(2*np.pi*f*3*t)*np.exp(-t/0.1)
    x += 0.15*lp(noise(len(t)), 600)*np.exp(-t/0.012)
    return x*env*vel*0.8

def ride(vel):
    t = t_(0.9)
    x = bp(noise(len(t)), 5500, 12500)*np.exp(-t/0.28)*0.5
    x += sum(np.sin(2*np.pi*f*t)*np.exp(-t/0.35) for f in (3900, 5200, 6900, 8300))*0.05
    return x*vel*np.minimum(1, t/0.0006)
def hat(vel):
    t = t_(0.12)
    return hp(noise(len(t)), 7000)*np.exp(-t/0.022)*vel*0.6*np.minimum(1, t/0.0004)
def kick(vel):
    t = t_(0.3)
    return np.sin(2*np.pi*(55+90*np.exp(-t/0.03))*t)*np.exp(-t/0.1)*vel
def brush(vel):
    t = t_(0.25)
    return bp(noise(len(t)), 1500, 6500)*np.exp(-t/0.07)*vel*0.4*np.minimum(1, t/0.01)

L = np.zeros(int(SR*LEN)); Rr = np.zeros(int(SR*LEN))
def put(buf_l, buf_r, x, at, pan=0.0, g=1.0):
    place(buf_l, x, at, g*(1-max(pan, 0)*0.7)); place(buf_r, x, at, g*(1+min(pan, 0)*0.7))
# buses
rh_l = np.zeros_like(L); rh_r = np.zeros_like(L)
vb_l = np.zeros_like(L); vb_r = np.zeros_like(L)
bs = np.zeros_like(L); dr_l = np.zeros_like(L); dr_r = np.zeros_like(L)
mel_rng = np.random.default_rng(11)
last_note = 76
def sw(b):  # tempo de semínima com swing (colcheia fraca em 2/3)
    f = b-int(b)
    return int(b)+(f if f < 0.01 else (0.667 if abs(f-0.5) < 0.01 else f))
for rep in range(2):
    for bi, name in enumerate(PROG):
        t0 = rep*TOTAL+bi*BAR
        root, voic, ints = CH[name]
        nxt = CH[PROG[(bi+1) % len(PROG)]][0]
        # baixo caminhando
        steps = [root, root+ints[1] if bi % 2 else root+ints[2], root+ints[2] if bi % 2 else root+ints[1]+ (0 if True else 0), None]
        bl = [root, root+ints[1], root+ints[2], nxt+(1 if nxt < root+3 else -1)]
        bl = [b if b >= 28 else b+12 for b in bl]
        for k, m in enumerate(bl):
            place(bs, bass(mtof(m), BEAT*0.9, 0.85 if k == 0 else 0.7), t0+k*BEAT)
        # comping do piano elétrico
        pats = [[(0, 1.4, .8), (1.667, .9, .6), (3.0, .6, .5)], [(0.667, 1.0, .65), (2.0, 1.2, .75), (3.667, .5, .5)]]
        for beat, ln, v in pats[bi % 2]:
            at = t0+beat*BEAT
            for j, m in enumerate(voic):
                p = (j-1.5)*0.18
                x = rhodes(mtof(m), ln*BEAT, v*(0.9+0.1*mel_rng.random()))
                place(rh_l, x, at+j*0.006, 1-max(p, 0)); place(rh_r, x, at+j*0.006, 1+min(p, 0))
        # melodia no vibrafone (esparsa)
        beats = [0.0, 1.0, 1.667, 2.0, 2.667, 3.0, 3.667]
        sc = [60+12+s for s in SCALE[name]]+[60+24+s for s in SCALE[name][:3]]
        sc = sorted(set(sc))
        pos = 0.0
        while pos < 4.0:
            if mel_rng.random() < 0.52 and (bi % 4 != 3 or pos < 2.0):
                cand = [s for s in sc if 72 <= s <= 88]
                cand.sort(key=lambda s: abs(s-last_note)+mel_rng.random()*3)
                last_note = cand[0]
                ln = [0.9, 1.4, 2.0][mel_rng.integers(0, 3)]
                x = vibes(mtof(last_note), ln*BEAT, 0.55+0.25*mel_rng.random())
                place(vb_l, x, t0+pos*BEAT, 0.9); place(vb_r, x, t0+pos*BEAT+0.004, 1.0)
                pos += ln if ln < 1.5 else ln
            else:
                pos += [1.0, 0.667, 1.333][mel_rng.integers(0, 3)]
            pos = round(pos, 3)
        # bateria
        for b, v in [(0, 1.0), (1, .7), (1.667, .45), (2, .85), (3, .7), (3.667, .45)]:
            x = ride(v*(0.85+0.15*mel_rng.random())); place(dr_l, x, t0+b*BEAT, 0.9); place(dr_r, x, t0+b*BEAT, 1.1)
        for b in (1, 3):
            place(dr_l, hat(0.7), t0+b*BEAT); place(dr_r, hat(0.7), t0+b*BEAT)
            place(dr_l, brush(0.5), t0+b*BEAT+0.005, .6); place(dr_r, brush(0.5), t0+b*BEAT+0.005, .6)
        for b in (0, 1, 2, 3):
            place(bs, kick(0.28), t0+b*BEAT)
# reverb
def ir(dur, seed, lpf):
    r = np.random.default_rng(seed); tt = t_(dur)
    x = r.standard_normal(len(tt))*np.exp(-tt/(dur*0.3)); x = lp(x, lpf); x[:int(0.012*SR)] *= np.linspace(0, 1, int(0.012*SR)); return x/np.sqrt(np.sum(x**2))
irl, irr = ir(1.8, 1, 5500), ir(1.8, 2, 5500)
def verb(a_l, a_r, wet):
    wl = signal.fftconvolve(a_l, irl)[:len(L)]; wr = signal.fftconvolve(a_r, irr)[:len(L)]
    return a_l+wet*wl*6, a_r+wet*wr*6
rh_l, rh_r = verb(rh_l, rh_r, 0.55); vb_l, vb_r = verb(vb_l, vb_r, 0.8)
dr_l, dr_r = verb(dr_l, dr_r, 0.2)
bs = lp(bs, 900)
mixl = rh_l*0.9+vb_l*0.55+bs*0.75+dr_l*0.35
mixr = rh_r*0.9+vb_r*0.55+bs*0.75+dr_r*0.35
a = int(SR*TOTAL); b = a+int(SR*TOTAL)
m = np.vstack([mixl[a:b], mixr[a:b]])
m = np.tanh(m/np.max(np.abs(m))*1.6)
m = m/np.max(np.abs(m))*0.85
# fecha o loop com microfade circular
fl = int(0.01*SR); w = np.linspace(0, 1, fl)
m[:, :fl] *= w; m[:, -fl:] *= w[::-1]
d = (m.T*32767).astype('<i2')
ww = wave.open('/tmp/claude-0/-home-claude/27a56503-d099-5819-9233-21b543fdca23/scratchpad/music.wav', 'wb'); ww.setnchannels(2); ww.setsampwidth(2); ww.setframerate(SR); ww.writeframes(d.tobytes()); ww.close()
print('ok', round(TOTAL, 1), 's')
