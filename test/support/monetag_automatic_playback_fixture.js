// Offline JavaScript behavior checks; no ad requests or clicks are made.
// Run from the project root: node test/support/monetag_automatic_playback_fixture.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('lib/widgets/adsterra_playback_ad_screen.dart', 'utf8');
const script = /const monetagAutomaticPlaybackScript = r'''([\s\S]*?)''';/.exec(source)[1];

function setup({ status = 200, hook = true, throws = false } = {}) {
  const messages = [];
  const requests = [];
  let now = 0;
  let triggerCount = 0;
  let interval;
  const window = hook ? {
    onClickTrigger() {
      triggerCount++;
      if (throws) throw new Error('tag failure');
    },
  } : {};
  const context = vm.createContext({
    window, URL,
    Date: { now: () => now },
    performance: { getEntriesByType: () => requests },
    setInterval(handler) { interval = handler; return 1; },
    clearInterval() { interval = undefined; },
    PlaybackAd: { postMessage(message) { messages.push(JSON.parse(message)); } },
  });
  vm.runInContext(script, context);
  return {
    context, messages,
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
  assert.equal(check.triggerCount, 0, 'allow asynchronous tag initialization to finish');
  check.tick(100);
  assert.equal(check.triggerCount, 1, 'trigger the popup without a user click');
  vm.runInContext(script, check.context);
  check.tick(2000);
  assert.equal(check.triggerCount, 1, 'one attempt per document, including duplicate injection');
  assert.deepEqual(check.messages, [{ event: 'activated' }]);
}
const empty = setup({ status: 204 });
empty.finishRequest();
empty.tick();
assert.equal(empty.triggerCount, 0);
assert.deepEqual(empty.messages, [{
  event: 'empty', url: 'https://ads.example/5/11983408/',
}]);

const missing = setup({ hook: false });
missing.finishRequest();
missing.tick(10000);
assert.equal(missing.triggerCount, 0);
assert.deepEqual(missing.messages, []);

const failure = setup({ throws: true });
failure.finishRequest();
failure.tick();
failure.tick(500);
assert.equal(failure.triggerCount, 1);
assert.equal(failure.messages[1].event, 'failed');
failure.tick(2000);
assert.equal(failure.triggerCount, 1);
process.stdout.write('Passed: automatic Monetag activation, initialization wait, one attempt, empty/missing/error handling.\n');
