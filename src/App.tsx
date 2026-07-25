/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect } from 'react';
import { Member, Session, Visitor, DriveFile } from './types';
import { 
  initialMembers, 
  initialSessions, 
  initialVisitors, 
  initialDriveFiles 
} from './data';

import { onAuthStateChanged } from 'firebase/auth';
import { auth } from './firebase';
import { 
  seedFirestoreIfEmpty,
  subscribeToCollection,
  logoutFromFirebase,
  addMemberToFirestore,
  updateMemberInFirestore,
  deleteMemberFromFirestore,
  addSessionToFirestore,
  updateSessionInFirestore,
  deleteSessionFromFirestore,
  addVisitorToFirestore,
  updateVisitorInFirestore,
  deleteVisitorFromFirestore
} from './lib/firebaseSync';

import LoginScreen from './components/LoginScreen';
import ParvisScreen from './components/ParvisScreen';
import MembersList from './components/MembersList';
import SessionsList from './components/SessionsList';
import VisitorsList from './components/VisitorsList';
import LibraryViewer from './components/LibraryViewer';
import TreasuryScreen from './components/TreasuryScreen';
import PlancheTraceeScreen from './components/PlancheTraceeScreen';
import SessionPresenceScreen from './components/SessionPresenceScreen';
import SessionEmargementScreen from './components/SessionEmargementScreen';

