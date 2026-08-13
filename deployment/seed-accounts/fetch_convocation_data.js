#!/usr/bin/env node
// Récupère les données réelles (session, membres, réglages) d'un projet
// Firebase pour reproduire côté Dart, à l'identique, le PDF que l'app
// générerait pour cette tenue — sans se connecter à l'app elle-même.
//
// Usage: node fetch_convocation_data.js --project <projectId> --service-account <chemin.json> [--session <id>] [--out <chemin.json>]

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

async function main() {
  const args = parseArgs();
  if (!args.project || !args['service-account']) {
    console.error('Usage: node fetch_convocation_data.js --project <projectId> --service-account <chemin.json> [--session <id>] [--out <chemin.json>]');
    process.exit(1);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(args['service-account'], 'utf8'));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: args.project,
  });
  const db = admin.firestore();

  let sessionDoc;
  if (args.session) {
    sessionDoc = await db.collection('sessions').doc(args.session).get();
  } else {
    // La plus récente par date, comme sessionsStream() côté app.
    const snap = await db.collection('sessions').get();
    let best = null;
    snap.forEach((d) => {
      const data = d.data();
      const dateStr = data.dateReprise || data.date || '';
      const t = Date.parse(dateStr);
      if (!best || (t && t > best.t)) best = { doc: d, t: t || 0 };
    });
    sessionDoc = best ? best.doc : null;
  }

  if (!sessionDoc || !sessionDoc.exists) {
    console.error('Aucune tenue trouvée.');
    process.exit(1);
  }

  const membersSnap = await db.collection('members').get();
  const settingsDoc = await db.collection('config').doc('settings').get();

  const out = {
    session: { id: sessionDoc.id, ...sessionDoc.data() },
    members: membersSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
    lodgeVmName: (settingsDoc.data() || {}).vmName || '',
  };

  const outPath = args.out || path.join(__dirname, 'convocation_data.json');
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log(`Session ${sessionDoc.id} (chrono ${out.session.chrono}, date ${out.session.dateReprise || out.session.date}) -> ${outPath}`);
  console.log(`Membres : ${out.members.length}, VM configuré : "${out.lodgeVmName}"`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
