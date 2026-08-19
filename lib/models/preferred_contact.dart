// Canal préféré pour l'envoi d'une invitation individuelle (lien de réponse,
// e-mail) à un membre ou un dignitaire. Champ facultatif : vide tant que
// personne ne l'a renseigné — les deux boutons d'envoi restent alors
// équivalents, celui pré-rempli sert juste de repère, pas de restriction.
const String kContactWhatsApp = 'WhatsApp';
const String kContactCourriel = 'Courriel';
const List<String> kPreferredContacts = [kContactWhatsApp, kContactCourriel];
