import { getAuth, signInWithPopup, GoogleAuthProvider } from 'firebase/auth';
import { Session, Member, Visitor } from '../types';

// ─── CONSTANTES ──────────────────────────────────────────────────
export const DRIVE_PARENT_FOLDER_ID = "11Qp8SXLFG0Spfks-G6OAQ66EHMGjEOgy";

let cachedAccessToken: string | null = null;
let cachedUserEmail: string | null = null;

// ─── AUTHENTIFICATION ──────────────────────────────────────────
export async function authenticateGoogleDrive(): Promise<{ token: string; email: string }> {
  if (cachedAccessToken && cachedUserEmail) {
    return { token: cachedAccessToken, email: cachedUserEmail };
  }

  const auth = getAuth();
  const provider = new GoogleAuthProvider();
  // Drive.file ne permet pas toujours l'accès aux dossiers existants partagés.
  // Utiliser la portée complète pour le dossier Google Drive ciblé.
  provider.addScope('https://www.googleapis.com/auth/drive');
  provider.addScope('https://www.googleapis.com/auth/userinfo.email');
  provider.addScope('https://www.googleapis.com/auth/userinfo.profile');

  try {
    const result = await signInWithPopup(auth, provider);
    const credential = GoogleAuthProvider.credentialFromResult(result);
    if (!credential?.accessToken) {
      throw new Error('Impossible d\'obtenir le jeton d\'accès.');
    }
    cachedAccessToken = credential.accessToken;
    cachedUserEmail = result.user.email || 'Utilisateur Google';
    return { token: cachedAccessToken, email: cachedUserEmail };
  } catch (error: any) {
    console.error('Erreur Google Drive:', error);
    const code = error?.code || error?.message || 'unknown_error';
    switch (code) {
      case 'auth/popup-closed-by-user':
        throw new Error('La fenêtre de connexion a été fermée avant validation.');
      case 'auth/popup-blocked':
      case 'auth/cancelled-popup-request':
        throw new Error('La fenêtre de connexion a été bloquée ou annulée. Autorisez les popups et réessayez.');
      case 'auth/operation-not-allowed':
        throw new Error('Google Sign-In n’est pas activé dans Firebase Authentication. Activez le fournisseur Google dans la console Firebase.');
      case 'auth/unauthorized-domain':
        throw new Error('Domaine non autorisé. Ajoutez votre domaine local ou distant aux domaines autorisés dans la console Firebase (authentification Google).');
      case 'auth/account-exists-with-different-credential':
        throw new Error('Ce compte Google existe déjà avec une autre méthode d\'authentification. Utilisez le même compte ou supprimez le lien actuel.');
      default:
        throw new Error(error?.message || `Échec de la connexion à Google Drive. Vérifiez les autorisations et la configuration Firebase (${code}).`);
    }
  }
}

export function hasGoogleDriveToken(): boolean {
  return !!cachedAccessToken;
}

export function disconnectGoogleDrive() {
  cachedAccessToken = null;
  cachedUserEmail = null;
}

// ─── GESTION DES DOSSIERS ──────────────────────────────────────
export function getSessionDetails(session: Session) {
  const numOnly = (session.sessionNumber || '').replace(/[^\d]/g, '');
  const chrono = numOnly ? numOnly.padStart(2, '0') : '03';
  let jj = '01', mm = '01', annee = '2026';
  const dateValue = session.date || session.dateReprise || '';
  if (dateValue) {
    const parts = dateValue.split('T')[0].split('-');
    if (parts.length === 3) {
      annee = parts[0];
      mm = parts[1];
      jj = parts[2];
    } else {
      const d = new Date(dateValue);
      jj = String(d.getDate()).padStart(2, '0');
      mm = String(d.getMonth() + 1).padStart(2, '0');
      annee = String(d.getFullYear());
    }
  }
  return { chrono, jj, mm, annee };
}

export function getDriveFolderName(session: Session): string {
  const { chrono, jj, mm, annee } = getSessionDetails(session);
  return `Tenue ${chrono} ${jj} ${mm} ${annee}`;
}

