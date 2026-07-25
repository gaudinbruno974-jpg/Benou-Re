import React, { useState, useEffect } from "react";
import { collection, addDoc, getDocs, updateDoc, deleteDoc, doc, Timestamp, query, orderBy, getDoc, setDoc } from "firebase/firestore";
import { db } from "../firebase";
import {
  ArrowLeft, Plus, Trash2, Edit, Calendar, Users, X, CheckCircle,
  Clock, MapPin, BookOpen, ChevronDown, ToggleLeft, ToggleRight,
  Lock, FileText, FolderOpen, CloudUpload, Loader2, LogOut, ExternalLink, UserCheck
} from "lucide-react";
import { motion, AnimatePresence } from "motion/react";
import { authenticateGoogleDrive, hasGoogleDriveToken, disconnectGoogleDrive, loadLogoDataUrl } from '../lib/googleDrive';
import logoGLDBUrl from '../assets/GLDB.png';
import logoBenouReUrl from '../assets/Benou-Re.png';
import { DEJAVU_SANS_NORMAL_BASE64, DEJAVU_SANS_BOLD_BASE64 } from '../lib/convocationFont';

// ═══════════════════════════════════════════════════════════════════
// TYPES (réutilisés)
// ═══════════════════════════════════════════════════════════════════
type Degre = "Apprenti" | "Compagnon" | "Maître";

interface Session {
  id: string;
  typeTenue: "Ordinaire" | "Extraordinaire" | "Banquet" | "Tenue blanche" | "Tenue noire";
  degreTravail: Degre;
  dateReprise: string;
  heureSuspension: string;
  lieuReunion: string;
  travail1: string;
  travail2: string;
  travail3: string;
  travail4: string;
  ordresJour: string[];
  ligneCloture: string;
  suitAgapes: boolean;
  heureAgape?: string;
  typeRepas?: "Agape avec médaille" | "Agape partage" | "Agape offerte";
  montantMedaille?: number;
  status: "Planifiée" | "En cours" | "Terminée" | "Annulée";
  driveFolderId?: string;
  driveFolderUrl?: string;
  chrono?: number;
  createdAt: Timestamp;
}

// ═══════════════════════════════════════════════════════════════════
// UTILITAIRES
// ═══════════════════════════════════════════════════════════════════
const degreToOrdinal = (degre: Degre): string => {
  switch (degre) {
    case "Apprenti": return "1er";
    case "Compagnon": return "2ème";
    case "Maître": return "3ème";
  }
};

const degreToOrdinalLong = (degre: Degre): string => {
  switch (degre) {
    case "Apprenti": return "1er DEGRE";
    case "Compagnon": return "2eme DEGRE";
    case "Maître": return "3eme DEGRE";
  }
};

// Date maçonnique (simplifiée)
const getMasonicDate = (date: Date): string => {
  const months = ["THOT", "PHAOPHI", "ATHYR", "KOIAK", "TYBI", "MECHIR", 
                  "PHAMENOTH", "PHARMOUTHI", "PACHONS", "PAYNI", "EPIPHI", "MECHORE"];
  const day = date.getDate();
  const month = months[date.getMonth()];
  const year = date.getFullYear() + 1292;
  const dayStr = day === 1 ? "1er" : `${day}ème`;
  return `Le ${dayStr} jour du mois de ${month} de la saison SCHA De l’an ${year} de la Lumière d’Egypte`;
};

const formatDateConvoc = (dateStr: string): string => {
  const d = new Date(dateStr);
  return d.toLocaleDateString("fr-FR", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  }).toUpperCase();
};

const formatDateFolder = (dateStr: string): string => {
  const d = new Date(dateStr);
  const day = String(d.getDate()).padStart(2, "0");
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const year = d.getFullYear();
  return `${day} ${month} ${year}`;
};

// ═══════════════════════════════════════════════════════════════════
// GÉNÉRATION DES TRAVAUX FIXES
// ═══════════════════════════════════════════════════════════════════
const genererTravauxFixes = (degre: Degre, dateReprise: string): {
  travail1: string;
  travail2: string;
  travail3: string;
  travail4: string;
} => {
  const ordinal = degreToOrdinal(degre);
  const heureOuverture = dateReprise
    ? new Date(dateReprise).toLocaleTimeString("fr-FR", {
        hour: "2-digit",
        minute: "2-digit",
      }).replace(":", "h")
    : "xxhxx";

  return {
    travail1: `${heureOuverture} Ouverture des Travaux au ${ordinal} Degré symbolique du R∴A∴P∴M∴M∴ par le V∴M∴ Bruno GAU∴`,
    travail2: "Appel des FF∴ et SS∴ de la loge",
    travail3: `Lecture de la planche tracée de nos derniers travaux au ${ordinal} Degré symbolique.`,
    travail4: "Lecture de la correspondance et des affaires diverses.",
  };
};

const genererLigneCloture = (
  degre: Degre,
  ordresCount: number,
  heureSuspension: string
): string => {
  const ordinal = degreToOrdinal(degre);
  const num = 4 + ordresCount + 1;
  const h = heureSuspension || "xxhxx";
  return `${num}. Clôture des Travaux au ${ordinal} Degré symbolique du R∴A∴P∴M∴M∴ par le V∴M∴ Bruno GAU∴`;
};

// ═══════════════════════════════════════════════════════════════════
// GOOGLE DRIVE API — Création de dossier et upload
// ═══════════════════════════════════════════════════════════════════
const DRIVE_PARENT_FOLDER_ID = "11Qp8SXLFG0Spfks-G6OAQ66EHMGjEOgy";

