// En-tête commun aux documents de la loge (convocation + planche tracée).
// Regroupe : la police Unicode intégrée (pour « ∴ »), les couleurs, le
// calendrier égyptien du R∴A∴P∴M∴M∴ et le dessin de l'en-tête
// (logos + GRANDE LOGE DE BOURBON + rites + filiations + R∴L∴ Bénou Ré).
import type { jsPDF } from 'jspdf';
import { DEJAVU_SANS_NORMAL_BASE64, DEJAVU_SANS_BOLD_BASE64 } from './convocationFont';
import type { LoadedLogo } from './googleDrive';

export const NAVY: [number, number, number] = [12, 35, 92];
export const VIOLET: [number, number, number] = [112, 26, 117];
export const LODGE_MARGIN = 15;

// Police DejaVu Sans sous-ensemblée : la police standard de jsPDF ne rend pas
// les symboles maçonniques « ∴ ».
export function registerLodgeFont(doc: jsPDF): string {
  const FONT = 'DejaVuSans';
  doc.addFileToVFS('DejaVuSans.ttf', DEJAVU_SANS_NORMAL_BASE64);
  doc.addFont('DejaVuSans.ttf', FONT, 'normal');
  doc.addFileToVFS('DejaVuSans-Bold.ttf', DEJAVU_SANS_BOLD_BASE64);
  doc.addFont('DejaVuSans-Bold.ttf', FONT, 'bold');
  return FONT;
}

// Calendrier égyptien du R∴A∴P∴M∴M∴
// - 12 mois de 30 jours répartis en 3 saisons (SCHA, PRE, SCHEMON)
// - 1er THOT = 19 juillet ; les 5 jours épagomènes tombent du 14 au 18 juillet
// - An de la Lumière d'Égypte = année civile + 1292 (nouvel an au 19 juillet)
const EG_MONTHS: Array<{ name: string; season: string }> = [
  { name: 'THOT', season: 'SCHA' },
  { name: 'PAOPHI', season: 'SCHA' },
  { name: 'ATHYR', season: 'SCHA' },
  { name: 'KHAOIAK', season: 'SCHA' },
  { name: 'TYBI', season: 'PRE' },
  { name: 'MEKHEIN', season: 'PRE' },
  { name: 'PHAMENOTH', season: 'PRE' },
  { name: 'PHARMOUTHI', season: 'PRE' },
  { name: 'PAKHOUS', season: 'SCHEMON' },
  { name: 'PSYRIE', season: 'SCHEMON' },
  { name: 'EPIPHI', season: 'SCHEMON' },
  { name: 'MESORI', season: 'SCHEMON' },
];
const EG_EPAGOMENES = ['OSIRIS', 'HORUS', 'SETH', 'ISIS', 'NEPHTHYS'];

export const getMasonicDate = (date: Date): string => {
  if (isNaN(date.getTime())) return 'Date inconnue';
  // Normaliser à midi (heure locale) pour éviter les décalages horaires.
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12);
  const civilYear = d.getFullYear();
  // Nouvel an égyptien = 1er THOT = 19 juillet (mois 6 en base 0).
  const newYear = new Date(civilYear, 6, 19, 12);
  let start: Date;
  let egYear: number;
  if (d.getTime() >= newYear.getTime()) {
    start = newYear;
    egYear = civilYear + 1292;
  } else {
    start = new Date(civilYear - 1, 6, 19, 12);
    egYear = civilYear - 1 + 1292;
  }
  const offset = Math.floor((d.getTime() - start.getTime()) / 86400000);
  const suffixe = 'de la Lumière d’Égypte';

  // Jours épagomènes : offsets 360 à 364 (14 au 18 juillet).
  if (offset >= 360) {
    const idx = Math.min(offset - 360, EG_EPAGOMENES.length - 1);
    const ord = idx + 1;
    const ordStr = ord === 1 ? '1er' : `${ord}ème`;
    return `Le ${ordStr} jour épagomène (Naissance de ${EG_EPAGOMENES[idx]}) De l’an ${egYear} ${suffixe}`;
  }

  const monthIndex = Math.floor(offset / 30);
  const dayInMonth = (offset % 30) + 1;
  const { name, season } = EG_MONTHS[monthIndex];
  const dayStr = dayInMonth === 1 ? '1er' : `${dayInMonth}ème`;
  return `Le ${dayStr} jour du mois de ${name} de la saison ${season} De l’an ${egYear} ${suffixe}`;
};

