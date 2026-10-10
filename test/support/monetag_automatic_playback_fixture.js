// Offline JavaScript behavior checks; no ad requests or clicks are made.
// Run from the project root: node test/support/monetag_automatic_playback_fixture.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('lib/widgets/adsterra_playback_ad_screen.dart', 'utf8');
const script = /const monetagAutomaticPlaybackScript = r'''([\s\S]*?)''';/.exec(source)[1];
const fallback = /const monetagTriggerPlaybackScript = r'''([\s\S]*?)''';/.exec(source)[1];

function setup({ status = 200, hook = true, button = true, disabled = false, throws = false } = {}) {
  const messages = [];
  const requests = [];
  let now = 0;
  let triggerCount = 0;
  let interval;
  const listeners = {};
  const control = { disabled };
  const window = hook ? {
    onClickTrigger() {
      triggerCount++;
      if (throws) throw new Error('tag failure');
    },
  } : {};
  window.addEventListener = (type, handler) => { listeners[type] = handler; };
  const context = vm.createContext({
    window, URL,
    document: { getElementById: () => button ? control : null },
    navigator: { userActivation: { isActive: true } },
    Date: { now: () => now },
    performance: { getEntriesByType: () => requests },
    setInterval(handler) { interval = handler; return 1; },
    clearInterval() { interval = undefined; },
    PlaybackAd: { postMessage(message) { messages.push(JSON.parse(message)); } },
  });
  vm.runInContext(script, context);
  return {
    context, messages, control, listeners,
    get triggerCount() { return triggerCount; },
    tick(ms = 100) { now += ms; interval?.(); },
    finishRequest() {
      requests.push({ name: 'https://ads.example/5/11983408/', responseStatus: status });
    },
  };
}

for (const status of [200, 0]) {
  const check = setup({ status });
  check.tick(1000);
  assert.equal(check.triggerCount, 0, 'script load alone must not trigger an unarmed tag');
  check.finishRequest();
  check.tick();
  check.tick(400);
  assert.deepEqual(check.messages, [], 'allow asynchronous tag initialization to finish');
  check.tick(100);
  assert.deepEqual(check.messages, [{ event: 'activation_ready' }]);
  assert.equal(check.triggerCount, 0, 'the native touch must run before any hook fallback');
  vm.runInContext(script, check.context);
  check.tick(2000);
  assert.deepEqual(check.messages, [{ event: 'activation_ready' }], 'one native attempt per document');
  vm.runInContext(fallback, check.context);
  vm.runInContext(fallback, check.context);
  assert.equal(check.triggerCount, 1, 'unsupported native input gets one hook fallback');
}
const empty = setup({ status: 204 });
empty.finishRequest();
empty.tick();
assert.equal(empty.triggerCount, 0);
assert.deepEqual(empty.messages, [{
  event: 'empty', url: 'https://ads.example/5/11983408/',
}]);

const missing = setup({ button: false });
missing.finishRequest();
missing.tick(10000);
assert.equal(missing.triggerCount, 0);
assert.deepEqual(missing.messages, []);

const disabled = setup({ disabled: true });
disabled.finishRequest();
disabled.tick(1000);
assert.deepEqual(disabled.messages, []);
disabled.control.disabled = false;
disabled.tick();
disabled.tick(500);
assert.deepEqual(disabled.messages, [{ event: 'activation_ready' }]);

const nativeOnly = setup({ hook: false });
nativeOnly.finishRequest();
nativeOnly.tick();
nativeOnly.tick(500);
assert.deepEqual(nativeOnly.messages, [{ event: 'activation_ready' }], 'native touch does not require a private hook');
nativeOnly.listeners.click({ target: { id: 'fq-continue' }, isTrusted: true });
assert.deepEqual(nativeOnly.messages[1], { event: 'input', trusted: true, active: true });
vm.runInContext(fallback, nativeOnly.context);
assert.equal(nativeOnly.messages[2].event, 'failed');

const failure = setup({ throws: true });
failure.finishRequest();
failure.tick();
failure.tick(500);
vm.runInContext(fallback, failure.context);
assert.equal(failure.triggerCount, 1);
assert.equal(failure.messages[2].event, 'failed');
failure.tick(2000);
assert.equal(failure.triggerCount, 1);
process.stdout.write('Passed: Monetag native readiness, initialization wait, one attempt, input reporting, hook fallback and empty/missing/error handling.\n');
