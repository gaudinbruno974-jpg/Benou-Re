import React, { useEffect, useState } from 'react';
import {
  ArrowLeft,
  CheckCircle2,
  Clock,
  Compass,
  Edit3,
  Eye,
  FileText,
  Printer,
  Save,
  Sparkles
} from 'lucide-react';
import { Member, Session, Visitor } from '../types';
import GoogleDriveArchivePanel from './GoogleDriveArchivePanel';
import SignaturePad from './SignaturePad';

interface PlancheTraceeScreenProps {
  currentUser: Member;
  sessions: Session[];
  members: Member[];
  visitors: Visitor[];
  selectedSessionId?: string | null;
  onUpdateSession: (updatedSession: Session) => void;
  onBack: () => void;
}

export default function PlancheTraceeScreen({
  currentUser,
  sessions,
  members,
  visitors,
  selectedSessionId,
  onUpdateSession,
  onBack
}: PlancheTraceeScreenProps) {
  const [selectedSession, setSelectedSession] = useState<Session | null>(
    sessions.find((session) => session.id === selectedSessionId) || sessions[0] || null
  );
  const [isEditing, setIsEditing] = useState(false);
  const [draftText, setDraftText] = useState('');
  const [sacText, setSacText] = useState('');
  const [showSignaturePad, setShowSignaturePad] = useState(false);
  const [signingRole, setSigningRole] = useState<'secretaire' | 'vm' | null>(null);

  const functionTrim = (currentUser.function || '').trim();
  const isVM = functionTrim === 'Vénérable Maître' ||
    currentUser.email === 'gaudin.bruno974@gmail.com' ||
    currentUser.email === 'vm@loge.com';
  const isSecretary = functionTrim === 'Secrétaire' ||
    currentUser.email === 'muriel.mete.mm@gmail.com';

  const canEdit = isVM || isSecretary;

  useEffect(() => {
    if (!selectedSessionId) return;
    const found = sessions.find((session) => session.id === selectedSessionId);
    if (found) {
      setSelectedSession(found);
    }
  }, [selectedSessionId, sessions]);

  useEffect(() => {
    if (!selectedSession) return;
    setDraftText(selectedSession.plancheDraftText || '');
    setSacText(selectedSession.sacPropositions || '');
  }, [selectedSession]);

  if (!selectedSession) {
    return (
      <div className="min-h-screen bg-[#081619] text-[#E8E8E8] flex flex-col items-center justify-center p-6">
        <div className="text-center space-y-4">
          <FileText className="h-16 w-16 text-amber-500/40 mx-auto" />
          <p className="text-sm text-gray-400">Aucune tenue n'est disponible pour tracer une planche.</p>
          <button onClick={onBack} className="text-xs text-amber-500 font-mono underline hover:text-amber-400">
            Retourner au Parvis
          </button>
        </div>
      </div>
    );
  }

  const selectedSessionDate = selectedSession.date || selectedSession.dateReprise || '';
  const selectedSessionLocation = selectedSession.location || selectedSession.lieuReunion || 'Lieu inconnu';
  const selectedSessionDegree = selectedSession.degree || selectedSession.degreTravail || 'Apprenti';

  const formatDate = (dateString: string) => {
    if (!dateString) return 'Date inconnue';
    return new Date(dateString).toLocaleDateString('fr-FR', {
      day: 'numeric',
      month: 'long',
      year: 'numeric'
    });
  };

  const handleGenerateTemplate = () => {
    const presentMembers = members.filter((m) => selectedSession.presentIds?.includes(m.id));
    const visitorNames = visitors
      .filter((v) => selectedSession.visitorIds?.includes(v.id))
      .map((v) => {
        const titleAndName = `V∴ S∴ ${v.firstName} ${v.lastName}`;
        const sessionRole = selectedSession.visitorRoles?.[v.id];
        const funcSuffix = sessionRole && sessionRole !== 'Simple Visiteur'
          ? `, occupant l'office de ${sessionRole}`
          : (v.function ? `, ${v.function}` : '');
        return `${titleAndName} (${v.lodge} - Orient de ${v.orient}${funcSuffix})`;
      });

    const formattedDate = formatDate(selectedSessionDate);

    const template = `L'An de la Vraie Lumière ${selectedSession.egyptianYear || '6026'} (Saison de l'Inondation), le ${formattedDate}, sous les auspices du Grand Architecte de l'Univers, les Travaux de la Respectable Loge "Bénou Ré" à l'Orient de Saint-Pierre (La Réunion) ont été régulièrement ouverts au ${selectedSessionDegree === 'Apprenti' ? '1er Degré (Apprenti)' : selectedSessionDegree === 'Compagnon' ? '2ème Degré (Compagnon)' : '3ème Degré (Maître)'} symbolique.

I. OUVERTURE DES TRAVAUX
Les Travaux ont été ouverts à l'heure prescrite par le Vénérable Maître ${selectedSession.vmName || 'Bruno GAUDIN'}, assisté des Officiers de l'Atelier.

II. APPEL & PRÉSENCES
Le Secrétaire a procédé à l'appel des FF∴ et SS∴ de la Loge.
- Membres présents : ${presentMembers.length > 0 ? presentMembers.map((m) => `${m.firstName} ${m.lastName}`).join(', ') : 'Néant'}
- Visiteurs accueillis : ${visitorNames.length > 0 ? visitorNames.join(', ') : 'Aucun visiteur'}

III. TRAVAUX DU JOUR
L'Ordre du Jour de la tenue comportait :
1. Lecture et approbation de la dernière planche tracée.
2. Correspondance et affaires diverses.
3. Travaux thématiques : "${selectedSession.title}"
   - ${selectedSession.description || "Présentation et morceaux d'architecture de l'Atelier."}

IV. TRONC DE LA VEUVE & SAC AUX PROPOSITIONS
Le Tronc de la Veuve a produit la somme de ${selectedSession.troncAmount || 0} € consacrée aux œuvres de bienfaisance.

V. CLÔTURE DES TRAVAUX
L'Ordre du Jour étant épuisé, le Vénérable Maître a clos les travaux en la forme accoutumée.`;

    setDraftText(template);
    setSacText('R.A.S');
  };

  const handleSave = () => {
    const updated: Session = {
      ...selectedSession,
      plancheDraftText: draftText,
      sacPropositions: sacText
    };
    onUpdateSession(updated);
    setSelectedSession(updated);
    setIsEditing(false);
  };

  const handleSaveSignature = (base64Png: string) => {
    if (!signingRole) return;
    const updated: Session = {
      ...selectedSession,
      plancheSecretarySignature: signingRole === 'secretaire' ? base64Png : selectedSession.plancheSecretarySignature,
      plancheVMSignature: signingRole === 'vm' ? base64Png : selectedSession.plancheVMSignature,
      plancheSecretarySigned: signingRole === 'secretaire' ? true : selectedSession.plancheSecretarySigned,
      plancheVMSigned: signingRole === 'vm' ? true : selectedSession.plancheVMSigned
    };
    onUpdateSession(updated);
    setSelectedSession(updated);
    setShowSignaturePad(false);
    setSigningRole(null);
  };

  const handleStartSignature = (role: 'secretaire' | 'vm') => {
    setSigningRole(role);
    setShowSignaturePad(true);
  };

  const presentCount = selectedSession.presentIds?.length || 0;
  const visitorCount = selectedSession.visitorIds?.length || 0;

  return (
    <div className="min-h-screen bg-[#081619] text-[#E8E8E8] pb-12 select-none animate-fade-in">
      <div className="hidden print:block bg-white text-black p-8 font-serif leading-relaxed max-w-4xl mx-auto" style={{ pageBreakInside: 'avoid' }}>
        <div className="flex justify-between items-start border-b-2 border-gray-900 pb-4 mb-6">
          <div>
            <h1 className="text-xl font-bold uppercase tracking-widest font-sans text-gray-900">Respectable Loge Bénou Ré</h1>
            <p className="text-xs uppercase tracking-wider font-mono text-gray-600">O∴ A∴ P∴ M∴ M∴ (Memphis-Misraïm)</p>
            <p className="text-xs text-gray-500">Orient de Saint-Pierre — La Réunion</p>
          </div>
          <div className="text-right text-xs space-y-0.5 text-gray-600 font-mono">
            <div>Tenue N° : {selectedSession.sessionNumber || selectedSession.chrono || 'N/A'}</div>
            <div>A∴ V∴ L∴ : {selectedSession.egyptianYear || '6026'}</div>
            <div>Degré : {selectedSessionDegree === 'Apprenti' ? '1er Degré' : selectedSessionDegree === 'Compagnon' ? '2ème Degré' : '3ème Degré'}</div>
          </div>
        </div>

        <div className="text-center my-6 space-y-1">
          <h2 className="text-2xl font-bold uppercase tracking-widest font-sans text-gray-900">Planche Tracée des Travaux</h2>
          <p className="text-sm italic text-gray-600">Tracée rédigée le {formatDate(selectedSessionDate)}</p>
        </div>

        <div className="text-sm whitespace-pre-wrap leading-relaxed text-gray-800 font-serif border-b border-gray-300 pb-6 mb-6">
          {draftText || 'Aucun contenu n'a encore été tracé pour cette tenue.'}
        </div>

        <div className="bg-gray-100 p-4 rounded border border-gray-300 text-xs mb-8 space-y-1">
          <h4 className="font-bold text-gray-900 uppercase font-sans tracking-wider">Résultat du Sac aux propositions :</h4>
          <p className="italic text-gray-700">{sacText || 'Aucune proposition déposée.'}</p>
        </div>

        <div className="grid grid-cols-2 gap-12 pt-6 border-t border-gray-300">
          <div className="text-center space-y-8">
            <span className="text-xs uppercase tracking-wider font-bold block text-gray-700">Le Secrétaire de l'Atelier</span>
            <div className="h-16 flex items-center justify-center">
              {selectedSession.plancheSecretarySigned ? (
                <div className="text-[#0C7A7A] font-mono text-xs border border-dashed border-[#0C7A7A] px-3 py-1 -rotate-3 uppercase font-bold bg-[#0C7A7A]/5">
                  ✓ SIGNÉ NUMÉRIQUEMENT
                </div>
              ) : (
                <span className="text-xs text-gray-400 italic">Signature en attente</span>
              )}
            </div>
            <span className="text-xs text-gray-500 block font-sans">Muriel MARTIN-FANTINO</span>
          </div>

          <div className="text-center space-y-8">
            <span className="text-xs uppercase tracking-wider font-bold block text-gray-700">Le Vénérable Maître</span>
            <div className="h-16 flex items-center justify-center">
              {selectedSession.plancheVMSigned ? (
                <div className="text-amber-600 font-mono text-xs border border-dashed border-amber-600 px-3 py-1 -rotate-3 uppercase font-bold bg-amber-500/5">
                  ✓ APPROUVÉ & VALIDE
                </div>
              ) : (
                <span className="text-xs text-gray-400 italic">Validation en attente</span>
              )}
            </div>
            <span className="text-xs text-gray-500 block font-sans">{selectedSession.vmName || 'Bruno GAUDIN'}</span>
          </div>
        </div>
      </div>

      <div className="print:hidden">
        <header className="bg-[#122428] border-b border-amber-500/20 sticky top-0 z-40 shadow-md">
          <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <button
                onClick={onBack}
                className="p-2 rounded-lg bg-teal-950/40 border border-teal-900/30 text-teal-400 hover:bg-teal-900/20 transition"
              >
                <ArrowLeft className="h-4 w-4" />
              </button>
              <h2 className="font-sans text-lg font-bold uppercase tracking-wider text-white flex items-center gap-2">
                <FileText className="h-5 w-5 text-amber-500" />
                Planches Tracées
              </h2>
            </div>

            <div className="flex items-center gap-2">
              <button
                onClick={handlePrint}
                className="flex items-center gap-2 px-4 py-2 rounded-xl bg-[#081619] border border-amber-500/20 text-[#87A0A0] text-xs font-bold hover:bg-amber-500/5 hover:text-white transition"
              >
                <Printer className="h-4 w-4 text-[#C5A059]" />
                IMPRIMER
              </button>
            </div>
          </div>
        </header>

        <main className="max-w-7xl mx-auto px-4 mt-8 grid grid-cols-1 lg:grid-cols-12 gap-8">
          <div className="lg:col-span-4 space-y-4">
            <h3 className="text-xs font-mono text-amber-500 uppercase tracking-widest flex items-center gap-1.5">
              <Compass className="h-4 w-4" />
              Sélectionner une Tenue
            </h3>

            <div className="space-y-2 max-h-[75vh] overflow-y-auto pr-2 custom-scrollbar">
              {sessions.map((s) => {
                const isSelected = selectedSession.id === s.id;
                const validated = s.plancheValidated;
                const secSigned = s.plancheSecretarySigned;
                const vmSigned = s.plancheVMSigned;

                return (
                  <button
                    key={s.id}
                    onClick={() => { setSelectedSession(s); setIsEditing(false); }}
                    className={`w-full text-left p-4 rounded-xl border transition flex flex-col gap-2 ${
                      isSelected
                        ? 'bg-[#122428] border-amber-500/30 shadow-lg shadow-amber-500/5'
                        : 'bg-[#122428]/40 border-amber-500/10 hover:border-amber-500/20'
                    }`}
                  >
                    <div className="flex justify-between items-start gap-2">
                      <span className="text-[10px] font-mono text-amber-400 font-bold uppercase">
                        N° {s.sessionNumber || 'N/A'} • {s.type || s.typeTenue || 'Ordinaire'}
                      </span>
                      <span className="text-[9px] text-[#87A0A0] font-mono shrink-0">
                        {new Date(s.date || s.dateReprise || '').toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })}
                      </span>
                    </div>

                    <h4 className="font-sans text-xs font-bold text-white uppercase group-hover:text-amber-300 transition line-clamp-1">
                      {s.title}
                    </h4>

                    <div className="flex flex-wrap gap-1.5 pt-1">
                      {validated ? (
                        <span className="px-1.5 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 text-[8px] font-bold font-mono">
                          VALIDÉE (VM)
                        </span>
                      ) : (
                        <span className="px-1.5 py-0.5 rounded bg-amber-500/10 text-amber-500 border border-amber-500/20 text-[8px] font-bold font-mono">
                          BROUILLON
                        </span>
                      )}
                      {secSigned && (
                        <span className="px-1.5 py-0.5 rounded bg-teal-500/10 text-teal-300 border border-teal-500/20 text-[8px] font-bold font-mono">
                          SEC ✓
                        </span>
                      )}
                      {vmSigned && (
                        <span className="px-1.5 py-0.5 rounded bg-amber-500/10 text-amber-400 border border-amber-500/20 text-[8px] font-bold font-mono">
                          VM ✓
                        </span>
                      )}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="lg:col-span-8 space-y-6">
            <div className="bg-[#122428] border border-amber-500/15 rounded-2xl p-5 flex flex-wrap items-center justify-between gap-4">
              <div>
                <span className="text-[10px] font-mono text-[#87A0A0] uppercase block">TRAVAUX SÉLECTIONNÉS</span>
                <h3 className="font-sans text-base font-bold text-white uppercase tracking-wider">
                  {selectedSession.title}
                </h3>
                <p className="text-xs text-[#C5A059] font-mono mt-0.5">
                  Tenue du {formatDate(selectedSessionDate)} • {selectedSessionLocation}
                </p>
              </div>

              <div className="flex gap-2">
                <div className="bg-[#081619] border border-[#87A0A0]/10 rounded-xl p-2 px-3 text-center min-w-18">
                  <span className="text-[8px] text-[#87A0A0] block uppercase">Présents</span>
                  <span className="text-sm font-bold text-teal-400 font-mono">{presentCount} FF</span>
                </div>
                <div className="bg-[#081619] border border-[#87A0A0]/10 rounded-xl p-2 px-3 text-center min-w-18">
                  <span className="text-[8px] text-[#87A0A0] block uppercase">Visiteurs</span>
                  <span className="text-sm font-bold text-amber-500 font-mono">{visitorCount} FF</span>
                </div>
                <div className="bg-[#081619] border border-[#87A0A0]/10 rounded-xl p-2 px-3 text-center min-w-18">
                  <span className="text-[8px] text-[#87A0A0] block uppercase">Tronc (€)</span>
                  <span className="text-sm font-bold text-emerald-400 font-mono">{selectedSession.troncAmount || 0} €</span>
                </div>
              </div>
            </div>

            <div className="bg-[#122428]/40 border border-amber-500/10 rounded-2xl p-5 space-y-4">
              <div className="flex flex-wrap items-center justify-between gap-4 border-b border-amber-500/5 pb-4">
                <h4 className="text-xs font-mono text-amber-500 uppercase tracking-widest flex items-center gap-1.5">
                  <Sparkles className="h-4 w-4" />
                  État du Tracé & Signatures
                </h4>

                <div className="flex items-center gap-2">
                  {canEdit && !selectedSession.plancheDraftText && !isEditing && (
                    <button
                      onClick={() => { setIsEditing(true); handleGenerateTemplate(); }}
                      className="px-3 py-1.5 rounded-lg bg-amber-500/10 border border-amber-500/30 text-amber-400 text-xs font-bold hover:bg-amber-500/20 transition"
                    >
                      Pré-remplir la Planche
                    </button>
                  )}
                  {canEdit && !isEditing && (
                    <button
                      onClick={() => setIsEditing(true)}
                      className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-[#0C7A7A] hover:bg-[#0A6868] text-white text-xs font-bold transition border border-amber-500/10"
                    >
                      <Edit3 className="h-3.5 w-3.5" />
                      RÉDIGER
                    </button>
                  )}
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-1">
                <div className="bg-[#081619]/60 border border-[#87A0A0]/10 rounded-xl p-4 flex items-center justify-between gap-3">
                  <div className="space-y-0.5">
                    <span className="text-[9px] text-[#87A0A0] block uppercase font-mono">Secrétaire de l'Atelier</span>
                    <span className="text-xs font-bold text-white">Muriel MARTIN-FANTINO</span>
                    <div className="flex items-center gap-1 mt-1">
                      {selectedSession.plancheSecretarySigned ? (
                        <span className="text-[9px] text-teal-400 font-mono font-semibold flex items-center gap-1">
                          <CheckCircle2 className="h-3 w-3" /> Signée numériquement
                        </span>
                      ) : (
                        <span className="text-[9px] text-gray-500 font-mono flex items-center gap-1">
                          <Clock className="h-3 w-3" /> En attente de signature
                        </span>
                      )}
                    </div>
                  </div>
                  {isSecretary && (
                    <button
                      onClick={() => handleStartSignature('secretaire')}
                      className={`px-3 py-1.5 rounded-lg text-xs font-bold font-mono transition border ${
                        selectedSession.plancheSecretarySigned
                          ? 'bg-red-950/20 border-red-500/30 text-red-400 hover:bg-red-900/20'
                          : 'bg-teal-500/10 border-teal-500/30 text-teal-400 hover:bg-teal-500/20'
                      }`}
                    >
                      {selectedSession.plancheSecretarySigned ? 'RETIRER' : 'SIGNER'}
                    </button>
                  )}
                </div>

                <div className="bg-[#081619]/60 border border-[#87A0A0]/10 rounded-xl p-4 flex items-center justify-between gap-3">
                  <div className="space-y-0.5">
                    <span className="text-[9px] text-[#87A0A0] block uppercase font-mono">Vénérable Maître</span>
                    <span className="text-xs font-bold text-white">{selectedSession.vmName || 'Bruno GAUDIN'}</span>
                    <div className="flex items-center gap-1 mt-1">
                      {selectedSession.plancheVMSigned ? (
                        <span className="text-[9px] text-amber-400 font-mono font-semibold flex items-center gap-1">
                          <CheckCircle2 className="h-3 w-3" /> Approuvée & Validée
                        </span>
                      ) : (
                        <span className="text-[9px] text-gray-500 font-mono flex items-center gap-1">
                          <Clock className="h-3 w-3" /> En attente d'approbation
                        </span>
                      )}
                    </div>
                  </div>
                  {isVM && (
                    <button
                      onClick={() => handleStartSignature('vm')}
                      className={`px-3 py-1.5 rounded-lg text-xs font-bold font-mono transition border ${
                        selectedSession.plancheVMSigned
                          ? 'bg-red-950/20 border-red-500/30 text-red-400 hover:bg-red-900/20'
                          : 'bg-amber-500/10 border-amber-500/30 text-amber-400 hover:bg-amber-500/20'
                      }`}
                    >
                      {selectedSession.plancheVMSigned ? 'RETIRER' : 'APPROUVER'}
                    </button>
                  )}
                </div>
              </div>
            </div>

            {(selectedSession.plancheValidated || selectedSession.plancheVMSigned) && (
              <GoogleDriveArchivePanel
                session={selectedSession}
                members={members}
                visitors={visitors}
                onUpdateSession={onUpdateSession}
              />
            )}

            <div className="bg-[#122428] border border-amber-500/20 rounded-2xl shadow-xl overflow-hidden">
              <div className="bg-[#122428] px-6 py-4 border-b border-amber-500/10 flex items-center justify-between">
                <span className="text-xs font-mono text-amber-400 font-bold uppercase tracking-widest flex items-center gap-1.5">
                  <Eye className="h-4 w-4 text-amber-500" />
                  {isEditing ? 'ÉDITION DU TRACÉ DES TRAVAUX' : 'LECTURE DE LA PLANCHE TRACÉE'}
                </span>
                {selectedSession.plancheValidated && (
                  <span className="px-2.5 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 text-[9px] font-bold font-mono tracking-widest">
                    RECONNU CONFORME
                  </span>
                )}
              </div>

              {isEditing ? (
                <div className="p-6 space-y-5">
                  <div className="space-y-1.5">
                    <label className="text-xs text-[#87A0A0] font-mono uppercase tracking-wider block">Texte de la planche (Détails de la tenue)</label>
                    <textarea
                      value={draftText}
                      onChange={(e) => setDraftText(e.target.value)}
                      placeholder="Tapez ou pré-remplissez le texte officiel de la planche..."
                      className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-3 text-xs text-white focus:border-[#C5A059] focus:outline-none min-h-64 leading-relaxed font-serif"
                    />
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-xs text-[#87A0A0] font-mono uppercase tracking-wider block">Sac aux propositions / Tronc de la Veuve</label>
                    <input
                      type="text"
                      value={sacText}
                      onChange={(e) => setSacText(e.target.value)}
                      placeholder="Résultats et propositions déposées..."
                      className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-3 text-xs text-white focus:border-[#C5A059] focus:outline-none"
                    />
                  </div>

                  <div className="flex gap-3 justify-end border-t border-amber-500/10 pt-4">
                    <button
                      onClick={() => setIsEditing(false)}
                      className="px-5 py-2 rounded-xl border border-gray-600 hover:bg-gray-800 text-xs font-bold transition font-mono uppercase"
                    >
                      Annuler
                    </button>
                    <button
                      onClick={handleSave}
                      className="flex items-center gap-1.5 px-6 py-2 rounded-xl bg-[#0C7A7A] hover:bg-[#0A6868] text-white text-xs font-bold transition border border-amber-500/10 font-mono uppercase"
                    >
                      <Save className="h-4 w-4" />
                      Sauvegarder
                    </button>
                  </div>
                </div>
              ) : (
                <div className="p-6 md:p-8 space-y-6">
                  {!selectedSession.plancheDraftText ? (
                    <div className="text-center py-12 space-y-4">
                      <FileText className="h-12 w-12 text-[#87A0A0]/30 mx-auto" />
                      <p className="text-xs text-[#87A0A0] leading-relaxed max-w-sm mx-auto">
                        Le tracé de cette tenue n'a pas encore été rédigé. {canEdit ? "Cliquez sur 'Pré-remplir la Planche' ou 'RÉDIGER' pour commencer la saisie." : "Seuls le VM et le Secrétaire de l'Atelier peuvent rédiger le tracé."}
                      </p>
                      {canEdit && (
                        <button
                          onClick={() => { setIsEditing(true); handleGenerateTemplate(); }}
                          className="px-4 py-2 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-400 text-xs font-bold hover:bg-amber-500/20 transition uppercase font-mono"
                        >
                          Pré-remplir la Planche
                        </button>
                      )}
                    </div>
                  ) : (
                    <>
                      <div className="whitespace-pre-wrap font-serif text-sm leading-relaxed text-gray-300 border-b border-amber-500/5 pb-6">
                        {selectedSession.plancheDraftText}
                      </div>

                      <div className="bg-[#081619] border border-amber-500/10 rounded-xl p-4 space-y-1.5">
                        <span className="text-[10px] text-amber-500 font-mono block uppercase">SAC AUX PROPOSITIONS</span>
                        <p className="text-xs italic text-gray-400">
                          {selectedSession.sacPropositions || 'R.A.S — Aucun dépôt.'}
                        </p>
                      </div>

                      <div className="grid grid-cols-2 gap-4 border-t border-amber-500/10 pt-6">
                        <div className="text-center space-y-1">
                          <span className="text-[9px] text-[#87A0A0] uppercase block">Secrétariat</span>
                          <span className="text-xs font-semibold text-white block">Muriel MARTIN-FANTINO</span>
                          <span className={`inline-block text-[9px] font-mono uppercase px-2 py-0.5 rounded ${
                            selectedSession.plancheSecretarySigned ? 'bg-teal-500/10 text-teal-300' : 'bg-gray-500/10 text-gray-500'
                          }`}>
                            {selectedSession.plancheSecretarySigned ? 'SIGNÉ ✓' : 'NON SIGNÉ'}
                          </span>
                        </div>
                        <div className="text-center space-y-1">
                          <span className="text-[9px] text-[#87A0A0] uppercase block">Vénérable Maître</span>
                          <span className="text-xs font-semibold text-white block">{selectedSession.vmName || 'Bruno GAUDIN'}</span>
                          <span className={`inline-block text-[9px] font-mono uppercase px-2 py-0.5 rounded ${
                            selectedSession.plancheVMSigned ? 'bg-amber-500/10 text-amber-400' : 'bg-gray-500/10 text-gray-500'
                          }`}>
                            {selectedSession.plancheVMSigned ? 'APPROUVÉ ✓' : 'NON SIGNÉ'}
                          </span>
                        </div>
                      </div>
                    </>
                  )}
                </div>
              )}
            </div>
          </div>
        </main>
      </div>

      {showSignaturePad && (
        <div className="fixed inset-0 z-50 bg-black/60 flex items-center justify-center p-4">
          <div className="w-full max-w-3xl rounded-3xl bg-[#122428] border border-amber-500/20 shadow-2xl overflow-hidden">
            <div className="flex items-center justify-between px-5 py-4 border-b border-amber-500/10">
              <div>
                <h3 className="text-sm font-bold uppercase tracking-wider text-white">Capture de signature</h3>
                <p className="text-xs text-[#87A0A0]">Signer en tant que {signingRole === 'vm' ? 'Vénérable Maître' : 'Secrétaire'}</p>
              </div>
              <button onClick={() => setShowSignaturePad(false)} className="text-xs text-amber-300 hover:text-white">Fermer</button>
            </div>
            <div className="p-5">
              <SignaturePad onSave={handleSaveSignature} onCancel={() => setShowSignaturePad(false)} />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
