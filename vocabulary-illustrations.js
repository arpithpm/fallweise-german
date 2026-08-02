(() => {
  const palettes={der:['#8dc8d8','#e8bd48'],die:['#f1886f','#ffd4c9'],das:['#75b68c','#d9ed72'],other:['#917fb3','#d8cdee']};
  /* Each sequence follows the authored order of its twenty-word unit. These are
     semantic prompts, not unit badges: every card receives its own visual cue. */
  const symbols={
    hello:'👋|🌅|☀️|🌇|🌙|👋|🚪|⏳|🌄|🤗|🙏|💐|🤲|🙇|👌|✅|❌|🤔|😊|💬',
    identity:'🏷️|👤|🪪|🏠|🛣️|🔢|🏙️|🌍|☎️|📧|🎂|📍|🏳️|🗣️|📛|🏡|➡️|💬|🔤|🙋',
    family:'👪|👩|👨|👫|👦|👧|🧒|👦|👧|👵|👴|👵|👴|🤵|👩|🧑|👩‍🦰|👶|💍|☝️',
    people:'🧑|🧔|👩|🏘️|👩‍🦰|👦|👧|🎩|👒|🛎️|🌱|🧓|📏|🤏|😊|🤝|😂|🤫|🥱|😄',
    home:'🏠|🏢|🚪|🛋️|🛏️|🧸|🍳|🛁|🚽|🚶|🌇|🌻|📦|🏬|🚪|🪟|🧱|🪵|💶|📦',
    furniture:'🪵|🪑|🛋️|🛏️|🚪|📚|💡|🧶|🪞|🚿|🧊|🔥|🫧|📺|🔑|☕|🥛|🍽️|🔪|🍴',
    food:'🍽️|🥐|🥗|🍲|🍞|🥖|🧈|🧀|🥚|🥩|🐟|🍚|🍝|🥔|🥣|🥗|🥦|🍇|🍎|🍌',
    drinks:'💧|☕|🍵|🥛|🧃|🍺|🍷|🍾|🥤|🥄|🧂|🧂|🌶️|🍰|🍫|🍴|🥤|🍳|😋|🤤',
    shopping:'🏪|🛒|🧺|🥐|🧾|🏷️|💶|🪙|💰|💳|🧾|🏷️|⚖️|⚖️|🛍️|💳|🏷️|🧺|⬇️|⬆️',
    clothes:'👚|👖|👖|👗|👗|👔|👕|🧶|🧥|🧥|👞|🧦|🧢|📐|🔴|🔵|🟢|⚫|⚪|🟡',
    numbers:'0️⃣|1️⃣|2️⃣|3️⃣|4️⃣|5️⃣|6️⃣|7️⃣|8️⃣|9️⃣|🔟|1️⃣1️⃣|1️⃣2️⃣|1️⃣3️⃣|2️⃣0️⃣|3️⃣0️⃣|💯|1️⃣K|📚|🤏',
    time:'⏳|🕰️|⌛|⏱️|📆|☕|▶️|⏹️|📍|⬅️|➡️|⚡|⏭️|🌅|🌙|🌄|☀️|🌆|❓|🕢',
    calendar:'1️⃣|2️⃣|3️⃣|4️⃣|5️⃣|6️⃣|7️⃣|📅|🎉|🗓️|🎆|📆|🎂|🌷|☀️|🍂|❄️|🔁|☀️|🎲',
    weather:'🌦️|☀️|🌧️|❄️|💨|☁️|🌡️|🌌|🌳|🌸|⛰️|🏞️|🌊|♨️|🥶|🔥|😎|🌬️|🌥️|☔',
    routine:'🛏️|⏰|🚿|👕|🥐|▶️|💼|📖|🛒|🧹|🧽|🫧|📺|☎️|🏠|😴|♾️|🔁|🌙|🚫',
    actions:'🟰|🎒|🛠️|🚶|🚗|🛑|🎁|✋|🔎|🔍|👁️|👂|📖|✍️|❓|💬|🤝|⏳|🔓|🔒',
    school:'🏫|📚|👥|👨‍🏫|👩‍🏫|👦|👧|📝|❓|✅|📕|📓|🖊️|📄|🔤|💬|📃|📋|💡|🔁',
    work:'💼|🧑‍🔧|🏢|🖥️|👔|👩‍💼|🧑‍💼|👩‍💼|🧔|👩|💻|🖥️|☎️|✉️|👥|🌇|👨‍⚕️|👩‍💼|💶|🏖️',
    city:'🎯|🏛️|🌳|🚉|🚏|✈️|🏦|📮|⚕️|🏥|👮|🏛️|📚|🏺|🎬|🍽️|☕|🛎️|⛪|🏊',
    directions:'🛣️|➕|🚦|↪️|🌉|🚌|🚆|🚄|🚇|🚋|🚕|🚗|🚲|🎫|⬅️|➡️|⬆️|↔️|📍|🚪',
    travel:'🗺️|🏖️|🥾|🧳|👜|🛂|🎫|✈️|🛎️|🛏️|🛏️🛏️|🌙|🛬|🚉|🛤️|🌍|📅|📝|📍|🚆',
    body:'🧍|🙂|😊|👁️|👂|👃|👄|🦷|🧣|🔙|💪|✋|☝️|🤰|🦵|🦶|💇|❤️|💚|🤒',
    health:'💚|🦠|⚡|🤕|🌡️|😷|🤧|💊|💊|🩺|🚨|🆘|🤕|😷|🙂|🛌|💊|🌷|👨‍⚕️|☎️',
    'free-time':'⏰|🎯|🎵|📷|📸|🎉|🎲|🎸|🎮|💃|🎤|📸|🎨|✏️|🥾|🚶|🧑‍🤝‍🧑|🎧|💌|💡',
    sport:'🏅|⚽|🎾|👥|⚽|📻|📰|💬|🎬|📺|🌐|📱|🏊|🏃|🚴|🏋️|🏆|😞|⚡|🐢',
    conversation:'👂|🔁|🐢|🤷|❓|🇩🇪|🆘|🤔|✅|🎯|💭|⏳|🙇|🛍️|🤲|📍|⏰|🏷️|❤️|👋',
    core:'🙋|👉|🎩|👨|👩|📦|👥|👨‍👩‍👧|❓|❔|📍|⬅️|➡️|⏰|💭|🤔|➕|🔀|↩️|🔗',
    housing:'🏘️|🔑|👩|📜|🛗|🪜|♨️|⚡|🗑️|📬|🔧|🔊|💥|🛋️|↔️|🖌️|🔨|📦➡️|📦⬅️|📣',
    'work-life':'📨|📄|💼|🎓|⭐|⏰|💶|✍️|📋|🏢|👥|🛡️|⏱️|🤝|💻|📨|✍️|🚪|🙋|✅',
    relationships:'💞|👋|💌|💒|🎁|🚪|📅|💥|💭|❤️|🤝|👤|😲|😞|👍|📅|🥂|🎉|🤔|💔',
    services:'📄|📝|🪪|🛡️|🧾|🏦|✍️|📑|🏛️|🕘|💶|📨|✅|🚨|✍️|🖊️|📬|💸|📦|📅',
    experiences:'✨|🏰|🏠|🛏️|🏞️|🚧|⏳|🔗|↩️|📘|🚶|⚡|⏱️|😍|🥵|👀|🔎|💭|🏃|🛏️',
    'health-care':'🔍|🩹|🕘|📜|🧴|🤕|🌼|🩺|🩸|🏥|🛡️|🌱|🔎|🩹|🫁|🤕|✍️|💫|🩼|🌼',
    restaurant:'📖|🍽️|🥗|🍛|🍰|📝|🧑‍🍳|💶|👅|🧅|🥣|📅|☝️|🍽️|🥄|👍|😋|🥦|🌶️|😊',
    consumer:'📦|⭐|®️|🛡️|🔄|↩️|🏷️|🏬|🧑‍💼|🗂️|🚚|⭐|🔄|↩️|⚖️|👕|🚚|⬇️|♻️|🚫',
    mobility:'🗓️|🧍|🚗|🚙|💥|↪️|🅿️|⛽|🪪|⚡|🛣️|🚶|🔄|🛑|🅿️|⛽|🏎️|🚧|🈵|⚠️',
    study:'👨‍🏫|📅|📘|💯|📜|🗣️|👥|✏️|🔤|👄|📖|🙋|✅|❌|🔎|🌐|📝|🗣️|🎓|🧩',
    'digital-life':'📱|📄|📁|⌨️|🖱️|🖨️|🌐|🔍|⚙️|💾|🔋|🔌|💾|🗑️|🖨️|☁️|📲|🟢|⚫|🪫',
    communication:'💬|☎️|📬|🎙️|🔔|👤|📥|📤|🏷️|📎|↩️|ℹ️|↪️|📝|🎯|📢|❌|📶|☎️|🎩',
    emotions:'😄|😨|😟|🌟|😲|😞|😠|😵|🧘|🙂|⚡|😊|🥳|😤|🙏|😰|🫶|😬|🦚|😌',
    culture:'🌍|🎵|🎭|🖼️|🎪|👥|🎨|🎬|🚪|🎟️|📖|🎫|🎤|👀|❤️|👏|🥱|⚡|😄|💡',
    nature:'🌿|🌲|🌱|🏞️|🏝️|🌊|🏔️|🪴|🐾|🐦|🚜|👀|🌱|🌸|🔭|🧗|⛺|➖|📐|🐺',
    housework:'🏠|👕|🍽️|🧹|🧹|🪣|🧴|🧰|🔨|🔩|💡|📋|🫧|👔|🧹|🪝|🔄|✨|🟤|📐',
    money:'🏦|💳|💳|💶|🏧|💸|📤|📥|📉|📈|🧮|🪙|⬅️💶|➡️💶|🐷|🤲|🛍️|🆓|📅|📊',
    language:'🌐|🏠🗣️|🔤|💡|🧩|❌|📏|🗣️|💬|📈|🎯|👥|🧠|🏋️|✏️|💬|👄|🌊|🔊|🔁',
    celebrations:'🎊|🎉|🕯️|🎄|🐣|🎆|🏅|🎀|🕯️|💐|🎉|🪅|🎀|🎁|🥂|🌠|📋|✨|🏷️|⭐',
    problems:'❓|🔍|💡|⚙️|💥|📣|🔄|🚧|💬❓|🚨|🧑‍🔧|🛣️|🧩|🔎|📢|🔄|⚙️|✅|🚫|🛡️',
    planning:'📝|📅|⏰|❗|📋|📁|👣|⌛|🔄|💡|🧰|🗂️|✏️|⏭️|📌|🗒️|➗|✅|↔️|🟢',
    'family-changes':'👪|💑|🤵|👰|👦|👧|🧔|👩|👶|↔️|💔|🌱|💍|↔️|🌱|🫶|🤲|🤰|🧑|🔗',
    community:'🏠|🏛️|🏙️|🤝|📍|🧺|🛝|🏫|🏛️|🚛|📌|📊|🙋|➕|🧺|❤️|📢|📍|🤲|🌐',
    'travel-details':'🧳|🎒|🚗|🌍|📍|🏢|✈️|🛫|🛬|🛂|🛃|🛡️|🧳|🛬|❌|⏳|🔄|➡️|🌐|➕',
    'news-weather':'🌦️|🌡️|⛈️|🌪️|🌫️|🌊|📢|📰|📄|🎙️|📍|🔮|🗞️|⚠️|📈|📉|📅|🏜️|💧|💥',
    society:'🌍|👥|🤝|🙋|🏛️|🎪|🧩|⚖️|🪙|🛡️|➕|📊|🌐|🤲|❤️|🙋|🤝|🌱|✊|🗳️',
    environment:'🌍|🌡️|⚡|📊|📦|🗑️|🪨|🚗|🚜|🛡️|♻️|☣️|☀️|📍|🧠|♻️|🚫|🛡️|💧|📉',
    media:'📡|📰|📢|🔗|📣|🔒|🔑|🌐|⏱️|👤|⚡|💻|✅|🟢|🔗|📤|📥|↗️|🔍|🎯',
    education:'🎓|🧠|💪|📚|🏛️|📜|🔬|📈|🎯|🧭|🧍|🔎|🛠️|📐|♾️|🌱|🧰|💬|⚖️|⬆️',
    arguments:'📍|💬|➕|➖|💡|➡️|🧩|⚖️|🛣️|↔️|1️⃣|2️⃣|↩️|➡️|🎲|📢|👍|👎|⚖️|🎯'
  };
  const guide=article=>{const kind=article==='der'?'MAX':article==='die'?'MIA':article==='das'?'BOT':'WORT';if(article==='das')return `<g transform="translate(12 12)"><path d="M18 11V5m-4-1h8" class="line"/><rect x="4" y="11" width="28" height="29" rx="7" fill="#d9ed72" class="line"/><circle cx="13" cy="24" r="2"/><circle cx="23" cy="24" r="2"/><path d="M12 32h12" class="line"/></g><text x="27" y="59">${kind}</text>`;const female=article==='die';return `<g transform="translate(9 7)"><circle cx="20" cy="19" r="12" fill="#e1a47c" class="line"/>${female?'<path d="M8 19Q7 1 21 2t13 20Q25 9 12 14v14Q8 24 8 19" fill="#f1886f" class="line"/>':'<path d="M8 15Q14 1 34 9l-2 7Q18 9 8 15" fill="#e8bd48" class="line"/>'}<circle cx="16" cy="19" r="1.5"/><circle cx="24" cy="19" r="1.5"/><path d="M16 25q4 3 8 0M7 50q2-21 13-21t14 21" fill="${female?'#f1886f':'#8dc8d8'}" class="line"/></g><text x="27" y="59">${kind}</text>`};
  const safe=value=>String(value).replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  function symbolFor(item,unit){const entries=symbols[unit.id],index=unit.items.indexOf(item);if(!entries)throw new Error(`Missing illustration unit: ${unit.id}`);const symbol=entries.split('|')[index];if(!symbol)throw new Error(`Missing illustration: ${unit.id}/${item.de}`);return symbol}
  function scene(item,unit){const [main,accent]=palettes[item.article||'other'],glyph=symbolFor(item,unit),label=(item.article||item.type).toUpperCase(),action=item.type==='verb'?'<path d="M117 57q10 7 21 0M198 57q-10 7-21 0" fill="none" class="motion"/>':item.type==='adjective'||item.type==='adverb'?'<path d="M121 26l4 4m66-4l-4 4m-63 29l-4 4m70-4l4 4" class="motion"/>':'<path d="M137 61h40" class="motion"/>';return `<svg viewBox="0 0 240 92" role="img" aria-label="Illustration of ${safe(item.de)}"><style>.line{stroke:#18201d;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}.motion{stroke:#18201d;stroke-width:1.5;stroke-linecap:round;stroke-dasharray:2 4}text{font:700 8px DM Sans,Arial;letter-spacing:.08em;fill:#18201d}.glyph{font:34px Apple Color Emoji,Segoe UI Emoji,Noto Color Emoji,sans-serif}</style><rect width="240" height="92" rx="8" fill="${main}"/><circle cx="205" cy="18" r="30" fill="${accent}" opacity=".9"/><path d="M0 74q76-20 147 1t93-2v19H0Z" fill="#fff" opacity=".7"/>${guide(item.article)}<g transform="translate(105 8)"><rect width="112" height="63" rx="18" fill="#fff" opacity=".86" class="line"/><text x="56" y="16" text-anchor="middle">${safe(label)}</text><text class="glyph" x="56" y="52" text-anchor="middle">${safe(glyph)}</text></g>${action}<path d="M72 73c38-9 91-8 143 1" fill="none" class="line" stroke-dasharray="3 6"/></svg>`}
  function audit(units){const missing=[];for(const unit of units){const entries=symbols[unit.id]?.split('|')||[];if(entries.length!==unit.items.length)missing.push(`${unit.id}: ${entries.length}/${unit.items.length}`);unit.items.forEach((item,index)=>{if(!entries[index])missing.push(`${unit.id}/${item.de}`)})}return missing}
  window.FallweiseIllustrations={scene,symbolFor,audit};
})();
