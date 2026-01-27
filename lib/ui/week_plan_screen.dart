IconButton(
  icon: const Icon(Icons.logout),
  onPressed: () => FirebaseAuth.instance.signOut(),
),
