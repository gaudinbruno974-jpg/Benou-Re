import React, { useState } from 'react';
import { 
  ArrowLeft, 
  Search, 
  Plus, 
  User, 
  Mail, 
  Phone, 
  MapPin, 
  Calendar, 
  Award, 
  CheckCircle, 
  AlertTriangle, 
  Trash2,
  Lock,
  Edit2
} from 'lucide-react';
import { Member } from '../types';

interface MembersListProps {
  currentUser: Member;
  members: Member[];
  onAddMember: (newMember: Member) => void;
  onUpdateMember: (updatedMember: Member) => void;
  onDeleteMember: (id: string) => void;
  onBack: () => void;
}

export default function MembersList({ 
  currentUser, 
  members, 
  onAddMember, 
  onUpdateMember, 
  onDeleteMember, 
  onBack 
}: MembersListProps) {
  const [selectedMember, setSelectedMember] = useState<Member | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [gradeFilter, setGradeFilter] = useState<'All' | 'Apprenti' | 'Compagnon' | 'Maitre'>('All');

  // Security Flags
  const isVM = currentUser.email === 'vm@loge.com' || 
               currentUser.email === 'gaudin.bruno974@gmail.com' ||
               currentUser.email === 'benoure974@gmail.com' ||
               currentUser.function === 'Vénérable Maître' ||
               currentUser.function === 'Vénérable maître' ||
               currentUser.function === 'Vénérable Maitre';

  const isSecrétaire = currentUser.function === 'Secrétaire' ||
                       currentUser.email === 'muriel.mete.mm@gmail.com';

  const canViewAllDetails = isVM || isSecrétaire || (selectedMember && currentUser.id === selectedMember.id);

  // State for add/edit form
  const [formData, setFormData] = useState<Partial<Member>>({});

  const handleOpenDetail = (member: Member) => {
    setSelectedMember(member);
    setIsEditing(false);
  };

  const handleStartEdit = (member: Member) => {
    setFormData(member);
    setIsEditing(true);
  };

  const handleStartCreate = () => {
    setFormData({
      id: 'm_' + Date.now(),
      firstName: '',
      lastName: '',
      address: '',
      phone: '',
      email: '',
      matricule: '',
      grade: 'Apprenti',
      function: 'Aucun',
      motherLodge: 'RL Bénou Ré',
      sponsor: '',
      loginId: '',
      password: 'password123',
      birthDate: '1990-01-01',
      initiationDate: new Date().toISOString().split('T')[0],
      entryDate: new Date().toISOString().split('T')[0],
      status: 'Actif',
      lodgeDues: 365,
      lodgeDuesPaid: false,
      orderDues: 50,
      orderDuesPaid: false,
      elevationDues: 0,
      elevationDuesPaid: false
    });
    setSelectedMember(null);
    setIsEditing(true);
  };

  const handleSaveForm = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.firstName || !formData.lastName || !formData.email) {
      alert('Veuillez remplir les champs obligatoires (Prénom, Nom, Email).');
      return;
    }

    const isNew = !members.some(m => m.id === formData.id);
    const finalMember = {
      ...formData,
      loginId: formData.loginId || formData.email,
    } as Member;

    if (isNew) {
      onAddMember(finalMember);
    } else {
      onUpdateMember(finalMember);
    }

    setIsEditing(false);
    setSelectedMember(finalMember);
  };

  const handleDelete = (id: string) => {
    if (window.confirm('Voulez-vous vraiment retirer ce membre du répertoire ?')) {
      onDeleteMember(id);
      setSelectedMember(null);
      setIsEditing(false);
    }
  };

  const filteredMembers = members.filter(m => {
    const fullName = `${m.firstName} ${m.lastName}`.toLowerCase();
    const query = searchQuery.toLowerCase();
    const matchesSearch = fullName.includes(query) || m.email.toLowerCase().includes(query) || m.matricule.toLowerCase().includes(query);
    const matchesGrade = gradeFilter === 'All' || m.grade === gradeFilter;
    return matchesSearch && matchesGrade;
  });

  return (
    <div className="min-h-screen bg-[#081619] text-[#E8E8E8] pb-12 animate-fade-in select-none">
      {/* Header */}
      <header className="bg-[#122428] border-b border-amber-500/20 sticky top-0 z-40 shadow-md">
        <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button 
              onClick={selectedMember || isEditing ? () => { setSelectedMember(null); setIsEditing(false); } : onBack}
              className="p-2 rounded-lg bg-teal-950/40 border border-teal-900/30 text-teal-400 hover:bg-teal-900/20 transition"
            >
              <ArrowLeft className="h-4 w-4" />
            </button>
            <h2 className="font-sans text-lg font-bold uppercase tracking-wider text-white">
              {isEditing ? (formData.id && members.some(m => m.id === formData.id) ? 'Modifier Profil' : 'Nouveau Profil') : selectedMember ? 'Fiche Membre' : 'Les Colonnes (Membres)'}
            </h2>
          </div>

          {isVM && !isEditing && !selectedMember && (
            <button
              onClick={handleStartCreate}
              className="flex items-center gap-2 px-4 py-2 rounded-xl bg-[#0C7A7A] hover:bg-[#0A6868] text-white text-xs font-bold border border-amber-500/20 transition"
            >
              <Plus className="h-4 w-4 text-[#C5A059]" />
              AJOUTER UN FRÈRE
            </button>
          )}
        </div>
      </header>

      <main className="max-w-4xl mx-auto px-4 mt-8">
        {/* VIEW 1: FORM (CREATE / EDIT) */}
        {isEditing && (
          <form onSubmit={handleSaveForm} className="bg-[#122428] border border-amber-500/20 rounded-2xl p-6 md:p-8 space-y-6">
            <h3 className="text-sm font-mono tracking-widest text-amber-500 uppercase border-b border-amber-500/10 pb-2">
              {formData.id && members.some(m => m.id === formData.id) ? 'Modification d\'une fiche' : 'Création d\'un nouveau profil'}
            </h3>

            {/* Form Fields Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Prénom */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Prénom *</label>
                <input
                  type="text"
                  required
                  disabled={!isVM && formData.id !== currentUser.id}
                  value={formData.firstName || ''}
                  onChange={e => setFormData({ ...formData, firstName: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                />
              </div>

              {/* Nom */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Nom *</label>
                <input
                  type="text"
                  required
                  disabled={!isVM && formData.id !== currentUser.id}
                  value={formData.lastName || ''}
                  onChange={e => setFormData({ ...formData, lastName: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                />
              </div>

              {/* Adresse */}
              <div className="space-y-1 md:col-span-2">
                <label className="text-xs text-[#87A0A0] block">Adresse</label>
                <input
                  type="text"
                  disabled={!isVM && formData.id !== currentUser.id}
                  value={formData.address || ''}
                  onChange={e => setFormData({ ...formData, address: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                />
              </div>

              {/* Téléphone */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Téléphone</label>
                <input
                  type="text"
                  disabled={!isVM && formData.id !== currentUser.id}
                  value={formData.phone || ''}
                  onChange={e => setFormData({ ...formData, phone: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                />
              </div>

              {/* Date de Naissance */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Date de Naissance</label>
                <input
                  type="date"
                  disabled={!isVM && formData.id !== currentUser.id}
                  value={formData.birthDate || ''}
                  onChange={e => setFormData({ ...formData, birthDate: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                />
              </div>

              {/* Email */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Email Personnel *</label>
                <input
                  type="email"
                  required
                  disabled={!isVM}
                  value={formData.email || ''}
                  onChange={e => setFormData({ ...formData, email: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                />
              </div>

              {/* Identifiant Connexion */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Identifiant Connexion *</label>
                <input
                  type="text"
                  required
                  disabled={!isVM}
                  value={formData.loginId || ''}
                  placeholder="Utiliser l'Email si vide"
                  onChange={e => setFormData({ ...formData, loginId: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                />
              </div>

              {/* Mot de Passe */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Mot de Passe</label>
                <input
                  type="text"
                  disabled={!isVM && formData.id !== currentUser.id}
                  value={formData.password || ''}
                  onChange={e => setFormData({ ...formData, password: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                />
              </div>

              {/* Matricule */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Matricule</label>
                <input
                  type="text"
                  disabled={!isVM}
                  value={formData.matricule || ''}
                  onChange={e => setFormData({ ...formData, matricule: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                />
              </div>

              {/* Grade */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Grade *</label>
                <select
                  disabled={!isVM}
                  value={formData.grade || 'Apprenti'}
                  onChange={e => setFormData({ ...formData, grade: e.target.value as any })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                >
                  <option value="Apprenti">Apprenti</option>
                  <option value="Compagnon">Compagnon</option>
                  <option value="Maitre">Maître</option>
                </select>
              </div>

              {/* Fonction */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Fonction / Office *</label>
                <select
                  disabled={!isVM}
                  value={formData.function || 'Aucun'}
                  onChange={e => setFormData({ ...formData, function: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
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

              {/* Loge Mère */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Loge Mère</label>
                <input
                  type="text"
                  disabled={!isVM}
                  value={formData.motherLodge || ''}
                  onChange={e => setFormData({ ...formData, motherLodge: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                />
              </div>

              {/* Parrain */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Parrain</label>
                <input
                  type="text"
                  disabled={!isVM}
                  value={formData.sponsor || ''}
                  onChange={e => setFormData({ ...formData, sponsor: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                />
              </div>

              {/* Date d'initiation */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Date d'Initiation</label>
                <input
                  type="date"
                  disabled={!isVM}
                  value={formData.initiationDate || ''}
                  onChange={e => setFormData({ ...formData, initiationDate: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                />
              </div>

              {/* Date d'Entrée */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Date d'Entrée</label>
                <input
                  type="date"
                  disabled={!isVM}
                  value={formData.entryDate || ''}
                  onChange={e => setFormData({ ...formData, entryDate: e.target.value })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                />
              </div>

              {/* Statut */}
              <div className="space-y-1">
                <label className="text-xs text-[#87A0A0] block">Statut *</label>
                <select
                  disabled={!isVM}
                  value={formData.status || 'Actif'}
                  onChange={e => setFormData({ ...formData, status: e.target.value as any })}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl px-4 py-2.5 text-sm text-white focus:border-[#C5A059] focus:outline-none disabled:opacity-50"
                >
                  <option value="Actif">Actif</option>
                  <option value="Honoraire">Honoraire</option>
                  <option value="En sommeil">En sommeil</option>
                  <option value="Démissionnaire">Démissionnaire</option>
                  <option value="Radié">Radié</option>
                </select>
              </div>
            </div>

            {/* Trésorerie setup (Only visible/editable by VM) */}
            {isVM && (
              <div className="border-t border-amber-500/10 pt-6 space-y-4">
                <h4 className="text-xs font-mono text-amber-400 uppercase tracking-widest">
                  Cotisations & Trésorerie (Admin)
                </h4>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  {/* Cotisation Loge */}
                  <div className="space-y-2 bg-[#081619]/40 border border-[#87A0A0]/10 rounded-xl p-4">
                    <label className="text-xs text-[#87A0A0] block font-semibold">Cotisation Loge (€)</label>
                    <input
                      type="number"
                      value={formData.lodgeDues !== undefined ? formData.lodgeDues : 365}
                      onChange={e => setFormData({ ...formData, lodgeDues: Number(e.target.value) })}
                      className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-lg p-2 text-xs text-white focus:border-[#C5A059] focus:outline-none"
                    />
                    <label className="flex items-center gap-2 mt-2 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={formData.lodgeDuesPaid || false}
                        onChange={e => setFormData({ ...formData, lodgeDuesPaid: e.target.checked })}
                        className="rounded accent-[#0C7A7A]"
                      />
                      <span className="text-xs text-[#87A0A0]">Déjà réglé</span>
                    </label>
                  </div>

                  {/* Cotisation Ordre */}
                  <div className="space-y-2 bg-[#081619]/40 border border-[#87A0A0]/10 rounded-xl p-4">
                    <label className="text-xs text-[#87A0A0] block font-semibold">Cotisation Ordre (€)</label>
                    <input
                      type="number"
                      value={formData.orderDues !== undefined ? formData.orderDues : 50}
                      onChange={e => setFormData({ ...formData, orderDues: Number(e.target.value) })}
                      className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-lg p-2 text-xs text-white focus:border-[#C5A059] focus:outline-none"
                    />
                    <label className="flex items-center gap-2 mt-2 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={formData.orderDuesPaid || false}
                        onChange={e => setFormData({ ...formData, orderDuesPaid: e.target.checked })}
                        className="rounded accent-[#0C7A7A]"
                      />
                      <span className="text-xs text-[#87A0A0]">Déjà réglé</span>
                    </label>
                  </div>

                  {/* Cotisation Élévation */}
                  <div className="space-y-2 bg-[#081619]/40 border border-[#87A0A0]/10 rounded-xl p-4">
                    <label className="text-xs text-[#87A0A0] block font-semibold">Frais Élévation (€)</label>
                    <input
                      type="number"
                      value={formData.elevationDues !== undefined ? formData.elevationDues : 0}
                      onChange={e => setFormData({ ...formData, elevationDues: Number(e.target.value) })}
                      className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-lg p-2 text-xs text-white focus:border-[#C5A059] focus:outline-none"
                    />
                    <label className="flex items-center gap-2 mt-2 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={formData.elevationDuesPaid || false}
                        onChange={e => setFormData({ ...formData, elevationDuesPaid: e.target.checked })}
                        className="rounded accent-[#0C7A7A]"
                      />
                      <span className="text-xs text-[#87A0A0]">Déjà réglé</span>
                    </label>
                  </div>
                </div>
              </div>
            )}

            {/* Form Actions */}
            <div className="flex gap-4 border-t border-amber-500/10 pt-6 justify-end">
              <button
                type="button"
                onClick={() => { setIsEditing(false); if (formData.id && members.some(m => m.id === formData.id)) { setSelectedMember(formData as Member); } }}
                className="px-6 py-2.5 rounded-xl border border-gray-600 hover:bg-gray-800 text-sm font-semibold transition"
              >
                ANNULER
              </button>
              <button
                type="submit"
                className="px-8 py-2.5 rounded-xl bg-[#0C7A7A] hover:bg-[#0A6868] text-white text-sm font-bold border border-amber-500/20 transition hover:shadow-lg hover:shadow-[#0C7A7A]/20"
              >
                ENREGISTRER
              </button>
            </div>
          </form>
        )}

        {/* VIEW 2: MEMBER DETAILS */}
        {selectedMember && !isEditing && (
          <div className="bg-[#122428] border border-amber-500/20 rounded-2xl p-6 md:p-8 space-y-8 animate-fade-in">
            {/* Header / Avatar */}
            <div className="flex flex-col items-center border-b border-[#87A0A0]/10 pb-6 text-center relative">
              <div className="h-24 w-24 rounded-full border-2 border-amber-500/30 flex items-center justify-center bg-[#081619] mb-4 shadow-xl shadow-amber-500/5">
                <User className="h-12 w-12 text-[#C5A059]" />
              </div>

              <h2 className="font-sans text-2xl font-bold uppercase tracking-wider text-white">
                {selectedMember.firstName} {selectedMember.lastName}
              </h2>
              <p className="text-[#C5A059] font-semibold text-sm">
                {selectedMember.grade} • {selectedMember.function !== 'Aucun' ? selectedMember.function : 'Frère'}
              </p>
              <p className="text-xs text-[#87A0A0] font-mono mt-1">
                {selectedMember.matricule ? `Matricule: ${selectedMember.matricule}` : 'Matricule non attribué'}
              </p>

              {/* Edit / Delete Row */}
              <div className="flex gap-2 mt-4">
                {(isVM || currentUser.id === selectedMember.id) && (
                  <button
                    onClick={() => handleStartEdit(selectedMember)}
                    className="flex items-center gap-1.5 px-4 py-1.5 rounded-lg bg-teal-950/40 border border-teal-900/30 text-teal-400 hover:bg-teal-900/20 text-xs font-semibold transition"
                  >
                    <Edit2 className="h-3.5 w-3.5" />
                    MODIFIER
                  </button>
                )}
                {isVM && currentUser.id !== selectedMember.id && (
                  <button
                    onClick={() => handleDelete(selectedMember.id)}
                    className="flex items-center gap-1.5 px-4 py-1.5 rounded-lg bg-red-950/20 border border-red-900/30 text-red-400 hover:bg-red-900/20 text-xs font-semibold transition"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                    SUPPRIMER
                  </button>
                )}
              </div>
            </div>

            {/* Profile Information details */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Left Column: Civil details */}
              <div className="space-y-4">
                <h4 className="text-xs font-mono text-amber-500 uppercase tracking-widest border-b border-[#87A0A0]/10 pb-1">
                  Identité Civile
                </h4>
                
                <div className="flex gap-3 items-start">
                  <Mail className="h-4 w-4 text-[#C5A059] mt-1 shrink-0" />
                  <div>
                    <span className="text-[10px] text-[#87A0A0] block">EMAIL PERSONNEL</span>
                    <span className="text-sm font-semibold text-white">{selectedMember.email}</span>
                  </div>
                </div>

                {canViewAllDetails && (
                  <div className="flex gap-3 items-start">
                    <User className="h-4 w-4 text-[#C5A059] mt-1 shrink-0" />
                    <div>
                      <span className="text-[10px] text-[#87A0A0] block">IDENTIFIANT DE CONNEXION</span>
                      <span className="text-sm font-semibold text-white">{selectedMember.loginId || selectedMember.email}</span>
                    </div>
                  </div>
                )}

                {selectedMember.phone && (
                  <div className="flex gap-3 items-start">
                    <Phone className="h-4 w-4 text-[#C5A059] mt-1 shrink-0" />
                    <div>
                      <span className="text-[10px] text-[#87A0A0] block">TÉLÉPHONE</span>
                      <span className="text-sm font-semibold text-white">{selectedMember.phone}</span>
                    </div>
                  </div>
                )}

                {selectedMember.address && (
                  <div className="flex gap-3 items-start">
                    <MapPin className="h-4 w-4 text-[#C5A059] mt-1 shrink-0" />
                    <div>
                      <span className="text-[10px] text-[#87A0A0] block">ADRESSE POSTALE</span>
                      <span className="text-sm font-semibold text-white">
                        {canViewAllDetails ? selectedMember.address : '🔒 Confidentiel (Officiers uniquement)'}
                      </span>
                    </div>
                  </div>
                )}

                {selectedMember.birthDate && (
                  <div className="flex gap-3 items-start">
                    <Calendar className="h-4 w-4 text-[#C5A059] mt-1 shrink-0" />
                    <div>
                      <span className="text-[10px] text-[#87A0A0] block">DATE DE NAISSANCE</span>
                      <span className="text-sm font-semibold text-white">
                        {canViewAllDetails 
                          ? new Date(selectedMember.birthDate).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })
                          : '🔒 Confidentiel (Officiers uniquement)'}
                      </span>
                    </div>
                  </div>
                )}

                {canViewAllDetails && selectedMember.password && (
                  <div className="flex gap-3 items-start bg-black/25 border border-amber-500/10 rounded-xl p-3">
                    <Lock className="h-4 w-4 text-amber-500 shrink-0 mt-0.5" />
                    <div>
                      <span className="text-[10px] text-amber-500 block font-mono">MOT DE PASSE STOCKÉ</span>
                      <span className="text-sm font-mono text-[#E8E8E8] font-bold">{selectedMember.password}</span>
                    </div>
                  </div>
                )}
              </div>

              {/* Right Column: Masonic details */}
              <div className="space-y-4">
                <h4 className="text-xs font-mono text-amber-500 uppercase tracking-widest border-b border-[#87A0A0]/10 pb-1">
                  Cursus Initiatique
                </h4>

                <div className="flex gap-3 items-start">
                  <Award className="h-4 w-4 text-[#C5A059] mt-1 shrink-0" />
                  <div>
                    <span className="text-[10px] text-[#87A0A0] block">LOGE MÈRE</span>
                    <span className="text-sm font-semibold text-white">
                      {canViewAllDetails ? (selectedMember.motherLodge || 'Bénou Ré') : '🔒 Confidentiel'}
                    </span>
                  </div>
                </div>

                {selectedMember.sponsor && (
                  <div className="flex gap-3 items-start">
                    <User className="h-4 w-4 text-[#C5A059] mt-1 shrink-0" />
                    <div>
                      <span className="text-[10px] text-[#87A0A0] block">PARRAIN INITIATEUR</span>
                      <span className="text-sm font-semibold text-white">
                        {canViewAllDetails ? selectedMember.sponsor : '🔒 Confidentiel'}
                      </span>
                    </div>
                  </div>
                )}

                {selectedMember.initiationDate && (
                  <div className="flex gap-3 items-start">
                    <Calendar className="h-4 w-4 text-[#C5A059] mt-1 shrink-0" />
                    <div>
                      <span className="text-[10px] text-[#87A0A0] block">DATE D'INITIATION</span>
                      <span className="text-sm font-semibold text-white">
                        {canViewAllDetails 
                          ? new Date(selectedMember.initiationDate).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })
                          : '🔒 Confidentiel'}
                      </span>
                    </div>
                  </div>
                )}

                {selectedMember.entryDate && (
                  <div className="flex gap-3 items-start">
                    <Calendar className="h-4 w-4 text-[#C5A059] mt-1 shrink-0" />
                    <div>
                      <span className="text-[10px] text-[#87A0A0] block">DATE D'ENTRÉE</span>
                      <span className="text-sm font-semibold text-white">
                        {canViewAllDetails 
                          ? new Date(selectedMember.entryDate).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })
                          : '🔒 Confidentiel'}
                      </span>
                    </div>
                  </div>
                )}

                <div className="flex gap-3 items-start">
                  <CheckCircle className="h-4 w-4 text-[#C5A059] mt-1 shrink-0" />
                  <div>
                    <span className="text-[10px] text-[#87A0A0] block">STATUT DE MEMBRE</span>
                    <span className="inline-flex px-2 py-0.5 rounded text-xs bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">
                      {selectedMember.status}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Treasury card summary */}
            {canViewAllDetails ? (
              <div className="bg-[#081619]/60 border border-[#87A0A0]/10 rounded-2xl p-5 space-y-4">
                <h4 className="text-xs font-mono text-amber-500 uppercase tracking-widest pb-1 border-b border-[#87A0A0]/10">
                  État de Trésorerie
                </h4>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  {/* Lodge Dues */}
                  <div className="flex items-center justify-between bg-black/20 p-3.5 rounded-xl border border-gray-800">
                    <div>
                      <span className="text-[10px] text-gray-500 block">COTISATION LOGE</span>
                      <span className="text-sm font-bold text-white">{selectedMember.lodgeDues} €</span>
                    </div>
                    <span className={`px-2.5 py-0.5 rounded text-[10px] font-bold ${selectedMember.lodgeDuesPaid ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'}`}>
                      {selectedMember.lodgeDuesPaid ? 'RÉGLÉ' : 'À PAYER'}
                    </span>
                  </div>

                  {/* Order Dues */}
                  <div className="flex items-center justify-between bg-black/20 p-3.5 rounded-xl border border-gray-800">
                    <div>
                      <span className="text-[10px] text-gray-500 block">COTISATION ORDRE</span>
                      <span className="text-sm font-bold text-white">{selectedMember.orderDues} €</span>
                    </div>
                    <span className={`px-2.5 py-0.5 rounded text-[10px] font-bold ${selectedMember.orderDuesPaid ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'}`}>
                      {selectedMember.orderDuesPaid ? 'RÉGLÉ' : 'À PAYER'}
                    </span>
                  </div>

                  {/* Elevation Dues */}
                  {selectedMember.elevationDues > 0 && (
                    <div className="flex items-center justify-between bg-black/20 p-3.5 rounded-xl border border-gray-800">
                      <div>
                        <span className="text-[10px] text-gray-500 block">FRAIS ÉLÉVATION</span>
                        <span className="text-sm font-bold text-white">{selectedMember.elevationDues} €</span>
                      </div>
                      <span className={`px-2.5 py-0.5 rounded text-[10px] font-bold ${selectedMember.elevationDuesPaid ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'}`}>
                        {selectedMember.elevationDuesPaid ? 'RÉGLÉ' : 'À PAYER'}
                      </span>
                    </div>
                  )}
                </div>
              </div>
            ) : (
              <div className="bg-[#081619]/30 border border-[#87A0A0]/10 rounded-2xl p-5 flex items-center justify-center gap-3 text-gray-500">
                <Lock className="h-4 w-4 text-amber-500/50 shrink-0" />
                <span className="text-[10px] font-mono uppercase tracking-wider">État de Trésorerie confidentiel (Officiers uniquement)</span>
              </div>
            )}
          </div>
        )}

        {/* VIEW 3: SEARCH & FILTERABLE LIST */}
        {!selectedMember && !isEditing && (
          <div className="space-y-6">
            {/* Search and Filters Bar */}
            <div className="bg-[#122428] border border-amber-500/15 rounded-2xl p-4 flex flex-col md:flex-row gap-4 items-center">
              <div className="relative w-full md:grow">
                <span className="absolute inset-y-0 left-0 flex items-center pl-3 text-[#C5A059]">
                  <Search className="h-4 w-4" />
                </span>
                <input
                  type="text"
                  placeholder="Rechercher un Frère..."
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                  className="w-full bg-[#081619] border border-[#87A0A0]/20 rounded-xl pl-10 pr-4 py-2.5 text-sm text-[#E8E8E8] focus:border-[#C5A059] focus:outline-none"
                />
              </div>

              {/* Grade Filter Row */}
              <div className="flex gap-1 bg-[#081619] p-1 rounded-xl border border-[#87A0A0]/20 w-full md:w-auto">
                {(['All', 'Apprenti', 'Compagnon', 'Maitre'] as const).map(tab => (
                  <button
                    key={tab}
                    onClick={() => setGradeFilter(tab)}
                    className={`grow md:flex-none px-3.5 py-1.5 rounded-lg text-xs font-bold transition ${
                      gradeFilter === tab
                        ? 'bg-[#0C7A7A] text-white border border-amber-500/10'
                        : 'text-[#87A0A0] hover:text-white'
                    }`}
                  >
                    {tab === 'All' ? 'Tous' : tab}
                  </button>
                ))}
              </div>
            </div>

            {/* Members Directory List */}
            <div className="space-y-3">
              {filteredMembers.length === 0 ? (
                <div className="text-center py-12 bg-[#122428]/40 border border-dashed border-gray-800 rounded-2xl text-gray-500">
                  Aucun membre ne correspond à votre recherche.
                </div>
              ) : (
                filteredMembers.map(member => {
                  const isUpToDate = member.lodgeDuesPaid && member.orderDuesPaid;
                  return (
                    <button
                      key={member.id}
                      onClick={() => handleOpenDetail(member)}
                      className="w-full text-left p-4 rounded-xl bg-[#122428] border border-amber-500/10 hover:border-amber-500/30 transition flex items-center justify-between group"
                    >
                      <div className="flex items-center gap-4">
                        <div className={`h-11 w-11 rounded-full border flex items-center justify-center bg-[#081619] transition group-hover:scale-105 ${isUpToDate ? 'border-amber-500/30' : 'border-red-500/20'}`}>
                          {isUpToDate ? (
                            <CheckCircle className="h-5 w-5 text-[#C5A059]" />
                          ) : (
                            <AlertTriangle className="h-5 w-5 text-rose-500 animate-pulse" />
                          )}
                        </div>
                        <div>
                          <h4 className="font-sans text-sm font-bold text-white uppercase tracking-wider group-hover:text-amber-300 transition">
                            {member.firstName} {member.lastName}
                          </h4>
                          <p className="text-xs text-[#87A0A0]">
                            {member.grade} • {member.function !== 'Aucun' ? member.function : 'Membre'}
                          </p>
                        </div>
                      </div>

                      <div className="flex items-center gap-2">
                        {member.id === currentUser.id && (
                          <span className="px-2 py-0.5 rounded bg-amber-500/10 border border-amber-500/20 text-amber-500 text-[9px] font-mono tracking-wider">
                            VOUS
                          </span>
                        )}
                        <span className="text-amber-500/30 group-hover:text-amber-400 group-hover:translate-x-0.5 transition font-mono">
                          →
                        </span>
                      </div>
                    </button>
                  );
                })
              )}
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
