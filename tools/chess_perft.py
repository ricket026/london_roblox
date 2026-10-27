# Line-for-line Python port of src/shared/Chess.luau, checked with perft (standard move counts).
# Keep it in step with Chess.luau when the rules change. Usage: python3 tools/chess_perft.py
# Expected: all OK. Position 5 expects 41 (standard 44): Chess.luau always promotes to a queen.
import sys
def sq(f,r): return None if f<1 or f>8 or r<1 or r>8 else (r-1)*8+f
def fr(i): return (i-1)%8+1,(i-1)//8+1
def other(c): return 'b' if c=='w' else 'w'
KN=[(1,2),(2,1),(-1,2),(-2,1),(1,-2),(2,-1),(-1,-2),(-2,-1)]
KG=[(1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)]
RK=[(1,0),(-1,0),(0,1),(0,-1)]; BS=[(1,1),(1,-1),(-1,1),(-1,-1)]
def attacked(b,i,by):
    f,r=fr(i); d=-1 if by=='w' else 1
    for df in(-1,1):
        s=sq(f+df,r+d)
        if s and b[s]==by+'P': return True
    for dd in KN:
        s=sq(f+dd[0],r+dd[1])
        if s and b[s]==by+'N': return True
    for dd in KG:
        s=sq(f+dd[0],r+dd[1])
        if s and b[s]==by+'K': return True
    def slide(dirs,a,c):
        for dd in dirs:
            nf,nr=f+dd[0],r+dd[1]; s=sq(nf,nr)
            while s:
                p=b[s]
                if p!='':
                    if p in(by+a,by+c): return True
                    break
                nf+=dd[0];nr+=dd[1];s=sq(nf,nr)
        return False
    return slide(RK,'R','Q') or slide(BS,'B','Q')
def incheck(st,c=None):
    c=c or st['turn']
    k=st['board'].index(c+'K') if c+'K' in st['board'] else 0
    return k!=0 and attacked(st['board'],k,other(c))
def pseudo(st,frm):
    b=st['board'];p=b[frm];out=[]
    if p=='': return out
    c,k=p[0],p[1]; f,r=fr(frm)
    def add(s):
        if not s: return False
        q=b[s]
        if q=='': out.append(s); return True
        if q[0]!=c: out.append(s)
        return False
    if k=='P':
        d=1 if c=='w' else -1; one=sq(f,r+d)
        if one and b[one]=='':
            out.append(one); two=sq(f,r+2*d)
            if r==(2 if c=='w' else 7) and two and b[two]=='': out.append(two)
        for df in(-1,1):
            s=sq(f+df,r+d)
            if s and ((b[s]!='' and b[s][0]!=c) or s==st['ep']): out.append(s)
    elif k in'NK':
        for dd in (KN if k=='N' else KG): add(sq(f+dd[0],r+dd[1]))
        if k=='K':
            home=1 if c=='w' else 8; foe=other(c)
            if r==home and f==5 and not attacked(b,frm,foe):
                clear=lambda fs: all(b[sq(x,home)]=='' for x in fs)
                if st['castle'][c+'K'] and b[sq(8,home)]==c+'R' and clear([6,7]) and not attacked(b,sq(6,home),foe): out.append(sq(7,home))
                if st['castle'][c+'Q'] and b[sq(1,home)]==c+'R' and clear([2,3,4]) and not attacked(b,sq(4,home),foe): out.append(sq(3,home))
    else:
        dirs=RK if k=='R' else BS if k=='B' else KG
        for dd in dirs:
            nf,nr=f+dd[0],r+dd[1]
            while add(sq(nf,nr)): nf+=dd[0];nr+=dd[1]
    return out
def apply(st,frm,to):
    b=list(st['board']);p=b[frm];c,k=p[0],p[1];cap=b[to]!='';ca=dict(st['castle'])
    ff,frr=fr(frm);tf,tr=fr(to);ep=0
    b[to]=p;b[frm]=''
    if k=='P':
        if to==st['ep'] and tf!=ff: b[sq(tf,frr)]='';cap=True
        if abs(tr-frr)==2: ep=sq(ff,(frr+tr)//2)
        if tr in(8,1): b[to]=c+'Q'
    elif k=='K':
        ca[c+'K']=False;ca[c+'Q']=False
        if abs(tf-ff)==2:
            rf=sq(8 if tf==7 else 1,frr);rt=sq(6 if tf==7 else 4,frr);b[rt]=b[rf];b[rf]=''
    for corner,right in {1:'wQ',8:'wK',57:'bQ',64:'bK'}.items():
        if frm==corner or to==corner: ca[right]=False
    return dict(board=b,turn=other(c),castle=ca,ep=ep,halfmove=0 if cap or k=='P' else st['halfmove']+1,plies=st['plies']+1)
def legal(st,frm):
    p=st['board'][frm]
    if p=='' or p[0]!=st['turn']: return []
    return [t for t in pseudo(st,frm) if not incheck(apply(st,frm,t),st['turn'])]
def fen(s):
    parts=s.split();b=['']*65;r=8;f=1
    for ch in parts[0]:
        if ch=='/': r-=1;f=1
        elif ch.isdigit(): f+=int(ch)
        else: b[sq(f,r)]=('w' if ch.isupper() else 'b')+ch.upper();f+=1
    ca={x:False for x in('wK','wQ','bK','bQ')}
    for ch,k in(('K','wK'),('Q','wQ'),('k','bK'),('q','bQ')):
        if ch in parts[2]: ca[k]=True
    ep=0 if parts[3]=='-' else sq(ord(parts[3][0])-96,int(parts[3][1]))
    return dict(board=b,turn=parts[1],castle=ca,ep=ep,halfmove=0,plies=0)
def perft(st,d):
    if d==0: return 1
    n=0
    for i in range(1,65):
        for t in legal(st,i): n+=perft(apply(st,i,t),d-1)
    return n
tests=[('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -',[20,400,8902]),
 ('r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -',[48,2039]),
 ('8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -',[14,191,2812]),
 ('rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ -',[41])]  # standard 44; -3 because promotion is queen-only
for f,exp in tests:
    st=fen(f); got=[perft(st,d) for d in range(1,len(exp)+1)]
    print('OK ' if got==exp else 'BAD', got, exp)