export default function App() {
  const [currentUser, setCurrentUser] = useState<Member | null>(null);
  const [currentView, setCurrentView] = useState<string>('parvis');
  const [authLoading, setAuthLoading] = useState<boolean>(true);

  const [members, setMembers] = useState<Member[]>(initialMembers);
  const [sessions, setSessions] = useState<Session[]>(initialSessions);
  const [visitors, setVisitors] = useState<Visitor[]>(initialVisitors);
  const [driveFiles] = useState<DriveFile[]>(initialDriveFiles);
  const [selectedSessionId, setSelectedSessionId] = useState<string | null>(null);

  // Seed Firestore on startup if empty
  useEffect(() => {
    seedFirestoreIfEmpty();
  }, []);

  // Sync state changes from Firebase
  useEffect(() => {
    let currentFirebaseUser: any = null;

    // Real-time subscription to members (always active)
    const unsubMembers = subscribeToCollection<Member>('members', (updatedMembers) => {
      setMembers(updatedMembers);
      
      // Auto-match current user if signed in
      if (currentFirebaseUser) {
        const matchedProfile = updatedMembers.find(
          m => m.email.toLowerCase() === currentFirebaseUser.email?.toLowerCase()
        );
        if (matchedProfile) {
          setCurrentUser(matchedProfile);
        }
      }
    });

    // Real-time subscription to sessions (always active)
    const unsubSessions = subscribeToCollection<Session>('sessions', (updatedSessions) => {
      const getTimestamp = (session: Session) => {
        const dateValue = new Date(session.date || session.dateReprise || '');
        return isNaN(dateValue.getTime()) ? 0 : dateValue.getTime();
      };
      const sorted = [...updatedSessions].sort(
        (a, b) => getTimestamp(b) - getTimestamp(a)
      );
      setSessions(sorted);
    });

    // Real-time subscription to visitors (always active)
    const unsubVisitors = subscribeToCollection<Visitor>('visitors', (updatedVisitors) => {
      setVisitors(updatedVisitors);
    });

    // Handle authentication state
    const unsubscribeAuth = onAuthStateChanged(auth, (firebaseUser) => {
      currentFirebaseUser = firebaseUser;
      if (firebaseUser) {
        // Auto-match current user by email on auth state change
        setMembers((currentMembers) => {
          const matchedProfile = currentMembers.find(
            m => m.email.toLowerCase() === firebaseUser.email?.toLowerCase()
          );
          if (matchedProfile) {
            setCurrentUser(matchedProfile);
          }
          return currentMembers;
        });
        setAuthLoading(false);
      } else {
        setCurrentUser(null);
        setAuthLoading(false);
      }
    });

    return () => {
      unsubMembers();
      unsubSessions();
      unsubVisitors();
      unsubscribeAuth();
    };
  }, []);

  // Member actions
  const handleAddMember = async (newMember: Member) => {
    await addMemberToFirestore(newMember);
  };

  const handleUpdateMember = async (updatedMember: Member) => {
    await updateMemberInFirestore(updatedMember);
  };

  const handleDeleteMember = async (id: string) => {
    await deleteMemberFromFirestore(id);
  };

  // Session actions
  const handleAddSession = async (newSession: Session) => {
    await addSessionToFirestore(newSession);
  };

  const handleUpdateSession = async (updatedSession: Session) => {
    await updateSessionInFirestore(updatedSession);
  };

  const handleDeleteSession = async (id: string) => {
    await deleteSessionFromFirestore(id);
  };

  // Visitor actions
  const handleAddVisitor = async (newVisitor: Visitor) => {
    await addVisitorToFirestore(newVisitor);
  };

  const handleUpdateVisitor = async (updatedVisitor: Visitor) => {
    await updateVisitorInFirestore(updatedVisitor);
  };

  const handleDeleteVisitor = async (id: string) => {
    await deleteVisitorFromFirestore(id);
  };

  const openPlancheTracee = (sessionId: string) => {
    setSelectedSessionId(sessionId);
    setCurrentView('planche_tracee');
  };

  const openPresence = (sessionId: string) => {
    setSelectedSessionId(sessionId);
    setCurrentView('presence');
  };

  const openEmargement = (sessionId: string) => {
    setSelectedSessionId(sessionId);
    setCurrentView('emargement');
  };

  const handleLoginSuccess = (user: Member) => {
    setCurrentUser(user);
    setCurrentView('parvis');
  };

  const handleLogout = async () => {
    await logoutFromFirebase();
    setCurrentUser(null);
    setCurrentView('parvis');
  };

  // Beautiful Masonic loading screen
  if (authLoading) {
    return (
      <div className="min-h-screen bg-[#040D10] text-[#87A0A0] flex flex-col items-center justify-center font-sans">
        <div className="relative flex items-center justify-center">
          <div className="absolute w-24 h-24 border-t-2 border-b-2 border-[#C5A059]/40 rounded-full animate-spin"></div>
          <div className="text-3xl font-extralight text-[#C5A059] tracking-widest relative z-10">B∴R∴</div>
        </div>
        <div className="mt-8 text-xs tracking-widest text-[#87A0A0]/60 uppercase">Chargement du Temple...</div>
      </div>
    );
  }

  // Render proper screen view based on current state
  if (!currentUser) {
    return <LoginScreen members={members} onLoginSuccess={handleLoginSuccess} />;
  }

  switch (currentView) {
    case 'parvis':
      return (
        <ParvisScreen 
          currentUser={currentUser} 
          members={members}
          sessions={sessions}
          onLogout={handleLogout} 
          onNavigate={setCurrentView} 
          onUpdateMember={handleUpdateMember}
        />
      );
    case 'membres':
      return (
        <MembersList
          currentUser={currentUser}
          members={members}
          onAddMember={handleAddMember}
          onUpdateMember={handleUpdateMember}
          onDeleteMember={handleDeleteMember}
          onBack={() => setCurrentView('parvis')}
        />
      );
    case 'tenues':
      return (
        <SessionsList
          currentUser={currentUser}
          sessions={sessions}
          members={members}
          visitors={visitors}
          onAddSession={handleAddSession}
          onUpdateSession={handleUpdateSession}
          onDeleteSession={handleDeleteSession}
          onOpenPlancheTracee={openPlancheTracee}
          onOpenPresence={openPresence}
          onOpenEmargement={openEmargement}
          onBack={() => setCurrentView('parvis')}
        />
      );
    case 'presence':
      return (
        <SessionPresenceScreen
          currentUser={currentUser}
          sessions={sessions}
          members={members}
          visitors={visitors}
          selectedSessionId={selectedSessionId}
          onUpdateSession={handleUpdateSession}
          onBack={() => setCurrentView('parvis')}
        />
      );
    case 'emargement':
      return (
        <SessionEmargementScreen
          currentUser={currentUser}
          sessions={sessions}
          members={members}
          visitors={visitors}
          selectedSessionId={selectedSessionId}
          onUpdateSession={handleUpdateSession}
          onBack={() => setCurrentView('parvis')}
          onNavigate={setCurrentView}
        />
      );
    case 'visiteurs':
      return (
        <VisitorsList
          currentUser={currentUser}
          visitors={visitors}
          onAddVisitor={handleAddVisitor}
          onUpdateVisitor={handleUpdateVisitor}
          onDeleteVisitor={handleDeleteVisitor}
          onBack={() => setCurrentView('parvis')}
        />
      );
    case 'architecture':
      return (
        <LibraryViewer
          currentUser={currentUser}
          driveFiles={driveFiles}
          type="Architecture"
          onBack={() => setCurrentView('parvis')}
        />
      );
    case 'instructions':
      return (
        <LibraryViewer
          currentUser={currentUser}
          driveFiles={driveFiles}
          type="Instructions"
          onBack={() => setCurrentView('parvis')}
        />
      );
    case 'rituels':
      return (
        <LibraryViewer
          currentUser={currentUser}
          driveFiles={driveFiles}
          type="Rituels"
          onBack={() => setCurrentView('parvis')}
        />
      );
    case 'tresorerie':
      return (
        <TreasuryScreen
          currentUser={currentUser}
          members={members}
          sessions={sessions}
          onUpdateMember={handleUpdateMember}
          onBack={() => setCurrentView('parvis')}
        />
      );
    case 'planche_tracee':
      return (
        <PlancheTraceeScreen
          currentUser={currentUser}
          sessions={sessions}
          members={members}
          visitors={visitors}
          selectedSessionId={selectedSessionId}
          onUpdateSession={handleUpdateSession}
          onBack={() => setCurrentView('parvis')}
        />
      );
    default:
      return (
        <ParvisScreen 
          currentUser={currentUser} 
          members={members}
          sessions={sessions}
          onLogout={handleLogout} 
          onNavigate={setCurrentView} 
          onUpdateMember={handleUpdateMember}
        />
      );
  }
}
