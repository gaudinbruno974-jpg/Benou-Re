import React from 'react';
import { 
  Users, 
  Calendar, 
  ShieldAlert, 
  History, 
  BookOpen, 
  GraduationCap, 
  Briefcase, 
  LogOut,
  Sparkles,
  HelpCircle,
  MapPin
} from 'lucide-react';
import { Member, Session } from '../types';
import DashboardStats from './DashboardStats';

interface ParvisScreenProps {
  currentUser: Member;
  members: Member[];
  sessions: Session[];
  onLogout: () => void;
  onNavigate: (view: string) => void;
  onUpdateMember: (updatedMember: Member) => void;
}

export default function ParvisScreen({ 
  currentUser, 
  members, 
  sessions, 
  onLogout, 
  onNavigate,
  onUpdateMember
}: ParvisScreenProps) {
  // Check roles for menu accessibility
  const functionTrim = (currentUser.function || '').trim();
  const isAdmin = currentUser.isAdmin || false;
  
  const isTreasuryUser = isAdmin || 
    functionTrim.includes('Trésorier') || 
    functionTrim.includes('Vénérable Maître') || 
    functionTrim.includes('Secrétaire');
    
  const isVisitorsUser = isAdmin || 
    functionTrim.includes('Vénérable Maître') || 
    functionTrim.includes('Secrétaire');

  const menuItems = [
    {
      id: 'membres',
      title: 'Membres',
      subtitle: 'Tableau des colonnes',
      icon: Users,
      color: 'text-amber-400 border-amber-500/20 bg-amber-500/5',
      visible: true
    },
    {
      id: 'tenues',
      title: 'Tenues',
      subtitle: 'Calendrier des travaux',
      icon: Calendar,
      color: 'text-teal-400 border-teal-500/20 bg-teal-500/5',
      visible: true
    },
    {
      id: 'visiteurs',
      title: 'Visiteurs',
      subtitle: 'Répertoire des visiteurs',
      icon: ShieldAlert,
      color: 'text-emerald-400 border-emerald-500/20 bg-emerald-500/5',
      visible: isVisitorsUser
    },
    {
      id: 'architecture',
      title: "Morceaux d'architecture",
      subtitle: 'Planches et travaux',
      icon: History,
      color: 'text-sky-400 border-sky-500/20 bg-sky-500/5',
      visible: true
    },
    {
      id: 'instructions',
      title: 'Instructions',
      subtitle: 'Cahiers de formation',
      icon: GraduationCap,
      color: 'text-indigo-400 border-indigo-500/20 bg-indigo-500/5',
      visible: true
    },
    {
      id: 'rituels',
      title: 'Rituels',
      subtitle: 'Textes sacrés',
      icon: BookOpen,
      color: 'text-violet-400 border-violet-500/20 bg-violet-500/5',
      visible: true
    },
    {
      id: 'tresorerie',
      title: 'Trésorerie',
      subtitle: 'Bilans & Cotisations',
      icon: Briefcase,
      color: 'text-rose-400 border-rose-500/20 bg-rose-500/5',
      visible: isTreasuryUser
    }
  ];

  return (
    <div className="min-h-screen bg-[#081619] text-[#E8E8E8] pb-12 animate-fade-in">
      {/* Top Banner Header */}
      <header className="bg-[#122428] border-b border-amber-500/20 sticky top-0 z-40 shadow-md">
        <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-full border border-amber-500/30 flex items-center justify-center bg-[#081619]">
              <Sparkles className="h-5 w-5 text-[#C5A059]" />
            </div>
            <div>
              <h2 className="font-sans text-lg font-bold uppercase tracking-wider text-white">
                R. L. Bénou Ré
              </h2>
              <div className="flex items-center gap-2 text-xs text-[#87A0A0] font-mono">
                <MapPin className="h-3 w-3 text-amber-500/60" />
                <span>Orient de Saint-Pierre, La Réunion</span>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-4">
            <div className="hidden md:flex flex-col items-end">
              <span className="text-sm font-bold text-white">
                {currentUser.firstName} {currentUser.lastName}
              </span>
              <span className="text-xs text-[#C5A059] font-mono">
                {currentUser.grade} • {currentUser.function !== 'Aucun' ? currentUser.function : 'Frère'}
              </span>
            </div>
            <button
              onClick={onLogout}
              className="flex items-center gap-2 px-3.5 py-2 rounded-xl bg-red-950/20 border border-red-900/30 text-red-400 text-xs font-bold hover:bg-red-900/20 hover:border-red-500/40 transition group"
              title="Quitter le Temple"
            >
              <LogOut className="h-4 w-4 group-hover:translate-x-0.5 transition" />
              <span className="hidden sm:inline">QUITTER LE TEMPLE</span>
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 mt-8">
        {/* Dynamic Greeting & Quote */}
        <div className="bg-[#122428]/40 border border-amber-500/10 rounded-2xl p-6 mb-8 relative overflow-hidden flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
          <div className="absolute right-0 top-0 w-64 h-64 bg-teal-500/5 rounded-full blur-3xl pointer-events-none" />
          
          <div className="space-y-1">
            <h3 className="font-sans text-xl font-bold text-white">
              Salutations Fraternelles, mon T. C. F. {currentUser.firstName}
            </h3>
            <p className="text-sm text-[#87A0A0] max-w-2xl leading-relaxed">
              Bienvenue sur le Parvis numérique de la Loge. Retrouvez ici les fiches de vos Frères, le calendrier de nos travaux sacrés, nos planches d'architectures, ainsi que la bibliothèque des rituels et les outils de trésorerie de l'atelier.
            </p>
          </div>

          <div className="border border-amber-500/20 bg-amber-500/5 rounded-xl p-3 px-4 text-xs font-mono text-amber-400 self-stretch md:self-auto flex flex-col justify-center text-center">
            <span className="text-[10px] tracking-widest text-[#87A0A0] uppercase mb-0.5 block">DEVISE DE L'ORDRE</span>
            <span>EX CINERIBUS, AD LUCEM PERPETUAM</span>
          </div>
        </div>

        {/* Dashboard Grid */}
        <div className="space-y-4">
          <h4 className="text-xs font-mono tracking-widest text-[#C5A059] uppercase flex items-center gap-2 mb-4">
            <HelpCircle className="h-4 w-4" />
            VOTRE ESPACE DE TRAVAIL
          </h4>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {menuItems
              .filter((item) => item.visible)
              .map((item) => {
                const IconComp = item.icon;
                return (
                  <button
                    key={item.id}
                    onClick={() => onNavigate(item.id)}
                    className="flex text-left items-center p-5 rounded-2xl bg-[#122428] border border-amber-500/15 hover:border-amber-500/35 hover:-translate-y-0.5 transition shadow-lg hover:shadow-amber-500/5 group"
                  >
                    <div className={`h-12 w-12 rounded-xl border flex items-center justify-center mr-4 group-hover:scale-105 transition shrink-0 ${item.color}`}>
                      <IconComp className="h-6 w-6" />
                    </div>
                    <div className="space-y-0.5 grow min-w-0">
                      <h3 className="font-sans text-base font-bold text-white tracking-wide group-hover:text-amber-300 transition truncate">
                        {item.title}
                      </h3>
                      <p className="text-xs text-[#87A0A0] truncate">
                        {item.subtitle}
                      </p>
                    </div>
                    <div className="text-amber-500/50 group-hover:text-amber-400 group-hover:translate-x-1 transition ml-2 font-mono shrink-0">
                      →
                    </div>
                  </button>
                );
              })}
          </div>
        </div>

        {/* Dashboard Statistics Panel */}
        <div className="mt-10">
          <DashboardStats members={members} sessions={sessions} currentUser={currentUser} onUpdateMember={onUpdateMember} />
        </div>

        {/* Informative Status / Guard Rail */}
        <div className="mt-12 border-t border-amber-500/10 pt-6 flex flex-col sm:flex-row justify-between items-center text-xs text-[#87A0A0]/60 gap-4">
          <div className="flex items-center gap-2">
            <span className="h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>Temple couvert — Échange de données crypté</span>
          </div>
          <div className="font-mono">
            RL Bénou Ré • RAPMM • v1.0.0
          </div>
        </div>
      </main>
    </div>
  );
}
