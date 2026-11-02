# Genera los rompecabezas de "Forja de palabras" (assets/minigames/forge_XX.json).
#
# Uso (en una carpeta con dict/es.dic y dict/en.dic de
# https://github.com/wooorm/dictionaries y `pip install wordfreq`):
#   python genforge.py
#
# Solo usa palabras que estén a la vez en el diccionario (hunspell) y entre las
# 40.000 más frecuentes (wordfreq), sin tildes (salvo la Ñ). Las listas BLOCK y
# EXCLUDE quitan palabrotas, nombres propios, siglas y palabras poco aptas;
# se revisaron a mano todas las palabras resultantes.
import json, random, unicodedata, sys
from collections import Counter
from wordfreq import top_n_list
def norm(w, lang):
    w=w.lower()
    if lang=='es': w=w.replace('ñ','\x00')
    w=''.join(c for c in unicodedata.normalize('NFD',w) if unicodedata.category(c)!='Mn')
    return w.replace('\x00','ñ').upper()
BLOCK={'es':['puta','puto','mierda','joder','coño','polla','verga','pendej','cabron','marica','zorra','culo','teta','pene','sexo','nazi','droga','coca','porro','cagar','mear','follar','putas','mamar','violar','matar','muerte','morir','suicid','ano','cojon','chocho','perra','zorr','anal','vagina','orgasm','borrach','idiot','estupid','tonto','tonta','gordo','gorda','feo'],
       'en':['fuck','shit','bitch','dick','pussy','cock','cunt','nigg','nazi','sex','porn','rape','kill','dead','die','ass','damn','hell','crap','slut','whore','tit','drug','gun','fag','penis','anal','cum','piss','homo','gay','suicid','murder','idiot','stupid','fat','ugly','beer','wine','sexy']}
EXCLUDE={'es':set('ISA QUI ETA ARA SET TEA ANA EVA LUIS ART BEN BENITO CARLA DANS DES ETC GIL IRAN ISLAM NASA OPUS ORTO PEDO PITO POTOSI RAIN RITA SIDA TOP VOL PEDRO LEO SOSA OTERO TIPA VIOLA FETO SOTO PAGS LESA MOLE DIOS DIOSES ATEO PLUS BLUES MAYA MAYAS ISLAM SANA ARABES ARABE BRETAÑA DARNOS HABERLA APOLO ARGEL ARTS CHE GRAL LORA MANI MECA PINCHE PINCHES RAFA ROSS TRAD OPIO SENO CHINO ADAN AGUERO CAMILO CROSS EDIT JORGE JUAN LUISA MARTA RAMON ROMAN SILVA ORINA TRAUMA HOLANDA SANCHO GERMAN ANGELES ROMANA GINEBRA HINCHAS AGUSTIN CARMEN COREA JAEN JANE ROMEO SEMEN INSULTO ABUSAR CANCER MARS MEDINA MISS SIMON TESLA TUIT LORD HOSTIA HOSTIAS JEREZ TITO MALTA TUITS BITS'.split()),
         'en':set('KEN ORG REC REG COR LIB BEY YEN ROGER ERR ROE TIS AIN ANS ESS SIS NAN MON DEM REP PRO CON SEC MIC LOL OMG ASS GOD COM DES ETC INC LAS LOS MPS PRES SIMS TED TOM TONY ROMEO PETER BRAD DEAN LEE MAC MAR ROMAN SURREY SPERM SLAVE SLAVES OBESE MORON SUCK THUG HECK DARN UGH THO THRU GOTTA BRO BROS LAMA VITA SANS SEARS POLY REV REPS TEMP DOC DOCS GLEN HOMER OVERS OUTS LEGIT MINS LIT COKE MALT CORP INTEL MANILA HIP HIPS SEMI SPEC SPECS CAMS BOTS STUD FLIRT WHOEVER YEA THEE THOU RAND GOD BLACKS BLACK FIREARM GUN RIFLE ANGELS TRUTHS NEGRO NUDE PSYCHO PSYCH PSYCHIC THUGS MARS GOSH DANG YEP COCA AMES GRAN VOL PIC PICS REFS BERG CUTLER SHES SEIZURE PAGAN EARL POSH BUTT LING LEAFS HUBS VETS OFFS COMP AINT ABUSE ABUSES ABUSIVE BUTTS LOSER LOSERS PRISON PRISONS SLAIN PETERS RICK TUCKER WALES WELSH SICK VILE MANS ANON BRAT SINS SIN BROWNS BROWN ROMANS SAINTS POISON SPOUSE CORPSE CIGAR CRACK CRACKS NICK EXEC INFO FETUS UTERUS MENS METS TROY DELL NOEL PROF SLAY CHRONIC FIAT CHINA KHAN HANK POOH TREY VOLS OLDS CIRCA'.split())}
def load(lang):
    stems=set()
    for line in open(f'dict/{lang}.dic',encoding='utf-8').read().split('\n')[1:]:
        w=line.split('/')[0].strip()
        if w and w.isalpha() and w==w.lower(): stems.add(w)
    top=top_n_list(lang,40000)
    rank={w:i for i,w in enumerate(top)}
    valid={}
    for w,i in rank.items():
        if not w.isalpha(): continue
        ok = w in stems or (w.endswith('s') and w[:-1] in stems) or (w.endswith('es') and w[:-2] in stems)
        if not ok: continue
        n=norm(w,lang)
        if not (3<=len(n)<=7): continue
        if any(b in n.lower() for b in BLOCK[lang]): continue
        if len(n)==3 and i>6000: continue
        if n in EXCLUDE[lang]: continue
        if n not in valid or valid[n]>i: valid[n]=i
    return valid
def gen(lang, count):
    valid=load(lang)
    common={w:r for w,r in valid.items() if r<20000}
    bases=[w for w,r in common.items() if len(w) in (6,7) and r<12000]
    random.seed(7); random.shuffle(bases)
    out=[]; used=set()
    for b in bases:
        if len(set(b))<len(b)-1: continue
        letters=Counter(b)
        subs=sorted({w for w in common if not Counter(w)-letters}, key=lambda w:(len(w),w))
        if not (8<=len(subs)<=22): continue
        if len([w for w in subs if len(w)>=5])<2: continue
        key=''.join(sorted(b))
        if key in used: continue
        used.add(key)
        out.append({'letters':b,'words':subs})
        if len(out)>=count: break
    return out
for lang in ('es','en'):
    p=gen(lang,60)
    print(lang,len(p), p[:3])
    json.dump({'language':lang,'puzzles':p},open(f'forge_{lang}.json','w'),ensure_ascii=False)
