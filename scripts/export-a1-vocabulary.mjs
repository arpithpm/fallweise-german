globalThis.window = {};
await import('../a1-vocabulary-data.js');
const data = JSON.stringify(window.A1Vocabulary, null, 2);
await import('node:fs').then(fs => fs.writeFileSync(new URL('../FallweiseIOS/Fallweise/Resources/a1-vocabulary.json', import.meta.url), data));
