appBar: AppBar( // <-- const HIER entfernen
  title: const Text("Wochenplan"),
  actions: [
    IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () => FirebaseAuth.instance.signOut(),
    ),
  ],
),
