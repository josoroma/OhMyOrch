// Convert an amount between two currencies at today's rate (US-2.1), and print it with
// the rate and its date (US-2.2).
import { normalize } from './rates.js';

// Round to the nearest cent, a half cent rounding up (BR-002). The detour through six
// decimals removes binary noise such as 1804.5000000000002 before rounding.
export const cents = (value) => Math.round(Number((value * 100).toFixed(6))) / 100;

export async function convert(amount, from, to, rates) {
  const value = Number(amount);
  if (!Number.isFinite(value)) throw new Error(`Not an amount: ${amount}`);
  const base = normalize(from);
  const quote = normalize(to);
  // The same currency needs no rate, so the API is not called (BR-004).
  if (base === quote) return { amount: cents(value), currency: quote };
  const { rate, date } = await rates.getRate(base, quote);
  return { amount: cents(value * rate), currency: quote, from: base, rate, date };
}

// The converted amount, then the rate and its date (US-2.2), or a note that none was needed.
export function format(result) {
  const amount = `${result.amount.toFixed(2)} ${result.currency}`;
  if (result.rate === undefined) return `${amount} (same currency, no rate needed)`;
  return `${amount} (1 ${result.from} = ${result.rate} ${result.currency} on ${result.date})`;
}
