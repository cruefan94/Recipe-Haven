import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/block_models.dart';
import '../services/block_service.dart';
import 'chat_screen.dart';

class BlocksScreen extends StatefulWidget {
  const BlocksScreen({super.key});
  @override State<BlocksScreen> createState() => _BlocksScreenState();
}

class _BlocksScreenState extends State<BlocksScreen>
    with WidgetsBindingObserver {
  late BlockService service;
  late Future<List<NeighbourhoodBlock>> blocks;
  bool operating = false;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    service = BlockService(Supabase.instance.client);
    refresh();
  }

  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(refresh);
  }

  void refresh() { blocks = service.myBlocks(); }

  void toast(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<String?> prompt({
    required String title, required String label,
    required String button, bool multiline = false,
  }) async {
    String inputText = '';
    return showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: TextField(
            onChanged: (value) => inputText = value,
            minLines: 1, maxLines: multiline ? 3 : 1,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialog,inputText.trim()),
              child: Text(button),
            ),
          ],
        ),
      );
  }

  Future<void> createBlock() async {
    if (operating) return;
    final value = await prompt(
      title: 'Create a private Block',
      label: 'Your neighbourhood name',
      button: 'Create Block',
    );
    if (value == null) return;
    setState(() => operating = true);
    try {
      await service.createBlock(value);
      if (mounted) { setState(refresh); toast('Block created. Invite neighbours to join.'); }
    } on FormatException catch (e) {
      if (mounted) toast(e.message);
    } catch (_) {
      if (mounted) toast('Could not create the Block. Please try again.');
    } finally {
      if (mounted) setState(() => operating = false);
    }
  }

  Future<void> joinBlock() async {
    if (operating) return;
    final value = await prompt(
      title: 'Join a Block',
      label: 'Single-use invitation code',
      button: 'Request to join',
    );
    if (value == null) return;
    setState(() => operating = true);
    try {
      await service.joinBlock(value);
      if (mounted) {
        setState(refresh);
        toast('Request sent. A Block administrator must approve it.');
      }
    } on FormatException catch (e) {
      if (mounted) toast(e.message);
    } catch (_) {
      if (mounted) toast('Invitation not accepted. Check the code or request a new one.');
    } finally {
      if (mounted) setState(() => operating = false);
    }
  }

  Future<void> changeName() async {
    try {
      final currentName = await service.displayName();
      if (!mounted) return;
      final newName = await prompt(
        title:'Your display name', label:'Current: $currentName',
        button:'Save',
      );
      if (newName == null) return;
      await service.updateDisplayName(newName);
      if (mounted) toast('Display name updated.');
    } on FormatException catch (e) {
      if (mounted) toast(e.message);
    } catch (_) {
      if (mounted) toast('Could not update display name.');
    }
  }

  Future<void> cancelRequest(NeighbourhoodBlock entry) async {
    if (operating || entry.approved) return;
    final cancel = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Cancel your request?'),
        content: Text('Withdraw your request to join ' + entry.name +
          '? You will need another invitation to request access again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep request')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Withdraw')),
        ],
      ),
    );
    if (cancel != true || !mounted) return;
    setState(() => operating = true);
    try {
      await service.leaveBlock(entry.id);
      if (mounted) {
        setState(refresh);
        toast('Your request was withdrawn.');
      }
    } catch (_) {
      if (mounted) toast('Could not withdraw the request. Please try again.');
    } finally {
      if (mounted) setState(() => operating = false);
    }
  }

  Future<void> openBlock(NeighbourhoodBlock entry) async {
    if (!entry.approved) {
      toast('Membership is pending administrator approval.');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlockChatScreen(block: entry, service: service),
    ));
    if (mounted) setState(refresh);
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('The Block', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [
        IconButton(onPressed: () => setState(refresh),
          icon: const Icon(Icons.refresh),tooltip:'Refresh membership'),
        PopupMenuButton<String>(
          tooltip: 'Account',
          icon: const Icon(Icons.account_circle_outlined),
          onSelected: (choice) async {
            if (choice == 'profile') await changeName();
            if (choice == 'logout') {
              await Supabase.instance.client.auth.signOut();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value:'profile',child:Text('Display name')),
            PopupMenuItem(value:'logout',child:Text('Sign out')),
          ],
        ),
      ],
    ),
    body: SafeArea(child: RefreshIndicator(
      onRefresh: () async {
        setState(refresh);
        try { await blocks; } catch (_) { /* FutureBuilder shows retry. */ }
      },
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF17453F),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(crossAxisAlignment:CrossAxisAlignment.start,children: [
              const Icon(Icons.holiday_village_outlined,
                size: 38,color:Color(0xFF79E2CE)),
              const SizedBox(height: 12),
              Text('Welcome to your neighbourhood',
                style:Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight:FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Private conversations with your invited community.'),
            ]),
          ),
          const SizedBox(height: 24),
          Text('Your Blocks',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight:FontWeight.w700)),
          const SizedBox(height: 10),
          FutureBuilder<List<NeighbourhoodBlock>>(
            future: blocks,
            builder:(context,snapshot) {
              if (snapshot.hasError) { return Card(
                child: Padding(padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    const Text('Unable to load your Blocks. Check your connection.'),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed:()=>setState(refresh),
                      child:const Text('Try again')),
                  ])),
              ); }
              if (!snapshot.hasData) { return const Center(
                child: Padding(padding:EdgeInsets.all(22),
                  child:CircularProgressIndicator()),
              ); }
              if (snapshot.data!.isEmpty) { return const Card(
                child:Padding(padding:EdgeInsets.all(20),
                  child:Text('You have no Blocks yet. Create one or enter an invitation code.')),
              ); }
              return Column(children: [
                for (final entry in snapshot.data!)
                  Card(child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal:16,vertical:8),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF285A54),
                      child: const Icon(Icons.home_outlined,
                        color:Color(0xFF7FE0D0))),
                    title: Text(entry.name,style: const TextStyle(
                      fontWeight:FontWeight.w600)),
                    subtitle: Text(entry.approved ?
                      (entry.administrator ? 'Administrator' : 'Member') :
                      'Waiting for approval'),
                    trailing: entry.approved ?
                      const Icon(Icons.chevron_right) :
                      IconButton(
                        tooltip: 'Withdraw join request',
                        icon: const Icon(Icons.cancel_outlined),
                        onPressed: operating ? null : () => cancelRequest(entry),
                      ),
                    onTap: entry.approved ? () => openBlock(entry) : null,
                  )),
              ]);
            },
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: operating ? null : joinBlock,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Join with an invitation'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: operating ? null : createBlock,
            icon: const Icon(Icons.add_home_outlined),
            label: const Text('Create a new Block'),
          ),
          const SizedBox(height: 18),
          Text('Each Block is separate. You need a new invitation and approval to join another.',
            style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    )),
  );
}
