const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('lib/service/browser_transport.dart', 'utf8');
const body = source.match(/const browserFetchScript = r'''([\s\S]*?)''';/)[1];
function execute(url, method, payload, fetch) {
  const context = vm.createContext({
    URL, Uint8Array, AbortController, setTimeout, clearTimeout, btoa,
    location: { origin: 'https://www.wenku8.net' },
    fetch, requestUrl: url, requestMethod: method, requestBody: payload,
  });
  return vm.runInContext('(async () => {' + body + '})()', context);
}
test('GET retains browser credentials and exact GBK response bytes', async () => {
  const result = await execute('https://www.wenku8.net/userdetail.php', 'GET', null,
    async (url, options) => {
      assert.equal(options.credentials, 'same-origin');
      assert.ok(options.signal instanceof AbortSignal);
      assert.equal(options.method, 'GET');
      return new Response(new Uint8Array([0xd6, 0xd0, 0xce, 0xc4]), { status: 200 });
    });
  assert.equal(result.status, 200);
  assert.deepEqual(Buffer.from(result.body, 'base64'), Buffer.from([0xd6, 0xd0, 0xce, 0xc4]));
});
test('POST sends existing encoded form without changing tokens', async () => {
  await execute('https://www.wenku8.net/modules/article/reviews.php', 'POST', 'title=%D6%D0+test',
    async (url, options) => {
      assert.equal(options.body, 'title=%D6%D0+test');
      assert.equal(options.headers['Content-Type'], 'application/x-www-form-urlencoded');
      return new Response('ok');
    });
});
test('credentials are never sent to a different website', async () => {
  let called = false;
  await assert.rejects(execute('https://other.example/userdetail.php', 'GET', null,
    async () => { called = true; return new Response(''); }), /selected website/);
  assert.equal(called, false);
});
test('403 challenge remains visible instead of being treated as successful HTML', async () => {
  const result = await execute('https://www.wenku8.net/userdetail.php', 'GET', null,
    async () => new Response('challenge', { status: 403, headers: { 'cf-mitigated': 'challenge' } }));
  assert.equal(result.status, 403);
  assert.equal(result.challenge, true);
});

test('ordinary 403 is distinguished and returns response correlation metadata', async () => {
  const result = await execute('https://www.wenku8.net/userdetail.php', 'GET', null,
    async () => new Response('forbidden', { status: 403, headers: { 'cf-ray': 'abcdef0123456789-HKG' } }));
  assert.equal(result.status, 403);
  assert.equal(result.challenge, false);
  assert.equal(result.ray, 'abcdef0123456789-HKG');
});
