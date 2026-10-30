import json,re,subprocess,pathlib
p=pathlib.Path('.scratch/issue-review'); repo='open-mt2/devkit'
statepath=p/'published.json'; state=json.loads(statepath.read_text()) if statepath.exists() else {'issues':{},'linked':[],'edges':[],'comments':{}}
def save(): statepath.write_text(json.dumps(state,indent=2))
def gh(*args):
 r=subprocess.run(['gh',*args],text=True,capture_output=True)
 if r.returncode: raise RuntimeError(r.stderr)
 return r.stdout.strip()
def api(path,*args): return json.loads(gh('api',f'repos/{repo}/{path}',*args))
sources=json.loads((p/'before.json').read_text()); sources={i['number']:i for i in sources if (p/f'{i["number"]:02}-review.md').exists()}
ids={re.match(r'\[([^]]+)\]',i['title']).group(1):n for n,i in sources.items() if re.match(r'\[([^]]+)\]',i['title'])}
def deps(n):
 m=re.search(r'\*\*Deps\*\*: (.*)',sources[n]['body'])
 if not m:return []
 s=m.group(1).split(' —')[0].replace('TA.2–TA.6','TA.2, TA.3, TA.4, TA.5, TA.6')
 return [ids[t.strip()] for t in s.split(',') if t.strip() in ids]
selected=[n for n in sorted(sources) if (p/f'{n:02}-ticket.md').exists()]
order=[]
def visit(n):
 if n in order:return
 for d in deps(n):
  if d in selected:visit(d)
 order.append(n)
for n in selected:visit(n)
labels=json.loads(gh('label','list','--repo',repo,'--limit','100','--json','name'))
if 'ready-for-agent' not in {x['name'] for x in labels}:gh('label','create','ready-for-agent','--repo',repo,'--color','0E8A16','--description','Specified implementation ticket; respect blockers and deferred status')
for n in order:
 key=str(n)
 if key not in state['issues']:
  body=(p/f'{n:02}-ticket.md').read_text()
  body+='\nThis child rewrites the parent scope; it does not add a task to the parity plan. The parent retains the task ID, verification instructions and evidence requirements.\n'
  body+=f'\n<!-- to-tickets-review-parent:{n} -->\n'
  # Turn task identifiers into navigable issue references, preserving soft/recommended qualifiers.
  if '## Blocked by' in body:
   head,tail=body.split('## Blocked by',1)
   for tid,parent in sorted(ids.items(),key=lambda t:-len(t[0])):
    target=state['issues'].get(str(parent),{}).get('number',parent)
    tail=re.sub(r'(?<![\w.])'+re.escape(tid)+r'(?![\w.])',f'{tid} (#{target})',tail)
   body=head+'## Blocked by'+tail
  f=p/f'{n:02}-publish.md';f.write_text(body)
  args=['issue','create','--repo',repo,'--title',sources[n]['title']+' — implementation ticket','--body-file',str(f),'--label','parity','--label','ready-for-agent']
  if any(x['name']=='deferred' for x in sources[n]['labels']):args+=['--label','deferred']
  if sources[n]['milestone']:args+=['--milestone',sources[n]['milestone']['title']]
  url=gh(*args);number=int(url.rsplit('/',1)[1]);state['issues'][key]={'number':number,'url':url};save();print('Created',n,url,flush=True)
 child=state['issues'][key];data=api(f'issues/{child["number"]}');child['id']=data['id'];save()
 if n not in state['linked']:
  api(f'issues/{n}/sub_issues','--method','POST','-F',f'sub_issue_id={data["id"]}');state['linked'].append(n);save()
 for d in deps(n):
  target=state['issues'].get(str(d),{}).get('number',d);edge=f'{child["number"]}:{target}'
  if edge not in state['edges']:
   blocker=api(f'issues/{target}')
   api(f'issues/{child["number"]}/dependencies/blocked_by','--method','POST','-F',f'issue_id={blocker["id"]}');state['edges'].append(edge);save()
for n in sorted(sources):
 if str(n) in state['comments']:continue
 body=(p/f'{n:02}-review.md').read_text()
 if str(n) in state['issues']:body+='\nApproved scope rewrite: '+state['issues'][str(n)]['url']+' (linked child issue).\n'
 body+=f'\n<!-- to-tickets-review:{n} -->\n'
 f=p/f'{n:02}-comment.md';f.write_text(body)
 url=gh('issue','comment',str(n),'--repo',repo,'--body-file',str(f));state['comments'][str(n)]=url;save();print('Reviewed',n,url,flush=True)
print('DONE',len(state['issues']),len(state['linked']),len(state['edges']),len(state['comments']),flush=True)
