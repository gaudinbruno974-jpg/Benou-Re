import React, { useEffect, useState } from 'react';
import { ArrowLeft, Check, UserCheck, Users, MapPin, Clock } from 'lucide-react';
import { Member, Session, Visitor } from '../types';

interface SessionPresenceScreenProps {
  currentUser: Member;
  sessions: Session[];
  members: Member[];
  visitors: Visitor[];
  selectedSessionId?: string | null;
  onUpdateSession: (updatedSession: Session) => void;
  onBack: () => void;
}

export default function SessionPresenceScreen({
  currentUser,
  sessions,
  members,
  visitors,
  selectedSessionId,
  onUpdateSession,
  onBack
}: SessionPresenceScreenProps) {
  const [session, setSession] = useState<Session | null>(null);
  const [presentIds, setPresentIds] = useState<string[]>([]);
  const [excusedIds, setExcusedIds] = useState<string[]>([]);
  const [visitorIds, setVisitorIds] = useState<string[]>([]);
  const [visitorRoles, setVisitorRoles] = useState<Record<string, string>>({});

  const visitorRoleOptions = [
    'Premier Surveillant',
    'Second Surveillant',
    'Orateur',
    'Secrétaire',
    'Trésorier',
    'Hospitalier',
    'Maître des Cérémonies',
    'Couvreur',
    "Maître de l'Harmonie",
    "à l’Orient",
    'Colonne du Septentrion',
    'Colonne du midi'
  ];

  useEffect(() => {
    const selected = sessions.find((s) => s.id === selectedSessionId) || sessions[0] || null;
    setSession(selected);
    if (selected) {
      setPresentIds(selected.presentIds || []);
      setExcusedIds(selected.excusedIds || []);
      setVisitorIds(selected.visitorIds || []);
      setVisitorRoles(selected.visitorRoles || {});
    }
  }, [selectedSessionId, sessions]);

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

  const togglePresent = (memberId: string) => {
    setPresentIds((prev) => {
      if (prev.includes(memberId)) return prev.filter((id) => id !== memberId);
      return [...prev, memberId];
    });
    setExcusedIds((prev) => prev.filter((id) => id !== memberId));
  };

  const toggleExcused = (memberId: string) => {
    setExcusedIds((prev) => {
      if (prev.includes(memberId)) return prev.filter((id) => id !== memberId);
      return [...prev, memberId];
    });
    setPresentIds((prev) => prev.filter((id) => id !== memberId));
  };

  const toggleVisitor = (visitorId: string) => {
    setVisitorIds((prev) => {
      if (prev.includes(visitorId)) {
        const next = prev.filter((id) => id !== visitorId);
        setVisitorRoles((roles) => {
          const nextRoles = { ...roles };
          delete nextRoles[visitorId];
          return nextRoles;
        });
        return next;
      }
      return [...prev, visitorId];
    });
  };

  const updateVisitorRole = (visitorId: string, role: string) => {
    setVisitorRoles((prev) => ({
      ...prev,
      [visitorId]: role,
    }));
  };

  const handleSave = () => {
    onUpdateSession({
      ...session,
      presentIds,
      excusedIds,
      visitorIds,
      visitorRoles,
    });
  };

  const sessionDate = session.date || session.dateReprise || '';
  const displayDate = sessionDate && !isNaN(new Date(sessionDate).getTime())
    ? new Date(sessionDate).toLocaleDateString('fr-FR', {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric',
      })
    : 'Date inconnue';
  const sessionLocation = session.location || session.lieuReunion || 'Lieu inconnu';
  const displaySessionNumber = session.sessionNumber || (session.chrono ? `${session.chrono}` : 'N/A');

  return (
    <div className="min-h-screen bg-[#081619] text-[#E8E8E8] pb-12">
      <header className="bg-[#122428] border-b border-amber-500/20 sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <button onClick={onBack} className="p-2 rounded-lg bg-teal-950/40 border border-teal-900/30 text-teal-400 hover:bg-teal-900/20 transition">
              <ArrowLeft className="h-4 w-4" />
            </button>
            <div>
              <p className="text-[10px] uppercase tracking-widest font-mono text-[#87A0A0]">Gestion des présences</p>
              <h1 className="text-lg font-bold uppercase tracking-wider text-white">Tenue n°{displaySessionNumber} — {session.title}</h1>
            </div>
          </div>
          <button
            onClick={handleSave}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-emerald-500 text-[#081619] font-bold uppercase tracking-widest hover:bg-emerald-400 transition"
          >
            <Check className="h-4 w-4" />
            Enregistrer
          </button>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-6 grid gap-6 lg:grid-cols-[1fr_0.9fr]">
        <section className="space-y-6">
          <div className="bg-[#122428] border border-[#87A0A0]/10 rounded-3xl p-5">
            <div className="flex items-center gap-3 mb-4">
              <Users className="h-5 w-5 text-sky-400" />
              <div>
                <p className="text-xs uppercase tracking-widest text-[#87A0A0]">Membres</p>
                <p className="text-sm text-white">Présents / Excusés</p>
              </div>
            </div>
            <div className="grid gap-3">
              {members.map((member) => {
                const isPresent = presentIds.includes(member.id);
                const isExcused = excusedIds.includes(member.id);
                return (
                  <div key={member.id} className="flex items-center justify-between gap-3 rounded-2xl border border-[#87A0A0]/10 bg-[#081619]/70 p-3">
                    <div className="min-w-0">
                      <p className="text-sm font-semibold text-white truncate">{member.firstName} {member.lastName}</p>
                      <p className="text-xs text-[#87A0A0]">{member.function || 'Membre'}</p>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => togglePresent(member.id)}
                        className={`px-3 py-1 rounded-full text-[11px] font-semibold uppercase transition ${isPresent ? 'bg-emerald-500 text-[#081619]' : 'bg-[#0C7A7A]/10 text-[#87A0A0] hover:bg-[#0C7A7A]/20'}`}
                      >
                        Présent
                      </button>
                      <button
                        onClick={() => toggleExcused(member.id)}
                        className={`px-3 py-1 rounded-full text-[11px] font-semibold uppercase transition ${isExcused ? 'bg-amber-500 text-[#081619]' : 'bg-[#0C7A7A]/10 text-[#87A0A0] hover:bg-[#0C7A7A]/20'}`}
                      >
                        Excusé
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="bg-[#122428] border border-[#87A0A0]/10 rounded-3xl p-5">
            <div className="flex items-center gap-3 mb-4">
              <UserCheck className="h-5 w-5 text-amber-400" />
              <div>
                <p className="text-xs uppercase tracking-widest text-[#87A0A0]">Visiteurs</p>
                <p className="text-sm text-white">Présents</p>
              </div>
            </div>
            <div className="grid gap-3">
              {visitors.map((visitor) => {
                const isVisitorPresent = visitorIds.includes(visitor.id);
                const selectedRole = visitorRoles[visitor.id] || '';
                return (
                  <div key={visitor.id} className="rounded-2xl border border-[#87A0A0]/10 bg-[#081619]/70 p-3">
                    <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                      <div className="min-w-0">
                        <p className="text-sm font-semibold text-white truncate">{visitor.firstName} {visitor.lastName}</p>
                        <p className="text-xs text-[#87A0A0]">{visitor.lodge} — {visitor.orient}</p>
                      </div>
                      <button
                        onClick={() => toggleVisitor(visitor.id)}
                        className={`px-3 py-1 rounded-full text-[11px] font-semibold uppercase transition ${isVisitorPresent ? 'bg-sky-500 text-white shadow-sm shadow-sky-500/30' : 'bg-[#0C7A7A]/10 text-white border border-[#0C7A7A]/50 hover:bg-[#0C7A7A]/20'}`}
                      >
                        {isVisitorPresent ? 'Présent' : 'Absent'}
                      </button>
                    </div>
                    {isVisitorPresent && (
                      <div className="mt-3 grid gap-2 md:grid-cols-[1fr_1.2fr]">
                        <label className="text-[11px] uppercase tracking-widest text-[#87A0A0]">Poste pendant la tenue</label>
                        <select
                          value={selectedRole}
                          onChange={(e) => updateVisitorRole(visitor.id, e.target.value)}
                          className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-3.5 py-2 text-white focus:border-[#C5A059] focus:outline-none"
                        >
                          <option value="">Aucun</option>
                          {visitorRoleOptions.map((option) => (
                            <option key={option} value={option}>{option}</option>
                          ))}
                        </select>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        </section>

        <aside className="space-y-6">
          <div className="bg-[#122428] border border-[#87A0A0]/10 rounded-3xl p-5">
            <p className="text-xs uppercase tracking-widest text-[#87A0A0] mb-2">Résumé de la tenue</p>
            <div className="space-y-2 text-sm text-[#E2E8F0]">
              <p><span className="font-semibold text-white">Date :</span> {displayDate}</p>
              <p><span className="font-semibold text-white">Lieu :</span> {sessionLocation}</p>
              <p><span className="font-semibold text-white">Présents :</span> {presentIds.length}</p>
              <p><span className="font-semibold text-white">Excusés :</span> {excusedIds.length}</p>
              <p><span className="font-semibold text-white">Visiteurs :</span> {visitorIds.length}</p>
            </div>
          </div>

          <div className="bg-[#122428] border border-[#87A0A0]/10 rounded-3xl p-5">
            <p className="text-xs uppercase tracking-widest text-[#87A0A0] mb-3">Astuce</p>
            <p className="text-sm text-[#E2E8F0]">Les membres ne peuvent pas être marqués présents et excusés simultanément. Enregistrez les modifications avant de passer au panneau d'émargement.</p>
          </div>
        </aside>
      </main>
    </div>
  );
}
