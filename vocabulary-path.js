(() => {
  const {units,items,count}=window.A1Vocabulary;
  const params=new URLSearchParams(location.search),requested=params.get('unit'),reviewId=params.get('review');
  const els={grid:document.getElementById('unitGrid'),search:document.getElementById('vocabSearch'),searchCount:document.getElementById('searchCount'),lesson:document.getElementById('unitLesson'),practice:document.getElementById('unitPractice'),title:document.getElementById('unitTitle'),goal:document.getElementById('unitGoal'),kicker:document.getElementById('unitKicker'),words:document.getElementById('wordList'),start:document.getElementById('startPractice'),count:document.getElementById('count'),kind:document.getElementById('exerciseKind'),question:document.getElementById('question'),answers:document.getElementById('answers'),feedback:document.getElementById('feedback'),next:document.getElementById('next'),result:document.getElementById('vocabResult'),mastery:document.getElementById('vocabMastery')};
  document.querySelectorAll('[data-word-count]').forEach(el=>el.textContent=count);
  let progress=new Map(),unit=units.find(row=>row.id===requested)||null,api=null,activities=[],index=0,locked=false,results=[],started=performance.now(),baseline={};
  const ready=()=>new Promise(resolve=>{if(window.FallweiseProgress)resolve(window.FallweiseProgress);else addEventListener('fallweise:ready',event=>resolve(event.detail),{once:true})});
  const display=item=>item.article?`${item.article} ${item.de}`:item.de;
  const normalize=value=>String(value).trim().toLocaleLowerCase('de-DE').replace(/[.!?]/g,'').replace(/\s+/g,' ');
  const shuffled=array=>[...array].sort(()=>Math.random()-.5);
  const distract=(item,field)=>shuffled(unit.items.filter(row=>row!==item).map(row=>field==='display'?display(row):row[field]).filter((value,i,all)=>value&&all.indexOf(value)===i)).slice(0,3);
  const choices=(correct,others)=>shuffled([correct,...others]);

  function renderUnits(filter=''){
    const query=normalize(filter),matches=units.filter(row=>!query||normalize(`${row.title} ${row.goal} ${row.items.map(item=>`${item.de} ${item.en}`).join(' ')}`).includes(query));
    els.searchCount.textContent=`${matches.length} ${matches.length===1?'UNIT':'UNITS'} · ${matches.reduce((sum,row)=>sum+row.items.length,0)} WORDS`;
    els.grid.innerHTML=matches.length?matches.map((row,i)=>{const saved=progress.get(`vocabulary-a1:${row.id}`),label=saved?.status==='completed'?`✓ ${Math.round(Number(saved.mastery||0)*100)}% recalled`:saved?'Continue practice':'Not started';return `<a class="unit" href="vocabulary-path.html?unit=${row.id}#unitLesson"><div class="unit-top"><span class="unit-icon" aria-hidden="true">${row.icon}</span><span class="unit-number">UNIT ${String(units.indexOf(row)+1).padStart(2,'0')}</span></div><h3>${row.title}</h3><p>${row.goal}</p><div class="unit-foot"><span>${row.items.length} words</span><span class="unit-progress">${label} →</span></div></a>`}).join(''):'<div class="empty">No match yet. Try a German word, its English meaning, or a broader topic.</div>';
  }
  els.search.oninput=event=>renderUnits(event.target.value);

  function renderUnit(){
    if(!unit)return;
    els.lesson.hidden=false;els.kicker.textContent=`Unit ${String(units.indexOf(unit)+1).padStart(2,'0')} · 20 words`;els.title.textContent=unit.title;els.goal.textContent=unit.goal+'. Tap a card to reveal the meaning; use the speaker to hear the complete German item.';
    els.words.innerHTML=unit.items.map(item=>`<article class="curriculum-word" tabindex="0" role="button" aria-label="Reveal the meaning of ${display(item)}"><span class="word-type">${item.type}${item.article?` · ${item.article}`:''}</span><div class="german">${display(item)}</div><div class="plural">${item.type==='noun'?`Plural: ${item.plural}`:'&nbsp;'}</div><div class="english">${item.en}</div><span class="tap">TAP TO REVEAL</span></article>`).join('');
    els.words.querySelectorAll('.curriculum-word').forEach(card=>{const toggle=()=>card.classList.toggle('revealed');card.onclick=event=>{if(!event.target.closest('.speak-btn'))toggle()};card.onkeydown=event=>{if(event.key==='Enter'||event.key===' '){event.preventDefault();toggle()}}});
    if(location.hash==='#unitLesson')requestAnimationFrame(()=>els.lesson.scrollIntoView({block:'start'}));
  }

  function buildActivities(){
    activities=unit.items.map((item,i)=>{
      if(item.type==='noun'&&i%4===1)return {item,type:'article',skill:'form',kind:'Article retrieval',prompt:`Which article belongs with ${item.de}?`,options:['der','die','das'],correct:item.article};
      if(i%5===2)return {item,type:'listening',skill:'listening',kind:'Listen without reading',prompt:'Which meaning matches what Vivian says?',options:choices(item.en,distract(item,'en')),correct:item.en,audio:true};
      if(i%5===3)return {item,type:'spelling',skill:'meaning',kind:'Produce the German',prompt:`Type the German ${item.type==='noun'?'noun (article not needed)':'word or phrase'} for “${item.en}”.`,answers:[item.de],correct:item.de};
      if(i%5===4)return {item,type:'reverse',skill:'meaning',kind:'English to German',prompt:`Which German item means “${item.en}”?`,options:choices(display(item),distract(item,'display')),correct:display(item)};
      return {item,type:'meaning',skill:'meaning',kind:'Meaning from memory',prompt:`What does “${display(item)}” mean?`,options:choices(item.en,distract(item,'en')),correct:item.en};
    });
    if(reviewId){const parts=reviewId.split(':'),item=unit.items.find(row=>row.id===parts[2]),type=parts[3];if(item){const one=activities.find(a=>a.item===item&&a.type===type)||activities.find(a=>a.item===item);activities=[one]}}
  }
  function score(skill){const prior=baseline[skill]||{attempts:0,correct_attempts:0},session=results.filter(row=>row.skill===skill),attempts=prior.attempts+session.length,correct=prior.correct_attempts+session.filter(row=>row.correct).length;return attempts?Math.round(correct/attempts*100):0}
  function renderMastery(){els.mastery.innerHTML=[['meaning','Meaning'],['form','Form'],['listening','Listening']].map(([id,label])=>`<div><span>${label}</span><b>${score(id)}%</b></div>`).join('')}
  function renderActivity(){
    locked=false;started=performance.now();const activity=activities[index];els.count.textContent=`ACTIVITY ${index+1} OF ${activities.length}`;els.kind.textContent=activity.kind;els.question.textContent=activity.prompt;els.answers.innerHTML='';els.feedback.textContent='';els.next.style.display='none';els.result.classList.remove('show');
    if(activity.audio){const audio=document.createElement('div');audio.className='german';audio.textContent=display(activity.item);els.answers.appendChild(audio)}
    if(activity.options)activity.options.forEach(option=>{const button=document.createElement('button');button.className='answer';button.textContent=option;button.onclick=()=>submit(normalize(option)===normalize(activity.correct),button,option);els.answers.appendChild(button)});
    else{const form=document.createElement('form');form.className='vocab-form';form.innerHTML='<input aria-label="Your answer" autocomplete="off" autocapitalize="none" required><button>Check</button>';form.onsubmit=event=>{event.preventDefault();const input=form.querySelector('input'),value=input.value;submit(activity.answers.some(answer=>normalize(answer)===normalize(value)),input,value)};els.answers.appendChild(form)}
  }
  async function submit(correct,target,selected){
    if(locked)return;locked=true;const activity=activities[index],elapsed=Math.round(performance.now()-started);target.classList?.add(correct?'correct':'wrong');if(activity.options)[...els.answers.querySelectorAll('.answer')].find(button=>normalize(button.textContent)===normalize(activity.correct))?.classList.add('correct');
    const packageText=activity.item.type==='noun'?`${display(activity.item)} · ${activity.item.plural} · ${activity.item.en}`:`${activity.item.de} · ${activity.item.en}`;els.feedback.textContent=correct?`Richtig! ${packageText}`:`Not yet. The answer is “${activity.correct}”. ${packageText}`;els.next.style.display='inline-block';els.next.disabled=true;els.next.textContent=index===activities.length-1?'See my result →':'Next activity →';results.push({skill:activity.skill,correct});renderMastery();await save(activity,correct,selected,elapsed);els.next.disabled=false;
  }
  async function save(activity,correct,selected,response_ms){
    api=api||await ready();const now=new Date().toISOString(),done=index===activities.length-1,lessonId=`vocabulary-a1:${unit.id}`,mastery=results.filter(row=>row.correct).length/activities.length,skillId=`vocab-a1-${unit.id}:${activity.skill}`,prior=baseline[activity.skill]||{attempts:0,correct_attempts:0,current_streak:0},session=results.filter(row=>row.skill===activity.skill),attempts=prior.attempts+session.length,correctAttempts=prior.correct_attempts+session.filter(row=>row.correct).length;
    api.recordAttempt({exercise_id:`vocab:A1-${unit.id}:${activity.item.id}:${activity.type}`,skill_id:skillId,lesson_id:lessonId,exercise_type:activity.type==='spelling'?'fill_blank':activity.type==='listening'?'listening':'choice',answer:{selected,prompt:activity.prompt},correct,hints_used:0,response_ms,attempted_at:now});
    if(!reviewId)api.saveLesson({lesson_id:lessonId,status:done?'completed':'in_progress',mastery,current_step:index+1,total_steps:activities.length,last_activity_at:now,...(index===0?{started_at:now}:{}),...(done?{completed_at:now}:{})});
    api.saveSkill({skill_id:skillId,level:'A1',domain:activity.skill==='listening'?'listening':'vocabulary',mastery:correctAttempts/attempts,attempts,correct_attempts:correctAttempts,current_streak:correct?(prior.current_streak||0)+1:0,last_practised_at:now});
    const due=new Date(now);due.setMinutes(due.getMinutes()+(correct?1440:10));api.saveReview({item_id:`vocab:A1-${unit.id}:${activity.item.id}:${activity.type}`,skill_id:skillId,item_type:activity.type==='reverse'?'meaning':activity.type,interval_days:correct?1:0,ease_factor:correct?2.5:2.3,repetitions:correct?1:0,lapses:correct?0:1,due_at:due.toISOString(),last_reviewed_at:now,suspended:false});
  }
  function finish(){const correct=results.filter(row=>row.correct).length,weak=[['meaning','Meaning'],['form','Form'],['listening','Listening']].sort((a,b)=>score(a[0])-score(b[0]))[0][1];els.question.textContent='';els.answers.innerHTML='';els.feedback.textContent='';els.kind.textContent='';els.next.style.display='none';els.result.classList.add('show');els.result.innerHTML=`<div class="kicker" style="color:var(--lime)">${reviewId?'Review':'Unit'} complete</div><h3>${correct}/${activities.length} retrieved</h3><p>${reviewId?'This memory has a new review date.':`Your next focus is <b>${weak}</b>. Difficult items will return sooner.`}</p><a href="${reviewId?'index.html':`vocabulary-path.html#curriculum`}">${reviewId?'Back to today’s learning':'Choose the next unit'} →</a>`}
  function startPractice(){els.practice.hidden=false;els.practice.scrollIntoView({behavior:'smooth'});buildActivities();index=0;results=[];renderMastery();renderActivity()}
  els.start.onclick=startPractice;els.next.onclick=()=>{if(index===activities.length-1)return finish();index++;renderActivity()};
  renderUnits();renderUnit();
  ready().then(async value=>{api=value;if(api.client){const [{data:rows},{data:skills}]=await Promise.all([api.client.from('lesson_progress').select('*').like('lesson_id','vocabulary-a1:%'),unit?api.client.from('skill_mastery').select('*').like('skill_id',`vocab-a1-${unit.id}:%`):Promise.resolve({data:[]})]);progress=new Map((rows||[]).map(row=>[row.lesson_id,row]));(skills||[]).forEach(row=>baseline[row.skill_id.split(':').pop()]=row);renderUnits(els.search.value);renderMastery()}if(reviewId&&unit)startPractice()});
})();
