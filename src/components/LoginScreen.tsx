import React, { useState, useEffect } from 'react';
import { Eye, Mail, Lock, LogIn, Sparkles, CheckCircle2 } from 'lucide-react';
import { Member } from '../types';
import { loginWithFirebase, initializeAllAccountsAndDatabase } from '../lib/firebaseSync';

interface LoginScreenProps {
  members: Member[];
  onLoginSuccess: (member: Member) => void;
}

export default function LoginScreen({ members, onLoginSuccess }: LoginScreenProps) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [rememberEmail, setRememberEmail] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Firebase initialization state
  const [initStatus, setInitStatus] = useState<string | null>(null);
  const [initProgress, setInitProgress] = useState<number>(0);
  const [isInitializing, setIsInitializing] = useState<boolean>(false);

  useEffect(() => {
    // Load saved email if remember is set
    const saved = localStorage.getItem('remember_email');
    if (saved) {
      setEmail(saved);
      setRememberEmail(true);
    }
  }, []);

  const handleLogin = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    setIsLoading(true);
    setError(null);

    try {
      await loginWithFirebase(email, password);

      const searchEmail = email.trim().toLowerCase() === 'vm@loge.com' ? 'gaudin.bruno974@gmail.com' : email.trim().toLowerCase();
      const match = members.find(
        (m) => m.email.toLowerCase().trim() === searchEmail
      );

      if (rememberEmail) {
        localStorage.setItem('remember_email', email);
      } else {
        localStorage.removeItem('remember_email');
      }

      if (match) {
        onLoginSuccess(match);
      }
    } catch (err: any) {
      console.error(err);
      if (err.code === 'auth/user-not-found' || err.code === 'auth/invalid-credential') {
        setError('Identifiants incorrects. Veuillez vérifier votre email et mot de passe.');
      } else {
        setError(err.message || 'Une erreur est survenue lors de la connexion.');
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleQuickLogin = async (roleEmail: string) => {
    setEmail(roleEmail);
    setPassword('password123');
    setIsLoading(true);
    setError(null);

    try {
      await loginWithFirebase(roleEmail, 'password123');
      const found = members.find((m) => m.email === roleEmail);
      if (found) {
        onLoginSuccess(found);
      }
    } catch (err: any) {
      console.error(err);
      setError('Une erreur est survenue lors du raccourci de connexion.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleInitializeFirebase = async () => {
    setIsInitializing(true);
    setInitProgress(0);
    setInitStatus("Initialisation du Temple commencée...");
    try {
      await initializeAllAccountsAndDatabase((status, progress) => {
        setInitStatus(status);
        setInitProgress(progress);
      });
      // Allow user to see 100% complete
      await new Promise(resolve => setTimeout(resolve, 2000));
      setIsInitializing(false);
      setInitStatus(null);
    } catch (err: any) {
      console.error(err);
      setError("Erreur lors de l'initialisation de Firebase : " + (err.message || err));
      setIsInitializing(false);
      setInitStatus(null);
    }
  };

  return (
    <div className="min-h-screen flex flex-col justify-center items-center bg-[#081619] text-[#E8E8E8] px-4 py-8 relative overflow-hidden select-none">
      {/* Ancient Temple Ambient Background */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,var(--tw-gradient-stops))] from-teal-950/20 via-[#081619]/95 to-[#081619] pointer-events-none" />
      
      {/* Decorative Gold Stars / Points */}
      <div className="absolute top-10 left-10 w-2 h-2 rounded-full bg-amber-500/10" />
      <div className="absolute top-1/4 right-20 w-1.5 h-1.5 rounded-full bg-amber-500/20" />
      <div className="absolute bottom-16 left-1/3 w-2.5 h-2.5 rounded-full bg-amber-500/5 animate-pulse" />

      <div className="w-full max-w-md z-10">
        {/* All Seeing Eye / L'Oeil Omniscient */}
        <div className="flex flex-col items-center mb-8">
          <div className="relative mb-4 flex items-center justify-center">
            {/* Radiant glowing aura */}
            <div className="absolute w-24 h-24 rounded-full bg-[#0C7A7A]/20 blur-xl animate-pulse" />
            <div className="w-20 h-20 rounded-full border border-amber-500/40 flex items-center justify-center bg-[#081619] shadow-lg shadow-[#0C7A7A]/10">
              <Eye className="h-10 w-10 text-[#C5A059] animate-pulse" />
            </div>
            {/* Triangle surrounding the eye */}
            <div className="absolute w-24 h-24 border border-amber-500/10 rotate-45 pointer-events-none" />
          </div>

          <h1 className="font-sans text-3xl tracking-wider text-[#E8E8E8] text-center mb-1 font-semibold uppercase">
            RL Bénou Ré
          </h1>
          <p className="font-sans text-xs tracking-widest text-[#87A0A0] uppercase text-center max-w-xs leading-relaxed">
            Ordre Initiatique Ancien et Primitif de Memphis-Misraïm
          </p>
        </div>

        {/* Login Box */}
        <div className="bg-[#122428] border border-amber-500/20 rounded-2xl shadow-2xl p-8 backdrop-blur-md relative">
          <div className="absolute top-0 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-amber-500/20 border border-amber-500/30 text-amber-500 text-[10px] font-mono tracking-widest px-4 py-0.5 rounded-full">
            ORIENT DE SAINT-PIERRE
          </div>

          {error && (
            <div className="mb-6 bg-red-950/40 border border-red-500/30 text-red-200 text-sm p-4 rounded-xl flex items-start gap-2 animate-shake">
              <span className="text-red-400 font-bold">⚠️</span>
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleLogin} className="space-y-5">
            {/* Email Field */}
            <div className="space-y-1.5">
              <label className="text-xs text-[#87A0A0] font-sans tracking-wide block">
                Email de connexion
              </label>
              <div className="relative">
                <span className="absolute inset-y-0 left-0 flex items-center pl-3 text-[#C5A059]">
                  <Mail className="h-4 w-4" />
                </span>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="ex: vm@loge.com"
                  className="w-full bg-[#081619]/60 border border-[#87A0A0]/30 rounded-xl pl-10 pr-4 py-3 text-sm text-[#E8E8E8] focus:border-[#C5A059] focus:outline-none transition font-sans placeholder-gray-600"
                />
              </div>
            </div>

            {/* Password Field */}
            <div className="space-y-1.5">
              <label className="text-xs text-[#87A0A0] font-sans tracking-wide block">
                Mot de Passe
              </label>
              <div className="relative">
                <span className="absolute inset-y-0 left-0 flex items-center pl-3 text-[#C5A059]">
                  <Lock className="h-4 w-4" />
                </span>
                <input
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full bg-[#081619]/60 border border-[#87A0A0]/30 rounded-xl pl-10 pr-4 py-3 text-sm text-[#E8E8E8] focus:border-[#C5A059] focus:outline-none transition font-sans placeholder-gray-600"
                />
              </div>
            </div>

            {/* Remember Me */}
            <div className="flex items-center justify-between pt-1">
              <label className="flex items-center gap-2 cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={rememberEmail}
                  onChange={(e) => setRememberEmail(e.target.checked)}
                  className="rounded border-[#87A0A0]/30 text-[#0C7A7A] focus:ring-[#0C7A7A] bg-[#081619]/60 h-4 w-4 accent-[#0C7A7A]"
                />
                <span className="text-xs text-[#87A0A0] font-sans hover:text-[#E8E8E8] transition">
                  Se souvenir de mon email
                </span>
              </label>
            </div>

            {/* Action Button */}
            <button
              type="submit"
              disabled={isLoading}
              className="w-full bg-[#0C7A7A] hover:bg-[#0A6868] text-[#E8E8E8] border border-amber-500/30 rounded-xl py-3.5 px-4 font-sans font-bold text-sm tracking-wider flex items-center justify-center gap-2 transition hover:shadow-lg hover:shadow-[#0C7A7A]/20 active:translate-y-px"
            >
              {isLoading ? (
                <div className="h-5 w-5 border-2 border-[#E8E8E8] border-t-transparent rounded-full animate-spin" />
              ) : (
                <>
                  <LogIn className="h-4 w-4 text-[#C5A059]" />
                  ENTRER SUR LE PARVIS
                </>
              )}
            </button>
          </form>

          {/* Quick Access/Interactive roles list */}
          <div className="mt-8 border-t border-[#87A0A0]/10 pt-5">
            <h4 className="text-[10px] text-amber-500 font-mono tracking-widest uppercase mb-3 text-center flex items-center justify-center gap-1.5">
              <Sparkles className="h-3 w-3" />
              Accès Rapide (Démo / Test)
            </h4>
            <div className="grid grid-cols-2 gap-2 text-xs">
              {/* VM */}
              <button
                onClick={() => handleQuickLogin('gaudin.bruno974@gmail.com')}
                className="bg-[#081619]/60 hover:bg-[#081619] border border-[#87A0A0]/20 rounded-lg p-2 flex flex-col items-center transition hover:border-[#C5A059]/40 group"
              >
                <span className="font-semibold text-amber-400 text-[11px] group-hover:text-amber-300 transition">VM (Bruno)</span>
                <span className="text-[9px] text-gray-500">gaudin.bruno974@gmail.com</span>
              </button>

              {/* Secrétaire */}
              <button
                onClick={() => handleQuickLogin('muriel.mete.mm@gmail.com')}
                className="bg-[#081619]/60 hover:bg-[#081619] border border-[#87A0A0]/20 rounded-lg p-2 flex flex-col items-center transition hover:border-[#C5A059]/40 group"
              >
                <span className="font-semibold text-amber-400 text-[11px] group-hover:text-amber-300 transition">Secrétaire (Muriel)</span>
                <span className="text-[9px] text-amber-500/50 font-mono">muriel.mete.mm@gmail.com</span>
              </button>

              {/* Trésorier */}
              <button
                onClick={() => handleQuickLogin('gaudin.noah974@gmail.com')}
                className="bg-[#081619]/60 hover:bg-[#081619] border border-[#87A0A0]/20 rounded-lg p-2 flex flex-col items-center transition hover:border-[#C5A059]/40 group"
              >
                <span className="font-semibold text-amber-400 text-[11px] group-hover:text-amber-300 transition">Trésorier (Noah)</span>
                <span className="text-[9px] text-amber-500/50 font-mono">gaudin.noah974@gmail.com</span>
              </button>

              {/* Maître */}
              <button
                onClick={() => handleQuickLogin('philippe.costille@gmail.com')}
                className="bg-[#081619]/60 hover:bg-[#081619] border border-[#87A0A0]/20 rounded-lg p-2 flex flex-col items-center transition hover:border-[#C5A059]/40 group"
              >
                <span className="font-semibold text-[#87A0A0] text-[11px] group-hover:text-[#E8E8E8] transition">Maître (Philippe)</span>
                <span className="text-[9px] text-gray-500">philippe.costille@gmail.com</span>
              </button>

              {/* Compagnon */}
              <button
                onClick={() => handleQuickLogin('aure.costille@gmail.com')}
                className="bg-[#081619]/60 hover:bg-[#081619] border border-[#87A0A0]/20 rounded-lg p-2 flex flex-col items-center transition hover:border-[#C5A059]/40 group"
              >
                <span className="font-semibold text-[#87A0A0] text-[11px] group-hover:text-[#E8E8E8] transition">Compagnon (Aure)</span>
                <span className="text-[9px] text-gray-500">aure.costille@gmail.com</span>
              </button>

              {/* Apprenti */}
              <button
                onClick={() => handleQuickLogin('sacha.costille@gmail.com')}
                className="bg-[#081619]/60 hover:bg-[#081619] border border-[#87A0A0]/20 rounded-lg p-2 flex flex-col items-center transition hover:border-[#C5A059]/40 group"
              >
                <span className="font-semibold text-[#87A0A0] text-[11px] group-hover:text-[#E8E8E8] transition">Apprenti (Sacha)</span>
                <span className="text-[9px] text-gray-500">sacha.costille@gmail.com</span>
              </button>
            </div>

            {/* Firebase Database & Authentication Seeder */}
            <div className="mt-5 pt-4 border-t border-[#87A0A0]/10 flex flex-col items-center">
              <button
                type="button"
                onClick={handleInitializeFirebase}
                className="w-full py-2.5 px-3 bg-[#081619]/80 border border-amber-500/30 rounded-xl text-[10px] tracking-wider text-[#C5A059] uppercase hover:bg-amber-500/10 hover:border-amber-500/60 transition flex items-center justify-center gap-2 hover:shadow-md hover:shadow-amber-500/5 active:translate-y-px"
              >
                <Sparkles className="h-3.5 w-3.5 text-amber-500 animate-pulse" />
                Initialiser la collection & Comptes (Firebase)
              </button>
              <p className="text-[9px] text-[#87A0A0]/50 text-center mt-2 leading-tight">
                Crée automatiquement la collection <strong>membres</strong> et pré-enregistre les 9 comptes dans Firebase Authentication avec le mot de passe "password123".
              </p>
            </div>
          </div>
        </div>

        {/* Footer info */}
        <p className="text-center text-[10px] text-[#87A0A0]/40 font-mono mt-8">
          EX CINERIBUS, AD LUCEM PERPETUAM
        </p>
      </div>

      {/* Beautiful Masonic Progress Overlay */}
      {isInitializing && (
        <div className="fixed inset-0 bg-[#040D10]/95 backdrop-blur-md flex flex-col items-center justify-center z-50 p-6 select-none animate-fadeIn">
          <div className="bg-[#122428] border border-amber-500/40 rounded-2xl p-8 max-w-md w-full text-center space-y-6 shadow-2xl relative">
            <div className="absolute top-0 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-amber-500/20 border border-amber-500/40 text-amber-500 text-[9px] font-mono tracking-widest px-4 py-0.5 rounded-full uppercase">
              RÉGÉNÉRATION DU TEMPLE
            </div>

            <div className="relative flex items-center justify-center py-4">
              <div className="absolute w-20 h-20 border-t-2 border-b-2 border-amber-500/60 rounded-full animate-spin"></div>
              <div className="text-xl font-extralight text-amber-500 tracking-widest relative z-10 font-mono">B∴R∴</div>
            </div>

            <h3 className="text-base font-semibold text-[#E8E8E8] tracking-wider uppercase font-sans">
              Configuration de Firebase
            </h3>

            <div className="bg-[#081619]/60 border border-[#87A0A0]/10 rounded-xl p-4 min-h-20 flex items-center justify-center">
              <p className="text-xs text-[#87A0A0] leading-relaxed">
                {initStatus}
              </p>
            </div>

            <div className="space-y-2">
              <div className="w-full bg-[#081619] rounded-full h-2.5 overflow-hidden border border-[#87A0A0]/20">
                <div 
                  className="bg-[#0C7A7A] h-full transition-all duration-300 rounded-full shadow-lg shadow-[#0C7A7A]/40"
                  style={{ width: `${initProgress}%` }}
                />
              </div>
              <div className="flex justify-between items-center text-[10px] font-mono text-[#87A0A0]">
                <span className="text-[#87A0A0]/60">SÉCURISATION & SYNCHRONISATION</span>
                <span className="text-amber-500 font-bold">{initProgress}%</span>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
