// The command: convert <amount> <from> <to>. Returns the exit status.
import { UnknownCurrencyError } from './rates.js';
import { convert, format } from './convert.js';

export async function run(argv, { rates, print = console.log, fail = console.error }) {
  const [amount, from, to] = argv;
  if (!amount || !from || !to) {
    fail('Usage: convert <amount> <from> <to>');
    return 2;
  }
  try {
    print(format(await convert(amount, from, to, rates)));
    return 0;
  } catch (error) {
    if (error instanceof UnknownCurrencyError) {
      fail(error.message);
      return 1;
    }
    throw error;
  }
}
