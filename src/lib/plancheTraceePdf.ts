// Génération du PDF de la planche tracée.
// Reprend le même en-tête que la convocation (logos, GRANDE LOGE DE BOURBON,
// rites, filiations, R∴L∴ Bénou Ré N°5), puis, à la place de l'ordre du jour,
// le corps officiel de la planche (protocole, présences, placements, travaux,
// tronc, clôture) et les signatures Orateur / V∴M∴ / Secrétaire.
import type { jsPDF as JsPDFType } from 'jspdf';
import { Session, Member, Visitor } from '../types';
import { loadLogoDataUrl, LoadedLogo } from './googleDrive';
import { registerLodgeFont, drawLodgeHeader, NAVY } from './lodgeHeader';
import logoGLDBUrl from '../assets/GLDB.png';
import logoBenouReUrl from '../assets/Benou-Re.png';

// Placement rituel de chaque office dans le Temple. Les libellés reprennent
// exactement les options proposées à l'écran de présence (visitorRoleOptions).
const OFFICE_PLACEMENT: Record<string, string> = {
  'Trésorier': 'Orient',
  'Hospitalier': 'Orient',
  'Secrétaire': 'Orient',
  'Orateur': 'Orient',
  'Premier Surveillant': 'Colonne du Midi',
  '1er Surveillant': 'Colonne du Midi',
  'Second Surveillant': 'Colonne du Nord',
  '2nd Surveillant': 'Colonne du Nord',
  '2ème Surveillant': 'Colonne du Nord',
  'Expert': 'Colonne du Midi',
  'Maître des Cérémonies': 'Colonne du Nord',
  'Couvreur': 'Occident',
  'Maître des Banquets': 'Colonne du Midi',
  "Maître de l'Harmonie": 'Colonne du Nord',
  'Maître de la Colonne d\'Harmonie': 'Colonne du Nord',
};

// Choix de placement direct (sans office) proposés à l'écran de présence.
const DIRECT_PLACEMENT: Record<string, string> = {
  "à l’Orient": 'Orient',
  "à l'Orient": 'Orient',
  'Colonne du Septentrion': 'Colonne du Nord',
  'Colonne du midi': 'Colonne du Midi',
  'Colonne du Midi': 'Colonne du Midi',
};

const degreOrdinal = (degre?: string): string => {
  switch (degre) {
    case 'Compagnon': return '2ème';
    case 'Maitre':
    case 'Maître': return '3ème';
    default: return '1er';
  }
};

const formatDateFR = (dateStr?: string): string => {
  if (!dateStr) return 'xx-xx-xxxx';
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return 'xx-xx-xxxx';
  const jj = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  return `${jj}-${mm}-${d.getFullYear()}`;
};

const memberFullName = (m: Member): string => `${m.firstName} ${m.lastName}`.trim();
const visitorFullName = (v: Visitor): string => `${v.firstName} ${v.lastName}`.trim();

// Assemble les points d'ordre du jour de la tenue (mêmes sources que la convocation).
const collectOrdreDuJour = (session: Session): string[] => {
  const raw = [
    session.travail1,
    session.travail2,
    session.travail3,
    session.travail4,
    ...((session.ordresJour || []).filter((o) => (o || '').trim() !== '')),
    session.ligneCloture,
  ];
  const fallback = [session.agenda1, session.agenda2, session.agenda3, session.agenda4];
  const items = (raw.some((r) => (r || '').trim() !== '') ? raw : fallback)
    .map((item) => (item || '').replace(/^\s*\d+\s*[.)]\s*/, '').trim())
    .filter((item) => item !== '');
  return items;
};

export async function generatePlancheTraceePDF(
  session: Session,
  members: Member[],
  visitors: Visitor[],
  chrono: number,
): Promise<Blob> {
  const { jsPDF } = await import('jspdf');
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });
  const [logoGLDB, logoBenou] = await Promise.all([
    loadLogoDataUrl(logoGLDBUrl),
    loadLogoDataUrl(logoBenouReUrl),
  ]);
  renderPlanche(doc, logoGLDB, logoBenou, session, members, visitors, chrono);
  return doc.output('blob');
}

