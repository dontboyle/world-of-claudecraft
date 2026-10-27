// Seeds LAN accounts listed in SEED_ACCOUNTS (in .env.local, which is git-ignored: this
// fork is public, so family logins never land in the repo). Format, comma-separated:
//   SEED_ACCOUNTS=username:password:email,username:password:email
// Accounts are created through the server's own functions (the same scrypt hash and
// accounts row as /api/register) but straight in the database, so registration's shape
// rules (3+ character usernames, 6+ character passwords) do not apply; login does not
// re-check them. Existing usernames are left untouched, so rerunning is safe.
// Run with the VS Code task "Setup: seed LAN accounts", which bundles this with esbuild.
import { createAccount } from '../server/account_create_db';
import { hashPassword, normalizeEmail } from '../server/auth';
import { findAccount, pool, setAccountEmail } from '../server/db';

interface SeedAccount {
  username: string;
  password: string;
  email: string;
}

function parseSeedAccounts(raw: string): SeedAccount[] {
  return raw
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => {
      const [username = '', password = '', email = ''] = entry.split(':');
      const normalized = normalizeEmail(email);
      // Name only the username in errors: the entry also holds the password.
      if (!username || !password || !normalized) {
        throw new Error(`SEED_ACCOUNTS entry for "${username}" needs username:password:email`);
      }
      return { username, password, email: normalized };
    });
}

async function main(): Promise<void> {
  const accounts = parseSeedAccounts(process.env.SEED_ACCOUNTS ?? '');
  if (accounts.length === 0) {
    throw new Error('SEED_ACCOUNTS is empty; add username:password:email entries to .env.local.');
  }
  for (const { username, password, email } of accounts) {
    if (await findAccount(username)) {
      console.log(`${username}: already exists, left unchanged`);
      continue;
    }
    const account = await createAccount(username, await hashPassword(password));
    await setAccountEmail(account.id, email);
    console.log(`${username}: created (account ${account.id}, ${email})`);
  }
}

main()
  .catch((err: unknown) => {
    console.error(err instanceof Error ? err.message : err);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
