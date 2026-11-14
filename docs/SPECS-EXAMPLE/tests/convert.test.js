// US-2.1 Convert an amount and US-2.2 Show the rate and its date: one test per acceptance
// scenario, against a stubbed API.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRates } from '../src/rates.js';
import { run } from '../src/cli.js';
import { stubApi } from './stub-api.js';

// Runs the command with a stubbed API and returns what it printed and its exit status.
async function convert(args, rates = { 'USD/EUR': { rate: 0.9022, date: '2026-11-14' } }) {
  const api = stubApi(rates);
  const out = [];
  const err = [];
  const status = await run(args.split(' '), { rates: createRates({ fetch: api.fetch }), print: (line) => out.push(line), fail: (line) => err.push(line) });
  return { out, err, status, calls: api.calls };
}

// The amount and currency at the start of a printed result.
const amountOf = (line) => line.split(' (')[0];

test('Convert and round to the cent', async () => {
  const { out, status } = await convert('20 USD EUR');
  assert.equal(status, 0);
  assert.equal(amountOf(out[0]), '18.04 EUR');
});

test('Round a half cent up', async () => {
  const { out } = await convert('20 USD EUR', { 'USD/EUR': { rate: 0.90225, date: '2026-11-14' } });
  assert.equal(amountOf(out[0]), '18.05 EUR');
});

test('Same currency needs no rate', async () => {
  const { out, calls } = await convert('20 USD USD');
  assert.equal(amountOf(out[0]), '20.00 USD');
  assert.equal(calls.length, 0);
});

test('Print the converted amount', async () => {
  const { out } = await convert('10 eur usd', { 'EUR/USD': { rate: 1.1084, date: '2026-11-14' } });
  assert.deepEqual(out, ['11.08 USD (1 EUR = 1.1084 USD on 2026-11-14)']);
});

test('Show the rate and its date', async () => {
  const { out } = await convert('20 USD EUR');
  assert.deepEqual(out, ['18.04 EUR (1 USD = 0.9022 EUR on 2026-11-14)']);
});

test('Same currency says no rate was used', async () => {
  const { out } = await convert('20 USD USD');
  assert.deepEqual(out, ['20.00 USD (same currency, no rate needed)']);
});

test('Unknown currency', async () => {
  const { out, err, status } = await convert('20 USD XYZ');
  assert.deepEqual(out, []);
  assert.deepEqual(err, ['Unknown currency: XYZ']);
  assert.equal(status, 1);
});