// Rendu pur (sans DOM) : dessine l'en-tête et le corps de la planche dans un
// document jsPDF déjà construit, avec les logos déjà chargés.
export function renderPlanche(
  doc: JsPDFType,
  logoGLDB: LoadedLogo | null,
  logoBenou: LoadedLogo | null,
  session: Session,
  members: Member[],
  visitors: Visitor[],
  chrono: number,
): void {
  const FONT = registerLodgeFont(doc);

  const pageWidth = doc.internal.pageSize.getWidth();
  const pageHeight = doc.internal.pageSize.getHeight();
  const margin = 15;
  const contentWidth = pageWidth - 2 * margin;
  const centerX = pageWidth / 2;

  let y = drawLodgeHeader(doc, FONT, logoGLDB, logoBenou);

  const vmName = session.vmName || 'Bruno GAUDIN';
  const dateFR = formatDateFR(session.dateReprise || session.date);
  const degre = degreOrdinal(session.degreTravail || session.degree);

  // Helpers de rendu ----------------------------------------------------
  const ensureSpace = (needed: number) => {
    if (y + needed > pageHeight - 20) {
      doc.addPage();
      y = 20;
    }
  };
  const paragraph = (
    text: string,
    opts: { size?: number; bold?: boolean; align?: 'left' | 'center'; color?: [number, number, number]; gap?: number } = {},
  ) => {
    const size = opts.size ?? 10;
    doc.setFont(FONT, opts.bold ? 'bold' : 'normal');
    doc.setFontSize(size);
    doc.setTextColor(...(opts.color ?? [0, 0, 0]));
    const lines = doc.splitTextToSize(text, contentWidth);
    const lineHeight = size * 0.52;
    ensureSpace(lines.length * lineHeight);
    if (opts.align === 'center') {
      doc.text(lines, centerX, y, { align: 'center' });
    } else {
      doc.text(lines, margin, y);
    }
    y += lines.length * lineHeight + (opts.gap ?? 4);
    doc.setTextColor(0, 0, 0);
  };

  // ─── TITRE DE LA PLANCHE ────────────────────────────────────────────
  paragraph(`Planche Tracée de la Tenue Régulière N°${chrono} du ${dateFR}`, {
    size: 13, bold: true, align: 'center', color: NAVY, gap: 2,
  });
  paragraph('De la Respectable Loge BENOU RE N°5 à l’Orient Saint-Pierre', {
    size: 11, bold: true, align: 'center', color: NAVY, gap: 8,
  });

  paragraph('Vénérable Maître en chaire et vous tous mes Frères et Sœurs en vos grades et qualités.', {
    size: 10, gap: 6,
  });

  paragraph(`Protocole de la Tenue ${session.type === 'Solennelle' ? 'Solennelle' : (session.typeTenue || session.type || 'Régulière')} du ${dateFR} de Ère Vulgaire.`, {
    size: 10, bold: true, gap: 6,
  });

  paragraph(
    'Les Membres composant la Respectable Loge BENOU RE N°5 régulièrement Convoqués, sont traditionnellement réunis en un lieu très pur, très saint et très éclairé par la lumière d’Egypte, lieu où règne la Paix, la Joie et l’Harmonie.',
    { size: 10, gap: 6 },
  );

  paragraph(`Les Sœurs et Frères sont éclairés à l’orient par la sagesse du V∴ M∴ en chaire ${vmName}.`, {
    size: 10, gap: 6,
  });

  paragraph('Les Sœurs et Frères dont le nom figure sur le registre des présences, nous ont fait la joie d’assister à nos travaux.', {
    size: 10, gap: 6,
  });

  // ─── MEMBRES EXCUSÉS ────────────────────────────────────────────────
  const excused = (session.excusedIds || [])
    .map((id) => members.find((m) => m.id === id))
    .filter((m): m is Member => !!m);
  if (excused.length > 0) {
    const noms = excused.map(memberFullName).join(', ');
    paragraph(`${noms} membre(s) de la R∴ L∴ Bénou Ré sont absents excusés. (Voir la liste des membres excusés)`, {
      size: 10, gap: 6,
    });
  } else {
    paragraph('Aucun membre de la R∴ L∴ Bénou Ré n’est absent excusé.', { size: 10, gap: 6 });
  }

  // ─── INVITÉS : DIGNITAIRES À L'ORIENT + PLACEMENTS ─────────────────
  const presentVisitors = (session.visitorIds || [])
    .map((id) => visitors.find((v) => v.id === id))
    .filter((v): v is Visitor => !!v);
  // Rôle occupé par l'invité pendant la tenue : rôle attribué pour la session,
  // sinon la fonction figurant sur la feuille de présence.
  const roleOf = (v: Visitor): string | undefined => {
    const r = (session.visitorRoles?.[v.id] || '').trim();
    if (r && r !== 'Simple Visiteur' && r !== 'Visiteur') return r;
    const f = (v.function || '').trim();
    if (f && f !== 'Simple Visiteur' && f !== 'Visiteur') return f;
    return undefined;
  };
  // Un office (Trésorier, Surveillant…) est nommé « en qualité de … » ;
  // un choix de placement direct (à l'Orient, Colonne du midi…) ne l'est pas.
  const isOffice = (role: string): boolean => role in OFFICE_PLACEMENT;
  const placementOf = (v: Visitor): string | undefined => {
    const role = roleOf(v);
    if (!role) return undefined;
    return OFFICE_PLACEMENT[role] || DIRECT_PLACEMENT[role];
  };
  const placementSentence = (v: Visitor, placement: string, role: string): string => {
    const who = `le F∴ S∴ ${visitorFullName(v)} (${v.lodge})`;
    const qualite = isOffice(role) ? ` en qualité de ${role}` : '';
    switch (placement) {
      case 'Colonne du Midi':
        return `Au Midi, a pris place ${who}${qualite}.`;
      case 'Colonne du Nord':
        return `Au Nord, a pris place ${who}${qualite}.`;
      case 'Occident':
        return `À l’Occident, à la porte d’entrée à l’intérieur, a pris place ${who}${qualite}.`;
      default:
        return `À l’Orient, a pris place ${who}${qualite}.`;
    }
  };

  // Dignitaires à l'Orient (hors Orateur, cité juste après).
  const dignitairesOrient = presentVisitors.filter(
    (v) => placementOf(v) === 'Orient' && roleOf(v) !== 'Orateur' && isOffice(roleOf(v) || ''),
  );
  if (dignitairesOrient.length > 0) {
    const liste = dignitairesOrient
      .map((v) => `${visitorFullName(v)} (${roleOf(v)} – ${v.lodge})`)
      .join(', ');
    paragraph(`A l’Orient, sont venus soutenir nos travaux les dignitaires suivants : ${liste}.`, {
      size: 10, gap: 6,
    });
  }

  // Poste d'Orateur
  const orateurMember = members.find(
    (m) => (m.function || '').trim() === 'Orateur' && (session.presentIds || []).includes(m.id),
  );
  const orateurVisitor = presentVisitors.find((v) => roleOf(v) === 'Orateur');
  const orateurName = session.plancheOrateurName
    || (orateurMember ? memberFullName(orateurMember) : undefined)
    || (orateurVisitor ? visitorFullName(orateurVisitor) : undefined);
  paragraph(
    orateurName
      ? `Le poste d’Orateur est occupé par le F∴ S∴ ${orateurName}.`
      : 'Le poste d’Orateur est resté vide.',
    { size: 10, gap: 6 },
  );

  // Placement des invités (hors dignitaires de l'Orient et Orateur déjà cités) :
  // - avec une fonction/placement → phrase adaptée à la colonne ;
  // - sinon → placement sur les Colonnes selon la feuille de présence.
  presentVisitors.forEach((v) => {
    const role = roleOf(v);
    const placement = placementOf(v);
    if (role === 'Orateur') return; // déjà traité par le poste d'Orateur
    if (placement === 'Orient' && isOffice(role || '')) return; // déjà dans les dignitaires
    if (placement) {
      paragraph(placementSentence(v, placement, role as string), { size: 10, gap: 3 });
    } else {
      paragraph(`Le F∴ S∴ ${visitorFullName(v)} (${v.lodge} – Orient de ${v.orient}) a pris place sur les Colonnes, selon la feuille de présence.`, {
        size: 10, gap: 3,
      });
    }
  });
  y += 3;

  paragraph('La planche tracée de nos derniers travaux a été adoptée.', { size: 10, gap: 6 });

  // ─── ORDRE DU JOUR TRAITÉ (rappel numéroté + notes du secrétaire) ──
  paragraph('L’ordre du jour de la Tenue a appelé :', { size: 11, bold: true, gap: 5 });
  const items = collectOrdreDuJour(session);
  const notes = session.plancheTravauxNotes || [];
  items.forEach((item, idx) => {
    const numberLabel = `${idx + 1}. `;
    doc.setFont(FONT, 'normal');
    doc.setFontSize(10);
    doc.setTextColor(0, 0, 0);
    const indent = doc.getTextWidth(numberLabel);
    const lines = doc.splitTextToSize(item, contentWidth - indent);
    ensureSpace(lines.length * 5.2 + 3);
    doc.text(numberLabel, margin, y);
    doc.text(lines, margin + indent, y);
    y += lines.length * 5.2 + 2;
    const note = (notes[idx] || '').trim();
    if (note) {
      doc.setFont(FONT, 'normal');
      doc.setFontSize(9.5);
      doc.setTextColor(70, 70, 70);
      const noteLines = doc.splitTextToSize(note, contentWidth - indent);
      ensureSpace(noteLines.length * 4.6 + 2);
      doc.text(noteLines, margin + indent, y);
      y += noteLines.length * 4.6 + 3;
      doc.setTextColor(0, 0, 0);
    } else {
      y += 1.5;
    }
  });
  y += 4;

  // ─── TRONC DE LA VEUVE & SAC AUX PROPOSITIONS ──────────────────────
  const tronc = session.troncAmount || 0;
  const euros = Math.floor(tronc);
  const centimes = Math.round((tronc - euros) * 100);
  paragraph(
    `L’ordre du jour étant épuisé, le V∴ M∴ fait circuler le Tronc de la veuve et le Sac aux Propositions. Ce dernier revient pur et sans tache. Le Tronc revient lourd de ${euros} Pierre(s) Plate(s) et ${centimes} Morceau(x) d’éclats, qui ont été pris en charge par le Trésorier.`,
    { size: 10, gap: 6 },
  );

  // ─── CLÔTURE ────────────────────────────────────────────────────────
  paragraph(
    `Les Travaux sont ensuite fermés au ${degre} degré symbolique. Au cours de ce Cérémonial, les Sœurs et les Frères forment une Chaîne d’Union Fraternelle, selon le Rite, puis se séparent en jurant de garder le Silence sur les Travaux de ce Jour.`,
    { size: 10, gap: 8 },
  );

  paragraph('J’ai dit Vénérable Maître,', { size: 10, bold: true, gap: 10 });

  // ─── SIGNATURES (Orateur / V∴M∴ / Secrétaire) ─────────────────────
  ensureSpace(38);
  const colW = contentWidth / 3;
  const secretaryMember = members.find(
    (m) => (m.function || '').trim() === 'Secrétaire' && (session.presentIds || []).includes(m.id),
  );
  const secretaryName = secretaryMember ? memberFullName(secretaryMember) : '';
  const signatures: Array<{ role: string; name: string; img?: string }> = [
    { role: 'Le Frère Orateur', name: orateurName || '', img: session.plancheOrateurSignature },
    { role: 'Le Vénérable Maître', name: vmName, img: session.plancheVMSignature },
    { role: 'La Sœur Secrétaire', name: secretaryName, img: session.plancheSecretarySignature },
  ];
  const sigTop = y;
  signatures.forEach((s, i) => {
    const cCenter = margin + colW * i + colW / 2;
    doc.setFont(FONT, 'bold');
    doc.setFontSize(9.5);
    doc.setTextColor(...NAVY);
    doc.text(s.role, cCenter, sigTop, { align: 'center' });
    if (s.img) {
      try {
        doc.addImage(s.img, 'PNG', cCenter - 20, sigTop + 3, 40, 18);
      } catch {
        // signature indisponible
      }
    }
    doc.setFont(FONT, 'normal');
    doc.setFontSize(9);
    doc.setTextColor(0, 0, 0);
    if (s.name) doc.text(s.name, cCenter, sigTop + 26, { align: 'center' });
  });
}
