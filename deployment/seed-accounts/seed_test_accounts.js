#!/usr/bin/env node
// Crée ou met à jour les comptes de test (Firebase Auth + fiche Firestore
// `members`) d'une loge, à partir d'un fichier de comptes JSON.
//
// La clé de compte de service n'est jamais commitée : elle est passée par
// chemin (--service-account), typiquement téléchargée dans un dossier hors
// dépôt (ex. Téléchargements) depuis Console Firebase > Paramètres du projet
// > Comptes de service > Générer une nouvelle clé privée.
//
// Usage :
//   npm install
//   node seed_test_accounts.js --project <projectId> --service-account <chemin.json> [--accounts <chemin.json>]
//
// Sans --accounts, cherche accounts.<projectId>.json à côté de ce script.

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function parseArgs() {
  const args = {};
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i += 2) {
    args[argv[i].replace(/^--/, '')] = argv[i + 1];
  }
  return args;
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

async function upsertAuthUser(account) {
  const auth = admin.auth();
  const displayName = `${account.firstName} ${account.lastName}`.trim();
  try {
    const existing = await auth.getUserByEmail(account.email);
    await auth.updateUser(existing.uid, {
      password: account.password,
      displayName,
      emailVerified: true,
    });
    console.log(`Auth   : ${account.email} déjà existant, mis à jour (${existing.uid}).`);
    return existing.uid;
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
    const created = await auth.createUser({
      email: account.email,
      password: account.password,
      displayName,
      emailVerified: true,
    });
    console.log(`Auth   : ${account.email} créé (${created.uid}).`);
    return created.uid;
  }
}

async function upsertMemberDoc(uid, account) {
  const doc = {
    firstName: account.firstName,
    lastName: account.lastName,
    email: account.email,
    grade: account.grade,
    function: account.function,
    status: 'Actif',
    isAdmin: false,
    authUid: uid,
  };
  await admin.firestore().collection('members').doc(uid).set(doc, { merge: true });
  console.log(`Firestore: members/${uid} (${account.email}) écrit.`);
}

async function main() {
  const args = parseArgs();
  if (!args.project || !args['service-account']) {
    console.error(
      'Usage: node seed_test_accounts.js --project <projectId> --service-account <chemin.json> [--accounts <chemin.json>]',
    );
    process.exit(1);
  }

  const accountsPath = args.accounts || path.join(__dirname, `accounts.${args.project}.json`);
  if (!fs.existsSync(accountsPath)) {
    console.error(`Fichier de comptes introuvable : ${accountsPath}`);
    process.exit(1);
  }
  const accounts = readJson(accountsPath);

  const serviceAccount = readJson(args['service-account']);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: args.project,
  });

  for (const account of accounts) {
    const uid = await upsertAuthUser(account);
    await upsertMemberDoc(uid, account);
  }

  console.log(`Terminé : ${accounts.length} compte(s) synchronisé(s) sur ${args.project}.`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
