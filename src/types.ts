export interface Member {
  id: string;
  firstName: string;
  lastName: string;
  address: string;
  phone: string;
  email: string;
  matricule: string;
  grade: 'Apprenti' | 'Compagnon' | 'Maitre';
  function: string;
  motherLodge: string;
  sponsor: string;
  loginId: string;
  password: string;
  birthDate: string;
  initiationDate: string;
  entryDate: string;
  status: 'Actif' | 'Honoraire' | 'En sommeil' | 'Démissionnaire' | 'Radié';
  lodgeDues: number;
  lodgeDuesPaid: boolean;
  orderDues: number;
  orderDuesPaid: boolean;
  elevationDues: number;
  elevationDuesPaid: boolean;
  isAdmin?: boolean;
}

export interface Session {
  id: string;
  date: string; // ISO String
  degree: 'Apprenti' | 'Compagnon' | 'Maitre';
  type: 'Ordinaire' | 'Solennelle' | 'Instruction' | 'Banquet' | 'Conseil';
  title: string;
  description: string;
  location: string;
  dateReprise?: string;
  lieuReunion?: string;
  typeTenue?: string;
  degreTravail?: 'Apprenti' | 'Compagnon' | 'Maitre';
  heureReprise?: string;
  travail1?: string;
  travail2?: string;
  travail3?: string;
  travail4?: string;
  ordresJour?: string[];
  ligneCloture?: string;
  presentIds: string[];
  excusedIds: string[];
  visitorIds: string[];
  troncAmount: number;
  signatures: Record<string, string>; // ID -> base64 string
  closingTime: string; // "18:30"
  agenda1: string;
  agenda2: string;
  agenda3: string;
  agenda4: string;
  hasAgape: boolean;
  agapeTime: string; // "20:00"
  agapeType: 'Agape partage' | 'Agape offerte' | 'Agape avec médaille';
  agapePrice: number;
  sessionNumber?: string;
  deityName?: string;
  egyptianYear?: string;
  vmName?: string;
  customLines?: string[];
  agapeText?: string;
  contactText?: string;
  plancheDraftText?: string;
  plancheValidated?: boolean;
  isValidated?: boolean;
  plancheSecretarySigned?: boolean;
  plancheVMSigned?: boolean;
  plancheSecretarySignature?: string;
  plancheVMSignature?: string;
  plancheOrateurSignature?: string;
  plancheOrateurName?: string;
  plancheTravauxNotes?: string[];
  sacPropositions?: string;
  visitorRoles?: Record<string, string>; // mapping visitorId -> position/role held during session
  driveFolderId?: string;
  driveFolderUrl?: string;
  chrono?: number;
}

export interface Visitor {
  id: string;
  firstName: string;
  lastName: string;
  lodge: string;
  orient: string;
  obedience: string;
  email: string;
  phone: string;
  function?: string;
}

export interface DriveFile {
  id: string;
  title: string;
  type: 'Architecture' | 'Rituels' | 'Instructions';
  grade: 'Apprenti' | 'Compagnon' | 'Maitre' | 'Officiers';
  author: string;
  date: string;
  summary: string;
  content?: string;
}
