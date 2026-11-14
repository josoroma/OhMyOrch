// A stand-in for the Frankfurter API: canned rates, a list of codes it rejects, and a
// record of every request, so tests run offline and can count calls.
export function stubApi(rates = { 'USD/EUR': { rate: 0.9022, date: '2026-11-14' } }, { invalid = ['XYZ'] } = {}) {
  const calls = [];
  async function fetch(url) {
    calls.push(url);
    const [base, quote] = new URL(url).pathname.split('/').slice(-2);
    const bad = [base, quote].find((code) => invalid.includes(code));
    if (bad) return reply(422, { status: 422, message: `invalid currency: ${bad}` });
    const entry = rates[`${base}/${quote}`];
    if (!entry) return reply(404, { status: 404, message: 'rate not found' });
    return reply(200, { date: entry.date, base, quote, rate: entry.rate });
  }
  return { fetch, calls };
}

const reply = (status, body) => ({ status, ok: status >= 200 && status < 300, json: async () => body });
