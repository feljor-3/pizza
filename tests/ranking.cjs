const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict');
class El {
 constructor(tag='div'){this.tagName=tag;this.children=[];this.hidden=false;this.value='';this.classList={toggle(){}};this.style={};this.files=[];this.elements=[];this.disabled=false;this.attributes={};}
 append(...x){this.children.push(...x)}replaceChildren(...x){this.children=[...x]}setAttribute(k,v){this.attributes[k]=v}removeAttribute(k){delete this.attributes[k]}querySelector(){return new El('button')}querySelectorAll(){return this.children.flatMap(x=>[x,...x.children]).filter(x=>x.tagName==='input'&&x.checked)}focus(){}scrollIntoView(){}reset(){}addEventListener(){}showModal(){this.open=true}close(){this.open=false}
}
const els={},timers=[];const ctx={document:{getElementById:id=>els[id]??=new El(),createElement:tag=>new El(tag),addEventListener(){},querySelectorAll(){return []}},window:{addEventListener(){}},URL,Image:class{},crypto:require('crypto').webcrypto,setTimeout:fn=>(timers.push(fn),timers.length),clearTimeout(){},console,confirm:()=>true,localStorage:{getItem(){},setItem(){},removeItem(){}}};vm.createContext(ctx);
const script=fs.readFileSync(require('node:path').join(__dirname,'..','index.html'),'utf8').match(/<script>\n([\s\S]*?)<\/script>/)[1];vm.runInContext(script,ctx);const run=s=>vm.runInContext(s,ctx);
(async()=>{
 assert.equal(run("normalizeName('  ANA   Silva ')"),'ana silva');
 run("person='Ana';pizzas=[{id:'a',nome:'A',casal:'1',autores:['ana']},{id:'b',nome:'B',casal:'2',autores:[]},{id:'c',nome:'C',casal:'3',autores:[]},{id:'d',nome:'D',casal:'4',autores:[]},{id:'e',nome:'E',casal:'5',autores:[]}];participants=[{nome:'ana',exibicao:'Ana'}];ballots=[];loaded=true;registered=true;render()");
 assert.equal(els['ranking-fields'].children.length,8);assert(els.reveal.hidden);
 const ownCard=els['pizza-list'].children[0];assert(ownCard.children[1].children.some(e=>e.disabled&&e.textContent==='Sua pizza · fora do seu ranking'));
 assert.equal(run("JSON.stringify(eligibleChoices(['a','b','b','missing','c'],pizzas,'ana'))"),'["b","c"]');
 run("ballots=[{votante:'ana',escolhas:['b','c','d','e']}]");
 assert.equal(run("JSON.stringify(rankPizzas(pizzas,ballots).map(p=>[p.id,p.points]))"),'[["b",5],["c",4],["d",3],["e",2],["a",0]]');
 run("ballots.push({votante:'bia',escolhas:['c','b']});revealed=true;render()");assert(!els.results.hidden);assert(els.ranking.children[0].textContent.includes('Empate'));
 run("draft=['b','c'];lastSaved=[];render()");assert(!els['save-ranking'].disabled);
 // Saved result remains separate from unsaved edits, then is replaced atomically.
 ctx.calls=[];ctx.fail=false;ctx.server=[];ctx.dbPizzas=run('pizzas');ctx.dbParticipants=run('participants');
 ctx.mockDb={from(table){return {
 upsert(payload,options){ctx.calls.push({table,payload,options});return {select(){return {single:async()=>{if(ctx.fail)return {error:{message:'offline'}};ctx.server=[payload];return {data:payload};}};}};},
 select(){const response={data:table==='pizzas'?ctx.dbPizzas:table==='participantes'?ctx.dbParticipants:ctx.server};const p=Promise.resolve(response);p.order=async()=>response;return p;},
 delete(){ctx.calls.push({delete:true});return {eq:async()=>({error:null})};}
 };}};
 run('channel={};db=mockDb');
 await run('saveRanking()');assert.equal(ctx.calls[0].options.onConflict,'votante');assert.equal(JSON.stringify(ctx.calls[0].payload.escolhas),'["b","c"]');assert.equal(run('dirty()'),false);
 run("draft=['c','b'];fail=true");await run('saveRanking()');assert.equal(run("JSON.stringify(draft)"),'["c","b"]');assert.equal(run("JSON.stringify(savedChoices())"),'["b","c"]');assert(els.notice.textContent.includes('não foi confirmado'));
 // Deleted/now-owned pizzas are dropped from a draft while remote refresh preserves edits.
 run("fail=false;dbPizzas=dbPizzas.filter(p=>p.id!=='b')");await run('refresh()');assert.equal(run('JSON.stringify(draft)'),'["c"]');
 ctx.confirm=()=>false;const count=ctx.calls.length;await run("deletePizza('c')");assert.equal(ctx.calls.length,count);
 // Ranking can be explicitly cleared and result gate closes.
 run('draft=[]');await run('saveRanking()');assert(els.results.hidden);assert(els.reveal.hidden);
 // Link dialog displays registered participants and existing ownership.
 run("openOwners('a')");assert(els['owners-dialog'].open);assert(els['owners-list'].children[0].children[0].checked);
 console.log('PASS: 5/4/3/2 points, aggregate tie, self exclusion, duplicate filtering, four slots, saved-result gate, atomic save, retry preservation, deleted-choice reconciliation, deletion cancellation, ranking clear, participant dialog.');
})().catch(e=>{console.error(e);process.exitCode=1});
