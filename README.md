# Team Territory Upgrades

Mod Civ VI Gathering Storm pour autoriser l'upgrade d'une unite dans le territoire d'un coequipier.

Le bouton d'upgrade de remplacement envoie une operation `PlayerOperations.EXECUTE_SCRIPT`. Civ VI la route vers `GameEvents` dans le gameplay de l'hote. Le gameplay verifie l'equipe, le cout, puis recree l'unite amelioree en conservant son etat. Aucun pacte d'alliance diplomatique n'est utilise.

Tous les joueurs doivent avoir la meme version activee en multijoueur.
