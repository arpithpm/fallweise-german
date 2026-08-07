globalThis.window = {};
await import('../a1-vocabulary-data.js');
await import('../vocabulary-illustrations.js');
for (const unit of window.A1Vocabulary.units) {
  for (const item of unit.items) item.symbol = window.FallweiseIllustrations.symbolFor(item, unit);
}
const data = JSON.stringify(window.A1Vocabulary, null, 2);
await import('node:fs').then(fs => fs.writeFileSync(new URL('../FallweiseIOS/Fallweise/Resources/a1-vocabulary.json', import.meta.url), data));
