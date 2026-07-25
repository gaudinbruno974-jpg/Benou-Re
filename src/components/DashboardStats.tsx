import React, { useState } from 'react';
import { 
  TrendingUp, 
  Users, 
  Calendar, 
  Coins, 
  ChevronRight, 
  UserCheck, 
  Award,
  BookOpen,
  PieChart as PieIcon,
  HelpCircle,
  Mail,
  Phone,
  MapPin,
  Search,
  Lock,
  Unlock,
  Info,
  Activity,
  CheckCircle,
  AlertTriangle,
  Shield
} from 'lucide-react';
import { Member, Session } from '../types';

interface DashboardStatsProps {
  members: Member[];
  sessions: Session[];
  currentUser?: Member;
  onUpdateMember?: (updatedMember: Member) => void;
}

export default function DashboardStats({ members, sessions, currentUser, onUpdateMember }: DashboardStatsProps) {
  const [hoveredSessionIndex, setHoveredSessionIndex] = useState<number | null>(null);
  const [hoveredMonthIndex, setHoveredMonthIndex] = useState<number | null>(null);
  const [activeChartTab, setActiveChartTab] = useState<'attendance' | 'dues' | 'members'>('attendance');
  const [selectedVisualMember, setSelectedVisualMember] = useState<Member | null>(null);
  const [memberSearchQuery, setMemberSearchQuery] = useState('');
  const [visualGradeFilter, setVisualGradeFilter] = useState<'All' | 'Apprenti' | 'Compagnon' | 'Maitre'>('All');
  const [visualDuesFilter, setVisualDuesFilter] = useState<'All' | 'Paid' | 'Unpaid'>('All');
  
  // Member edit state
  const [isEditingMember, setIsEditingMember] = useState(false);
  const [editFormData, setEditFormData] = useState<Partial<Member>>({});

  const handleSelectVisualMember = (m: Member | null) => {
    setSelectedVisualMember(m);
    setIsEditingMember(false);
    if (m) {
      setEditFormData(m);
    } else {
      setEditFormData({});
    }
  };

  const handleSaveMemberEdit = () => {
    if (!editFormData.firstName || !editFormData.lastName || !editFormData.email) {
      alert('Veuillez remplir les champs obligatoires (Prénom, Nom, Email).');
      return;
    }
    if (onUpdateMember && selectedVisualMember) {
      const finalMember = {
        ...selectedVisualMember,
        ...editFormData,
        loginId: editFormData.loginId || editFormData.email
      } as Member;
      onUpdateMember(finalMember);
      setSelectedVisualMember(finalMember);
      setIsEditingMember(false);
    }
  };

  const isVM = currentUser?.email === 'vm@loge.com' || 
               currentUser?.email === 'gaudin.bruno974@gmail.com' || 
               currentUser?.email === 'benoure974@gmail.com' || 
               currentUser?.function === 'Vénérable Maître' ||
               currentUser?.function === 'Vénérable maître' ||
               currentUser?.function === 'Vénérable Maitre';

  // --- ATTENDANCE STATS CALCULATIONS ---
  const activeMembers = members.filter(m => m.status === 'Actif');
  const activeMembersCount = activeMembers.length || members.length || 1;

  // Sort sessions chronological ascending
  const getTimestamp = (session: Session) => {
    const dateValue = session.date || session.dateReprise || '';
    const dateObj = new Date(dateValue);
    return isNaN(dateObj.getTime()) ? 0 : dateObj.getTime();
  };
  const sortedSessions = [...sessions].sort((a, b) => getTimestamp(a) - getTimestamp(b));

  const attendanceData = sortedSessions.map((session) => {
    const dateValue = session.date || session.dateReprise || '';
    const dateObj = new Date(dateValue);
    const formattedDate = isNaN(dateObj.getTime()) 
      ? 'Non daté' 
      : dateObj.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
    
    const presentCount = session.presentIds ? session.presentIds.length : 0;
    const excusedCount = session.excusedIds ? session.excusedIds.length : 0;
    const visitorCount = session.visitorIds ? session.visitorIds.length : 0;
    
    const rate = Math.min(100, Math.round((presentCount / activeMembersCount) * 100));
    
    return {
      id: session.id,
      title: session.title || 'Tenue',
      shortTitle: (session.title || 'Tenue').replace(/du \d{2}\/\d{2}\/\d{4}/, '').trim(),
      date: formattedDate,
      fullDate: isNaN(dateObj.getTime()) ? '' : dateObj.toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', year: 'numeric' }),
      degree: session.degree || session.degreTravail || 'Apprenti',
      type: session.type || session.typeTenue || 'Ordinaire',
      presentCount,
      excusedCount,
      visitorCount,
      totalCount: activeMembersCount,
      rate,
    };
  });

  // Calculate average attendance
  const averageAttendance = attendanceData.length > 0
    ? Math.round(attendanceData.reduce((acc, curr) => acc + curr.rate, 0) / attendanceData.length)
    : 0;

  // Attendance by Grade/Degree
  const grades = ['Apprenti', 'Compagnon', 'Maitre'] as const;
  const attendanceByGrade = grades.map(grade => {
    const gradeSessions = sessions.filter(s => s.degree === grade);
    if (gradeSessions.length === 0) return { grade, rate: 0, count: 0 };
    
    const totalRate = gradeSessions.reduce((acc, session) => {
      // In high grades, only members of that grade or above are present.
      // But let's calculate rate based on the eligible members for that grade
      const eligibleMembers = members.filter(m => {
        if (grade === 'Maitre') return m.grade === 'Maitre';
        if (grade === 'Compagnon') return m.grade === 'Compagnon' || m.grade === 'Maitre';
        return m.status === 'Actif'; // All active members can attend Apprenti sessions
      });
      const eligibleCount = eligibleMembers.length || 1;
      const presentCount = session.presentIds ? session.presentIds.filter(id => eligibleMembers.some(em => em.id === id)).length : 0;
      return acc + Math.min(100, Math.round((presentCount / eligibleCount) * 100));
    }, 0);
    
    return {
      grade,
      rate: Math.round(totalRate / gradeSessions.length),
      count: gradeSessions.length
    };
  });


  // --- DUES / COTISATIONS CALCULATIONS ---
  // We compute dues expected vs received per month based on deterministic entry date
  const monthNames = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];
  const monthAbbrs = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];

  const monthlyExpected = Array(12).fill(0);
  const monthlyPaid = Array(12).fill(0);

  members.forEach(m => {
    // Determine month based on entry date (or stable hash of id)
    const entryDate = m.entryDate || '2026-01-01';
    let mDate = new Date(entryDate);
    if (isNaN(mDate.getTime())) {
      mDate = new Date('2026-01-01');
    }
    const baseMonth = mDate.getMonth(); // 0 - 11

    // 1. Lodge dues
    const lodgeMonth = baseMonth;
    monthlyExpected[lodgeMonth] += m.lodgeDues;
    if (m.lodgeDuesPaid) {
      monthlyPaid[lodgeMonth] += m.lodgeDues;
    }

    // 2. Order dues (staggered slightly to make the progression curve smooth and beautiful)
    const orderMonth = (baseMonth + 1) % 12;
    monthlyExpected[orderMonth] += m.orderDues;
    if (m.orderDuesPaid) {
      monthlyPaid[orderMonth] += m.orderDues;
    }

    // 3. Elevation dues
    if (m.elevationDues > 0) {
      const elevMonth = (baseMonth + 2) % 12;
      monthlyExpected[elevMonth] += m.elevationDues;
      if (m.elevationDuesPaid) {
        monthlyPaid[elevMonth] += m.elevationDues;
      }
    }
  });

  // Cumulative sums month-by-month
  let sumExpected = 0;
  let sumPaid = 0;
  const cumulativeExpected = Array(12).fill(0);
  const cumulativePaid = Array(12).fill(0);

  for (let i = 0; i < 12; i++) {
    sumExpected += monthlyExpected[i];
    sumPaid += monthlyPaid[i];
    cumulativeExpected[i] = sumExpected;
    cumulativePaid[i] = sumPaid;
  }

  const annualTargetDues = sumExpected || 1;
  const totalCollectedDues = sumPaid;
  const globalCollectionRate = Math.round((totalCollectedDues / annualTargetDues) * 100);

  // Formatting values for charts
  const maxDuesValue = Math.max(...cumulativeExpected, 1000) * 1.1;


  // --- SVG PLOTTING UTILITIES ---
  // Coordinates mapper for Attendance Chart
  const svgW = 500;
  const svgH = 180;
  const padL = 40;
  const padR = 20;
  const padT = 15;
  const padB = 25;
  
  const chartW = svgW - padL - padR;
  const chartH = svgH - padT - padB;

  // Attendance points coordinates
  const attendancePoints = attendanceData.map((d, index) => {
    const x = padL + (attendanceData.length > 1 ? (index / (attendanceData.length - 1)) * chartW : chartW / 2);
    const y = svgH - padB - (d.rate / 100) * chartH;
    return { x, y, ...d };
  });

  // Line path generator
  let attendancePath = '';
  let attendanceAreaPath = '';
  if (attendancePoints.length > 0) {
    attendancePath = `M ${attendancePoints[0].x} ${attendancePoints[0].y} ` + 
      attendancePoints.slice(1).map(p => `L ${p.x} ${p.y}`).join(' ');
    
    attendanceAreaPath = `${attendancePath} L ${attendancePoints[attendancePoints.length - 1].x} ${svgH - padB} L ${attendancePoints[0].x} ${svgH - padB} Z`;
  }

  // Cotisations points coordinates
  const duesPoints = cumulativePaid.map((val, index) => {
    const x = padL + (index / 11) * chartW;
    const y = svgH - padB - (val / maxDuesValue) * chartH;
    return { x, y, val, expected: cumulativeExpected[index], month: monthAbbrs[index], fullName: monthNames[index] };
  });

  // Cotisations line generators
  let duesPaidPath = '';
  let duesPaidAreaPath = '';
  let duesExpectedPath = '';
  if (duesPoints.length > 0) {
    duesPaidPath = `M ${duesPoints[0].x} ${duesPoints[0].y} ` + 
      duesPoints.slice(1).map(p => `L ${p.x} ${p.y}`).join(' ');
    
    duesPaidAreaPath = `${duesPaidPath} L ${duesPoints[11].x} ${svgH - padB} L ${duesPoints[0].x} ${svgH - padB} Z`;

    duesExpectedPath = `M ${duesPoints[0].x} ${svgH - padB - (duesPoints[0].expected / maxDuesValue) * chartH} ` + 
      duesPoints.slice(1).map(p => `L ${p.x} ${svgH - padB - (p.expected / maxDuesValue) * chartH}`).join(' ');
  }

  // Seating configuration for interactive temple
  const getTempleSeats = () => {
    const seats: Array<{
      member: Member;
      x: number;
      y: number;
      label: string;
      role: string;
    }> = [];

    // Filter and sort members
    const appts = members.filter(m => m.grade === 'Apprenti' && m.function === 'Aucun');
    const compas = members.filter(m => m.grade === 'Compagnon' && m.function === 'Aucun');
    const maitres = members.filter(m => m.grade === 'Maitre' && m.function === 'Aucun');
    const officers = members.filter(m => m.function !== 'Aucun');

    // Temple dimensions: 500w x 300h
    // East is top (y: 40), West is bottom (y: 260)
    // North is left (x: 80), South is right (x: 420)

    // Position Officers
    officers.forEach(m => {
      let x = 250;
      let y = 150;
      let role = m.function;

      if (m.function === 'Vénérable Maître' || m.function === 'Vénérable maître' || m.function === 'Vénérable Maitre') {
        x = 250; y = 50;
      } else if (m.function.includes('Secrétaire')) {
        x = 310; y = 60;
      } else if (m.function.includes('Orateur')) {
        x = 190; y = 60;
      } else if (m.function.includes('Trésorier')) {
        x = 150; y = 90;
      } else if (m.function.includes('Hospitalier')) {
        x = 350; y = 90;
      } else if (m.function.includes('1er Surveillant')) {
        x = 250; y = 260;
      } else if (m.function.includes('2e Surveillant')) {
        x = 350; y = 175;
      } else if (m.function.includes('Expert')) {
        x = 150; y = 175;
      } else if (m.function.includes('Maître des Cérémonies') || m.function.includes('Maitre des Cérémonies')) {
        x = 310; y = 220;
      } else if (m.function.includes('Couvreur')) {
        x = 250; y = 285;
      } else {
        x = 190; y = 220;
      }

      seats.push({
        member: m,
        x,
        y,
        label: `${m.firstName[0]}${m.lastName[0]}`,
        role
      });
    });

    // Position Apprentis (Colonne du Nord - Left, y between 100 and 240)
    appts.forEach((m, idx) => {
      const x = 70;
      const step = appts.length > 1 ? 140 / (appts.length - 1) : 0;
      const y = 110 + idx * step;
      seats.push({
        member: m,
        x,
        y,
        label: `${m.firstName[0]}${m.lastName[0]}`,
        role: 'Apprenti'
      });
    });

    // Position Compagnons (Colonne du Midi - Right, y between 100 and 240)
    compas.forEach((m, idx) => {
      const x = 430;
      const step = compas.length > 1 ? 140 / (compas.length - 1) : 0;
      const y = 110 + idx * step;
      seats.push({
        member: m,
        x,
        y,
        label: `${m.firstName[0]}${m.lastName[0]}`,
        role: 'Compagnon'
      });
    });

    // Position other Masters (Middle / Chambre des Maîtres)
    maitres.forEach((m, idx) => {
      const angle = (idx / (maitres.length || 1)) * Math.PI * 2;
      const radius = 40;
      const x = 250 + Math.cos(angle) * radius;
      const y = 155 + Math.sin(angle) * radius;
      seats.push({
        member: m,
        x,
        y,
        label: `${m.firstName[0]}${m.lastName[0]}`,
        role: 'Maître'
      });
    });

    return seats;
  };

  return (
    <div className="bg-[#122428] border border-amber-500/15 rounded-2xl p-6 shadow-xl relative overflow-hidden select-none">
      {/* Background radial glowing gradients */}
      <div className="absolute right-0 bottom-0 w-80 h-80 bg-teal-500/5 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute left-0 top-0 w-80 h-80 bg-amber-500/5 rounded-full blur-3xl pointer-events-none" />

      {/* Main Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 border-b border-amber-500/10 pb-4 mb-6">
        <div>
          <h3 className="font-sans text-lg font-bold text-white tracking-wide flex items-center gap-2">
            <TrendingUp className="h-5 w-5 text-amber-500" />
            Statistiques & Analyses de l'Atelier
          </h3>
          <p className="text-xs text-[#87A0A0]">
            Données consolidées d'assiduité maçonnique et d'évolution des cotisations de la Loge
          </p>
        </div>

        {/* Tab Controls */}
        <div className="flex bg-[#081619] p-1 rounded-xl border border-[#87A0A0]/10 shrink-0">
          <button
            onClick={() => {
              setActiveChartTab('attendance');
              setSelectedVisualMember(null);
            }}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 ${
              activeChartTab === 'attendance' 
                ? 'bg-[#0C7A7A] text-white border border-amber-500/15' 
                : 'text-[#87A0A0] hover:text-white'
            }`}
          >
            <UserCheck className="h-3.5 w-3.5" />
            Assiduité ({averageAttendance}%)
          </button>
          <button
            onClick={() => {
              setActiveChartTab('dues');
              setSelectedVisualMember(null);
            }}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 ${
              activeChartTab === 'dues' 
                ? 'bg-[#0C7A7A] text-white border border-amber-500/15' 
                : 'text-[#87A0A0] hover:text-white'
            }`}
          >
            <Coins className="h-3.5 w-3.5" />
            Cotisations ({globalCollectionRate}%)
          </button>
          <button
            onClick={() => {
              setActiveChartTab('members');
              setSelectedVisualMember(null);
            }}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 ${
              activeChartTab === 'members' 
                ? 'bg-[#0C7A7A] text-white border border-amber-500/15' 
                : 'text-[#87A0A0] hover:text-white'
            }`}
          >
            <Users className="h-3.5 w-3.5" />
            Visualisation des Colonnes ({members.length})
          </button>
        </div>
      </div>

      {/* RENDER VIEW 1: ATTENDANCE CHARTS */}
      {activeChartTab === 'attendance' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-stretch">
          {/* Main Attendance Chart */}
          <div className="lg:col-span-2 bg-[#081619]/40 border border-amber-500/10 rounded-xl p-4 flex flex-col justify-between relative min-h-[260px]">
            <div className="flex justify-between items-start mb-2">
              <div>
                <span className="text-[10px] text-amber-400 font-mono uppercase tracking-wider block">Assiduité Historique</span>
                <span className="text-sm font-bold text-white">Taux de présence par tenue</span>
              </div>
              <div className="flex items-center gap-3 text-[10px] font-mono text-[#87A0A0]">
                <div className="flex items-center gap-1.5">
                  <span className="h-2.5 w-2.5 rounded-full bg-teal-500/20 border border-teal-500" />
                  <span>Présents (%)</span>
                </div>
              </div>
            </div>

            {/* Attendance SVG chart */}
            <div className="relative grow h-44 w-full">
              {attendancePoints.length === 0 ? (
                <div className="absolute inset-0 flex items-center justify-center text-xs text-gray-500 font-mono">
                  Aucun historique de tenue disponible
                </div>
              ) : (
                <svg viewBox={`0 0 ${svgW} ${svgH}`} width="100%" height="100%" className="overflow-visible">
                  {/* Grid Lines */}
                  {[0, 25, 50, 75, 100].map((gridVal) => {
                    const y = svgH - padB - (gridVal / 100) * chartH;
                    return (
                      <g key={gridVal}>
                        <line 
                          x1={padL} 
                          y1={y} 
                          x2={svgW - padR} 
                          y2={y} 
                          stroke="#122428" 
                          strokeWidth="1" 
                          strokeDasharray="3 3" 
                        />
                        <text 
                          x={padL - 8} 
                          y={y + 3} 
                          fill="#87A0A0" 
                          fontSize="9" 
                          fontFamily="monospace" 
                          textAnchor="end"
                          opacity="0.6"
                        >
                          {gridVal}%
                        </text>
                      </g>
                    );
                  })}

                  {/* Area fill under curve */}
                  {attendanceAreaPath && (
                    <path 
                      d={attendanceAreaPath} 
                      fill="url(#attendanceGrad)" 
                    />
                  )}

                  {/* Smooth line */}
                  {attendancePath && (
                    <path 
                      d={attendancePath} 
                      fill="none" 
                      stroke="#0C7A7A" 
                      strokeWidth="2.5" 
                      strokeLinecap="round" 
                      strokeLinejoin="round"
                    />
                  )}

                  {/* Custom gradients definition */}
                  <defs>
                    <linearGradient id="attendanceGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#0C7A7A" stopOpacity="0.25" />
                      <stop offset="100%" stopColor="#0C7A7A" stopOpacity="0.0" />
                    </linearGradient>
                  </defs>

                  {/* Interactive Circles & Labels */}
                  {attendancePoints.map((pt, idx) => {
                    const isHovered = hoveredSessionIndex === idx;
                    return (
                      <g key={pt.id}>
                        {/* Invisible larger hover zone */}
                        <circle 
                          cx={pt.x} 
                          cy={pt.y} 
                          r="15" 
                          fill="transparent" 
                          className="cursor-pointer"
                          onMouseEnter={() => setHoveredSessionIndex(idx)}
                          onMouseLeave={() => setHoveredSessionIndex(null)}
                        />
                        {/* Visible circle outline and point */}
                        <circle 
                          cx={pt.x} 
                          cy={pt.y} 
                          r={isHovered ? "6" : "4"} 
                          fill="#081619" 
                          stroke={isHovered ? "#C5A059" : "#0C7A7A"} 
                          strokeWidth={isHovered ? "3" : "2"} 
                          className="transition-all duration-150 pointer-events-none"
                        />
                        {/* X-axis Month/Day Label */}
                        <text 
                          x={pt.x} 
                          y={svgH - 8} 
                          fill="#87A0A0" 
                          fontSize="9" 
                          fontFamily="monospace" 
                          textAnchor="middle"
                          opacity={isHovered ? "1" : "0.7"}
                          className="transition-all pointer-events-none"
                        >
                          {pt.date}
                        </text>
                      </g>
                    );
                  })}
                </svg>
              )}

              {/* Dynamic HTML Tooltip on hover */}
              {hoveredSessionIndex !== null && attendancePoints[hoveredSessionIndex] && (
                <div className="absolute bg-[#122428] border border-amber-500/30 rounded-xl p-3 shadow-2xl z-50 text-xs w-60 animate-fade-in pointer-events-none"
                  style={{
                    left: `${Math.min(75, Math.max(5, (attendancePoints[hoveredSessionIndex].x / svgW) * 100))}%`,
                    top: '10px',
                    transform: 'translateX(-50%)'
                  }}
                >
                  <p className="font-mono text-[10px] text-amber-400 font-bold uppercase tracking-widest">
                    {attendancePoints[hoveredSessionIndex].degree} • {attendancePoints[hoveredSessionIndex].type}
                  </p>
                  <p className="font-bold text-white mt-0.5 truncate">
                    {attendancePoints[hoveredSessionIndex].title}
                  </p>
                  <p className="text-[#87A0A0] text-[10px] mt-0.5">
                    {attendancePoints[hoveredSessionIndex].fullDate}
                  </p>
                  <div className="border-t border-[#87A0A0]/10 mt-2 pt-1.5 flex justify-between items-center text-[11px]">
                    <span className="text-[#87A0A0]">Taux de présence :</span>
                    <span className="font-bold text-teal-400">{attendancePoints[hoveredSessionIndex].rate}%</span>
                  </div>
                  <div className="flex justify-between items-center text-[10px] text-[#87A0A0] mt-1">
                    <span>Membres présents :</span>
                    <span className="font-mono text-white">
                      {attendancePoints[hoveredSessionIndex].presentCount} / {attendancePoints[hoveredSessionIndex].totalCount}
                    </span>
                  </div>
                  {(attendancePoints[hoveredSessionIndex].excusedCount > 0 || attendancePoints[hoveredSessionIndex].visitorCount > 0) && (
                    <div className="border-t border-dashed border-[#87A0A0]/10 mt-1.5 pt-1.5 flex gap-2 justify-between text-[10px] text-[#87A0A0]">
                      {attendancePoints[hoveredSessionIndex].excusedCount > 0 && (
                        <span>{attendancePoints[hoveredSessionIndex].excusedCount} excusé(s)</span>
                      )}
                      {attendancePoints[hoveredSessionIndex].visitorCount > 0 && (
                        <span className="text-emerald-400 font-semibold">{attendancePoints[hoveredSessionIndex].visitorCount} visiteur(s)</span>
                      )}
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Sidebar Stats Block: Key Indicators and Attendance by Degree */}
          <div className="flex flex-col justify-between gap-4">
            {/* Quick KPIs Card */}
            <div className="bg-[#081619]/40 border border-amber-500/10 rounded-xl p-4 flex items-center justify-between shadow-md">
              <div className="space-y-1">
                <span className="text-[10px] text-[#87A0A0] font-mono tracking-widest uppercase">Moyenne Générale</span>
                <h4 className="text-3xl font-extrabold text-teal-400 tracking-tight font-sans">
                  {averageAttendance}%
                </h4>
                <span className="text-[10px] text-[#87A0A0] block">Assiduité sur l'année</span>
              </div>
              <div className="h-12 w-12 rounded-xl bg-teal-500/5 border border-teal-500/20 flex items-center justify-center">
                <Users className="h-6 w-6 text-teal-400" />
              </div>
            </div>

            {/* Attendance by grade bars */}
            <div className="bg-[#081619]/40 border border-amber-500/10 rounded-xl p-4 grow flex flex-col justify-center gap-3 shadow-md">
              <span className="text-[10px] text-amber-400 font-mono uppercase tracking-wider block mb-1">Assiduité par Grade</span>
              
              {attendanceByGrade.map((item) => (
                <div key={item.grade} className="space-y-1">
                  <div className="flex justify-between text-xs">
                    <span className="font-bold text-white flex items-center gap-1">
                      <Award className={`h-3 w-3 ${
                        item.grade === 'Apprenti' ? 'text-[#87A0A0]' : 
                        item.grade === 'Compagnon' ? 'text-amber-500/70' : 'text-amber-400'
                      }`} />
                      {item.grade}
                    </span>
                    <span className="font-mono text-[#87A0A0]">
                      {item.rate}% <span className="text-[10px]">({item.count} tenues)</span>
                    </span>
                  </div>
                  <div className="h-2 w-full bg-[#122428] rounded-full overflow-hidden border border-[#87A0A0]/5">
                    <div 
                      className={`h-full rounded-full transition-all duration-500 ${
                        item.grade === 'Apprenti' ? 'bg-teal-600' : 
                        item.grade === 'Compagnon' ? 'bg-amber-600' : 'bg-[#C5A059]'
                      }`}
                      style={{ width: `${item.rate}%` }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* RENDER VIEW 2: FINANCIAL / DUES PROGRESSION */}
      {activeChartTab === 'dues' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-stretch">
          {/* Main Dues Cumulative Progress Curve */}
          <div className="lg:col-span-2 bg-[#081619]/40 border border-amber-500/10 rounded-xl p-4 flex flex-col justify-between relative min-h-[260px]">
            <div className="flex justify-between items-start mb-2">
              <div>
                <span className="text-[10px] text-amber-400 font-mono uppercase tracking-wider block">Évolution des Encaissements</span>
                <span className="text-sm font-bold text-white">Courbe cumulative des cotisations perçues</span>
              </div>
              <div className="flex items-center gap-4 text-[10px] font-mono text-[#87A0A0]">
                <div className="flex items-center gap-1">
                  <span className="h-0.5 w-4 border-t border-dashed border-[#87A0A0]/60" />
                  <span>Cible ({annualTargetDues} €)</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <span className="h-2.5 w-2.5 rounded-full bg-amber-500/20 border border-amber-500" />
                  <span>Encaissé cumulé</span>
                </div>
              </div>
            </div>

            {/* Dues SVG chart */}
            <div className="relative grow h-44 w-full">
              <svg viewBox={`0 0 ${svgW} ${svgH}`} width="100%" height="100%" className="overflow-visible">
                {/* Expected dues curve (dashed target path or background progress guide) */}
                {duesExpectedPath && (
                  <path 
                    d={duesExpectedPath} 
                    fill="none" 
                    stroke="#87A0A0" 
                    strokeWidth="1.5" 
                    strokeDasharray="4 4" 
                    opacity="0.25"
                  />
                )}

                {/* Target final value line */}
                <line 
                  x1={padL} 
                  y1={svgH - padB - (annualTargetDues / maxDuesValue) * chartH} 
                  x2={svgW - padR} 
                  y2={svgH - padB - (annualTargetDues / maxDuesValue) * chartH} 
                  stroke="#C5A059" 
                  strokeWidth="1.5" 
                  strokeDasharray="3 3" 
                  opacity="0.4"
                />
                
                {/* Text for Target Final Value */}
                <text 
                  x={svgW - padR} 
                  y={svgH - padB - (annualTargetDues / maxDuesValue) * chartH - 5} 
                  fill="#C5A059" 
                  fontSize="8" 
                  fontFamily="monospace" 
                  textAnchor="end"
                  opacity="0.8"
                >
                  Objectif Annuel : {annualTargetDues} €
                </text>

                {/* Grid Lines */}
                {[0, 0.25, 0.5, 0.75, 1].map((pct, idx) => {
                  const targetVal = maxDuesValue * pct;
                  const y = svgH - padB - (targetVal / maxDuesValue) * chartH;
                  if (idx === 0) return null; // skip base line
                  return (
                    <g key={idx}>
                      <line 
                        x1={padL} 
                        y1={y} 
                        x2={svgW - padR} 
                        y2={y} 
                        stroke="#122428" 
                        strokeWidth="1" 
                        strokeDasharray="3 3" 
                      />
                      <text 
                        x={padL - 8} 
                        y={y + 3} 
                        fill="#87A0A0" 
                        fontSize="8" 
                        fontFamily="monospace" 
                        textAnchor="end"
                        opacity="0.5"
                      >
                        {Math.round(targetVal)} €
                      </text>
                    </g>
                  );
                })}

                {/* Area fill under cumulative paid curve */}
                {duesPaidAreaPath && (
                  <path 
                    d={duesPaidAreaPath} 
                    fill="url(#duesGrad)" 
                  />
                )}

                {/* Cumulative paid line */}
                {duesPaidPath && (
                  <path 
                    d={duesPaidPath} 
                    fill="none" 
                    stroke="#C5A059" 
                    strokeWidth="2.5" 
                    strokeLinecap="round" 
                    strokeLinejoin="round"
                  />
                )}

                {/* Dues visual gradient definition */}
                <defs>
                  <linearGradient id="duesGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#C5A059" stopOpacity="0.2" />
                    <stop offset="100%" stopColor="#C5A059" stopOpacity="0.0" />
                  </linearGradient>
                </defs>

                {/* Interactive circles */}
                {duesPoints.map((pt, idx) => {
                  const isHovered = hoveredMonthIndex === idx;
                  return (
                    <g key={idx}>
                      {/* Invisible hover zones */}
                      <rect 
                        x={pt.x - 12} 
                        y={padT} 
                        width="24" 
                        height={chartH} 
                        fill="transparent" 
                        className="cursor-pointer"
                        onMouseEnter={() => setHoveredMonthIndex(idx)}
                        onMouseLeave={() => setHoveredMonthIndex(null)}
                      />
                      {/* Visible point circle */}
                      <circle 
                        cx={pt.x} 
                        cy={pt.y} 
                        r={isHovered ? "5" : "3"} 
                        fill="#081619" 
                        stroke={isHovered ? "#0C7A7A" : "#C5A059"} 
                        strokeWidth="2" 
                        className="transition-all duration-150 pointer-events-none"
                      />
                      {/* X Axis Month Labels */}
                      <text 
                        x={pt.x} 
                        y={svgH - 8} 
                        fill="#87A0A0" 
                        fontSize="8" 
                        fontFamily="monospace" 
                        textAnchor="middle"
                        opacity={isHovered ? "1" : "0.6"}
                        className="transition-all pointer-events-none"
                      >
                        {pt.month}
                      </text>
                    </g>
                  );
                })}
              </svg>

              {/* Dynamic HTML Tooltip on hover */}
              {hoveredMonthIndex !== null && duesPoints[hoveredMonthIndex] && (
                <div className="absolute bg-[#122428] border border-amber-500/30 rounded-xl p-3 shadow-2xl z-50 text-xs w-56 animate-fade-in pointer-events-none"
                  style={{
                    left: `${Math.min(80, Math.max(5, (duesPoints[hoveredMonthIndex].x / svgW) * 100))}%`,
                    top: '15px',
                    transform: 'translateX(-50%)'
                  }}
                >
                  <p className="font-mono text-[10px] text-[#87A0A0] uppercase tracking-wider">
                    Situation à Fin
                  </p>
                  <p className="font-bold text-white text-sm">
                    {duesPoints[hoveredMonthIndex].fullName} 2026
                  </p>
                  <div className="border-t border-[#87A0A0]/10 mt-2 pt-1.5 space-y-1.5 text-[11px]">
                    <div className="flex justify-between items-center">
                      <span className="text-[#87A0A0]">Encaissé Cumulé :</span>
                      <span className="font-bold text-emerald-400">
                        {duesPoints[hoveredMonthIndex].val.toLocaleString('fr-FR')} €
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-[#87A0A0]">Appel de fonds :</span>
                      <span className="font-mono text-white/80">
                        {duesPoints[hoveredMonthIndex].expected.toLocaleString('fr-FR')} €
                      </span>
                    </div>
                    <div className="flex justify-between items-center text-[10px] text-[#87A0A0] pt-1 border-t border-dashed border-[#87A0A0]/5">
                      <span>Taux d'encaissement :</span>
                      <span className="font-bold text-amber-400">
                        {Math.round((duesPoints[hoveredMonthIndex].val / (duesPoints[hoveredMonthIndex].expected || 1)) * 100)}%
                      </span>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Sidebar Stats Block: Key Indicators and Payment breakdown */}
          <div className="flex flex-col justify-between gap-4">
            {/* KPI Card */}
            <div className="bg-[#081619]/40 border border-amber-500/10 rounded-xl p-4 flex items-center justify-between shadow-md">
              <div className="space-y-1">
                <span className="text-[10px] text-[#87A0A0] font-mono tracking-widest uppercase">Taux de Recouvrement</span>
                <h4 className="text-3xl font-extrabold text-[#C5A059] tracking-tight font-sans">
                  {globalCollectionRate}%
                </h4>
                <span className="text-[10px] text-[#87A0A0] block">
                  {totalCollectedDues.toLocaleString('fr-FR')} € sur {annualTargetDues.toLocaleString('fr-FR')} €
                </span>
              </div>
              <div className="h-12 w-12 rounded-xl bg-amber-500/5 border border-amber-500/20 flex items-center justify-center">
                <TrendingUp className="h-6 w-6 text-[#C5A059]" />
              </div>
            </div>

            {/* Dues categories breakdown */}
            <div className="bg-[#081619]/40 border border-amber-500/10 rounded-xl p-4 grow flex flex-col justify-center gap-3.5 shadow-md">
              <span className="text-[10px] text-amber-400 font-mono uppercase tracking-wider block mb-1">Détails par Type de Dues</span>
              
              {/* Lodge dues */}
              <div className="space-y-1.5">
                <div className="flex justify-between text-xs font-semibold">
                  <span className="text-white">Cotisations de Loge</span>
                  <span className="font-mono text-[#87A0A0]">
                    {members.filter(m => m.lodgeDuesPaid).length} / {members.length} payées
                  </span>
                </div>
                <div className="h-1.5 w-full bg-[#122428] rounded-full overflow-hidden">
                  <div 
                    className="h-full bg-emerald-500 rounded-full"
                    style={{ width: `${Math.round((members.filter(m => m.lodgeDuesPaid).length / members.length) * 100)}%` }}
                  />
                </div>
              </div>

              {/* Order dues */}
              <div className="space-y-1.5">
                <div className="flex justify-between text-xs font-semibold">
                  <span className="text-white">Capitations Nationales</span>
                  <span className="font-mono text-[#87A0A0]">
                    {members.filter(m => m.orderDuesPaid).length} / {members.length} payées
                  </span>
                </div>
                <div className="h-1.5 w-full bg-[#122428] rounded-full overflow-hidden">
                  <div 
                    className="h-full bg-amber-500 rounded-full"
                    style={{ width: `${Math.round((members.filter(m => m.orderDuesPaid).length / members.length) * 100)}%` }}
                  />
                </div>
              </div>

              {/* Elevation dues */}
              {members.filter(m => m.elevationDues > 0).length > 0 && (
                <div className="space-y-1.5">
                  <div className="flex justify-between text-xs font-semibold">
                    <span className="text-white">Droits d'Élévation de Grade</span>
                    <span className="font-mono text-[#87A0A0]">
                      {members.filter(m => m.elevationDues > 0 && m.elevationDuesPaid).length} / {members.filter(m => m.elevationDues > 0).length} payés
                    </span>
                  </div>
                  <div className="h-1.5 w-full bg-[#122428] rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-teal-500 rounded-full"
                      style={{ width: `${Math.round((members.filter(m => m.elevationDues > 0 && m.elevationDuesPaid).length / (members.filter(m => m.elevationDues > 0).length || 1)) * 100)}%` }}
                    />
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* RENDER VIEW 3: MEMBERS & COLUMNS MAP & REGISTRY */}
      {activeChartTab === 'members' && (
        <div className="space-y-6">
          {/* Top Info Bar */}
          <div className="bg-[#081619]/40 border border-amber-500/10 rounded-xl p-4 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
            <div>
              <h4 className="text-sm font-bold text-white flex items-center gap-2">
                <Shield className="h-4 w-4 text-[#C5A059]" />
                Cartographie Interactive du Temple & Registres de l'Atelier
              </h4>
              <p className="text-xs text-[#87A0A0] mt-0.5">
                {isVM 
                  ? "Accès privilégié Vénérable Maître — Visualisation exhaustive des Colonnes, du Tracé des Travaux et des secrets des Frères."
                  : "Visualisation symbolique du Temple et répartition fraternelle sur les Colonnes."}
              </p>
            </div>
            {isVM && (
              <span className="px-2.5 py-1 rounded bg-amber-500/10 border border-amber-500/30 text-amber-500 text-[10px] font-mono tracking-widest uppercase animate-pulse">
                SÉCURITÉ VM ACTIVE
              </span>
            )}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-stretch">
            {/* Column 1 & 2: Interactive SVG Temple Layout */}
            <div className="lg:col-span-2 bg-[#081619]/40 border border-amber-500/10 rounded-xl p-5 flex flex-col justify-between relative min-h-[400px]">
              <div className="flex justify-between items-center mb-4">
                <div>
                  <span className="text-[10px] text-amber-400 font-mono uppercase tracking-wider block">REPRÉSENTATION DES TRAVAUX</span>
                  <span className="text-sm font-bold text-white">Le Temple et les Colonnes du Nord et du Midi</span>
                </div>
                <div className="flex gap-2 text-[10px] font-mono">
                  <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-teal-500" /> Apprentis</span>
                  <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-amber-500" /> Compagnons</span>
                  <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-[#C5A059]" /> Maîtres/Offs</span>
                </div>
              </div>

              {/* Interactive SVG of the Temple */}
              <div className="relative grow flex items-center justify-center border border-[#122428] rounded-xl p-4 bg-[#081619]/20 overflow-hidden min-h-[300px]">
                {/* Masonic Checkered Pavement Background inside center */}
                <div className="absolute inset-0 opacity-[0.03] pointer-events-none" 
                     style={{ 
                       backgroundImage: 'repeating-conic-gradient(#fff 0% 25%, transparent 0% 50%)', 
                       backgroundSize: '30px 30px' 
                     }} 
                />

                <svg viewBox="0 0 500 320" width="100%" height="100%" className="overflow-visible select-none z-10">
                  {/* Temple Boundaries / Columns outline */}
                  <rect x="25" y="15" width="450" height="290" rx="16" fill="none" stroke="#C5A059" strokeWidth="1.5" strokeDasharray="6 4" opacity="0.4" />
                  
                  {/* Compass / Square Icon watermark in center */}
                  <g transform="translate(250, 160) scale(0.6)" opacity="0.08" stroke="#C5A059" strokeWidth="2" fill="none">
                    <path d="M -50,40 L 0,-50 L 50,40" />
                    <path d="M -50,-20 L 0,60 L 50,-20" />
                  </g>

                  {/* Cardinal points labels */}
                  <text x="250" y="28" fill="#C5A059" fontSize="10" fontFamily="monospace" textAnchor="middle" letterSpacing="2" opacity="0.6">L'ORIENT (EST)</text>
                  <text x="250" y="300" fill="#C5A059" fontSize="10" fontFamily="monospace" textAnchor="middle" letterSpacing="2" opacity="0.6">L'OCCIDENT (OUEST)</text>
                  <text x="35" y="165" fill="#87A0A0" fontSize="9" fontFamily="monospace" textAnchor="middle" transform="rotate(-90 35 165)" opacity="0.4">COLONNE DU NORD (SEPTENTRION)</text>
                  <text x="465" y="165" fill="#87A0A0" fontSize="9" fontFamily="monospace" textAnchor="middle" transform="rotate(90 465 165)" opacity="0.4">COLONNE DU MIDI</text>

                  {/* Pillars J and B */}
                  <g transform="translate(180, 260)">
                    <circle cx="0" cy="0" r="12" fill="#122428" stroke="#C5A059" strokeWidth="1.5" opacity="0.5" />
                    <text x="0" y="3" fill="#C5A059" fontSize="10" fontWeight="bold" textAnchor="middle" fontFamily="serif">J</text>
                  </g>
                  <g transform="translate(320, 260)">
                    <circle cx="0" cy="0" r="12" fill="#122428" stroke="#C5A059" strokeWidth="1.5" opacity="0.5" />
                    <text x="0" y="3" fill="#C5A059" fontSize="10" fontWeight="bold" textAnchor="middle" fontFamily="serif">B</text>
                  </g>

                  {/* Render seats */}
                  {getTempleSeats().map((seat, idx) => {
                    const isSelected = selectedVisualMember?.id === seat.member.id;
                    const isUnderHover = hoveredSessionIndex === idx;

                    // Determine color based on grade
                    let color = 'stroke-[#C5A059] fill-[#081619] text-[#C5A059]';
                    if (seat.member.grade === 'Apprenti') {
                      color = 'stroke-teal-500 fill-[#081619] text-teal-400';
                    } else if (seat.member.grade === 'Compagnon') {
                      color = 'stroke-amber-500 fill-[#081619] text-amber-400';
                    }

                    if (isSelected) {
                      color = 'stroke-amber-400 fill-amber-500/20 text-white';
                    }

                    return (
                      <g 
                        key={seat.member.id} 
                        className="cursor-pointer group"
                        onClick={() => handleSelectVisualMember(seat.member)}
                        onMouseEnter={() => setHoveredSessionIndex(idx)}
                        onMouseLeave={() => setHoveredSessionIndex(null)}
                      >
                        {/* Outer Glow for selected or hovered */}
                        {(isSelected || isUnderHover) && (
                          <circle cx={seat.x} cy={seat.y} r="18" fill="none" stroke="#C5A059" strokeWidth="1" strokeDasharray="2 2" className="animate-pulse" />
                        )}

                        <circle 
                          cx={seat.x} 
                          cy={seat.y} 
                          r={isSelected ? "14" : "11"} 
                          className={`transition-all duration-200 ${color}`}
                          strokeWidth={isSelected ? "2.5" : "1.5"}
                        />
                        
                        <text 
                          x={seat.x} 
                          y={seat.y + 3} 
                          fontSize="8" 
                          fontFamily="sans-serif" 
                          fontWeight="bold" 
                          textAnchor="middle"
                          className={isSelected ? "fill-white font-black" : "fill-gray-300 group-hover:fill-white"}
                        >
                          {seat.label}
                        </text>

                        {/* Miniature tooltip on hover of node */}
                        {isUnderHover && (
                          <g transform={`translate(${seat.x}, ${seat.y - 20})`} className="pointer-events-none">
                            <rect x="-65" y="-18" width="130" height="24" rx="4" fill="#122428" stroke="#C5A059" strokeWidth="1" opacity="0.95" />
                            <text x="0" y="-8" fill="#fff" fontSize="8" fontWeight="bold" textAnchor="middle">
                              {seat.member.firstName} {seat.member.lastName}
                            </text>
                            <text x="0" y="3" fill="#87A0A0" fontSize="7" textAnchor="middle">
                              {seat.member.function !== 'Aucun' ? seat.member.function : seat.member.grade}
                            </text>
                          </g>
                        )}
                      </g>
                    );
                  })}
                </svg>
              </div>

              <div className="text-center text-[10px] text-[#87A0A0] mt-3 font-mono">
                💡 Cliquez sur un symbole de Frère pour faire apparaître sa fiche initiatique, administrative et de trésorerie complète.
              </div>
            </div>

            {/* Column 3: Detailed Info panel for selected member */}
            <div className="bg-[#081619]/40 border border-amber-500/10 rounded-xl p-5 flex flex-col justify-between shadow-md min-h-[400px]">
              {selectedVisualMember ? (
                isEditingMember ? (
                  <div className="space-y-4 grow flex flex-col justify-between overflow-y-auto max-h-[550px] pr-1">
                    <div className="space-y-4">
                      <div className="border-b border-amber-500/15 pb-2">
                        <span className="text-[9px] text-amber-500 font-mono tracking-widest uppercase block">ADMINISTRATION DU VM</span>
                        <h3 className="text-sm font-bold text-white uppercase tracking-wider font-sans">
                          Modifier : {selectedVisualMember.firstName} {selectedVisualMember.lastName}
                        </h3>
                      </div>

                      <div className="space-y-3.5 text-xs">
                        {/* Prénom */}
                        <div className="space-y-1">
                          <label className="text-[#87A0A0] block text-[9px] uppercase font-mono tracking-wider">Prénom *</label>
                          <input
                            type="text"
                            value={editFormData.firstName || ''}
                            onChange={e => setEditFormData({ ...editFormData, firstName: e.target.value })}
                            className="w-full bg-[#081619] border border-[#87A0A0]/25 rounded-lg p-2 text-xs text-white focus:border-amber-500/50 focus:outline-none"
                          />
                        </div>

                        {/* Nom */}
                        <div className="space-y-1">
                          <label className="text-[#87A0A0] block text-[9px] uppercase font-mono tracking-wider">Nom *</label>
                          <input
                            type="text"
                            value={editFormData.lastName || ''}
                            onChange={e => setEditFormData({ ...editFormData, lastName: e.target.value })}
                            className="w-full bg-[#081619] border border-[#87A0A0]/25 rounded-lg p-2 text-xs text-white focus:border-amber-500/50 focus:outline-none"
                          />
                        </div>

                        {/* Grade */}
                        <div className="space-y-1">
                          <label className="text-[#87A0A0] block text-[9px] uppercase font-mono tracking-wider">Grade *</label>
                          <select
                            value={editFormData.grade || 'Apprenti'}
                            onChange={e => setEditFormData({ ...editFormData, grade: e.target.value as any })}
                            className="w-full bg-[#081619] border border-[#87A0A0]/25 rounded-lg p-2 text-xs text-white focus:border-amber-500/50 focus:outline-none"
                          >
                            <option value="Apprenti">Apprenti</option>
                            <option value="Compagnon">Compagnon</option>
                            <option value="Maitre">Maître</option>
                          </select>
                        </div>

                        {/* Fonction */}
                        <div className="space-y-1">
                          <label className="text-[#87A0A0] block text-[9px] uppercase font-mono tracking-wider">Fonction / Office *</label>
                          <select
                            value={editFormData.function || 'Aucun'}
                            onChange={e => setEditFormData({ ...editFormData, function: e.target.value })}
                            className="w-full bg-[#081619] border border-[#87A0A0]/25 rounded-lg p-2 text-xs text-white focus:border-amber-500/50 focus:outline-none"
                          >
                            <option value="Aucun">Aucun</option>
                            <option value="Vénérable Maître">Vénérable Maître</option>
                            <option value="1er Surveillant">1er Surveillant</option>
                            <option value="2nd Surveillant">2nd Surveillant</option>
                            <option value="Orateur">Orateur</option>
                            <option value="Secrétaire">Secrétaire</option>
                            <option value="Trésorier">Trésorier</option>
                            <option value="Hospitalier">Hospitalier</option>
                            <option value="Expert">Expert</option>
                            <option value="Maître des Cérémonies">Maître des Cérémonies</option>
                            <option value="Couvreur">Couvreur</option>
                          </select>
                        </div>

                        {/* Email */}
                        <div className="space-y-1">
                          <label className="text-[#87A0A0] block text-[9px] uppercase font-mono tracking-wider">Email Personnel *</label>
                          <input
                            type="email"
                            value={editFormData.email || ''}
                            onChange={e => setEditFormData({ ...editFormData, email: e.target.value })}
                            className="w-full bg-[#081619] border border-[#87A0A0]/25 rounded-lg p-2 text-xs text-white focus:border-amber-500/50 focus:outline-none"
                          />
                        </div>

                        {/* Téléphone */}
                        <div className="space-y-1">
                          <label className="text-[#87A0A0] block text-[9px] uppercase font-mono tracking-wider">Téléphone</label>
                          <input
                            type="text"
                            value={editFormData.phone || ''}
                            onChange={e => setEditFormData({ ...editFormData, phone: e.target.value })}
                            className="w-full bg-[#081619] border border-[#87A0A0]/25 rounded-lg p-2 text-xs text-white focus:border-amber-500/50 focus:outline-none"
                          />
                        </div>

                        {/* Adresse */}
                        <div className="space-y-1">
                          <label className="text-[#87A0A0] block text-[9px] uppercase font-mono tracking-wider">Adresse</label>
                          <input
                            type="text"
                            value={editFormData.address || ''}
                            onChange={e => setEditFormData({ ...editFormData, address: e.target.value })}
                            className="w-full bg-[#081619] border border-[#87A0A0]/25 rounded-lg p-2 text-xs text-white focus:border-amber-500/50 focus:outline-none"
                          />
                        </div>

                        {/* Matricule */}
                        <div className="space-y-1">
                          <label className="text-[#87A0A0] block text-[9px] uppercase font-mono tracking-wider">Matricule</label>
                          <input
                            type="text"
                            value={editFormData.matricule || ''}
                            onChange={e => setEditFormData({ ...editFormData, matricule: e.target.value })}
                            className="w-full bg-[#081619] border border-[#87A0A0]/25 rounded-lg p-2 text-xs text-white focus:border-amber-500/50 focus:outline-none"
                          />
                        </div>

                        {/* Mot de passe */}
                        <div className="space-y-1">
                          <label className="text-[#87A0A0] block text-[9px] uppercase font-mono tracking-wider">Mot de passe de connexion</label>
                          <input
                            type="text"
                            value={editFormData.password || ''}
                            onChange={e => setEditFormData({ ...editFormData, password: e.target.value })}
                            className="w-full bg-[#081619] border border-[#87A0A0]/25 rounded-lg p-2 text-xs text-white focus:border-amber-500/50 focus:outline-none"
                          />
                        </div>

                        {/* Trésorerie */}
                        <div className="space-y-2 pt-2 border-t border-amber-500/10">
                          <span className="text-[#87A0A0] block text-[9px] uppercase font-mono tracking-wider">Trésorerie</span>
                          
                          <div className="flex items-center justify-between bg-black/35 p-2 rounded border border-amber-500/5">
                            <span className="text-[11px] text-gray-300">Cotisation Loge</span>
                            <input
                              type="checkbox"
                              checked={editFormData.lodgeDuesPaid || false}
                              onChange={e => setEditFormData({ ...editFormData, lodgeDuesPaid: e.target.checked })}
                              className="rounded accent-emerald-500 cursor-pointer h-4 w-4"
                            />
                          </div>

                          <div className="flex items-center justify-between bg-black/35 p-2 rounded border border-amber-500/5">
                            <span className="text-[11px] text-gray-300">Capitation Ordre</span>
                            <input
                              type="checkbox"
                              checked={editFormData.orderDuesPaid || false}
                              onChange={e => setEditFormData({ ...editFormData, orderDuesPaid: e.target.checked })}
                              className="rounded accent-emerald-500 cursor-pointer h-4 w-4"
                            />
                          </div>
                        </div>
                      </div>
                    </div>

                    <div className="flex gap-2 mt-4 pt-3 border-t border-amber-500/10">
                      <button
                        onClick={handleSaveMemberEdit}
                        className="grow py-2.5 bg-emerald-700 hover:bg-emerald-600 border border-emerald-500/20 text-white rounded-xl text-xs font-bold transition uppercase tracking-widest"
                      >
                        Enregistrer
                      </button>
                      <button
                        onClick={() => setIsEditingMember(false)}
                        className="px-4 py-2.5 bg-[#122428] hover:bg-[#1b343a] border border-amber-500/10 text-white rounded-xl text-xs font-bold transition uppercase tracking-widest"
                      >
                        Annuler
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="space-y-4 grow flex flex-col justify-between">
                    <div className="space-y-4">
                      {/* Header with Photo/Initials */}
                      <div className="flex items-center gap-4 border-b border-amber-500/10 pb-4">
                        <div className={`h-14 w-14 rounded-2xl border-2 flex items-center justify-center font-bold text-lg text-white bg-[#122428] shrink-0 ${
                          selectedVisualMember.grade === 'Apprenti' ? 'border-teal-500' :
                          selectedVisualMember.grade === 'Compagnon' ? 'border-amber-500' : 'border-[#C5A059]'
                        }`}>
                          {selectedVisualMember.firstName[0]}{selectedVisualMember.lastName[0]}
                        </div>
                        <div className="space-y-1 min-w-0">
                          <span className="px-1.5 py-0.5 rounded bg-amber-500/5 border border-amber-500/20 text-amber-400 text-[9px] font-mono tracking-widest uppercase">
                            {selectedVisualMember.grade}
                          </span>
                          <h3 className="text-base font-bold text-white uppercase tracking-wide truncate">
                            {selectedVisualMember.firstName} {selectedVisualMember.lastName}
                          </h3>
                          {selectedVisualMember.function !== 'Aucun' && (
                            <p className="text-xs text-amber-500 font-semibold font-mono truncate">
                              {selectedVisualMember.function}
                            </p>
                          )}
                        </div>
                      </div>

                      {/* Secret information specifically for VM or self-view */}
                      <div className="space-y-3 text-xs">
                        {/* Section 1: Civil */}
                        <div className="space-y-1.5">
                          <span className="text-[10px] text-amber-500 font-mono tracking-wider uppercase block border-b border-[#87A0A0]/5 pb-0.5">Identité Civile</span>
                          
                          <div className="flex items-center gap-2 text-white">
                            <Mail className="h-3.5 w-3.5 text-[#C5A059] shrink-0" />
                            <span className="text-[#87A0A0] mr-1 shrink-0">Email:</span>
                            <span className="font-semibold truncate">{selectedVisualMember.email}</span>
                          </div>

                          {selectedVisualMember.phone && (
                            <div className="flex items-center gap-2 text-white">
                              <Phone className="h-3.5 w-3.5 text-[#C5A059] shrink-0" />
                              <span className="text-[#87A0A0] mr-1 shrink-0">Tél:</span>
                              <span className="font-semibold">{selectedVisualMember.phone}</span>
                            </div>
                          )}

                          {selectedVisualMember.address && (
                            <div className="flex items-start gap-2 text-white">
                              <MapPin className="h-3.5 w-3.5 text-[#C5A059] shrink-0 mt-0.5" />
                              <span className="text-[#87A0A0] mr-1 shrink-0">Adresse:</span>
                              <span className="font-semibold leading-relaxed text-[11px]">{selectedVisualMember.address}</span>
                            </div>
                          )}

                          {selectedVisualMember.birthDate && (
                            <div className="flex items-center gap-2 text-white">
                              <Calendar className="h-3.5 w-3.5 text-[#C5A059] shrink-0" />
                              <span className="text-[#87A0A0] mr-1 shrink-0">Date Naiss:</span>
                              <span className="font-semibold">{new Date(selectedVisualMember.birthDate).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })}</span>
                            </div>
                          )}
                        </div>

                        {/* Section 2: masonic info */}
                        <div className="space-y-1.5 pt-1">
                          <span className="text-[10px] text-amber-500 font-mono tracking-wider uppercase block border-b border-[#87A0A0]/5 pb-0.5">Dossier Initiatique</span>
                          
                          <div className="grid grid-cols-2 gap-2 text-[11px]">
                            <div>
                              <span className="text-[#87A0A0] block text-[9px] uppercase">Matricule</span>
                              <span className="font-mono font-bold text-white">{selectedVisualMember.matricule || 'N/A'}</span>
                            </div>
                            <div>
                              <span className="text-[#87A0A0] block text-[9px] uppercase">Statut</span>
                              <span className="font-bold text-emerald-400">{selectedVisualMember.status}</span>
                            </div>
                            <div>
                              <span className="text-[#87A0A0] block text-[9px] uppercase">Loge Mère</span>
                              <span className="font-bold text-white text-[10px] truncate block">{selectedVisualMember.motherLodge || 'Bénou Ré'}</span>
                            </div>
                            <div>
                              <span className="text-[#87A0A0] block text-[9px] uppercase">Parrain</span>
                              <span className="font-bold text-white text-[10px] truncate block">{selectedVisualMember.sponsor || 'N/A'}</span>
                            </div>
                          </div>

                          <div className="grid grid-cols-2 gap-2 text-[11px] pt-0.5">
                            {selectedVisualMember.initiationDate && (
                              <div>
                                <span className="text-[#87A0A0] block text-[9px] uppercase">Initié le</span>
                                <span className="font-semibold text-white">{new Date(selectedVisualMember.initiationDate).toLocaleDateString('fr-FR', { month: '2-digit', year: 'numeric' })}</span>
                              </div>
                            )}
                            {selectedVisualMember.entryDate && (
                              <div>
                                <span className="text-[#87A0A0] block text-[9px] uppercase">Affilié le</span>
                                <span className="font-semibold text-white">{new Date(selectedVisualMember.entryDate).toLocaleDateString('fr-FR', { month: '2-digit', year: 'numeric' })}</span>
                              </div>
                            )}
                          </div>
                        </div>

                        {/* Section 3: Treasury (Secret/Privileged for VM or self) */}
                        <div className="space-y-1.5 pt-1">
                          <span className="text-[10px] text-amber-500 font-mono tracking-wider uppercase block border-b border-[#87A0A0]/5 pb-0.5">Trésorerie</span>
                          
                          <div className="space-y-1 text-[11px]">
                            <div className="flex justify-between items-center bg-black/30 p-1.5 rounded border border-[#87A0A0]/5">
                              <span className="text-gray-400">Cotisation Loge ({selectedVisualMember.lodgeDues}€)</span>
                              <span className={`px-1.5 py-0.5 rounded text-[9px] font-bold ${selectedVisualMember.lodgeDuesPaid ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400'}`}>
                                {selectedVisualMember.lodgeDuesPaid ? 'PAYÉ' : 'À PAYER'}
                              </span>
                            </div>
                            <div className="flex justify-between items-center bg-black/30 p-1.5 rounded border border-[#87A0A0]/5">
                              <span className="text-gray-400">Capitation Ordre ({selectedVisualMember.orderDues}€)</span>
                              <span className={`px-1.5 py-0.5 rounded text-[9px] font-bold ${selectedVisualMember.orderDuesPaid ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400'}`}>
                                {selectedVisualMember.orderDuesPaid ? 'PAYÉ' : 'À PAYER'}
                              </span>
                            </div>
                            {selectedVisualMember.elevationDues > 0 && (
                              <div className="flex justify-between items-center bg-black/30 p-1.5 rounded border border-[#87A0A0]/5">
                                <span className="text-gray-400">Élévation ({selectedVisualMember.elevationDues}€)</span>
                                <span className={`px-1.5 py-0.5 rounded text-[9px] font-bold ${selectedVisualMember.elevationDuesPaid ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400'}`}>
                                  {selectedVisualMember.elevationDuesPaid ? 'PAYÉ' : 'À PAYER'}
                                </span>
                              </div>
                            )}
                          </div>
                        </div>

                        {/* Section 4: Secret Password display (VM ONLY) */}
                        {isVM && (
                          <div className="mt-2 bg-black/45 border border-red-500/20 rounded-xl p-2.5">
                            <div className="flex items-center gap-1.5 text-red-400 font-mono text-[9px] tracking-widest uppercase mb-1">
                              <Lock className="h-3 w-3 text-red-500" />
                              <span>CONNEXION (ADMIN VM)</span>
                            </div>
                            <div className="grid grid-cols-2 gap-2 text-[11px] font-mono">
                              <div className="min-w-0">
                                <span className="text-[#87A0A0] text-[8px] block">Identifiant:</span>
                                <span className="font-bold text-white select-all truncate block">{selectedVisualMember.loginId || selectedVisualMember.email}</span>
                              </div>
                              <div className="min-w-0">
                                <span className="text-[#87A0A0] text-[8px] block">Mot de Passe:</span>
                                <span className="font-bold text-amber-400 select-all block">{selectedVisualMember.password}</span>
                              </div>
                            </div>
                          </div>
                        )}
                      </div>
                    </div>

                    <div className="flex gap-2 mt-3 pt-2 border-t border-amber-500/10">
                      {isVM && (
                        <button 
                          onClick={() => { setIsEditingMember(true); setEditFormData(selectedVisualMember); }}
                          className="grow py-2 bg-[#0C7A7A] hover:bg-[#0A6868] border border-teal-500/10 text-white rounded-xl text-xs font-bold transition uppercase tracking-widest"
                        >
                          Modifier
                        </button>
                      )}
                      <button 
                        onClick={() => handleSelectVisualMember(null)}
                        className={`${isVM ? 'w-24' : 'w-full'} py-2 bg-[#122428] border border-amber-500/10 hover:border-amber-500/30 text-white rounded-xl text-xs font-bold transition uppercase tracking-widest`}
                      >
                        Fermer
                      </button>
                    </div>
                  </div>
                )
              ) : (
                <div className="grow flex flex-col justify-center items-center text-center p-6 space-y-3">
                  <div className="h-16 w-16 rounded-full bg-[#122428] border border-amber-500/15 flex items-center justify-center">
                    <UserCheck className="h-8 w-8 text-amber-500/60" />
                  </div>
                  <div>
                    <h4 className="text-white font-bold text-sm">Fiche Fraternelle</h4>
                    <p className="text-xs text-[#87A0A0] max-w-[200px] mt-1 leading-relaxed">
                      Sélectionnez un Frère sur le plan du Temple ou dans le registre ci-dessous pour inspecter sa fiche complète.
                    </p>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* VÉNÉRABLE MAÎTRE SEGMENT: SECRET DATA LEDGER TABLE */}
          {isVM && (
            <div className="bg-[#081619]/40 border border-amber-500/15 rounded-2xl p-6 space-y-4">
              <div className="border-b border-amber-500/10 pb-4 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                <div>
                  <h3 className="font-sans text-base font-bold text-white flex items-center gap-2">
                    <BookOpen className="h-5 w-5 text-amber-500" />
                    Grand Registre Secret du Vénérable Maître (VM)
                  </h3>
                  <p className="text-xs text-[#87A0A0]">
                    Tableau de bord exhaustif et instantané de l'ensemble des informations de l'Atelier.
                  </p>
                </div>

                {/* Filter / Search input */}
                <div className="flex flex-col sm:flex-row gap-2">
                  <div className="relative">
                    <span className="absolute inset-y-0 left-0 flex items-center pl-3 text-[#C5A059]">
                      <Search className="h-3.5 w-3.5" />
                    </span>
                    <input
                      type="text"
                      placeholder="Chercher dans le registre..."
                      value={memberSearchQuery}
                      onChange={e => setMemberSearchQuery(e.target.value)}
                      className="bg-black/40 border border-amber-500/10 rounded-xl pl-9 pr-3 py-1.5 text-xs text-white placeholder-gray-600 focus:outline-none focus:border-amber-500/40 w-full sm:w-48"
                    />
                  </div>

                  <select
                    value={visualGradeFilter}
                    onChange={e => setVisualGradeFilter(e.target.value as any)}
                    className="bg-black/40 border border-amber-500/10 rounded-xl px-2.5 py-1.5 text-xs text-white focus:outline-none"
                  >
                    <option value="All">Tous les Grades</option>
                    <option value="Apprenti">Apprentis</option>
                    <option value="Compagnon">Compagnons</option>
                    <option value="Maitre">Maîtres</option>
                  </select>

                  <select
                    value={visualDuesFilter}
                    onChange={e => setVisualDuesFilter(e.target.value as any)}
                    className="bg-black/40 border border-amber-500/10 rounded-xl px-2.5 py-1.5 text-xs text-white focus:outline-none"
                  >
                    <option value="All">Tous Paiements</option>
                    <option value="Paid">Cotisations Réglées</option>
                    <option value="Unpaid">Retards Trésorerie</option>
                  </select>
                </div>
              </div>

              {/* Secret Table */}
              <div className="overflow-x-auto rounded-xl border border-amber-500/5">
                <table className="w-full text-left text-xs border-collapse">
                  <thead>
                    <tr className="bg-[#122428] text-amber-500 font-mono uppercase tracking-widest text-[9px] border-b border-amber-500/15">
                      <th className="p-3">Matricule</th>
                      <th className="p-3">Identité / Frère</th>
                      <th className="p-3">Grade & Fonction</th>
                      <th className="p-3">Identité Civile</th>
                      <th className="p-3">Mots de Passe / Logins</th>
                      <th className="p-3">Parrain / Cursus</th>
                      <th className="p-3 text-right">Trésorerie / Cotis.</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-amber-500/5">
                    {members
                      .filter(m => {
                        // Match search query
                        const searchLower = memberSearchQuery.toLowerCase();
                        const matchSearch = m.firstName.toLowerCase().includes(searchLower) ||
                                            m.lastName.toLowerCase().includes(searchLower) ||
                                            m.email.toLowerCase().includes(searchLower) ||
                                            (m.phone || '').includes(searchLower) ||
                                            (m.matricule || '').includes(searchLower);
                        
                        // Match grade
                        const matchGrade = visualGradeFilter === 'All' || m.grade === visualGradeFilter;

                        // Match dues
                        let matchDues = true;
                        if (visualDuesFilter === 'Paid') {
                          matchDues = m.lodgeDuesPaid && m.orderDuesPaid;
                        } else if (visualDuesFilter === 'Unpaid') {
                          matchDues = !m.lodgeDuesPaid || !m.orderDuesPaid || (m.elevationDues > 0 && !m.elevationDuesPaid);
                        }

                        return matchSearch && matchGrade && matchDues;
                      })
                      .map((m) => {
                        return (
                          <tr 
                            key={m.id} 
                            onClick={() => handleSelectVisualMember(m)}
                            className="hover:bg-amber-500/5 transition cursor-pointer"
                          >
                            <td className="p-3 font-mono font-bold text-amber-400 text-[10px]">
                              {m.matricule || 'N/A'}
                            </td>
                            <td className="p-3">
                              <div className="font-bold text-white uppercase">{m.firstName} {m.lastName}</div>
                              <div className="text-[10px] text-[#87A0A0]">Statut : {m.status}</div>
                            </td>
                            <td className="p-3">
                              <span className={`px-1.5 py-0.5 rounded text-[9px] font-bold font-mono border ${
                                m.grade === 'Apprenti' ? 'bg-teal-500/5 text-teal-400 border-teal-500/20' :
                                m.grade === 'Compagnon' ? 'bg-amber-500/5 text-amber-400 border-amber-500/20' : 'bg-[#C5A059]/5 text-[#C5A059] border-[#C5A059]/20'
                              }`}>
                                {m.grade}
                              </span>
                              {m.function !== 'Aucun' && (
                                <div className="text-[10px] text-amber-500 font-semibold mt-1 font-mono">{m.function}</div>
                              )}
                            </td>
                            <td className="p-3 space-y-0.5 text-[11px]">
                              <div className="text-white font-mono">{m.email}</div>
                              {m.phone && <div className="text-[#87A0A0]">{m.phone}</div>}
                              {m.address && <div className="text-[#87A0A0] text-[10px] max-w-[150px] truncate">{m.address}</div>}
                            </td>
                            <td className="p-3 space-y-0.5 text-[11px] font-mono">
                              <div className="text-white"><span className="text-[#87A0A0] text-[9px]">ID:</span> {m.loginId || m.email}</div>
                              <div className="text-red-400 font-bold"><span className="text-[#87A0A0] text-[9px]">Pass:</span> {m.password}</div>
                            </td>
                            <td className="p-3 text-[11px]">
                              <div className="text-white"><span className="text-[#87A0A0]">Parrain:</span> {m.sponsor || 'N/A'}</div>
                              {m.initiationDate && (
                                <div className="text-[#87A0A0] text-[10px] mt-0.5">
                                  Initié : {new Date(m.initiationDate).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' })}
                                </div>
                              )}
                            </td>
                            <td className="p-3 text-right text-[11px]">
                              <div className="space-y-1">
                                <span className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-bold ${m.lodgeDuesPaid ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400'}`}>
                                  Loge: {m.lodgeDues}€
                                </span>
                                <span className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-bold ml-1.5 ${m.orderDuesPaid ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400'}`}>
                                  Ordre: {m.orderDues}€
                                </span>
                              </div>
                            </td>
                          </tr>
                        );
                      })}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Footer information bar */}
      <div className="mt-6 pt-4 border-t border-amber-500/10 flex flex-col sm:flex-row justify-between items-center text-[10px] text-[#87A0A0] font-mono gap-2">
        <span className="flex items-center gap-1.5">
          <BookOpen className="h-3 w-3 text-amber-500/60" />
          Mise à jour en temps réel d'après les registres du Secrétariat et de la Trésorerie
        </span>
        <span className="flex items-center gap-1">
          Période fiscale : 2026 • Clôture au 31 Décembre
        </span>
      </div>
    </div>
  );
}
