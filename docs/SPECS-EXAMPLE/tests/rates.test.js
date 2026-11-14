// US-1.1 Fetch a daily rate and US-1.2 Keep rates in memory: one test per acceptance
// scenario, against a stubbed API.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRates, UnknownCurrencyError } from '../src/rates.js';
import { stubApi } from './stub-api.js';

test("Fetch today's rate for a pair", async () => {
  const api = stubApi();
  const { getRate } = createRates({ fetch: api.fetch });
  const result = await getRate('USD', 'EUR');
  assert.equal(result.rate, 0.9022);
  assert.equal(result.date, '2026-11-14');
});

test('Accept lower-case currency codes', async () => {
  const api = stubApi();
  const { getRate } = createRates({ fetch: api.fetch });
  await getRate('usd', 'eur');
  assert.equal(api.calls.length, 1);
  assert.equal(api.calls[0], 'https://api.frankfurter.dev/v2/rate/USD/EUR');
});

test('Report an unknown currency code', async () => {
  const api = stubApi();
  const { getRate } = createRates({ fetch: api.fetch });
  await assert.rejects(getRate('USD', 'XYZ'), (error) => {
    assert.ok(error instanceof UnknownCurrencyError);
    assert.equal(error.message, 'Unknown currency: XYZ');
    return true;
  });
});

test('Reuse a rate on the same day', async () => {
  const api = stubApi();
  const { getRate } = createRates({ fetch: api.fetch, today: () => '2026-11-14' });
  await getRate('USD', 'EUR');
  const again = await getRate('USD', 'EUR');
  assert.equal(again.rate, 0.9022);
  assert.equal(api.calls.length, 1);
});

test('Fetch again on a new day', async () => {
  const api = stubApi();
  let day = '2026-11-13';
  const { getRate } = createRates({ fetch: api.fetch, today: () => day });
  await getRate('USD', 'EUR');
  day = '2026-11-14';
  await getRate('USD', 'EUR');
  assert.equal(api.calls.length, 2);
});
