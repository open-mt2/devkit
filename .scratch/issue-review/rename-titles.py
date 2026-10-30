import json,pathlib,re,subprocess
p=pathlib.Path('.scratch/issue-review')
items=json.load(open('/tmp/devkit-title-review.json'))
names={
1:'Track Windows/Linux parity decisions D1–D16',
2:'Establish the test harness and CI baseline',3:'Characterize pure-logic behavior',4:'Test binary formats with fixtures and fuzzing',5:'Capture headless renderer golden images',6:'Test audio, effects and models without hardware',7:'Smoke-test Python bindings and capture the API',8:'Prevent coverage regressions in CI',9:'Capture behavior snapshots before refactoring',10:'Consolidate engine layers L0–L3 into neoeter',11:'Separate Python bindings and game code into repositories',12:'Build the consolidated repositories with compatibility shims',13:'Archive the superseded package repositories',14:'Identify Windows cross-compilation blockers',15:'Add the Windows cross-build harness',16:'Audit data widths for the Windows target',17:'Introduce explicit platform and renderer macros',18:'Use SDL2 windows and events on both platforms',19:'Replace DirectInput with SDL2 input',20:'Load OpenGL functions on Windows',21:'Run the GL compatibility renderer on Windows',22:'Unify IME and text input across platforms',23:'Isolate OpenGL behind a renderer backend interface',24:'Document the fixed-function rendering feature matrix',25:'Remove the DevIL dependency',26:'Audit libjpeg usage and document its disposition',27:'Cross-build the Windows dependency set',28:'Run Python 2.7 and client bytecode on Windows',29:'Make CMake dependencies platform-aware',30:'Package the Windows client with matching assets',31:'Detect client crashes and black screens in CI',32:'Audit Windows/Linux behavioral parity',33:'Remove legacy platform and proprietary SDK references',34:'Build both targets in CI and document the workflow',35:'Render a textured quad with a Vulkan backend prototype',36:'Synthesize Vulkan programs and translate legacy shaders',37:'Complete the Vulkan rendering backend',38:'Compare rendering output across backends',39:'Track Windows/Linux parity delivery',41:'Restore standalone pkg_eterbase builds and affected CI workflows'}
s=json.loads((p/'published.json').read_text());parents={v['number']:int(k) for k,v in s['issues'].items()}
changes=[]
for i in items:
 n=i['number']; source=parents.get(n,n);prefix=re.match(r'^\[[^]]+\] ',i['title']); title=(prefix.group() if prefix else '')+names[source]
 changes.append({'number':n,'before':i['title'],'after':title})
(p/'title-changes.json').write_text(json.dumps(changes,indent=2))
for c in sorted(changes,key=lambda c:c['number']):
 if c['before']==c['after']:continue
 subprocess.run(['gh','issue','edit',str(c['number']),'--repo','open-mt2/devkit','--title',c['after']],check=True,capture_output=True,text=True,timeout=30)
 print('Updated',c['number'],flush=True)
