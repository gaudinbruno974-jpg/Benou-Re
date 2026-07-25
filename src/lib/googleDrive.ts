import { getAuth, signInWithPopup, GoogleAuthProvider } from 'firebase/auth';
import { Session, Member, Visitor } from '../types';
import logoBenouReUrl from '../assets/Benou-Re.png';

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

// Image base64 (data URL) du logo de la loge, à renseigner si disponible.
export const LODGE_LOGO_BASE64 = '';

const LODGE_NAME = 'Bénou Ré';

export type LoadedLogo = { dataUrl: string; width: number; height: number };

// Charge le logo (URL fournie par Vite) et le convertit en data URL base64,
// en récupérant ses dimensions naturelles pour préserver le ratio d'aspect.
// Retourne null si le chargement échoue, afin de ne pas planter la génération.
export async function loadLogoDataUrl(url: string): Promise<LoadedLogo | null> {
  try {
    const image = await new Promise<HTMLImageElement>((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = () => reject(new Error('Chargement du logo impossible'));
      img.src = url;
    });
    const width = image.naturalWidth;
    const height = image.naturalHeight;
    if (!width || !height) return null;
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d');
    if (!ctx) return null;
    ctx.drawImage(image, 0, 0);
    return { dataUrl: canvas.toDataURL('image/png'), width, height };
  } catch {
    return null;
  }
}

type EmargementRow = {
  lastName: string;
  firstName: string;
  role: string;
  lodge: string;
  signature: string;
};