export async function findOrCreateFolder(token: string, folderName: string, parentId: string): Promise<string> {
  const q = `mimeType='application/vnd.google-apps.folder' and name='${folderName.replace(/'/g, "\\'")}' and '${parentId}' in parents and trashed = false`;
  const searchUrl = `https://www.googleapis.com/drive/v3/files?q=${encodeURIComponent(q)}&fields=files(id,name)`;
  const searchRes = await fetch(searchUrl, { headers: { Authorization: `Bearer ${token}` } });
  if (!searchRes.ok) throw new Error(`Erreur recherche dossier: ${await searchRes.text()}`);
  const searchData = await searchRes.json();
  if (searchData.files && searchData.files.length > 0) {
    return searchData.files[0].id;
  }
  const createUrl = 'https://www.googleapis.com/drive/v3/files';
  const createRes = await fetch(createUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      name: folderName,
      mimeType: 'application/vnd.google-apps.folder',
      parents: [parentId]
    })
  });
  if (!createRes.ok) throw new Error(`Erreur création dossier: ${await createRes.text()}`);
  const folder = await createRes.json();
  return folder.id;
}

export async function uploadOrCreateFile(
  token: string,
  folderId: string,
  fileName: string,
  htmlContent: string
): Promise<string> {
  const q = `name='${fileName.replace(/'/g, "\\'")}' and '${folderId}' in parents and trashed = false`;
  const searchUrl = `https://www.googleapis.com/drive/v3/files?q=${encodeURIComponent(q)}&fields=files(id,name)`;
  const searchRes = await fetch(searchUrl, { headers: { Authorization: `Bearer ${token}` } });
  if (!searchRes.ok) throw new Error(`Erreur recherche fichier: ${await searchRes.text()}`);
  const searchData = await searchRes.json();
  let fileId = '';
  if (searchData.files && searchData.files.length > 0) {
    fileId = searchData.files[0].id;
  } else {
    const createUrl = 'https://www.googleapis.com/drive/v3/files';
    const createRes = await fetch(createUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        name: fileName,
        parents: [folderId],
        mimeType: 'application/vnd.google-apps.document'
      })
    });
    if (!createRes.ok) throw new Error(`Erreur création document: ${await createRes.text()}`);
    const fileData = await createRes.json();
    fileId = fileData.id;
  }
  const uploadUrl = `https://www.googleapis.com/upload/drive/v3/files/${fileId}?uploadType=media`;
  const uploadRes = await fetch(uploadUrl, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'text/html; charset=utf-8'
    },
    body: htmlContent
  });
  if (!uploadRes.ok) throw new Error(`Erreur archivage: ${await uploadRes.text()}`);
  return fileId;
}

export async function uploadBlobToDrive(
  token: string,
  folderId: string,
  fileName: string,
  blob: Blob
): Promise<void> {
  const formData = new FormData();
  formData.append('metadata', new Blob([JSON.stringify({
    name: fileName,
    parents: [folderId],
  })], { type: 'application/json' }));
  formData.append('file', blob);

  const res = await fetch('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: formData,
  });
  if (!res.ok) throw new Error(`Erreur upload du fichier: ${await res.text()}`);
}

// ─── GÉNÉRATION DES DOCUMENTS HTML ────────────────────────────
function formatDateFrench(dateStr: string): string {
  if (!dateStr) return 'Date inconnue';
  const date = new Date(dateStr);
  if (isNaN(date.getTime())) return 'Date inconnue';
  return date.toLocaleDateString('fr-FR', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  });
}

