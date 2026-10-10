// Execute the production landing-page check without fetching any ad.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const script = fs.readFileSync(0, 'utf8');
const url = 'https://advertiser.example/offer?tracking=retained#section';
const body = {
  innerText: 'A sponsored offer with visible content',
  getBoundingClientRect: () => ({
    width: 320, height: 480, top: 0, left: 0, right: 320, bottom: 480,
  }),
  querySelectorAll: () => [],
};
const context = vm.createContext({
  document: {
    body,
    readyState: 'loading',
    title: 'Sponsored offer',
    contentType: 'text/html',
  },
  location: { href: url },
  innerWidth: 320,
  innerHeight: 480,
  getComputedStyle: () => ({
    display: 'block', visibility: 'visible', opacity: '1', backgroundImage: 'none',
  }),
});
function inspect() { return JSON.parse(vm.runInContext(script, context)); }
for (const state of ['loading', 'interactive']) {
  context.document.readyState = state;
  assert.equal(inspect().ready, false, `Must wait for ${state} to finish`);
}
context.document.readyState = 'complete';
let report = inspect();
assert.equal(report.ready, true);
assert.equal(report.readyState, 'complete');
assert.equal(report.url, url, 'Must report the actual document, including tracking');
body.innerText = '';
assert.equal(inspect().ready, false, 'A finished blank redirect is not an ad');
context.document.body = null;
assert.equal(inspect().ready, false, 'A missing body is not a landing page');
process.stdout.write('Passed: loading state, document URL, visible content and blank redirects.\n');
