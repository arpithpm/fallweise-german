import fs from 'node:fs';
import vm from 'node:vm';

const root = new URL('../', import.meta.url);
const context = vm.createContext({ window: {} });
for (const file of ['advanced-vocabulary-data.js', 'a2-vocabulary-expansion.js']) {
  vm.runInContext(fs.readFileSync(new URL(file, root), 'utf8'), context, { filename: file });
}
vm.runInContext(fs.readFileSync(new URL('vocabulary-illustrations.js', root), 'utf8'), context, { filename: 'vocabulary-illustrations.js' });

for (const level of ['A2', 'B1']) {
  const source = context.window.AdvancedVocabulary[level];
  const data = {
    level,
    units: source.units.map(unit => ({ ...unit, items: unit.items.map(item => ({
      ...item,
      unitTitle: unit.title,
      symbol: context.window.FallweiseIllustrations.symbolFor(item, unit)
    })) })),
    items: source.items,
    count: source.count
  };
  const target = new URL(`FallweiseIOS/Fallweise/Resources/${level.toLowerCase()}-vocabulary.json`, root);
  fs.writeFileSync(target, `${JSON.stringify(data, null, 2)}\n`);
  console.log(`${level}: ${data.count} words across ${data.units.length} units`);
}