export function generateOrdreDuJourHtml(session: Session, members: Member[], visitors: Visitor[]): string {
  const { chrono, jj, mm, annee } = getSessionDetails(session);
  const formattedDate = formatDateFrench(session.date);
  const customLinesHtml = (session.customLines || [])
    .filter(line => line.trim() !== '')
    .map(line => `<li>${line}</li>`)
    .join('');
  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
body { font-family: 'Times New Roman', Georgia, serif; line-height: 1.6; color: #111; max-width: 800px; margin: 40px auto; padding: 20px; }
.header { text-align: center; border-bottom: 2px solid #1a365d; padding-bottom: 15px; margin-bottom: 25px; }
.motto { font-size: 10px; font-style: italic; color: #4a5568; letter-spacing: 1px; text-transform: uppercase; }
h1 { font-size: 18px; font-weight: bold; text-transform: uppercase; color: #1a365d; margin: 10px 0 5px 0; }
h2 { font-size: 14px; font-weight: bold; color: #2d3748; margin: 0 0 10px 0; }
.sub-header { font-size: 12px; font-style: italic; color: #4a5568; margin-bottom: 10px; }
.title-box { border: 2px solid #000; padding: 15px; text-align: center; margin: 25px auto; max-width: 550px; background-color: #fafafa; }
.title-box h3 { font-size: 12px; font-weight: bold; margin: 0; letter-spacing: 1px; }
.title-box p { font-size: 15px; font-weight: 900; margin: 8px 0 0 0; }
.invocation { text-align: center; font-style: italic; color: #701a75; font-size: 13px; margin: 25px 0; }
.egyptian-date { text-align: center; color: #1d4ed8; font-weight: bold; font-style: italic; font-size: 14px; margin: 20px 0; }
.agenda-title { font-weight: bold; text-decoration: underline; font-size: 13px; text-transform: uppercase; margin-top: 30px; }
ol { margin-top: 10px; padding-left: 20px; }
li { margin-bottom: 10px; font-size: 13px; }
.custom-agenda { margin-top: 20px; border-top: 1px dashed #cbd5e1; padding-top: 15px; }
.footer { margin-top: 50px; border-top: 1px solid #e2e8f0; padding-top: 20px; font-size: 11px; color: #64748b; text-align: center; }
</style></head><body>
<div class="header"><div class="motto">A La Gloire Du Sublime Architecte des Mondes</div>
<h1>Ordre Initiatique Ancien et Primitif de Memphis Misraïm</h1>
<h2>Respectable Loge Bénou Ré (Orient de Saint-Pierre)</h2>
<div class="sub-header">Ex Cineribus, Ad Lucem Perpetuam</div>
<div style="font-size: 11px; font-weight: bold; color: #4b5563;">GRANDE LOGE DE BOURBON</div></div>
<div class="title-box"><h3>ORDRE DU JOUR DE LA TENUE RÉGULIÈRE DU</h3><p>${formattedDate.toUpperCase()}</p></div>
<div class="invocation"><p>A la Gloire Du Grand Architecte De l’Univers,</p>
<p><strong>Mes TT∴CC∴SS∴ et TT∴CC∴FF∴,</strong></p>
<p>La R∴L∴ Bénou Ré a la grande joie de vous convier fraternellement à participer aux Travaux de sa</p>
<p style="font-weight: bold; color: #581c87; margin-top: 10px;">${session.sessionNumber || chrono + '°'} Tenue au grade d'${session.degree}</p></div>
<div class="egyptian-date"><p>Le jour de naissance de ${session.deityName || "Bénou"}</p>
<p>De l’an ${session.egyptianYear || "6026"} de la Lumière d’Egypte</p></div>
<div class="agenda-title">L'ordre du jour appellera :</div>
<ol><li>${session.agenda1 || '16:30 Reprise des travaux'}</li>
<li>${session.agenda2 || 'Lecture de la planche thématique'}</li>
<li>${session.agenda3 || 'Circulation du tronc de la Veuve et du sac aux propositions'}</li>
<li>${session.agenda4 || '18:30 Suspension des travaux'}</li></ol>
${customLinesHtml ? `<div class="custom-agenda"><div style="font-weight: bold; font-size: 13px; margin-bottom: 8px;">Travaux et Planches d'Architecture :</div><ul>${customLinesHtml}</ul></div>` : ''}
<div style="margin-top: 40px; border-top: 1px solid #000; padding-top: 15px;">
<table style="width: 100%; font-size: 12px;"><tr><td style="width: 50%; vertical-align: top;"><strong>Secrétaire de l'Atelier</strong><br>S∴ Muriel MARTIN-FANTINO</td>
<td style="width: 50%; text-align: right; vertical-align: top;"><strong>Vénérable Maître</strong><br>V∴M∴ ${session.vmName || 'Bruno GAUDIN'}</td></tr></table></div>
<div class="footer">Document officiel archivé automatiquement sur Google Drive • Temple Thérèse Eliseman à Saint-Pierre</div>
</body></html>`;
}

export function generateEmargementHtml(session: Session, members: Member[], visitors: Visitor[]): string {
  const normalizedSession = {
    ...session,
    presentIds: session.presentIds || [],
    excusedIds: session.excusedIds || [],
    visitorIds: session.visitorIds || [],
    signatures: session.signatures || {},
    visitorRoles: session.visitorRoles || {},
    title: session.title || '',
    location: session.location || session.lieuReunion || '',
    date: session.date || session.dateReprise || '',
    type: session.type || 'Ordinaire',
    degree: session.degree || 'Apprenti',
    troncAmount: session.troncAmount || 0,
    closingTime: session.closingTime || '18:30',
  };
  const formattedDate = formatDateFrench(normalizedSession.date || normalizedSession.dateReprise || '');
  const presentMembers = members.filter(m => normalizedSession.presentIds.includes(m.id));
  const excusedMembers = members.filter(m => normalizedSession.excusedIds.includes(m.id));
  const presentVisitors = visitors.filter(v => normalizedSession.visitorIds.includes(v.id));
  const membersRowsHtml = presentMembers.length > 0 
    ? presentMembers.map(m => {
        const signature = normalizedSession.signatures[m.id];
        return `<tr><td><strong>${m.firstName} ${m.lastName}</strong></td><td>${m.function !== 'Aucun' ? m.function : 'Membre de l\'Atelier'}</td><td class="sig-cell">${signature ? `<img src="${signature}" alt="Signature de ${m.firstName} ${m.lastName}" style="max-height: 65px; max-width: 180px; object-fit: contain;" />` : '<span style="color: #94a3b8; font-style: italic;">Néant</span>'}</td></tr>`;
      }).join('')
    : '<tr><td colspan="3" style="text-align: center; color: #94a3b8;">Aucun membre présent enregistré</td></tr>';
  const excusedRowsHtml = excusedMembers.length > 0
    ? excusedMembers.map(m => `<tr><td><strong>${m.firstName} ${m.lastName}</strong></td><td>${m.function !== 'Aucun' ? m.function : 'Membre'}</td><td style="color: #d97706; font-style: italic;">Excuse(e)</td></tr>`).join('')
    : '<tr><td colspan="3" style="text-align: center; color: #94a3b8;">Aucune excuse enregistrée</td></tr>';
  const visitorsRowsHtml = presentVisitors.length > 0
    ? presentVisitors.map(v => {
        const signature = normalizedSession.signatures[v.id];
        return `<tr><td><strong>${v.firstName} ${v.lastName}</strong></td><td>${v.lodge} (${v.orient})</td><td>${(session.visitorRoles?.[v.id]) || v.function || 'Visiteur'}</td><td class="sig-cell">${signature ? `<img src="${signature}" alt="Signature de ${v.firstName} ${v.lastName}" style="max-height: 65px; max-width: 180px; object-fit: contain;" />` : '<span style="color: #94a3b8; font-style: italic;">Néant</span>'}</td></tr>`;
      }).join('')
    : '<tr><td colspan="4" style="text-align: center; color: #94a3b8;">Aucun visiteur présent enregistré</td></tr>';
  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
body { font-family: 'Times New Roman', Georgia, serif; line-height: 1.5; color: #111; max-width: 800px; margin: 40px auto; padding: 20px; }
.header { text-align: center; border-bottom: 2px solid #1a365d; padding-bottom: 15px; margin-bottom: 25px; }
.motto { font-size: 10px; font-style: italic; color: #4a5568; letter-spacing: 1px; text-transform: uppercase; }
h1 { font-size: 18px; font-weight: bold; text-transform: uppercase; color: #1a365d; margin: 10px 0 5px 0; }
h2 { font-size: 14px; font-weight: bold; color: #2d3748; margin: 0 0 10px 0; }
.title-box { text-align: center; border-top: 1px solid #ddd; border-bottom: 1px solid #ddd; padding: 10px 0; margin: 20px 0; }
.title-box h3 { margin: 0; font-size: 15px; text-transform: uppercase; color: #111; letter-spacing: 1px; }
.title-box p { margin: 5px 0 0 0; font-size: 11px; color: #4a5568; }
.info-grid { display: table; width: 100%; border: 1px solid #cbd5e1; background-color: #f8fafc; margin-bottom: 30px; font-size: 12px; }
.info-row { display: table-row; }
.info-cell { display: table-cell; padding: 10px; border: 1px solid #cbd5e1; }
h4 { font-size: 12px; font-weight: bold; text-transform: uppercase; color: #1e293b; border-bottom: 1px solid #1e293b; padding-bottom: 4px; margin-top: 30px; letter-spacing: 0.5px; }
table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 12px; }
th { border: 1px solid #cbd5e1; padding: 8px; background-color: #f1f5f9; text-align: left; font-weight: bold; }
td { border: 1px solid #cbd5e1; padding: 8px; vertical-align: middle; }
.sig-cell { text-align: center; width: 150px; }
.tronc-box { border: 1px solid #cbd5e1; padding: 15px; background-color: #fafafa; margin-top: 30px; font-size: 12px; }
.footer { margin-top: 50px; border-top: 1px solid #e2e8f0; padding-top: 20px; font-size: 11px; color: #64748b; text-align: center; }
</style></head><body>
<div class="header"><div class="motto">A La Gloire Du Sublime Architecte des Mondes</div>
<h1>Ordre Initiatique Ancien et Primitif de Memphis Misraïm</h1>
<h2>Respectable Loge Bénou Ré (Orient de Saint-Pierre)</h2>
<div style="font-size: 11px; font-weight: bold; color: #4b5563;">GRANDE LOGE DE BOURBON</div></div>
<div class="title-box"><h3>Feuille d'Émargement et de Présence Officielle</h3><p>${session.title}</p></div>
<div class="info-grid"><div class="info-row"><div class="info-cell"><strong>Date :</strong> ${formattedDate}</div><div class="info-cell"><strong>Degré :</strong> ${session.degree}</div></div>
<div class="info-row"><div class="info-cell"><strong>Lieu :</strong> ${session.location}</div><div class="info-cell"><strong>Type :</strong> ${session.type}</div></div></div>
<h4>Membres de l'Atelier Présents (${presentMembers.length})</h4>
<table><thead><tr><th>Nom & Prénom</th><th>Office / Fonction</th><th class="sig-cell">Signature</th></tr></thead><tbody>${membersRowsHtml}</tbody></table>
<h4>Membres Excusez (${excusedMembers.length})</h4>
<table><thead><tr><th>Nom & Prénom</th><th>Office / Fonction</th><th>Statut</th></tr></thead><tbody>${excusedRowsHtml}</tbody></table>
<h4>Visiteurs Présents (${presentVisitors.length})</h4>
<table><thead><tr><th>Nom & Prénom</th><th>Loge & Orient</th><th>Office / Fonction Occupée</th><th class="sig-cell">Signature</th></tr></thead><tbody>${visitorsRowsHtml}</tbody></table>
<div class="tronc-box"><table style="width: 100%; border: none;"><tr style="border: none;"><td style="border: none; width: 50%;"><strong>Montant du Tronc de la Veuve :</strong> <span style="font-size: 14px; font-weight: bold; color: #16a34a;">${session.troncAmount || 0} €</span></td><td style="border: none; width: 50%; text-align: right;"><strong>Clôture des Travaux :</strong> ${session.closingTime || '18:30'}</td></tr></table></div>
<div class="footer">Feuille d'émargement officielle archivée automatiquement sur Google Drive • Temple Thérèse Eliseman</div>
</body></html>`;
}

export async function generateEmargementPdf(session: Session, members: Member[], visitors: Visitor[]): Promise<Blob> {
  const { jsPDF } = await import('jspdf');
  const html = generateEmargementHtml(session, members, visitors);
  const parser = new DOMParser();
  const parsed = parser.parseFromString(html, 'text/html');
  const wrapper = document.createElement('div');
  wrapper.style.position = 'fixed';
  wrapper.style.top = '-9999px';
  wrapper.style.left = '0';
  wrapper.style.width = '800px';
  wrapper.style.pointerEvents = 'none';
  wrapper.appendChild(parsed.documentElement);
  document.body.appendChild(wrapper);

  const doc = new jsPDF({ unit: 'mm', format: 'a4' });
  await doc.html(wrapper, {
    html2canvas: { scale: 2, useCORS: true },
    callback: () => {},
    x: 10,
    y: 10,
    width: 190,
  });

  const blob = doc.output('blob');
  document.body.removeChild(wrapper);
  return blob;
}

export function generatePlancheTraceeHtml(session: Session, members: Member[], visitors: Visitor[]): string {
  const { chrono, jj, mm, annee } = getSessionDetails(session);
  const formattedDate = formatDateFrench(session.date || session.dateReprise || '');
  const rawText = session.plancheDraftText || 'Aucun texte officiel enregistré pour cette planche.';
  const paragraphsHtml = rawText
    .split('\n')
    .map(p => p.trim() ? `<p>${p}</p>` : '')
    .filter(p => p !== '')
    .join('');
  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
body { font-family: 'Times New Roman', Georgia, serif; line-height: 1.6; color: #111; max-width: 800px; margin: 40px auto; padding: 20px; }
.header { text-align: center; border-bottom: 2px solid #1a365d; padding-bottom: 15px; margin-bottom: 25px; }
.motto { font-size: 10px; font-style: italic; color: #4a5568; letter-spacing: 1px; text-transform: uppercase; }
h1 { font-size: 18px; font-weight: bold; text-transform: uppercase; color: #1a365d; margin: 10px 0 5px 0; }
h2 { font-size: 14px; font-weight: bold; color: #2d3748; margin: 0 0 10px 0; }
.title-box { text-align: center; background-color: #fdfbf7; border: 1px solid #c5a059; padding: 15px; margin: 25px 0; }
.title-box h3 { margin: 0; font-size: 14px; text-transform: uppercase; color: #854d0e; }
.title-box p { margin: 5px 0 0 0; font-size: 12px; color: #4a5568; }
.content { font-size: 13px; text-align: justify; color: #1e293b; margin-top: 30px; }
.content p { margin-bottom: 15px; text-indent: 30px; }
.box { border: 1px solid #cbd5e1; padding: 12px; background-color: #f8fafc; margin-top: 25px; font-size: 12px; }
.box-title { font-weight: bold; text-transform: uppercase; font-size: 11px; color: #475569; margin-bottom: 5px; }
.signatures-section { margin-top: 40px; border-top: 1px solid #000; padding-top: 15px; font-size: 12px; }
.footer { margin-top: 50px; border-top: 1px solid #e2e8f0; padding-top: 20px; font-size: 11px; color: #64748b; text-align: center; }
</style></head><body>
<div class="header"><div class="motto">A La Gloire Du Sublime Architecte des Mondes</div>
<h1>Ordre Initiatique Ancien et Primitif de Memphis Misraïm</h1>
<h2>Respectable Loge Bénou Ré (Orient de Saint-Pierre)</h2>
<div style="font-size: 11px; font-weight: bold; color: #4b5563;">GRANDE LOGE DE BOURBON</div></div>
<div class="title-box"><h3>PLANCHÉ TRACÉE DE LA ${session.sessionNumber || chrono + '°'} TENUE RÉGULIÈRE</h3><p>Travaux ouverts au grade de : <strong>${session.degree}</strong></p><p>Date : ${formattedDate} (An Égyptien ${session.egyptianYear || '6026'})</p></div>
<div class="content">${paragraphsHtml}</div>
${session.sacPropositions ? `<div class="box"><div class="box-title">Sac aux propositions / Tronc de la Veuve :</div><p>${session.sacPropositions}</p></div>` : ''}
<div class="signatures-section"><table style="width: 100%;"><tr><td style="width: 50%; vertical-align: top;"><strong>Le Secrétaire de l'Atelier</strong><br>S∴ Muriel MARTIN-FANTINO<br><span style="font-size: 10px; font-style: italic; color: #0d9488;">${session.plancheSecretarySigned ? '✓ Signée numériquement' : 'En attente de signature'}</span></td>
<td style="width: 50%; text-align: right; vertical-align: top;"><strong>Le Vénérable Maître</strong><br>V∴M∴ ${session.vmName || 'Bruno GAUDIN'}<br><span style="font-size: 10px; font-style: italic; color: #0d9488;">${session.plancheVMSigned ? '✓ Approuvée & Validée' : 'En attente d\'approbation'}</span></td></tr></table></div>
<div class="footer">Planche tracée officielle archivée automatiquement sur Google Drive • Temple Thérèse Eliseman</div>
</body></html>`;
}