const createDriveFolder = async (folderName: string, accessToken: string): Promise<{ id: string; url: string }> => {
  const metadata = {
    name: folderName,
    mimeType: "application/vnd.google-apps.folder",
    parents: [DRIVE_PARENT_FOLDER_ID],
  };

  const res = await fetch("https://www.googleapis.com/drive/v3/files", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(metadata),
  });

  if (!res.ok) throw new Error("Erreur création dossier Drive");
  const data = await res.json();
  return {
    id: data.id,
    url: `https://drive.google.com/drive/folders/${data.id}`,
  };
};

const uploadFileToDrive = async (folderId: string, fileName: string, blob: Blob, accessToken: string): Promise<void> => {
  const formData = new FormData();
  formData.append("metadata", new Blob([JSON.stringify({
    name: fileName,
    parents: [folderId],
  })], { type: "application/json" }));
  formData.append("file", blob);

  const res = await fetch("https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart", {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}` },
    body: formData,
  });
  if (!res.ok) throw new Error("Erreur upload du fichier");
};

// ═══════════════════════════════════════════════════════════════════
// GÉNÉRATION PDF CONVOCATION (AVEC LOGOS)
// ═══════════════════════════════════════════════════════════════════
const generateConvocationPDF = async (
  session: Session,
  chrono: number
): Promise<Blob> => {
  const { jsPDF } = await import("jspdf");
  const doc = new jsPDF({ unit: "mm", format: "a4" });

  // Police Unicode intégrée : la police standard de jsPDF ne rend pas les
  // symboles maçonniques « ∴ ». DejaVu Sans (sous-ensemblée) les affiche.
  const FONT = 'DejaVuSans';
  doc.addFileToVFS('DejaVuSans.ttf', DEJAVU_SANS_NORMAL_BASE64);
  doc.addFont('DejaVuSans.ttf', FONT, 'normal');
  doc.addFileToVFS('DejaVuSans-Bold.ttf', DEJAVU_SANS_BOLD_BASE64);
  doc.addFont('DejaVuSans-Bold.ttf', FONT, 'bold');

  const pageWidth = doc.internal.pageSize.getWidth();
  const margin = 15;
  const contentWidth = pageWidth - 2 * margin;
  const centerX = pageWidth / 2;
  const NAVY: [number, number, number] = [12, 35, 92];
  const VIOLET: [number, number, number] = [112, 26, 117];
  let y = 12;

  // ─── LOGOS (GLDB à gauche, Bénou Ré à droite) ──────────────────
  const LOGO_BOX = 26;
  const [logoGLDB, logoBenou] = await Promise.all([
    loadLogoDataUrl(logoGLDBUrl),
    loadLogoDataUrl(logoBenouReUrl),
  ]);
  const placeLogo = (
    logo: Awaited<ReturnType<typeof loadLogoDataUrl>>,
    boxX: number
  ) => {
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
  doc.setFont(FONT, 'bold');
  doc.setFontSize(16);
  doc.setTextColor(NAVY[0], NAVY[1], NAVY[2]);
  doc.text('GRANDE LOGE DE BOURBON', centerX, y + 8, { align: 'center' });
  doc.setFont(FONT, 'normal');
  doc.setFontSize(7.5);
  const subtitle = doc.splitTextToSize(
    'FRANCS-MAÇONS TRAVAILLANT AU RITE ANCIEN ET PRIMITIF DE MEMPHIS MISRAÏM',
    contentWidth - 2 * LOGO_BOX - 8
  );
  doc.text(subtitle, centerX, y + 14, { align: 'center' });

  // Le contenu suivant démarre sous les logos (en-têtes bien aérés).
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
    doc.setFont(FONT, 'bold');
    doc.setFontSize(7.5);
    const nameLines = doc.splitTextToSize(rite.name, colWidth - 2);
    maxNameLines = Math.max(maxNameLines, nameLines.length);
    doc.text(nameLines, colCenter, y, { align: 'center' });
    doc.setFont(FONT, 'normal');
    doc.setFontSize(7);
    doc.text(rite.place, colCenter, y + nameLines.length * 3 + 1, { align: 'center' });
  });
  y += maxNameLines * 3 + 12;

  // ─── FILIATIONS (3 lignes centrées) ────────────────────────────
  doc.setFont(FONT, 'normal');
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
  doc.setFont(FONT, 'bold');
  doc.setFontSize(15);
  doc.setTextColor(NAVY[0], NAVY[1], NAVY[2]);
  doc.text('R∴ L∴ Bénou Ré N°5', centerX, y, { align: 'center' });
  y += 7;
  doc.setFontSize(11);
  doc.text('O∴ de Saint Pierre – Île de la Réunion', centerX, y, { align: 'center' });
  y += 16;

  // ─── CADRE ORDRE DU JOUR ────────────────────────────────────────
  const dateFormatted = formatDateConvoc(session.dateReprise);
  doc.setFont(FONT, 'bold');
  doc.setFontSize(11);
  doc.setTextColor(0, 0, 0);
  const boxTitle = doc.splitTextToSize(
    `ORDRE DU JOUR DE LA TENUE RÉGULIÈRE DU ${dateFormatted} E∴V∴`,
    contentWidth - 12
  );
  const boxHeight = boxTitle.length * 6 + 8;
  doc.setDrawColor(0, 0, 0);
  doc.setLineWidth(0.4);
  doc.rect(margin, y, contentWidth, boxHeight);
  doc.text(boxTitle, centerX, y + 6, { align: 'center' });
  y += boxHeight + 12;

  // ─── INVITATION (lignes centrées) ──────────────────────────────
  doc.setFont(FONT, 'normal');
  doc.setFontSize(11);
  doc.setTextColor(0, 0, 0);
  doc.text('A la Gloire Du Grand Architecte De l\'Univers,', centerX, y, { align: 'center' });
  y += 6;
  doc.text('Mes TT∴CC∴SS∴ et TT∴CC∴FF∴,', centerX, y, { align: 'center' });
  y += 9;
  const degreLong = degreToOrdinalLong(session.degreTravail);
  const typeTenue = session.typeTenue || 'Ordinaire';
  const lieu = session.lieuReunion || 'Temple Thérèse Eliseman à Saint-Pierre';
  // Phrase d'invitation en violet.
  doc.setTextColor(VIOLET[0], VIOLET[1], VIOLET[2]);
  const invitation = doc.splitTextToSize(
    `La R∴L∴ Bénou Ré a la grande joie de vous convier fraternellement à participer aux Travaux de sa ${chrono}° TENUE ${typeTenue.toUpperCase()} au ${degreLong} qui se déroulera au ${lieu} le :`,
    contentWidth
  );
  doc.text(invitation, centerX, y, { align: 'center' });
  y += invitation.length * 5 + 6;

  // ─── DATE ÉGYPTIENNE (bleu foncé) ──────────────────────────────
  const masonicDate = getMasonicDate(new Date(session.dateReprise));
  doc.setFont(FONT, 'bold');
  doc.setFontSize(11);
  doc.setTextColor(NAVY[0], NAVY[1], NAVY[2]);
  const masonicLines = doc.splitTextToSize(masonicDate, contentWidth);
  doc.text(masonicLines, centerX, y, { align: 'center' });
  y += masonicLines.length * 5 + 12;
  doc.setTextColor(0, 0, 0);

  // ─── ORDRE DU JOUR : LISTE NUMÉROTÉE 1 À N ─────────────────────
  doc.setFont(FONT, 'bold');
  doc.setFontSize(12);
  doc.text("L'ordre du jour appellera :", margin, y);
  y += 8;
  doc.setFont(FONT, 'normal');
  doc.setFontSize(11);

  const rawItems = [
    session.travail1,
    session.travail2,
    session.travail3,
    session.travail4,
    ...(session.ordresJour || []).filter(o => o.trim() !== ''),
    session.ligneCloture,
  ]
    .map(item => (item || '').replace(/^\s*\d+\s*[.)]\s*/, '').trim())
    .filter(item => item !== '');

  rawItems.forEach((item, idx) => {
    const numberLabel = `${idx + 1}. `;
    const indent = doc.getTextWidth(numberLabel);
    const lines = doc.splitTextToSize(item, contentWidth - indent);
    doc.text(numberLabel, margin, y);
    doc.text(lines, margin + indent, y);
    y += lines.length * 5.5 + 2.5;
    if (y > 270) { doc.addPage(); y = 20; }
  });
  y += 8;

  // ─── PIED DE PAGE : AGAPES (centré, bleu foncé) ────────────────
  if (session.suitAgapes) {
    if (y > 262) { doc.addPage(); y = 20; }
    doc.setFont(FONT, 'normal');
    doc.setFontSize(10);
    doc.setTextColor(NAVY[0], NAVY[1], NAVY[2]);
    const medaille = session.montantMedaille && session.montantMedaille > 0
      ? ` La médaille est de ${session.montantMedaille} euros.`
      : '';
    const agapeLines = doc.splitTextToSize(
      `Les Travaux seront suivis d'Agapes au nom de la Fraternité en Salle Humide.${medaille}`,
      contentWidth
    );
    doc.text(agapeLines, centerX, y, { align: 'center' });
    y += agapeLines.length * 5 + 3;
    const annonce = doc.splitTextToSize(
      "Merci aux SS∴ et FF∴ Invités de s'annoncer afin d'ajuster au mieux les Agapes. Tél : 06 93 470 700",
      contentWidth
    );
    doc.text(annonce, centerX, y, { align: 'center' });
    doc.setTextColor(0, 0, 0);
  }

  return doc.output("blob");
};

