// Today's reference rate for a currency pair, from Frankfurter: daily reference rates
// from central banks, free and without an API key.
export const API = 'https://api.frankfurter.dev/v2/rate';

export class UnknownCurrencyError extends Error {
  constructor(code) {
    super(`Unknown currency: ${code}`);
    this.name = 'UnknownCurrencyError';
    this.code = code;
  }
}

// A currency code is three letters; input is case-insensitive (BR-001).
export const normalize = (code) => String(code).trim().toUpperCase();

// Today's calendar date, YYYY-MM-DD, in local time.
export const localDay = () => new Date().toLocaleDateString('en-CA');

// `fetch` and `today` are passed in so tests can replace the API with a stub that counts
// calls, and set the day. Rates are kept in memory only, by pair and day (BR-003).
export function createRates({ fetch = globalThis.fetch, today = localDay } = {}) {
  const memory = new Map();
  async function getRate(base, quote) {
    const from = normalize(base);
    const to = normalize(quote);
    const key = `${from}/${to}/${today()}`;
    if (memory.has(key)) return memory.get(key);
    const response = await fetch(`${API}/${from}/${to}`);
    if (response.status === 422) {
      const body = await response.json().catch(() => ({}));
      const match = /invalid currency: (\w+)/i.exec(body.message || '');
      throw new UnknownCurrencyError(match ? match[1].toUpperCase() : to);
    }
    if (!response.ok) throw new Error(`The rate API answered HTTP ${response.status}`);
    const { rate, date } = await response.json();
    const result = { base: from, quote: to, rate, date };
    memory.set(key, result);
    return result;
  }
  return { getRate };
}
