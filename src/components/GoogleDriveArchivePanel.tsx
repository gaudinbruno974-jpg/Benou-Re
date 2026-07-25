import React, { useState, useEffect } from 'react';
import { 
  FolderOpen, 
  CloudUpload, 
  Check, 
  Loader2, 
  LogOut, 
  ExternalLink, 
  ShieldAlert,
  FileText,
  UserCheck,
  Compass
} from 'lucide-react';
import { Session, Member, Visitor } from '../types';
import { 
  authenticateGoogleDrive, 
  hasGoogleDriveToken, 
  disconnectGoogleDrive,
  findOrCreateFolder, 
  uploadOrCreateFile,
  getDriveFolderName,
  DRIVE_PARENT_FOLDER_ID,
  getSessionDetails,
  generateOrdreDuJourHtml,
  generateEmargementHtml,
  generatePlancheTraceeHtml
} from '../lib/googleDrive';

interface GoogleDriveArchivePanelProps {
  session: Session;
  members: Member[];
  visitors: Visitor[];
  onUpdateSession: (updatedSession: Session) => void;
}

type ArchiveStatus = 'idle' | 'authenticating' | 'creating_folder' | 'uploading_ordre' | 'uploading_emargement' | 'uploading_planche' | 'success' | 'error';

export default function GoogleDriveArchivePanel({ 
  session, 
  members, 
  visitors,
  onUpdateSession
}: GoogleDriveArchivePanelProps) {
  const [status, setStatus] = useState<ArchiveStatus>('idle');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [googleEmail, setGoogleEmail] = useState<string | null>(null);
  const [folderId, setFolderId] = useState<string | null>(null);
  const [isConnected, setIsConnected] = useState<boolean>(hasGoogleDriveToken());

  const folderName = getDriveFolderName(session);
  const { chrono, jj, mm, annee } = getSessionDetails(session);

  // Auto-connect if token is active in-memory
  useEffect(() => {
    setIsConnected(hasGoogleDriveToken());
  }, [session]);

  const handleConnect = async () => {
    setStatus('authenticating');
    setErrorMsg(null);
    try {
      const result = await authenticateGoogleDrive();
      setGoogleEmail(result.email);
      setIsConnected(true);
      setStatus('idle');
    } catch (err: any) {
      console.error(err);
      setErrorMsg(err.message || 'Échec de la connexion à Google Drive.');
      setStatus('error');
    }
  };

  const handleDisconnect = () => {
    disconnectGoogleDrive();
    setIsConnected(false);
    setGoogleEmail(null);
    setFolderId(null);
    setStatus('idle');
    setErrorMsg(null);
  };

  const handleStartArchiving = async () => {
    setErrorMsg(null);
    
    // Explicit user confirmation for overwriting existing files, as required by Workspace integration guidelines
    const confirmed = window.confirm(
      `Confirmez-vous l'archivage (ou la mise à jour) des documents officiels de la Tenue N° ${chrono} dans le dossier Google Drive "${folderName}" ?`
    );
    if (!confirmed) return;

    try {
      // 1. Authenticate / Ensure connection
      setStatus('authenticating');
      const { token } = await authenticateGoogleDrive();

      // 2. Reuse existing folder ID if available, otherwise find or create the folder
      setStatus('creating_folder');
      let createdFolderId = session.driveFolderId || '';
      let createdFolderUrl = session.driveFolderUrl || '';
      if (!createdFolderId) {
        createdFolderId = await findOrCreateFolder(token, folderName, DRIVE_PARENT_FOLDER_ID);
        createdFolderUrl = `https://drive.google.com/drive/folders/${createdFolderId}`;
        onUpdateSession({
          ...session,
          driveFolderId: createdFolderId,
          driveFolderUrl: createdFolderUrl,
        });
      } else if (!createdFolderUrl) {
        createdFolderUrl = `https://drive.google.com/drive/folders/${createdFolderId}`;
        onUpdateSession({
          ...session,
          driveFolderUrl: createdFolderUrl,
        });
      }
      setFolderId(createdFolderId);

      // 3. Generate and Upload Ordre du jour
      setStatus('uploading_ordre');
      const ordreTitle = `Ordre du jour Tenue N° ${chrono} et la date ${jj} ${mm} ${annee}`;
      const ordreHtml = generateOrdreDuJourHtml(session, members, visitors);
      await uploadOrCreateFile(token, createdFolderId, ordreTitle, ordreHtml);

      // 4. Generate and Upload Feuille d'émargement
      setStatus('uploading_emargement');
      const emargementTitle = `Emargement Tenue N° ${chrono} et la date ${jj} ${mm} ${annee}`;
      const emargementHtml = generateEmargementHtml(session, members, visitors);
      await uploadOrCreateFile(token, createdFolderId, emargementTitle, emargementHtml);

      // 5. Generate and Upload Planche Tracée
      setStatus('uploading_planche');
      const plancheTitle = `Planche tracée Tenue N° ${chrono} et la date ${jj} ${mm} ${annee}`;
      const plancheHtml = generatePlancheTraceeHtml(session, members, visitors);
      await uploadOrCreateFile(token, createdFolderId, plancheTitle, plancheHtml);

      setStatus('success');
    } catch (err: any) {
      console.error(err);
      setErrorMsg(err.message || 'Une erreur est survenue lors de l\'archivage.');
      setStatus('error');
    }
  };

  return (
    <div className="bg-amber-500/5 border border-amber-500/20 rounded-2xl p-5 space-y-4 animate-fade-in relative overflow-hidden" id="google-drive-archive-panel">
      {/* Background decoration */}
      <div className="absolute right-0 top-0 -mr-6 -mt-6 w-24 h-24 bg-amber-500/5 rounded-full blur-xl pointer-events-none" />

      <div className="flex items-start gap-3">
        <div className="p-2.5 bg-amber-500/10 rounded-xl text-amber-500 shrink-0">
          <FolderOpen className="h-5 w-5 animate-pulse" />
        </div>
        <div className="space-y-1">
          <h4 className="text-xs font-bold text-white uppercase font-sans tracking-wider flex items-center gap-2">
            Archivage Numérique Officiel
            {isConnected && (
              <span className="inline-block w-2 h-2 rounded-full bg-emerald-500 animate-ping" />
            )}
          </h4>
          <p className="text-[11px] text-[#87A0A0] leading-relaxed">
            Générez et archivez automatiquement les 3 documents de cette tenue (Ordre du jour, Émargement et Planche Tracée) dans le Google Drive de l'Atelier.
          </p>
        </div>
      </div>

      {/* Target Folder Details */}
      <div className="bg-[#081619]/80 border border-[#87A0A0]/10 rounded-xl p-3.5 space-y-1">
        <span className="text-[8px] text-[#87A0A0] block uppercase font-mono tracking-widest font-bold">RÉPERTOIRE CIBLE SUR GOOGLE DRIVE</span>
        <div className="text-xs font-mono font-bold text-amber-400 select-all">
          {folderName}
        </div>
      </div>
      {status === 'idle' && errorMsg && (
        <div className="bg-rose-500/10 border border-rose-500/20 rounded-xl p-3 text-xs text-rose-400">
          <p className="font-semibold uppercase tracking-widest text-rose-300 font-mono">Erreur Drive</p>
          <p className="mt-1 leading-relaxed">{errorMsg}</p>
        </div>
      )}

      {/* Current progress / interactive states */}
      {status === 'idle' && isConnected && (
        <div className="bg-teal-500/5 border border-teal-500/15 rounded-xl p-3 text-xs text-[#87A0A0] space-y-2">
          <div className="flex items-center justify-between text-[10px] font-mono">
            <span>COMPTE CONNECTÉ</span>
            <button 
              onClick={handleDisconnect}
              className="text-rose-400 hover:text-rose-300 flex items-center gap-1 transition"
              title="Déconnecter le compte Google"
            >
              <LogOut className="h-3 w-3" /> Déconnexion
            </button>
          </div>
          <p className="text-white font-semibold">{googleEmail || 'VOS COMPTES GOOGLE CONNECTÉ'}</p>
          
          <div className="pt-2 border-t border-[#87A0A0]/10 grid grid-cols-3 gap-2 text-[10px] font-mono">
            <span className="flex items-center gap-1"><FileText className="h-3 w-3 text-amber-500" /> Ordre</span>
            <span className="flex items-center gap-1"><UserCheck className="h-3 w-3 text-amber-500" /> Émargement</span>
            <span className="flex items-center gap-1"><Compass className="h-3 w-3 text-amber-500" /> Planche</span>
          </div>
        </div>
      )}

      {/* Uploading progress tracker */}
      {status !== 'idle' && status !== 'error' && status !== 'success' && (
        <div className="bg-[#081619] border border-[#87A0A0]/10 rounded-xl p-4 space-y-3">
          <div className="flex items-center gap-2.5 text-xs text-white">
            <Loader2 className="h-4 w-4 text-amber-500 animate-spin" />
            <span className="font-semibold uppercase tracking-wider font-mono">Archivage en cours...</span>
          </div>
          
          <div className="space-y-2 text-[11px] font-mono">
            <div className="flex items-center justify-between">
              <span>Dossier de Tenue</span>
              <span className={status === 'creating_folder' ? 'text-amber-400 font-bold' : 'text-emerald-400'}>
                {status === 'creating_folder' ? 'Création...' : '✓ Prêt'}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span>1. L'Ordre du jour</span>
              <span className={status === 'creating_folder' ? 'text-gray-600' : status === 'uploading_ordre' ? 'text-amber-400 font-bold' : 'text-emerald-400'}>
                {status === 'creating_folder' ? 'En attente' : status === 'uploading_ordre' ? 'Envoi...' : '✓ Archivé'}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span>2. Feuille d'émargement</span>
              <span className={['creating_folder', 'uploading_ordre'].includes(status) ? 'text-gray-600' : status === 'uploading_emargement' ? 'text-amber-400 font-bold' : 'text-emerald-400'}>
                {['creating_folder', 'uploading_ordre'].includes(status) ? 'En attente' : status === 'uploading_emargement' ? 'Envoi...' : '✓ Archivé'}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span>3. Planche tracée</span>
              <span className={['creating_folder', 'uploading_ordre', 'uploading_emargement'].includes(status) ? 'text-gray-600' : status === 'uploading_planche' ? 'text-amber-400 font-bold' : 'text-emerald-400'}>
                {['creating_folder', 'uploading_ordre', 'uploading_emargement'].includes(status) ? 'En attente' : status === 'uploading_planche' ? 'Envoi...' : '✓ Archivé'}
              </span>
            </div>
          </div>
        </div>
      )}

      {/* Error state */}
      {status === 'error' && (
        <div className="bg-rose-500/10 border border-rose-500/20 rounded-xl p-3 flex gap-2.5 text-xs text-rose-400">
          <ShieldAlert className="h-4 w-4 shrink-0 mt-0.5" />
          <div className="space-y-1">
            <p className="font-bold uppercase tracking-wider font-mono">Erreur d'archivage</p>
            <p className="leading-relaxed">{errorMsg}</p>
            <button 
              onClick={() => {
                if (isConnected) {
                  handleStartArchiving();
                } else {
                  handleConnect();
                }
              }}
              className="text-xs underline font-bold text-white hover:text-amber-400 mt-1 block"
            >
              Réessayer
            </button>
          </div>
        </div>
      )}

      {/* Success state */}
      {status === 'success' && (
        <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-xl p-4 space-y-3 animate-scale-up">
          <div className="flex items-center gap-2.5 text-xs text-emerald-400 font-bold font-mono uppercase tracking-wider">
            <Check className="h-5 w-5 text-emerald-500 bg-emerald-500/10 p-0.5 rounded-full" />
            Documents Archivés avec Succès !
          </div>
          <p className="text-[11px] text-[#87A0A0] leading-relaxed">
            L'Ordre du jour, la Feuille d'émargement et la Planche tracée ont été convertis et synchronisés en format Google Docs natif sous votre répertoire de tenue.
          </p>
          <div className="flex gap-2 pt-1">
            <a
              href={`https://drive.google.com/drive/folders/${folderId || DRIVE_PARENT_FOLDER_ID}`}
              target="_blank"
              rel="noopener noreferrer"
              className="grow inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-lg bg-emerald-600 text-white text-xs font-bold hover:bg-emerald-500 transition font-sans uppercase tracking-wider"
            >
              <ExternalLink className="h-3.5 w-3.5" />
              Ouvrir le dossier Drive
            </a>
            <button
              onClick={() => setStatus('idle')}
              className="px-3 py-2 rounded-lg bg-teal-950 border border-teal-800 text-teal-400 text-xs font-mono font-semibold hover:bg-teal-900 transition uppercase"
            >
              Ok
            </button>
          </div>
        </div>
      )}

      {/* Primary Action Button */}
      {status === 'idle' && (
        <div className="pt-2">
          {!isConnected ? (
            <button
              type="button"
              onClick={handleConnect}
              className="w-full inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-amber-500 text-[#081619] text-xs font-bold hover:bg-amber-400 transition font-mono uppercase tracking-wider shadow-lg shadow-amber-500/10 cursor-pointer"
            >
              <CloudUpload className="h-4 w-4" />
              Se connecter à Google Drive
            </button>
          ) : (
            <button
              type="button"
              onClick={handleStartArchiving}
              className="w-full inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-linear-to-r from-amber-600 to-amber-500 text-white text-xs font-extrabold hover:brightness-110 transition font-mono uppercase tracking-wider shadow-md cursor-pointer"
            >
              <CloudUpload className="h-4 w-4" />
              Archiver sur Google Drive
            </button>
          )}
        </div>
      )}
    </div>
  );
}