export async function generateEmargementPdf(session: Session, members: Member[], visitors: Visitor[]): Promise<Blob> {
  const { jsPDF } = await import('jspdf');
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });

  const PAGE_WIDTH = 210;
  const PAGE_HEIGHT = 297;
  const MARGIN_LEFT = 20;
  const MARGIN_RIGHT = 20;
  const MARGIN_TOP = 25;
  const CONTENT_WIDTH = PAGE_WIDTH - MARGIN_LEFT - MARGIN_RIGHT;
  const COLUMNS = [35, 35, 35, 35, 30];
  const HEADERS = ['Nom', 'Prénom', 'Fonction', 'Loge', 'Signature'];
  const ROW_MIN_HEIGHT = 9;
  const BORDER_WIDTH = 0.18; // 0,5 pt
  const PURPLE: [number, number, number] = [112, 26, 117];
  const GREY: [number, number, number] = [217, 217, 217];

  const signatures = session.signatures || {};
  const presentIds = session.presentIds || [];
  const visitorIds = session.visitorIds || [];
  const visitorRoles = session.visitorRoles || {};
  const location = session.location || session.lieuReunion || '';
  const dateStr = session.date || session.dateReprise || '';
  const type = session.type || session.typeTenue || 'Ordinaire';
  const degree = session.degree || session.degreTravail || 'Apprenti';
  const sessionNumber = session.sessionNumber || (session.chrono != null ? String(session.chrono) : '');

  const presentMembers = members.filter(m => presentIds.includes(m.id));
  const presentVisitors = visitors.filter(v => visitorIds.includes(v.id));

  const memberRows: EmargementRow[] = presentMembers.map(m => ({
    lastName: m.lastName || '',
    firstName: m.firstName || '',
    role: m.function && m.function !== 'Aucun' ? m.function : 'Membre',
    lodge: LODGE_NAME,
    signature: signatures[m.id] || '',
  }));
  const visitorRows: EmargementRow[] = presentVisitors.map(v => ({
    lastName: v.lastName || '',
    firstName: v.firstName || '',
    role: visitorRoles[v.id] || v.function || 'Visiteur',
    lodge: v.lodge || '',
    signature: signatures[v.id] || '',
  }));

  const columnX = (index: number) => MARGIN_LEFT + COLUMNS.slice(0, index).reduce((a, b) => a + b, 0);
  const tableWidth = COLUMNS.reduce((a, b) => a + b, 0);

  const signatureMaxWidth = COLUMNS[4] - 4;
  const signatureSize = (dataUrl: string): { width: number; height: number } | null => {
    if (!dataUrl) return null;
    let ratio = 0.35;
    try {
      const props = doc.getImageProperties(dataUrl);
      if (props?.width && props?.height) ratio = props.height / props.width;
    } catch {
      return null;
    }
    const width = signatureMaxWidth;
    return { width, height: Math.max(1, width * ratio) };
  };

  const memberRowsNaturalHeight = (count: number): number => {
    let total = 0;
    for (let i = 0; i < count; i++) {
      const image = memberRows[i] ? signatureSize(memberRows[i].signature) : null;
      total += Math.max(ROW_MIN_HEIGHT, image ? image.height + 2 : 0);
    }
    return total;
  };

  const drawCellBorders = (y: number, height: number) => {
    doc.setDrawColor(0, 0, 0);
    doc.setLineWidth(BORDER_WIDTH);
    doc.line(MARGIN_LEFT, y, MARGIN_LEFT + tableWidth, y);
    doc.line(MARGIN_LEFT, y + height, MARGIN_LEFT + tableWidth, y + height);
    for (let i = 0; i <= COLUMNS.length; i++) {
      const x = columnX(i);
      doc.line(x, y, x, y + height);
    }
  };

  const drawHeaderRow = (y: number): number => {
    const height = ROW_MIN_HEIGHT;
    doc.setFillColor(GREY[0], GREY[1], GREY[2]);
    doc.rect(MARGIN_LEFT, y, tableWidth, height, 'F');
    drawCellBorders(y, height);
    doc.setTextColor(0, 0, 0);
    doc.setFont('times', 'bold');
    doc.setFontSize(11);
    HEADERS.forEach((label, i) => {
      doc.text(label, columnX(i) + COLUMNS[i] / 2, y + height / 2, { align: 'center', baseline: 'middle' });
    });
    return y + height;
  };

  const drawSectionRow = (y: number, label: string): number => {
    const height = ROW_MIN_HEIGHT;
    doc.setFillColor(GREY[0], GREY[1], GREY[2]);
    doc.rect(MARGIN_LEFT, y, tableWidth, height, 'F');
    doc.setDrawColor(0, 0, 0);
    doc.setLineWidth(BORDER_WIDTH);
    doc.rect(MARGIN_LEFT, y, tableWidth, height, 'S');
    doc.setTextColor(0, 0, 0);
    doc.setFont('times', 'bold');
    doc.setFontSize(12);
    doc.text(label, MARGIN_LEFT + tableWidth / 2, y + height / 2, { align: 'center', baseline: 'middle' });
    return y + height;
  };

  const drawDataRow = (y: number, row: EmargementRow | null, minHeight = ROW_MIN_HEIGHT): number => {
    const image = row ? signatureSize(row.signature) : null;
    const height = Math.max(minHeight, image ? image.height + 2 : 0);
    drawCellBorders(y, height);
    if (row) {
      doc.setTextColor(0, 0, 0);
      doc.setFont('times', 'normal');
      doc.setFontSize(11);
      const values = [row.lastName, row.firstName, row.role, row.lodge];
      values.forEach((value, i) => {
        if (!value) return;
        const maxWidth = COLUMNS[i] - 4;
        const text = doc.splitTextToSize(value, maxWidth)[0];
        doc.text(text, columnX(i) + 2, y + height / 2, { baseline: 'middle' });
      });
      if (image) {
        const x = columnX(4) + (COLUMNS[4] - image.width) / 2;
        const imageY = y + (height - image.height) / 2;
        try {
          doc.addImage(row.signature, x, imageY, image.width, image.height);
        } catch {
          // signature illisible : cellule laissée vide
        }
      }
    }
    return y + height;
  };

  const drawFooter = () => {
    doc.setTextColor(0, 0, 0);
    doc.setFont('times', 'bold');
    doc.setFontSize(10);
    doc.text('1', PAGE_WIDTH / 2, PAGE_HEIGHT - 20, { align: 'center', baseline: 'middle' });
  };

  // ── PAGE 1 ──
  let y = MARGIN_TOP;
  const LOGO_RESERVED_HEIGHT = 30;
  const logo = await loadLogoDataUrl(logoBenouReUrl);
  if (logo) {
    // Centrage horizontal sur la page (105 mm), ratio d'aspect conservé.
    const maxLogoHeight = LOGO_RESERVED_HEIGHT;
    const maxLogoWidth = 40;
    const ratio = logo.width / logo.height;
    let logoHeight = maxLogoHeight;
    let logoWidth = logoHeight * ratio;
    if (logoWidth > maxLogoWidth) {
      logoWidth = maxLogoWidth;
      logoHeight = logoWidth / ratio;
    }
    const logoX = (PAGE_WIDTH - logoWidth) / 2;
    const logoY = y + (LOGO_RESERVED_HEIGHT - logoHeight) / 2;
    try {
      doc.addImage(logo.dataUrl, 'PNG', logoX, logoY, logoWidth, logoHeight);
    } catch {
      // logo indisponible : on conserve l'espace réservé
    }
  }
  y += LOGO_RESERVED_HEIGHT; // espace réservé au logo (conservé même en cas d'échec)

  y += 5;
  doc.setFont('times', 'bold');
  doc.setFontSize(18);
  doc.setTextColor(PURPLE[0], PURPLE[1], PURPLE[2]);
  doc.text('Respectable Loge Benou Ré', PAGE_WIDTH / 2, y, { align: 'center', baseline: 'top' });
  y += 8;

  doc.setDrawColor(0, 0, 0);
  doc.setLineWidth(BORDER_WIDTH);
  doc.line(MARGIN_LEFT, y, MARGIN_LEFT + CONTENT_WIDTH, y);

  y += 15;
  const titleText = 'FEUILLE DE PRÉSENCE';
  doc.setFont('times', 'bold');
  doc.setFontSize(22);
  doc.setTextColor(PURPLE[0], PURPLE[1], PURPLE[2]);
  doc.text(titleText, PAGE_WIDTH / 2, y, { align: 'center', baseline: 'top', charSpace: 0.4 });
  const titleWidth = doc.getTextWidth(titleText) + 0.4 * titleText.length;
  doc.setDrawColor(PURPLE[0], PURPLE[1], PURPLE[2]);
  doc.line((PAGE_WIDTH - titleWidth) / 2, y + 9, (PAGE_WIDTH + titleWidth) / 2, y + 9);

  y += 20;
  const metaLines: Array<[string, string]> = [
    ['Objet : ', `${type} – Grade d'${degree}`],
    ['Fiche N° : ', sessionNumber],
    ['Date : ', formatDateFrench(dateStr)],
    ['Lieu : ', location],
  ];
  doc.setTextColor(0, 0, 0);
  metaLines.forEach(([label, value], index) => {
    const lineY = y + index * 7;
    doc.setFont('times', 'bold');
    doc.setFontSize(12);
    doc.text(label, MARGIN_LEFT, lineY, { baseline: 'middle' });
    const labelWidth = doc.getTextWidth(label);
    const lineStart = MARGIN_LEFT + labelWidth;
    doc.setDrawColor(0, 0, 0);
    doc.setLineWidth(BORDER_WIDTH);
    doc.line(lineStart, lineY + 1.5, lineStart + 120, lineY + 1.5);
    if (value) {
      doc.setFont('times', 'normal');
      doc.text(doc.splitTextToSize(value, 118)[0], lineStart + 2, lineY, { baseline: 'middle' });
    }
  });

  y = y + (metaLines.length - 1) * 7 + 20;
  y = drawHeaderRow(y);
  y = drawSectionRow(y, 'MEMBRES DE LA LOGE');

  // La hauteur nominale de 9 mm par ligne dépasse le bas de page : on la réduit
  // au besoin pour que les 20 lignes tiennent au-dessus du pied de page.
  const MEMBER_ROWS = 20;
  const availableHeight = PAGE_HEIGHT - 25 - y;
  const naturalHeight = memberRowsNaturalHeight(MEMBER_ROWS);
  const memberRowMinHeight = naturalHeight > availableHeight
    ? Math.max(6, ROW_MIN_HEIGHT - (naturalHeight - availableHeight) / MEMBER_ROWS)
    : ROW_MIN_HEIGHT;
  for (let i = 0; i < MEMBER_ROWS; i++) {
    y = drawDataRow(y, memberRows[i] || null, memberRowMinHeight);
  }
  drawFooter();

  // ── PAGE 2 ──
  doc.addPage();
  y = MARGIN_TOP;
  y = drawHeaderRow(y);
  y = drawSectionRow(y, 'INVITÉS');
  for (let i = 0; i < 5; i++) {
    y = drawDataRow(y, visitorRows[i] || null);
  }
  drawFooter();

  return doc.output('blob');
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