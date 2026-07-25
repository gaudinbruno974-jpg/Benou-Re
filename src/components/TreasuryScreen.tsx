import React, { useState } from 'react';
import { 
  ArrowLeft, 
  Wallet, 
  Coins, 
  Lock, 
  CheckCircle, 
  XCircle, 
  Users, 
  Calendar,
  AlertCircle
} from 'lucide-react';
import { Member, Session } from '../types';

interface TreasuryScreenProps {
  currentUser: Member;
  members: Member[];
  sessions: Session[];
  onUpdateMember: (updatedMember: Member) => void;
  onBack: () => void;
}

export default function TreasuryScreen({
  currentUser,
  members,
  sessions,
  onUpdateMember,
  onBack
}: TreasuryScreenProps) {
  const [activeTab, setActiveTab] = useState<'cotisations' | 'tronc'>('cotisations');

  const functionTrim = (currentUser.function || '').trim();
  const isAdmin = currentUser.isAdmin || false;
  
  // Edit rights for treasury: Admin, Trésorier, or VM
  const canEdit = isAdmin || 
    functionTrim.includes('Trésorier') || 
    functionTrim.includes('Vénérable Maître') ||
    functionTrim.includes('Vénérable Maitre') ||
    functionTrim.includes('Vénérable maître') ||
    currentUser.email === 'vm@loge.com' ||
    currentUser.email === 'gaudin.bruno974@gmail.com' ||
    currentUser.email === 'benoure974@gmail.com';

  // Calculations for Cotisations
  let totalCollected = 0;
  let totalPending = 0;

  members.forEach(m => {
    // Lodge dues
    if (m.lodgeDuesPaid) totalCollected += m.lodgeDues;
    else totalPending += m.lodgeDues;

    // Order dues
    if (m.orderDuesPaid) totalCollected += m.orderDues;
    else totalPending += m.orderDues;

    // Elevation dues
    if (m.elevationDues > 0) {
      if (m.elevationDuesPaid) totalCollected += m.elevationDues;
      else totalPending += m.elevationDues;
    }
  });

  // Calculations for Tronc de la Veuve (charity tronc collected from all sessions)
  const sessionsWithTronc = sessions.filter(s => s.troncAmount > 0);
  const totalTroncCollected = sessions.reduce((acc, curr) => acc + (curr.troncAmount || 0), 0);

  const handleToggleDue = (member: Member, dueType: 'lodge' | 'order' | 'elevation') => {
    if (!canEdit) return;

    const updated = { ...member };
    if (dueType === 'lodge') {
      updated.lodgeDuesPaid = !updated.lodgeDuesPaid;
    } else if (dueType === 'order') {
      updated.orderDuesPaid = !updated.orderDuesPaid;
    } else if (dueType === 'elevation') {
      updated.elevationDuesPaid = !updated.elevationDuesPaid;
    }

    onUpdateMember(updated);
  };

  return (
    <div className="min-h-screen bg-[#081619] text-[#E8E8E8] pb-12 animate-fade-in select-none">
      {/* Header */}
      <header className="bg-[#122428] border-b border-amber-500/20 sticky top-0 z-40 shadow-md">
        <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button 
              onClick={onBack}
              className="p-2 rounded-lg bg-teal-950/40 border border-teal-900/30 text-teal-400 hover:bg-teal-900/20 transition"
            >
              <ArrowLeft className="h-4 w-4" />
            </button>
            <h2 className="font-sans text-lg font-bold uppercase tracking-wider text-white">
              Trésorerie de la Loge
            </h2>
          </div>

          <div className="flex gap-1.5 bg-[#081619] p-1 rounded-xl border border-[#87A0A0]/10">
            <button
              onClick={() => setActiveTab('cotisations')}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1 ${
                activeTab === 'cotisations' 
                  ? 'bg-[#0C7A7A] text-white border border-amber-500/10' 
                  : 'text-[#87A0A0] hover:text-white'
              }`}
            >
              <Users className="h-3.5 w-3.5" />
              Cotisations
            </button>
            <button
              onClick={() => setActiveTab('tronc')}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1 ${
                activeTab === 'tronc' 
                  ? 'bg-[#0C7A7A] text-white border border-amber-500/10' 
                  : 'text-[#87A0A0] hover:text-white'
              }`}
            >
              <Coins className="h-3.5 w-3.5" />
              Tronc de la Veuve
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-4xl mx-auto px-4 mt-8">
        {/* VIEW 1: COTISATIONS SHEET */}
        {activeTab === 'cotisations' && (
          <div className="space-y-6">
            {/* Financial Balance Counters Cards Row */}
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-[#122428] border border-emerald-500/20 rounded-2xl p-5 text-center flex flex-col items-center justify-center gap-1 shadow-lg shadow-emerald-500/5">
                <span className="text-[10px] text-emerald-400 font-mono tracking-widest uppercase">Total encaissé</span>
                <span className="text-3xl font-extrabold text-emerald-400 tracking-tight font-sans">
                  {totalCollected.toLocaleString('fr-FR')} €
                </span>
                <span className="text-[10px] text-[#87A0A0] mt-1">Reçu en banque de loge</span>
              </div>

              <div className="bg-[#122428] border border-amber-500/20 rounded-2xl p-5 text-center flex flex-col items-center justify-center gap-1 shadow-lg shadow-amber-500/5">
                <span className="text-[10px] text-amber-500 font-mono tracking-widest uppercase">À percevoir</span>
                <span className="text-3xl font-extrabold text-amber-500 tracking-tight font-sans">
                  {totalPending.toLocaleString('fr-FR')} €
                </span>
                <span className="text-[10px] text-[#87A0A0] mt-1">Relances à envoyer</span>
              </div>
            </div>

            {/* Non-editor Warning banner */}
            {!canEdit && (
              <div className="bg-amber-950/20 border border-amber-500/20 rounded-xl p-3 px-4 text-xs text-amber-400 flex items-center gap-2">
                <Lock className="h-4 w-4 shrink-0" />
                <span>Mode Consultation uniquement. Seuls le VM et le Trésorier peuvent basculer le statut de paiement des fiches.</span>
              </div>
            )}

            {/* Members Cotisation Grid */}
            <div className="space-y-3">
              <h3 className="text-xs font-mono tracking-widest text-[#C5A059] uppercase flex items-center gap-1">
                <Coins className="h-4 w-4" />
                DÉTAIL DES COMPTES INDIVIDUELS ({members.length})
              </h3>

              {members.map(member => {
                return (
                  <div
                    key={member.id}
                    className="p-5 rounded-2xl bg-[#122428] border border-amber-500/10 flex flex-col sm:flex-row justify-between sm:items-center gap-4 shadow-md"
                  >
                    <div>
                      <h4 className="font-sans text-sm font-bold text-white uppercase tracking-wider">
                        {member.firstName} {member.lastName}
                      </h4>
                      <p className="text-xs text-[#87A0A0]">
                        {member.grade} • {member.function !== 'Aucun' ? member.function : 'Membre'}
                      </p>
                    </div>

                    {/* Dues boxes control row */}
                    <div className="flex flex-wrap gap-3">
                      {/* Loge due button */}
                      <button
                        onClick={() => handleToggleDue(member, 'lodge')}
                        disabled={!canEdit}
                        className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl border text-xs font-bold transition ${
                          member.lodgeDuesPaid 
                            ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400' 
                            : 'bg-rose-500/10 border-rose-500/30 text-rose-400 hover:bg-rose-500/20'
                        } ${!canEdit ? 'cursor-default' : ''}`}
                      >
                        {member.lodgeDuesPaid ? <CheckCircle className="h-3.5 w-3.5" /> : <XCircle className="h-3.5 w-3.5" />}
                        <span>LOGE : {member.lodgeDues} €</span>
                      </button>

                      {/* Order due button */}
                      <button
                        onClick={() => handleToggleDue(member, 'order')}
                        disabled={!canEdit}
                        className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl border text-xs font-bold transition ${
                          member.orderDuesPaid 
                            ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400' 
                            : 'bg-rose-500/10 border-rose-500/30 text-rose-400 hover:bg-rose-500/20'
                        } ${!canEdit ? 'cursor-default' : ''}`}
                      >
                        {member.orderDuesPaid ? <CheckCircle className="h-3.5 w-3.5" /> : <XCircle className="h-3.5 w-3.5" />}
                        <span>ORDRE : {member.orderDues} €</span>
                      </button>

                      {/* Elevation due button */}
                      {member.elevationDues > 0 && (
                        <button
                          onClick={() => handleToggleDue(member, 'elevation')}
                          disabled={!canEdit}
                          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl border text-xs font-bold transition ${
                            member.elevationDuesPaid 
                              ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400' 
                              : 'bg-rose-500/10 border-rose-500/30 text-rose-400 hover:bg-rose-500/20'
                          } ${!canEdit ? 'cursor-default' : ''}`}
                        >
                          {member.elevationDuesPaid ? <CheckCircle className="h-3.5 w-3.5" /> : <XCircle className="h-3.5 w-3.5" />}
                          <span>GRADES : {member.elevationDues} €</span>
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* VIEW 2: TRONC DE LA VEUVE HISTORIQUE */}
        {activeTab === 'tronc' && (
          <div className="space-y-6">
            {/* Tronc Total Collected Counter */}
            <div className="bg-[#122428] border border-amber-500/20 rounded-2xl p-6 text-center flex flex-col items-center justify-center gap-1 shadow-lg shadow-amber-500/5 relative overflow-hidden">
              <div className="absolute right-0 top-0 w-32 h-32 bg-amber-500/5 rounded-full blur-2xl pointer-events-none" />
              <Wallet className="h-10 w-10 text-[#C5A059] mb-2 animate-bounce" />
              <span className="text-[10px] text-[#87A0A0] font-mono tracking-widest uppercase">Caisse Générale du Tronc</span>
              <span className="text-4xl font-extrabold text-[#C5A059] tracking-tight font-sans">
                {totalTroncCollected.toFixed(2)} €
              </span>
              <span className="text-xs text-[#87A0A0] mt-1 max-w-sm">
                Fonds entièrement dédiés aux œuvres de bienfaisance et à l'aide aux veuves et orphelins de l'atelier.
              </span>
            </div>

            {/* Tronc sessions history list */}
            <div className="space-y-3">
              <h3 className="text-xs font-mono tracking-widest text-[#C5A059] uppercase flex items-center gap-1">
                <Calendar className="h-4 w-4" />
                HISTORIQUE DE VÉRIFICATION DES TENUES
              </h3>

              {sessionsWithTronc.length === 0 ? (
                <div className="text-center py-12 bg-[#122428]/40 border border-dashed border-gray-800 rounded-2xl text-gray-500">
                  Aucun tronc de la veuve n'a encore été récolté ou enregistré.
                </div>
              ) : (
                <div className="space-y-3">
                  {sessionsWithTronc.map(session => (
                    <div
                      key={session.id}
                      className="p-4 rounded-xl bg-[#122428] border border-amber-500/10 flex items-center justify-between shadow-md"
                    >
                      <div className="space-y-1">
                        <h4 className="font-sans text-sm font-bold text-white uppercase tracking-wider">
                          {session.title}
                        </h4>
                        <p className="text-xs text-[#87A0A0]">
                          Tenue de grade : {session.degree || session.degreTravail || 'Apprenti'} • {new Date(session.date || session.dateReprise || '').toLocaleDateString('fr-FR')}
                        </p>
                      </div>

                      <span className="text-base font-bold text-emerald-400 bg-emerald-500/5 border border-emerald-500/20 px-3 py-1 rounded-xl">
                        + {session.troncAmount.toFixed(2)} €
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
