return Scaffold( // <-- const HIER entfernen
  appBar: AppBar(
    title: const Text("Wochenplan"),
    actions: [
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () => FirebaseAuth.instance.signOut(),
      ),
    ],
  ),
  body: ...
);
