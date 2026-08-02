const path=require('path');
global.window=global;
require(path.join(__dirname,'..','a1-vocabulary-data.js'));
const {units,items,count}=global.A1Vocabulary;
const errors=[];
const assert=(condition,message)=>{if(!condition)errors.push(message)};
const unique=(values,label)=>{const seen=new Set();for(const value of values){assert(!seen.has(value),`Duplicate ${label}: ${value}`);seen.add(value)}};
assert(count>=500&&count<=700,`Expected 500–700 entries, found ${count}`);
assert(units.length>=20,'Curriculum needs at least 20 manageable units');
units.forEach(unit=>{assert(unit.items.length>=12&&unit.items.length<=20,`${unit.id} has ${unit.items.length} entries; expected 12–20`);assert(unit.title&&unit.goal,`${unit.id} needs a title and practical goal`)});
unique(items.map(item=>item.id),'ID');
unique(items.map(item=>`${item.de.toLocaleLowerCase('de-DE')}|${item.en.toLowerCase()}`),'German/English entry');
items.forEach(item=>{assert(item.de&&item.en,`${item.id} needs German and English`);assert(item.example&&item.exampleEn,`${item.id} needs a bilingual example`);if(item.type==='noun'){assert(['der','die','das'].includes(item.article),`${item.id} needs a valid article`);assert(item.plural,`${item.id} needs a plural or — mass marker`)}});
if(errors.length){console.error(errors.join('\n'));process.exit(1)}
const types=items.reduce((all,item)=>(all[item.type]=(all[item.type]||0)+1,all),{});
console.log(`✓ ${count} unique A1 entries in ${units.length} units`);
console.log(`✓ ${types.noun} nouns · ${types.verb} verbs · ${count-types.noun-types.verb} other useful words and phrases`);