// Dessine l'en-tête commun (logos GLDB/Bénou-Ré, titre GRANDE LOGE DE BOURBON,
// rites historiques, filiations, R∴L∴ Bénou Ré N°5) et renvoie la coordonnée y
// juste sous le bloc de localisation de la loge.
export function drawLodgeHeader(
  doc: jsPDF,
  font: string,
  logoGLDB: LoadedLogo | null,
  logoBenou: LoadedLogo | null,
): number {
  const pageWidth = doc.internal.pageSize.getWidth();
  const margin = LODGE_MARGIN;
  const contentWidth = pageWidth - 2 * margin;
  const centerX = pageWidth / 2;
  let y = 12;

  // ─── LOGOS (GLDB à gauche, Bénou Ré à droite) ──────────────────
  const LOGO_BOX = 26;
  const placeLogo = (logo: LoadedLogo | null, boxX: number) => {
    if (!logo) return;
    const ratio = logo.width / logo.height;
    let w = LOGO_BOX;
    let h = LOGO_BOX;
    if (ratio >= 1) h = w / ratio;
    else w = h * ratio;
    const drawX = boxX + (LOGO_BOX - w) / 2;
    const drawY = y + (LOGO_BOX - h) / 2;
    try {
      doc.addImage(logo.dataUrl, 'PNG', drawX, drawY, w, h);
    } catch {
      // logo indisponible : espace conservé
    }
  };
  placeLogo(logoGLDB, margin);
  placeLogo(logoBenou, pageWidth - margin - LOGO_BOX);

  // ─── EN-TÊTE TEXTE (centré entre les logos, bleu foncé) ────────
  doc.setFont(font, 'bold');
  doc.setFontSize(16);
  doc.setTextColor(NAVY[0], NAVY[1], NAVY[2]);
  doc.text('GRANDE LOGE DE BOURBON', centerX, y + 8, { align: 'center' });
  doc.setFont(font, 'normal');
  doc.setFontSize(7.5);
  const subtitle = doc.splitTextToSize(
    'FRANCS-MAÇONS TRAVAILLANT AU RITE ANCIEN ET PRIMITIF DE MEMPHIS MISRAÏM',
    contentWidth - 2 * LOGO_BOX - 8,
  );
  doc.text(subtitle, centerX, y + 14, { align: 'center' });

  y += LOGO_BOX + 12;

  // ─── RITES HISTORIQUES (5 colonnes, nom puis lieu/année) ───────
  const rites: Array<{ name: string; place: string }> = [
    { name: 'Rite Primitif', place: 'Paris 1721' },
    { name: 'Rite Primitif des Philadelphes', place: 'Narbonne 1779' },
    { name: 'Rite de Memphis', place: 'Montauban 1815' },
    { name: 'Rite de Misraïm', place: 'Venise 1788' },
    { name: 'Rite Ancien et Primitif', place: 'Manchester 1876' },
  ];
  const colWidth = contentWidth / rites.length;
  doc.setTextColor(0, 0, 0);
  let maxNameLines = 1;
  rites.forEach((rite, i) => {
    const colCenter = margin + colWidth * i + colWidth / 2;
    doc.setFont(font, 'bold');
    doc.setFontSize(7.5);
    const nameLines = doc.splitTextToSize(rite.name, colWidth - 2);
    maxNameLines = Math.max(maxNameLines, nameLines.length);
    doc.text(nameLines, colCenter, y, { align: 'center' });
    doc.setFont(font, 'normal');
    doc.setFontSize(7);
    doc.text(rite.place, colCenter, y + nameLines.length * 3 + 1, { align: 'center' });
  });
  y += maxNameLines * 3 + 12;

  // ─── FILIATIONS (3 lignes centrées) ────────────────────────────
  doc.setFont(font, 'normal');
  doc.setFontSize(8);
  doc.setTextColor(80, 80, 80);
  const filiations = [
    'Filiation directe Robert Ambelain',
    'Filiation Directe Gérard Kloppel',
    'Filiation Directe Joseph Tsang Mang Kin',
  ];
  filiations.forEach((f) => {
    doc.text(f, centerX, y, { align: 'center' });
    y += 4.5;
  });
  y += 8;

  // ─── LOCALISATION DE LA LOGE (2 lignes centrées, bleu foncé) ───
  doc.setFont(font, 'bold');
  doc.setFontSize(15);
  doc.setTextColor(NAVY[0], NAVY[1], NAVY[2]);
  doc.text('R∴ L∴ Bénou Ré N°5', centerX, y, { align: 'center' });
  y += 7;
  doc.setFontSize(11);
  doc.text('O∴ de Saint Pierre – Île de la Réunion', centerX, y, { align: 'center' });
  y += 16;
  doc.setTextColor(0, 0, 0);
  return y;
}
