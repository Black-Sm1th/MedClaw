// Ensure the account expiry uses the package end_time matched by credit-lot code,
// not the monthly credit-lot expires_at.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const qml = fs.readFileSync(
  path.resolve(__dirname, '../main.qml'),
  'utf8',
).replace(/\r\n/g, '\n');

function extract(name) {
  const signature = `    function ${name}(`;
  const start = qml.indexOf(signature);
  if (start < 0) throw new Error(`function ${name} not found`);

  const open = qml.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < qml.length; ++i) {
    if (qml[i] === '{') depth += 1;
    if (qml[i] === '}') depth -= 1;
    if (depth === 0) return qml.slice(start, i + 1);
  }
  throw new Error(`end of ${name} not found`);
}

const helpers = [
  extract('accountPlanName'),
  extract('accountIsAddon'),
  extract('accountCreditGroups'),
  extract('accountExpiry'),
].join('\n');
const createAccountHelpers = new Function(`
  ${helpers}
  return { accountCreditGroups, accountExpiry };
`);
const { accountCreditGroups, accountExpiry } = createAccountHelpers();

const groups = accountCreditGroups(
  [{
    code: 'standard-monthly',
    subscription_id: 'lot-subscription',
    status: 'ACTIVE',
    credits_total: 3000,
    credits_remaining: 2500,
    expires_at: '2026-10-31T15:59:59Z',
  }],
  [{
    code: 'standard-monthly',
    subscription_id: 'package-subscription',
    status: 'ACTIVE',
    end_time: '2027-03-31T15:59:59Z',
  }, {
    code: 'standard-monthly',
    subscription_id: 'renewed-package-subscription',
    status: 'ACTIVE',
    end_time: '2028-03-31T15:59:59Z',
  }],
);

assert.equal(groups.length, 1);
assert.equal(
  groups[0].expiresAt,
  '2028-03-31T15:59:59Z',
  'the latest matching package end_time should replace the monthly credit-lot expiry',
);
assert.equal(accountExpiry(groups), '2028-03-31T15:59:59Z');

const unmatchedGroups = accountCreditGroups(
  [{
    code: 'standard-monthly',
    status: 'ACTIVE',
    credits_total: 3000,
    credits_remaining: 2500,
    expires_at: '2026-10-31T15:59:59Z',
  }],
  [],
);
assert.equal(
  accountExpiry(unmatchedGroups),
  '',
  'the monthly credit expiry must not be used if no package end_time matches',
);

console.log('account expiry checks passed');