// ═══════════════════════════════════════════════════════════════════
// COMPOSANT PRINCIPAL
// ═══════════════════════════════════════════════════════════════════
interface SessionsListProps {
  currentUser: any;
  sessions: Session[];
  members: any[];
  visitors: any[];
  onAddSession: (session: Session) => void;
  onUpdateSession: (session: Session) => void;
  onDeleteSession: (sessionId: string) => void;
  onOpenPlancheTracee: (sessionId: string) => void;
  onOpenPresence: (sessionId: string) => void;
  onOpenEmargement: (sessionId: string) => void;
  onBack: () => void;
}

export default function SessionsList({ onBack, onOpenPlancheTracee, onOpenPresence, onOpenEmargement }: SessionsListProps) {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [googleToken, setGoogleToken] = useState<string>("");
  const [googleEmail, setGoogleEmail] = useState<string | null>(null);
  const [isConnected, setIsConnected] = useState<boolean>(false);
  const [driveError, setDriveError] = useState<string | null>(null);

  // Vérifier si un token est déjà en cache
  useEffect(() => {
    const checkToken = async () => {
      const tokenExists = hasGoogleDriveToken();
      setIsConnected(tokenExists);
      if (tokenExists) {
        setGoogleEmail("Utilisateur Google");
      }
    };
    checkToken();
  }, []);

  const handleConnectDrive = async () => {
    try {
      setDriveError(null);
      const result = await authenticateGoogleDrive();
      setGoogleToken(result.token);
      setGoogleEmail(result.email);
      setIsConnected(true);
    } catch (err: any) {
      console.error("Erreur connexion Drive:", err);
      const message = err?.message || "Impossible de se connecter à Google Drive. Vérifiez les autorisations.";
      setDriveError(message);
      setIsConnected(false);
    }
  };

  const handleDisconnectDrive = () => {
    disconnectGoogleDrive();
    setGoogleToken("");
    setGoogleEmail(null);
    setIsConnected(false);
  };

  const initialForm: Partial<Session> = {
    typeTenue: "Ordinaire",
    degreTravail: "Apprenti",
    dateReprise: "",
    heureSuspension: "",
    lieuReunion: "Temple Thérèse Eliseman à Saint-Pierre",
    travail1: "",
    travail2: "",
    travail3: "",
    travail4: "",
    ordresJour: [""],
    ligneCloture: "",
    suitAgapes: false,
    heureAgape: "",
    typeRepas: undefined,
    montantMedaille: undefined,
    status: "Planifiée",
  };

  const [formData, setFormData] = useState<Partial<Session>>({ ...initialForm });

  // ─── Chargement ─────────────────────────────────────────────────
  useEffect(() => {
    loadSessions();
  }, []);

  const loadSessions = async () => {
    const q = query(collection(db, "sessions"), orderBy("dateReprise", "desc"));
    const snap = await getDocs(q);
    const data = snap.docs.map((d) => ({ id: d.id, ...d.data() } as Session));
    setSessions(data);
  };

  // ─── Récupère et incrémente le chrono ───────────────────────────
  const getAndIncrementChrono = async (): Promise<number> => {
    const chronoRef = doc(db, "config", "settings");
    const chronoSnap = await getDoc(chronoRef);

    let currentChrono = 1;
    if (chronoSnap.exists()) {
      currentChrono = chronoSnap.data().regularSessionChrono || 1;
    }

    await setDoc(chronoRef, { regularSessionChrono: currentChrono + 1 }, { merge: true });

    return currentChrono;
  };

  // ─── Regénère les textes auto ───────────────────────────────────
  const regenereTextesAuto = (
    prev: Partial<Session>,
    degre: Degre,
    dateReprise: string,
    heureSuspension: string
  ): Partial<Session> => {
    const fixes = genererTravauxFixes(degre, dateReprise);
    const ordres = prev.ordresJour || [""];
    const count = ordres.filter((o: string) => o.trim()).length;
    const cloture = genererLigneCloture(degre, count, heureSuspension);

    return {
      ...prev,
      travail1: fixes.travail1,
      travail2: fixes.travail2,
      travail3: fixes.travail3,
      travail4: fixes.travail4,
      ligneCloture: cloture,
    };
  };

  // ─── Handlers ───────────────────────────────────────────────────
  const handleChange = (field: keyof Session, value: any) => {
    setFormData((prev) => {
      let next = { ...prev, [field]: value };

      if (field === "degreTravail" || field === "dateReprise") {
        next = regenereTextesAuto(
          next,
          (next.degreTravail as Degre) || "Apprenti",
          next.dateReprise || "",
          next.heureSuspension || ""
        );
      }

      if (field === "heureSuspension") {
        const ordres = next.ordresJour || [""];
        const count = ordres.filter((o: string) => o.trim()).length;
        next.ligneCloture = genererLigneCloture(
          (next.degreTravail as Degre) || "Apprenti",
          count,
          value
        );
      }

      if (field === "suitAgapes" && value === false) {
        next.heureAgape = "";
        next.typeRepas = undefined;
        next.montantMedaille = undefined;
      }

      if (field === "typeRepas" && value !== "Agape avec médaille") {
        next.montantMedaille = undefined;
      }

      return next;
    });
  };

  const handleOrdreJourChange = (index: number, value: string) => {
    setFormData((prev) => {
      const newOrdres = [...(prev.ordresJour || [""])];
      newOrdres[index] = value;
      const count = newOrdres.filter((o: string) => o.trim()).length;
      const cloture = genererLigneCloture(
        (prev.degreTravail as Degre) || "Apprenti",
        count,
        prev.heureSuspension || ""
      );
      return { ...prev, ordresJour: newOrdres, ligneCloture: cloture };
    });
  };

  const ajouterLigneOrdre = () => {
    setFormData((prev) => {
      const newOrdres = [...(prev.ordresJour || [""]), ""];
      const count = newOrdres.filter((o: string) => o.trim()).length;
      const cloture = genererLigneCloture(
        (prev.degreTravail as Degre) || "Apprenti",
        count,
        prev.heureSuspension || ""
      );
      return { ...prev, ordresJour: newOrdres, ligneCloture: cloture };
    });
  };

  const supprimerLigneOrdre = (index: number) => {
    setFormData((prev) => {
      const newOrdres = (prev.ordresJour || [""]).filter((_, i) => i !== index);
      if (newOrdres.length === 0) newOrdres.push("");
      const count = newOrdres.filter((o: string) => o.trim()).length;
      const cloture = genererLigneCloture(
        (prev.degreTravail as Degre) || "Apprenti",
        count,
        prev.heureSuspension || ""
      );
      return { ...prev, ordresJour: newOrdres, ligneCloture: cloture };
    });
  };

  // ═══════════════════════════════════════════════════════════════════
  // SUBMIT PRINCIPAL — Création + Drive + PDF
  // ═══════════════════════════════════════════════════════════════════
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.dateReprise || !formData.typeTenue) return;
    setIsSubmitting(true);

    try {
      const degre = (formData.degreTravail as Degre) || "Apprenti";

      // 1. Récupère le chrono
      const chrono = await getAndIncrementChrono();

      // 2. Authentification Google Drive si besoin
      let token = googleToken;
      if (!token) {
        try {
          const auth = await authenticateGoogleDrive();
          token = auth.token;
          setGoogleToken(token);
          setGoogleEmail(auth.email);
          setIsConnected(true);
        } catch (err) {
          console.warn("Connexion Google Drive échouée, le dossier ne sera pas créé.");
        }
      }

      let driveFolderId = "";
      let driveFolderUrl = "";

      if (token) {
        try {
          const folderName = `Tenue ${chrono} ${formatDateFolder(formData.dateReprise)}`;
          const folder = await createDriveFolder(folderName, token);
          driveFolderId = folder.id;
          driveFolderUrl = folder.url;
        } catch (err) {
          console.warn("Erreur création dossier Drive:", err);
        }
      }

      // 3. Préparer les données
      const fixes = genererTravauxFixes(degre, formData.dateReprise);
      const ordres = formData.ordresJour || [""];
      const count = ordres.filter((o: string) => o.trim()).length;
      const cloture = genererLigneCloture(degre, count, formData.heureSuspension || "");

      const payload: any = {
        typeTenue: formData.typeTenue,
        degreTravail: degre,
        dateReprise: formData.dateReprise,
        heureSuspension: formData.heureSuspension || "",
        lieuReunion: formData.lieuReunion || "",
        travail1: fixes.travail1,
        travail2: fixes.travail2,
        travail3: fixes.travail3,
        travail4: fixes.travail4,
        ordresJour: ordres,
        ligneCloture: cloture,
        suitAgapes: formData.suitAgapes || false,
        status: formData.status || "Planifiée",
        chrono,
        driveFolderId,
        driveFolderUrl,
        createdAt: Timestamp.now(),
      };

      if (formData.suitAgapes) {
        payload.heureAgape = formData.heureAgape || "";
        payload.typeRepas = formData.typeRepas;
        if (formData.typeRepas === "Agape avec médaille") {
          payload.montantMedaille = formData.montantMedaille || 0;
        }
      }

      // 4. Sauvegarde Firestore
      let docRef;
      if (editingId) {
        await updateDoc(doc(db, "sessions", editingId), payload);
        docRef = { id: editingId };
      } else {
        docRef = await addDoc(collection(db, "sessions"), payload);
      }

      // 5. Génération et upload du PDF (si token disponible)
      if (token && driveFolderId) {
        try {
          const sessionData = { ...payload, id: editingId || docRef.id } as Session;
          const pdfBlob = await generateConvocationPDF(sessionData, chrono);
          await uploadFileToDrive(driveFolderId, `Convocation_Tenue_${chrono}.pdf`, pdfBlob, token);
        } catch (err) {
          console.warn("Erreur upload PDF:", err);
        }
      }

      setShowForm(false);
      setEditingId(null);
      setFormData({ ...initialForm });
      loadSessions();
    } catch (err) {
      console.error("Erreur lors de la planification:", err);
      alert("Une erreur est survenue. Vérifiez la console.");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (confirm("Supprimer cette tenue ?")) {
      await deleteDoc(doc(db, "sessions", id));
      loadSessions();
    }
  };

  const handleEdit = (session: Session) => {
    setFormData({
      typeTenue: session.typeTenue,
      degreTravail: session.degreTravail,
      dateReprise: session.dateReprise,
      heureSuspension: session.heureSuspension || "",
      lieuReunion: session.lieuReunion || "",
      travail1: session.travail1,
      travail2: session.travail2,
      travail3: session.travail3,
      travail4: session.travail4,
      ordresJour: session.ordresJour || [""],
      ligneCloture: session.ligneCloture || "",
      suitAgapes: session.suitAgapes || false,
      heureAgape: session.heureAgape || "",
      typeRepas: session.typeRepas,
      montantMedaille: session.montantMedaille,
      status: session.status,
    });
    setEditingId(session.id);
    setShowForm(true);
  };

  // ─── Rendu ──────────────────────────────────────────────────────
  return (
    <div className="p-6 max-w-5xl mx-auto">
      {/* Header */}
      <div className="flex items-start justify-between mb-8 gap-4">
        <div className="space-y-3">
          <button
            onClick={onBack}
            className="inline-flex items-center gap-2 text-[#87A0A0] hover:text-[#C5A059] text-xs uppercase tracking-widest font-medium"
          >
            <ArrowLeft className="h-4 w-4" />
            Retour au Parvis
          </button>
          <div>
            <h1 className="text-2xl font-bold text-[#C5A059] tracking-wider">
              Planification des Tenues
            </h1>
            <p className="text-[#87A0A0] text-sm mt-1">
              Gérez les tenues de la R.L. Bénou Ré
            </p>
          </div>
        </div>
        <div className="flex items-center gap-3">
          {isConnected ? (
            <div className="flex items-center gap-1 text-xs text-emerald-400 bg-emerald-500/10 px-3 py-1.5 rounded-full border border-emerald-500/20">
              <span className="h-2 w-2 rounded-full bg-emerald-400 animate-pulse" />
              Drive connecté
              <button onClick={handleDisconnectDrive} className="ml-1 text-[#87A0A0] hover:text-white">
                <LogOut size={14} />
              </button>
            </div>
          ) : (
            <button
              onClick={handleConnectDrive}
              className="flex items-center gap-1.5 bg-[#0C7A7A] hover:bg-[#0A6565] text-white px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
            >
              <CloudUpload size={14} />
              Connecter Drive
            </button>
          )}
        </div>
      </div>
      {driveError && (
        <div className="mb-4 rounded-xl border border-rose-500/20 bg-rose-500/5 p-3 text-sm text-rose-200">
          <strong className="block text-xs uppercase tracking-widest text-rose-300">Erreur Google Drive</strong>
          <p className="mt-1 leading-relaxed">{driveError}</p>
        </div>
      )}
      <button
        onClick={() => {
          setShowForm(true);
          setEditingId(null);
          setFormData({ ...initialForm });
        }}
        className="flex items-center gap-2 bg-[#0C7A7A] hover:bg-[#0A6565] text-white px-5 py-2.5 rounded-lg transition-colors font-medium"
      >
        <Plus size={18} />
        Nouvelle tenue
      </button>

      {/* ═══════════════════════════════════════════════════════════════
          FORMULAIRE
          ═══════════════════════════════════════════════════════════════ */}
      <AnimatePresence>
        {showForm && (
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="bg-[#122428] border border-[#C5A05930] rounded-xl p-6 mb-8"
          >
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-lg font-semibold text-[#C5A059]">
                {editingId ? "Modifier la tenue" : "Planifier une tenue"}
              </h2>
              <button
                onClick={() => setShowForm(false)}
                className="text-[#87A0A0] hover:text-white transition-colors"
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-5">
              {/* ── Ligne 1 : Type + Degré ── */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-[#87A0A0] text-sm mb-2">Type de Tenue</label>
                  <div className="relative">
                    <select
                      value={formData.typeTenue}
                      onChange={(e) => handleChange("typeTenue", e.target.value)}
                      className="w-full bg-[#081619] border border-[#C5A05930] rounded-lg px-4 py-2.5 text-white focus:border-[#C5A059] focus:outline-none appearance-none"
                    >
                      <option value="Ordinaire">Ordinaire</option>
                      <option value="Extraordinaire">Extraordinaire</option>
                      <option value="Banquet">Banquet</option>
                      <option value="Tenue blanche">Tenue blanche</option>
                      <option value="Tenue noire">Tenue noire</option>
                    </select>
                    <ChevronDown size={16} className="absolute right-3 top-1/2 -translate-y-1/2 text-[#87A0A0] pointer-events-none" />
                  </div>
                </div>
                <div>
                  <label className="block text-[#87A0A0] text-sm mb-2">Degré de Travail</label>
                  <div className="relative">
                    <select
                      value={formData.degreTravail}
                      onChange={(e) => handleChange("degreTravail", e.target.value as Degre)}
                      className="w-full bg-[#081619] border border-[#C5A05930] rounded-lg px-4 py-2.5 text-white focus:border-[#C5A059] focus:outline-none appearance-none"
                    >
                      <option value="Apprenti">Apprenti (1er Degré)</option>
                      <option value="Compagnon">Compagnon (2ème Degré)</option>
                      <option value="Maître">Maître (3ème Degré)</option>
                    </select>
                    <ChevronDown size={16} className="absolute right-3 top-1/2 -translate-y-1/2 text-[#87A0A0] pointer-events-none" />
                  </div>
                </div>
              </div>

              {/* ── Ligne 2 : Date & Heure ── */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-[#87A0A0] text-sm mb-2">Date & Heure de reprise</label>
                  <input
                    type="datetime-local"
                    value={formData.dateReprise}
                    onChange={(e) => handleChange("dateReprise", e.target.value)}
                    className="w-full bg-[#081619] border border-[#C5A05930] rounded-lg px-4 py-2.5 text-white focus:border-[#C5A059] focus:outline-none"
                    required
                  />
                </div>
                <div>
                  <label className="block text-[#87A0A0] text-sm mb-2">Heure de suspension (Clôture)</label>
                  <input
                    type="time"
                    value={formData.heureSuspension}
                    onChange={(e) => handleChange("heureSuspension", e.target.value)}
                    className="w-full bg-[#081619] border border-[#C5A05930] rounded-lg px-4 py-2.5 text-white focus:border-[#C5A059] focus:outline-none"
                  />
                </div>
              </div>

              {/* ── Lieu ── */}
              <div>
                <label className="block text-[#87A0A0] text-sm mb-2">Lieu de Réunion</label>
                <div className="relative">
                  <MapPin size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#87A0A0]" />
                  <input
                    type="text"
                    value={formData.lieuReunion}
                    onChange={(e) => handleChange("lieuReunion", e.target.value)}
                    className="w-full bg-[#081619] border border-[#C5A05930] rounded-lg pl-10 pr-4 py-2.5 text-white focus:border-[#C5A059] focus:outline-none"
                  />
                </div>
              </div>

              {/* ═══════════════════════════════════════════════════════════
                  ORDRE DU JOUR — TOUS LES CHAMPS MODIFIABLES
                  ═══════════════════════════════════════════════════════════ */}
              <div>
                <label className="block text-[#C5A059] text-sm font-medium mb-3 tracking-wide">
                  ORDRE DU JOUR — TRAVAUX FIXES ({degreToOrdinal((formData.degreTravail as Degre) || "Apprenti")} Degré)
                </label>
                <div className="space-y-3">
                  {[1, 2, 3, 4].map((num) => {
                    const field = `travail${num}` as keyof Session;
                    const value = (formData[field] as string) || "";
                    return (
                      <div key={num} className="flex items-start gap-3">
                        <span className="text-[#C5A059] text-xs font-mono mt-2.5 w-6 shrink-0">{num}.</span>
                        <div className="flex-1">
                          <input
                            type="text"
                            value={value}
                            onChange={(e) => handleChange(field, e.target.value)}
                            className="w-full bg-[#081619] border border-[#C5A05930] rounded-lg px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none"
                            placeholder={`Saisir le travail ${num}`}
                          />
                        </div>
                      </div>
                    );
                  })}
                </div>
                <p className="text-[#87A0A060] text-xs mt-2">
                  Tous les travaux peuvent être modifiés manuellement.
                </p>
              </div>

              {/* ═══════════════════════════════════════════════════════════
                  ORDRES COMPLÉMENTAIRES
                  ═══════════════════════════════════════════════════════════ */}
              <div>
                <div className="flex items-center justify-between mb-3">
                  <label className="block text-[#C5A059] text-sm font-medium tracking-wide">
                    [ + ] ORDRES DU JOUR COMPLÉMENTAIRES
                  </label>
                  <button
                    type="button"
                    onClick={ajouterLigneOrdre}
                    className="text-[#0C7A7A] hover:text-[#C5A059] text-xs font-medium flex items-center gap-1 transition-colors"
                  >
                    <Plus size={14} />
                    Ajouter une ligne
                  </button>
                </div>
                <div className="space-y-2">
                  {(formData.ordresJour || [""]).map((ordre, idx) => (
                    <div key={idx} className="flex items-center gap-2">
                      <span className="text-[#C5A059] text-xs font-mono w-6">{5 + idx}.</span>
                      <input
                        type="text"
                        value={ordre}
                        onChange={(e) => handleOrdreJourChange(idx, e.target.value)}
                        placeholder="ex: Lecture de planche..."
                        className="flex-1 bg-[#081619] border border-[#C5A05930] rounded-lg px-3 py-2 text-white text-sm focus:border-[#C5A059] focus:outline-none placeholder-[#87A0A040]"
                      />
                      {(formData.ordresJour || []).length > 1 && (
                        <button
                          type="button"
                          onClick={() => supprimerLigneOrdre(idx)}
                          className="p-1.5 text-[#87A0A0] hover:text-red-400 transition-colors"
                        >
                          <Trash2 size={14} />
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              {/* ═══════════════════════════════════════════════════════════
                  LIGNE DE CLÔTURE (modifiable)
                  ═══════════════════════════════════════════════════════════ */}
              <div>
                <label className="block text-[#87A0A0] text-sm mb-2">Ligne de clôture</label>
                <input
                  type="text"
                  value={formData.ligneCloture || ""}
                  onChange={(e) => handleChange("ligneCloture", e.target.value)}
                  className="w-full bg-[#081619] border border-[#C5A05930] rounded-lg px-4 py-2.5 text-white text-sm focus:border-[#C5A059] focus:outline-none"
                  placeholder="Saisir la clôture"
                />
                <p className="text-[#87A0A060] text-xs mt-1">
                  Numéro auto-généré : {4 + (formData.ordresJour || []).filter((o) => o.trim()).length + 1}° (vous pouvez modifier le texte).
                </p>
              </div>

              {/* ═══════════════════════════════════════════════════════════
                  SECTION AGAPE
                  ═══════════════════════════════════════════════════════════ */}
              <div className="border-t border-[#C5A05920] pt-5">
                <div className="flex items-center justify-between mb-4">
                  <label className="block text-[#C5A059] text-sm font-medium tracking-wide">
                    SUIT-ELLE D'AGAPES FRATERNELLES ?
                  </label>
                  <button
                    type="button"
                    onClick={() => handleChange("suitAgapes", !formData.suitAgapes)}
                    className="relative"
                  >
                    {formData.suitAgapes ? (
                      <ToggleRight size={40} className="text-[#0C7A7A]" />
                    ) : (
                      <ToggleLeft size={40} className="text-[#87A0A040]" />
                    )}
                  </button>
                </div>

                <AnimatePresence>
                  {formData.suitAgapes && (
                    <motion.div
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: "auto" }}
                      exit={{ opacity: 0, height: 0 }}
                      transition={{ duration: 0.25 }}
                      className="overflow-hidden"
                    >
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                          <label className="block text-[#87A0A0] text-sm mb-2">Heure de l'agape</label>
                          <input
                            type="time"
                            value={formData.heureAgape || ""}
                            onChange={(e) => handleChange("heureAgape", e.target.value)}
                            className="w-full bg-[#081619] border border-[#C5A05930] rounded-lg px-4 py-2.5 text-white focus:border-[#C5A059] focus:outline-none"
                          />
                        </div>
                        <div>
                          <label className="block text-[#87A0A0] text-sm mb-2">Type de repas</label>
                          <div className="relative">
                            <select
                              value={formData.typeRepas || ""}
                              onChange={(e) => handleChange("typeRepas", e.target.value)}
                              className="w-full bg-[#081619] border border-[#C5A05930] rounded-lg px-4 py-2.5 text-white focus:border-[#C5A059] focus:outline-none appearance-none"
                            >
                              <option value="">-- Sélectionnez --</option>
                              <option value="Agape avec médaille">🏅 Agape avec médaille</option>
                              <option value="Agape partage">🤝 Agape partage</option>
                              <option value="Agape offerte">🎁 Agape offerte</option>
                            </select>
                            <ChevronDown size={16} className="absolute right-3 top-1/2 -translate-y-1/2 text-[#87A0A0] pointer-events-none" />
                          </div>
                        </div>
                      </div>

                      <AnimatePresence>
                        {formData.typeRepas === "Agape avec médaille" && (
                          <motion.div
                            initial={{ opacity: 0, y: -10 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: -10 }}
                            className="mt-4"
                          >
                            <label className="block text-[#87A0A0] text-sm mb-2">Montant de la médaille (€)</label>
                            <div className="relative max-w-xs">
                              <input
                                type="number"
                                min="0"
                                step="0.01"
                                value={formData.montantMedaille || ""}
                                onChange={(e) => handleChange("montantMedaille", parseFloat(e.target.value) || 0)}
                                placeholder="Ex: 15.00"
                                className="w-full bg-[#081619] border border-[#C5A059] rounded-lg px-4 py-2.5 text-white focus:outline-none focus:ring-2 focus:ring-[#C5A05940]"
                              />
                              <span className="absolute right-4 top-1/2 -translate-y-1/2 text-[#C5A059] font-medium">€</span>
                            </div>
                          </motion.div>
                        )}
                      </AnimatePresence>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>

              {/* ── Boutons ── */}
              <div className="flex gap-3 pt-4 border-t border-[#C5A05920]">
                <button
                  type="button"
                  onClick={() => setShowForm(false)}
                  className="flex-1 py-2.5 border border-[#C5A05930] text-[#87A0A0] rounded-lg hover:bg-[#C5A05910] transition-colors font-medium"
                >
                  ANNULER
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="flex-1 bg-[#0C7A7A] hover:bg-[#0A6565] disabled:opacity-50 text-white py-2.5 rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
                >
                  {isSubmitting ? (
                    <>
                      <Loader2 size={18} className="animate-spin" />
                      Traitement...
                    </>
                  ) : (
                    <>
                      <CheckCircle size={18} />
                      {editingId ? "ENREGISTRER" : "PLANIFIER"}
                    </>
                  )}
                </button>
              </div>
            </form>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ═══════════════════════════════════════════════════════════════
          LISTE DES TENUES
          ═══════════════════════════════════════════════════════════════ */}
      <div className="space-y-4">
        {sessions.length === 0 ? (
          <div className="text-center py-16 text-[#87A0A0]">
            <Calendar size={56} className="mx-auto mb-4 opacity-20" />
            <p className="text-lg">Aucune tenue planifiée</p>
          </div>
        ) : (
          sessions.map((session) => {
            const ordresCount = session.ordresJour?.filter((o) => o.trim()).length || 0;
            return (
              <motion.div
                key={session.id}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                className="bg-[#122428] border border-[#C5A05920] rounded-xl p-5 hover:border-[#C5A05940] transition-colors"
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-3 flex-wrap">
                      <span className={`px-2.5 py-1 rounded-full text-xs font-medium ${
                        session.typeTenue === "Banquet" ? "bg-[#C5A05920] text-[#C5A059]" : "bg-[#0C7A7A20] text-[#0C7A7A]"
                      }`}>{session.typeTenue}</span>
                      <span className="px-2.5 py-1 rounded-full text-xs font-medium bg-[#C5A05915] text-[#C5A059]">
                        {session.degreTravail} ({degreToOrdinal(session.degreTravail)} Degré)
                      </span>
                      <span className={`px-2.5 py-1 rounded-full text-xs font-medium ${
                        session.status === "Planifiée" ? "bg-blue-500/15 text-blue-400" :
                        session.status === "Terminée" ? "bg-green-500/15 text-green-400" :
                        "bg-red-500/15 text-red-400"
                      }`}>{session.status}</span>
                      {session.chrono && (
                        <span className="px-2.5 py-1 rounded-full text-xs font-medium bg-[#C5A05915] text-[#C5A059]">
                          Tenue n°{session.chrono}
                        </span>
                      )}
                      {session.driveFolderUrl && (
                        <a
                          href={session.driveFolderUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs bg-[#0C7A7A20] text-[#0C7A7A] hover:bg-[#0C7A7A30] transition"
                        >
                          <FolderOpen size={12} />
                          Drive
                        </a>
                      )}
                    </div>

                    <h3 className="text-white font-semibold text-lg">
                      {new Date(session.dateReprise).toLocaleDateString("fr-FR", {
                        weekday: "long", year: "numeric", month: "long", day: "numeric",
                      })}
                    </h3>

                    <div className="flex flex-wrap items-center gap-x-4 gap-y-1 mt-2 text-sm text-[#87A0A0]">
                      <span className="flex items-center gap-1.5">
                        <Clock size={14} className="text-[#0C7A7A]" />
                        {new Date(session.dateReprise).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}
                        {session.heureSuspension && <> → <span className="text-[#C5A059]">{session.heureSuspension}</span></>}
                      </span>
                      <span className="flex items-center gap-1.5">
                        <MapPin size={14} className="text-[#0C7A7A]" />
                        {session.lieuReunion}
                      </span>
                    </div>

                    <div className="mt-3 pl-3 border-l-2 border-[#C5A05920]">
                      <p className="text-xs text-[#87A0A060] mb-1 uppercase tracking-wider">
                        Ordre du jour ({4 + ordresCount + 1} points)
                      </p>
                      <p className="text-sm text-[#87A0A0] line-clamp-2">
                        1. {session.travail1} — 2. {session.travail2} — 3. {session.travail3} — 4. {session.travail4}
                        {ordresCount > 0 && ` — +${ordresCount} ordre(s)`}
                        {" — "}<span className="text-[#C5A059]">{session.ligneCloture}</span>
                      </p>
                    </div>

                    {session.suitAgapes && session.typeRepas && (
                      <div className="mt-3 flex items-center gap-3 text-sm">
                        <span className="flex items-center gap-1.5 text-[#C5A059]">
                          <Users size={14} />
                          {session.typeRepas}
                        </span>
                        {session.montantMedaille !== undefined && session.montantMedaille > 0 && (
                          <span className="text-[#C5A059] font-medium">— {session.montantMedaille.toFixed(2)} €</span>
                        )}
                      </div>
                    )}
                  </div>

                  <div className="flex items-center gap-2 ml-4 shrink-0 flex-wrap">
                    <button
                      onClick={() => onOpenPresence(session.id)}
                      className="inline-flex items-center gap-2 px-3 py-2 text-[11px] font-semibold uppercase rounded-xl bg-sky-500/10 text-sky-200 border border-sky-500/20 hover:bg-sky-500/15 transition-colors"
                      title="Gérer la présence"
                    >
                      <Users size={16} />
                      Présence
                    </button>
                    <button
                      onClick={() => onOpenEmargement(session.id)}
                      className="inline-flex items-center gap-2 px-3 py-2 text-[11px] font-semibold uppercase rounded-xl bg-emerald-500/10 text-emerald-200 border border-emerald-500/20 hover:bg-emerald-500/15 transition-colors"
                      title="Accéder à l'émargement"
                    >
                      <UserCheck size={16} />
                      Émargement
                    </button>
                    <button
                      onClick={() => onOpenPlancheTracee(session.id)}
                      className="inline-flex items-center gap-2 px-3 py-2 text-[11px] font-semibold uppercase rounded-xl bg-fuchsia-500/10 text-fuchsia-200 border border-fuchsia-500/20 hover:bg-fuchsia-500/15 transition-colors"
                      title="Ouvrir la planche tracée"
                    >
                      <FileText size={16} />
                      Planche tracée
                    </button>
                    <button onClick={() => handleEdit(session)} className="p-2 text-[#87A0A0] hover:text-[#C5A059] hover:bg-[#C5A05910] rounded-lg transition-colors" title="Modifier">
                      <Edit size={18} />
                    </button>
                    <button onClick={() => handleDelete(session.id)} className="p-2 text-[#87A0A0] hover:text-red-400 hover:bg-red-400/10 rounded-lg transition-colors" title="Supprimer">
                      <Trash2 size={18} />
                    </button>
                  </div>
                </div>
              </motion.div>
            );
          })
        )}
      </div>
    </div>
  );
}