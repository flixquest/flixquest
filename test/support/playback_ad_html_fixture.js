// Offline regression check for the generated HTML. No remote code is fetched.
// Export the stream-found playbackAdHtml string as {"popunder": html}, then run:
// node test/support/playback_ad_html_fixture.js < exported-fixtures.json
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const fixtures = JSON.parse(fs.readFileSync(0, 'utf8'));

function run(html, { delayScriptLoaded = false } = {}) {
  const events = [];
  const timers = [];
  const pageListeners = new Map();
  const domListeners = new Map();
  const clicks = [];
  const document = {
    body: null,
    readyState: 'loading',
    addEventListener(name, handler) {
      const handlers = domListeners.get(name) || [];
      handlers.push(handler);
      domListeners.set(name, handlers);
    },
    getElementById() { return button; },
  };
  let button = null;
  let providerArmed = false;
  const clickListeners = [];
  const context = vm.createContext({
    document,
    PlaybackAd: { postMessage(message) { events.push(JSON.parse(message)); } },
    setTimeout(handler, delay) { timers.push({ handler, delay }); },
    addEventListener(name, handler) {
      const handlers = pageListeners.get(name) || [];
      handlers.push(handler);
      pageListeners.set(name, handlers);
    },
  });
  context.window = context;
  const deferred = [];
  let loaded;
  // The mock tag reproduces the reported failure: it immediately appends to
  // document.body, then arms its trigger on DOMContentLoaded.
  function executeTag(attrs) {
    document.body.appendChild({ tagName: 'IFRAME' });
    assert.ok(button, 'Continue control must exist before provider execution');
    document.addEventListener('DOMContentLoaded', () => { providerArmed = true; });
    const onload = /onload="([^"]+)"/.exec(attrs)[1];
    loaded = () => vm.runInContext(onload, context);
    if (!delayScriptLoaded) loaded();
  }
  const tokens = /<body\b[^>]*>|<button\b[^>]*id="fq-continue"[^>]*>|<script\b([^>]*)>([\s\S]*?)<\/script>/g;
  for (const token of html.matchAll(tokens)) {
    if (token[0].startsWith('<body')) {
      document.body = { appendChild() {} };
    } else if (token[0].startsWith('<button')) {
      button = {
        disabled: /\bdisabled\b/.test(token[0]),
        textContent: '',
        addEventListener(name, handler) {
          if (name === 'click') clickListeners.push(handler);
        },
        click() {
          clicks.push({ providerArmed, isTrusted: false });
          for (const listener of clickListeners) listener({ isTrusted: false });
        },
      };
    } else if (/\bsrc=/.test(token[1])) {
      if (/\bdefer\b/.test(token[1])) deferred.push(() => executeTag(token[1]));
      else executeTag(token[1]);
    } else {
      vm.runInContext(token[2], context);
    }
  }
  document.readyState = 'interactive';
  for (const execute of deferred) execute();
  assert.equal(clicks.length, 0, 'No activation before page initialization');
  for (const handler of domListeners.get('DOMContentLoaded') || []) handler();
  document.readyState = 'complete';
  for (const handler of pageListeners.get('load') || []) handler();
  if (delayScriptLoaded) {
    assert.equal(button.disabled, true, 'Continue must wait for the tag');
    loaded();
  }
  assert.equal(button.disabled, false, 'Tag onload enables Continue');
  assert.equal(button.textContent, 'Continue to player');
  assert.equal(clicks.length, 0, 'The page never clicks its own control');
  for (const listener of clickListeners) listener({ isTrusted: true });
  assert.equal(timers.length, 1);
  assert.equal(timers[0].delay, 750);
  timers.shift().handler();
  assert.deepEqual(events.map(event => event.event), ['loaded', 'done']);
}

// Prove the fixture detects the original null-body appendChild ordering bug.
assert.throws(() => run(fixtures.popunder.replace('<script defer ', '<script ')), /appendChild/);
run(fixtures.popunder);
run(fixtures.popunder, { delayScriptLoaded: true });
process.stdout.write('Passed: body/control ready before the tag runs, Continue enabled on load, no programmatic click.\n');
