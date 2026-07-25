import React, { useMemo, useEffect, useState } from 'react';
import { ArrowLeft, FileText } from 'lucide-react';
import { Member, Session, Visitor } from '../types';
import { generateEmargementHtml, generateEmargementPdf, authenticateGoogleDrive, uploadBlobToDrive } from '../lib/googleDrive';
import SignaturePad from './SignaturePad';

interface SessionEmargementScreenProps {
  currentUser: Member;
  sessions: Session[];
  members: Member[];
  visitors: Visitor[];
  selectedSessionId?: string | null;
  onUpdateSession: (updatedSession: Session) => void;
  onBack: () => void;
  onNavigate: (view: string) => void;
}

export default function SessionEmargementScreen({
  currentUser,
  sessions,
  members,
  visitors,
  selectedSessionId,
  onUpdateSession,
  onBack,
  onNavigate,
}: SessionEmargementScreenProps) {
  const session = useMemo(
    () => sessions.find((s) => s.id === selectedSessionId) || sessions[0] || null,
    [selectedSessionId, sessions]
  );

  const [showSignaturePad, setShowSignaturePad] = useState(false);
  const [previewKey, setPreviewKey] = useState(0);
  const [signingPersonId, setSigningPersonId] = useState<string | null>(null);
  const [isExporting, setIsExporting] = useState(false);
  const [driveStatus, setDriveStatus] = useState<{ type: 'idle' | 'uploading' | 'success' | 'warning' | 'error'; message: string }>({ type: 'idle', message: '' });

  const safeSession = useMemo(() => {
    if (!session) return null;
    return {
      ...session,
      presentIds: session.presentIds || [],
      excusedIds: session.excusedIds || [],
      visitorIds: session.visitorIds || [],
      signatures: session.signatures || {},
      visitorRoles: session.visitorRoles || {},
      title: session.title || session.typeTenue || '',
      location: session.location || session.lieuReunion || '',
      date: session.date || session.dateReprise || '',
      type: session.type || session.typeTenue || 'Ordinaire',
      degree: session.degree || session.degreTravail || 'Apprenti',
      troncAmount: session.troncAmount || 0,
      closingTime: session.closingTime || '18:30',
    } as Session;
  }, [session]);

  const presentMembers = useMemo(
    () => (safeSession ? members.filter((m) => safeSession.presentIds.includes(m.id)) : []),
    [safeSession, members]
  );

  const presentVisitors = useMemo(
    () => (safeSession ? visitors.filter((v) => safeSession.visitorIds.includes(v.id)) : []),
    [safeSession, visitors]
  );

  const presentAttendees = useMemo(() => {
    if (!safeSession) return [];
    const memberItems = presentMembers.map((m) => ({
      id: m.id,
      name: `${m.firstName} ${m.lastName}`,
      role: m.function !== 'Aucun' ? m.function : 'Membre de l\'Atelier',
      signed: Boolean(safeSession.signatures[m.id]),
    }));
    const visitorItems = presentVisitors.map((v) => ({
      id: v.id,
      name: `${v.firstName} ${v.lastName}`,
      role: safeSession.visitorRoles?.[v.id] || v.function || 'Visiteur',
      signed: Boolean(safeSession.signatures[v.id]),
    }));
    return [...memberItems, ...visitorItems];
  }, [safeSession, presentMembers, presentVisitors]);

  const signingPerson = useMemo(() => {
    if (!signingPersonId) return null;
    return (
      presentAttendees.find((person) => person.id === signingPersonId) ||
      [...presentMembers, ...presentVisitors].find((person) => person.id === signingPersonId) ||
      null
    );
  }, [signingPersonId, presentAttendees, presentMembers, presentVisitors]);

  const nextUnsignedPerson = presentAttendees.find((person) => !person.signed) || null;

  const sheetHtml = useMemo(
    () => (safeSession ? generateEmargementHtml(safeSession, members, visitors) : ''),
    [safeSession, members, visitors, previewKey]
  );

  const handleExportPdf = async () => {
    if (!safeSession || isExporting) return;
    setIsExporting(true);
    setDriveStatus({ type: 'idle', message: '' });
    const fileName = `Feuille-Emargement-Tenue-${session.sessionNumber || session.id}.pdf`;
    let blob: Blob;
    try {
      blob = await generateEmargementPdf(session, members, visitors);
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = fileName;
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Erreur génération PDF émargement:', error);
      setDriveStatus({ type: 'error', message: 'Impossible de générer le PDF. Vérifiez la console.' });
      setIsExporting(false);
      return;
    }

    const driveFolderId = session.driveFolderId;
    if (!driveFolderId) {
      setDriveStatus({
        type: 'warning',
        message: "PDF téléchargé localement. Aucun dossier Google Drive n'est associé à cette tenue : l'archivage sur Drive a été ignoré.",
      });
      setIsExporting(false);
      return;
    }

    try {
      setDriveStatus({ type: 'uploading', message: 'Archivage du PDF sur Google Drive…' });
      const { token } = await authenticateGoogleDrive();
      await uploadBlobToDrive(token, driveFolderId, fileName, blob);
      setDriveStatus({
        type: 'success',
        message: 'PDF téléchargé localement et archivé dans le dossier Google Drive de la tenue.',
      });
    } catch (error) {
      console.error('Erreur upload PDF émargement sur Drive:', error);
      const detail = error instanceof Error ? error.message : String(error);
      setDriveStatus({
        type: 'error',
        message: `PDF téléchargé localement, mais l'archivage sur Google Drive a échoué : ${detail}`,
      });
    } finally {
      setIsExporting(false);
    }
  };

  const handleSaveSignature = (base64Png: string) => {
    if (!safeSession || !signingPersonId) return;
    onUpdateSession({
      ...safeSession,
      signatures: {
        ...safeSession.signatures,
        [signingPersonId]: base64Png,
      },
    });
    setShowSignaturePad(false);
    setSigningPersonId(null);
    setPreviewKey((prev) => prev + 1);
  };

  useEffect(() => {
    document.body.style.overflow = showSignaturePad ? 'hidden' : '';
    return () => {
      document.body.style.overflow = '';
    };
  }, [showSignaturePad]);

  if (!session) {
    return (
      <div className="min-h-screen bg-[#081619] text-[#E8E8E8] flex flex-col items-center justify-center p-6">
        <div className="text-center space-y-4">
          <p className="text-lg font-semibold">Aucune tenue sélectionnée</p>
          <button onClick={onBack} className="px-4 py-2 rounded-lg bg-amber-500 text-[#081619] font-bold uppercase tracking-widest">Retour</button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#081619] text-[#E8E8E8] pb-6">
      <header className="bg-[#122428] border-b border-amber-500/20 sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 py-4 flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:gap-3">
            <button onClick={onBack} className="p-2 rounded-lg bg-teal-950/40 border border-teal-900/30 text-teal-400 hover:bg-teal-900/20 transition">
              <ArrowLeft className="h-4 w-4" />
            </button>
            <div>
              <p className="text-[10px] uppercase tracking-widest font-mono text-[#87A0A0]">Feuille d&apos;émargement</p>
              <h1 className="text-lg font-bold uppercase tracking-wider text-white">Tenue n°{session.sessionNumber || (session.chrono ? `${session.chrono}` : 'N/A')} — {session.title}</h1>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <button
              onClick={() => {
                if (nextUnsignedPerson) {
                  setSigningPersonId(nextUnsignedPerson.id);
                  setShowSignaturePad(true);
                }
              }}
              disabled={!nextUnsignedPerson}
              className={`inline-flex items-center gap-2 px-4 py-2 rounded-xl font-bold uppercase tracking-widest transition ${nextUnsignedPerson ? 'bg-amber-500 text-[#081619] hover:bg-amber-400' : 'bg-slate-500/30 text-slate-300 cursor-not-allowed'}`}
            >
              <FileText className="h-4 w-4" />
              {nextUnsignedPerson ? `Signer ${nextUnsignedPerson.name}` : 'Tous signés'}
            </button>
            <button
              onClick={handleExportPdf}
              disabled={isExporting}
              className={`inline-flex items-center gap-2 px-4 py-2 rounded-xl font-bold uppercase tracking-widest transition ${isExporting ? 'bg-blue-500/40 text-[#081619]/70 cursor-not-allowed' : 'bg-blue-500 text-[#081619] hover:bg-blue-400'}`}
            >
              <FileText className="h-4 w-4" />
              {isExporting ? 'Export en cours…' : 'Export PDF'}
            </button>
          </div>
        </div>
        <div className="max-w-7xl mx-auto px-4 pb-3 border-b border-amber-500/10 flex flex-wrap gap-2">
          <button
            onClick={() => onNavigate('parvis')}
            className="rounded-full border border-amber-500/20 bg-[#081619]/80 px-3 py-2 text-[11px] uppercase tracking-widest text-amber-300 hover:bg-[#081619] transition"
          >
            Parvis
          </button>
          <button
            onClick={() => onNavigate('presence')}
            className="rounded-full border border-teal-500/20 bg-[#081619]/80 px-3 py-2 text-[11px] uppercase tracking-widest text-teal-300 hover:bg-[#081619] transition"
          >
            Présence
          </button>
          <button
            onClick={() => onNavigate('planche_tracee')}
            className="rounded-full border border-amber-500/20 bg-[#081619]/80 px-3 py-2 text-[11px] uppercase tracking-widest text-amber-300 hover:bg-[#081619] transition"
          >
            Planche tracée
          </button>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-6">
        {driveStatus.type !== 'idle' && (
          <div
            className={`mb-6 rounded-2xl border px-4 py-3 text-sm ${
              driveStatus.type === 'success'
                ? 'border-emerald-500/30 bg-emerald-500/10 text-emerald-200'
                : driveStatus.type === 'warning'
                ? 'border-amber-500/30 bg-amber-500/10 text-amber-200'
                : driveStatus.type === 'error'
                ? 'border-red-500/30 bg-red-500/10 text-red-200'
                : 'border-blue-500/30 bg-blue-500/10 text-blue-200'
            }`}
          >
            {driveStatus.message}
          </div>
        )}
        <div className="bg-[#122428] border border-[#87A0A0]/10 rounded-3xl p-5 mb-6">
          <div className="flex flex-col gap-4">
            <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
              <div className="flex items-center gap-3">
                <FileText className="h-5 w-5 text-amber-400" />
                <div>
                  <p className="text-xs uppercase tracking-widest text-[#87A0A0]">Émargement</p>
                  <p className="text-sm text-white">Chaque personne présente doit signer sa feuille.</p>
                </div>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <span className="rounded-full bg-slate-800/80 px-3 py-1 text-xs uppercase tracking-wider text-slate-200">
                  {presentAttendees.filter((person) => !person.signed).length} signature(s) manquante(s)
                </span>
                <button
                  onClick={() => {
                    if (nextUnsignedPerson) {
                      setSigningPersonId(nextUnsignedPerson.id);
                      setShowSignaturePad(true);
                    }
                  }}
                  disabled={!nextUnsignedPerson}
                  className={`inline-flex items-center gap-2 px-4 py-2 rounded-xl font-bold uppercase tracking-widest transition ${nextUnsignedPerson ? 'bg-amber-500 text-[#081619] hover:bg-amber-400' : 'bg-slate-500/30 text-slate-300 cursor-not-allowed'}`}
                >
                  <FileText className="h-4 w-4" />
                  {nextUnsignedPerson ? `Signer ${nextUnsignedPerson.name}` : 'Tous signés'}
                </button>
              </div>
            </div>
            <div className="grid gap-3 md:grid-cols-2">
              {presentAttendees.length > 0 ? (
                presentAttendees.map((attendee) => (
                  <div key={attendee.id} className="rounded-3xl border border-[#87A0A0]/10 bg-[#081619]/90 p-4 flex items-center justify-between gap-4">
                    <div>
                      <p className="text-sm font-semibold text-white">{attendee.name}</p>
                      <p className="text-xs text-[#87A0A0]">{attendee.role}</p>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className={`rounded-full px-2 py-1 text-[11px] font-semibold ${attendee.signed ? 'bg-emerald-500/15 text-emerald-300' : 'bg-amber-500/15 text-amber-200'}`}>
                        {attendee.signed ? 'Signé' : 'En attente'}
                      </span>
                      {!attendee.signed && (
                        <button
                          onClick={() => {
                            setSigningPersonId(attendee.id);
                            setShowSignaturePad(true);
                          }}
                          className="px-3 py-2 rounded-xl bg-amber-500 text-[#081619] text-[11px] font-bold uppercase tracking-wider"
                        >
                          Signer
                        </button>
                      )}
                    </div>
                  </div>
                ))
              ) : (
                <div className="rounded-3xl border border-[#87A0A0]/10 bg-[#081619]/90 p-4 text-sm text-[#E2E8E8]">
                  Aucun participant présent n&apos;a été trouvé pour cette session.
                </div>
              )}
            </div>
          </div>
        </div>

        <div className="overflow-hidden rounded-3xl border border-[#87A0A0]/10 bg-[#081619]/90">
          <iframe id="emargement-preview" title="Aperçu de la feuille d'émargement" srcDoc={sheetHtml} className="w-full min-h-[calc(100vh-220px)] border-none bg-white" />
        </div>
      </main>

      {showSignaturePad && (
        <SignaturePad title="Signatures de la feuille d'émargement" onSave={handleSaveSignature} onCancel={() => setShowSignaturePad(false)} />
      )}
    </div>
  );
}
