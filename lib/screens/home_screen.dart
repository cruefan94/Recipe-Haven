import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/kitchen_backup_service.dart';
import '../models/recipe.dart';
import '../services/cookbook_store.dart';
import '../services/shopping_list_store.dart';
import '../services/recipe_import_service.dart';
import '../services/recipe_search_service.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';
import 'ingredient_finder_screen.dart';
import 'ingredient_alternatives_screen.dart';
import 'pantry_cooking_screen.dart';
import 'babe_starter_recipes_screen.dart';
import 'shopping_list_screen.dart';
import '../services/incoming_recipe_share.dart';
import '../services/private_cookbook_password.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.cookbook, required this.shopping});
  final CookbookStore cookbook;
  final ShoppingListStore shopping;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _page = 0; // Kitchen dashboard; each cooking tool has its own full-screen page.
  final _privatePassword = PrivateCookbookPassword();
  bool _privateUnlocked = false;
  bool _unlockBusy = false;
  final _search = TextEditingController();
  final _cookbookFilter = TextEditingController();
  final _marijuanaFilter = TextEditingController();
  String _newRecipeCollection = RecipeCollection.general;
  final _api = RecipeSearchService();
  bool _fileTransferBusy = false;
  String _prefillAlternatives = '';
  String _prefillFinder = '';
  String _sharedRecipeUrl = '';
  int _shareSerial = 0;
  List<Recipe> _results = const [];
  List<String> _failed = const [];
  String _searched = '';
  bool _loading = false;
  int _searchSequence = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.cookbook.addListener(_refresh);
    widget.shopping.addListener(_refresh);
    IncomingRecipeShare.instance.addListener(_receiveSharedLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _receiveSharedLink();
    });
  }

  void _receiveSharedLink() {
    if (!mounted) return;
    final url = IncomingRecipeShare.instance.takePendingUrl();
    if (url == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _privateUnlocked = false;
      _marijuanaFilter.clear();
      _newRecipeCollection = RecipeCollection.general;
      _sharedRecipeUrl = url;
      _shareSerial++;
      _page = 3; // Let the user review and choose a collection before saving.
    });
    _notice('Link received from Android Share. Review it, then tap Save.');
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || !mounted) return;
    if (_privateUnlocked || _newRecipeCollection == RecipeCollection.marijuana) {
      // Close protected recipe detail routes before showing public UI.
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(() {
        _privateUnlocked = false;
        _newRecipeCollection = RecipeCollection.general;
        _marijuanaFilter.clear();
        _shareSerial++;
        _page = 0;
      });
    }
  }

  Future<({String password, String confirmation})?> _promptPassword({
    required bool creating,
  }) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    try {
      return await showDialog<({String password, String confirmation})>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(creating ? 'Set private cookbook password' : 'Unlock private cookbook'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(creating
                ? 'Choose at least 8 characters. Your password cannot be recovered. Keep a private record of it.'
                : 'Enter your personal password to open the private collection.'),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: creating ? TextInputAction.next : TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (creating) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: confirmation,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Confirm password'),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, (
                password: password.text,
                confirmation: confirmation.text,
              )),
              child: Text(creating ? 'Create password' : 'Unlock'),
            ),
          ],
        ),
      );
    } finally {
      password.dispose();
      confirmation.dispose();
    }
  }

  Future<void> _openPrivateCookbook() async {
    if (_unlockBusy) return;
    setState(() => _unlockBusy = true);
    try {
      final configured = await _privatePassword.isConfigured;
      if (!mounted) return;
      final result = await _promptPassword(creating: !configured);
      if (!mounted || result == null) return;
      if (!configured) {
        if (result.password != result.confirmation) {
          throw const FormatException('The passwords do not match.');
        }
        await _privatePassword.create(result.password);
      } else if (!await _privatePassword.verify(result.password)) {
        _notice('Incorrect password. Please try again.');
        return;
      }
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _privateUnlocked = true;
        _page = 4;
      });
    } on FormatException catch (error) {
      _notice(error.message.toString());
    } catch (_) {
      _notice('Could not unlock the private cookbook. Please try again.');
    } finally {
      if (mounted) setState(() => _unlockBusy = false);
    }
  }

  Widget _optionsPage() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
    children: [
      Text('Options', style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      Card(child: ListTile(
        leading: const Icon(Icons.lock_outline_rounded),
        title: const Text('Private Cookbook'),
        subtitle: const Text('Open a collection protected by your personal password.'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _unlockBusy ? null : _openPrivateCookbook,
      )),
      const SizedBox(height: 12),
      Text('Your password controls access inside this app. '
        'Saved recipes and exported backup files are not encrypted.',
        style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  @override
  void dispose() {
    _searchSequence++;
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    _cookbookFilter.dispose();
    _marijuanaFilter.dispose();
    _api.dispose();
    widget.cookbook.removeListener(_refresh);
    widget.shopping.removeListener(_refresh);
    IncomingRecipeShare.instance.removeListener(_receiveSharedLink);
    super.dispose();
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _find(String searchText) async {
    final query = searchText.trim();
    if (query.isEmpty) return;
    final request = ++_searchSequence;
    FocusManager.instance.primaryFocus?.unfocus();
    _search.text = query;
    final local = RecipeSearchService.offlineSuggestions(query);
    setState(() {
      _privateUnlocked = false;
      _marijuanaFilter.clear();
      _page = 1;
      _loading = true;
      _searched = query;
      _failed = [];
      // Let people open offline recipes immediately while web sources load.
      _results = local;
    });
    try {
      final data = await _api.search(query);
      if (!mounted || request != _searchSequence) return;
      setState(() { _results = data.recipes; _failed = data.failedSources; });
    } catch (_) {
      if (request == _searchSequence) _notice('Could not load recipes. Check your connection and try again.');
    } finally {
      if (mounted && request == _searchSequence) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSave(Recipe recipe) async {
    try {
      if (widget.cookbook.contains(recipe.id)) {
        await widget.cookbook.remove(recipe.id);
        _notice(recipe.collection == RecipeCollection.marijuana
            ? 'Removed from Marijuana Cookbook' : 'Removed from My Cookbook');
      } else {
        await widget.cookbook.save(recipe);
        _notice(recipe.collection == RecipeCollection.marijuana
            ? 'Saved to Marijuana Cookbook' : 'Saved to My Cookbook');
      }
    } catch (_) { _notice('Could not save changes. Please try again.'); }
  }

  void _open(Recipe recipe) {
    if (recipe.collection == RecipeCollection.marijuana && !_privateUnlocked) return;
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
      RecipeDetailScreen(recipe: recipe, cookbook: widget.cookbook,
        shopping: widget.shopping)));
  }

  void _navigate(int page) {
    if ((page == 4 || page == 12) && !_privateUnlocked) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      // Only protected cookbook and protected shopping list retain the unlock.
      if (page != 4 && page != 12) {
        _privateUnlocked = false;
        _newRecipeCollection = RecipeCollection.general;
        _marijuanaFilter.clear();
      }
      if (page == 3) {
        _newRecipeCollection = RecipeCollection.general;
        _sharedRecipeUrl = '';
        _shareSerial++;
      }
      _page = page;
    });
  }

  void _findAlternativesFor(String ingredient) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _privateUnlocked = false;
      _prefillAlternatives = ingredient;
      _page = 7;
    });
  }

  void _findStoresFor(String ingredient) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _privateUnlocked = false;
      _prefillFinder = ingredient;
      _page = 5;
    });
  }

  Widget _dashboard() {
    final theme = Theme.of(context);
    final entries = <({String title, String subtitle, IconData icon, int page})>[
      (title: 'Find Recipes', subtitle: 'Search and compare versions of your favourite dishes.', icon: Icons.search_rounded, page: 1),
      (title: 'Babe Quick Recipes', subtitle: '18 original step-by-step recipes you can use without internet.', icon: Icons.menu_book_outlined, page: 10),
      (title: 'My Cookbook', subtitle: 'Read your saved recipes, including offline instructions.', icon: Icons.bookmark_rounded, page: 2),
      (title: 'Shopping List', subtitle: widget.shopping.toBuyCount.toString() + ' groceries still to buy. Add recipe ingredients in one tap.', icon: Icons.shopping_cart_outlined, page: 9),
      (title: 'Add Recipe', subtitle: 'Import a recipe link or write down a family favourite.', icon: Icons.add_circle_outline_rounded, page: 3),
      (title: 'Find Ingredient', subtitle: 'Find grocery stores within 30 km and open product searches.', icon: Icons.shopping_basket_rounded, page: 5),
      (title: 'Ingredient Alternatives', subtitle: 'Out of something? See substitute amounts and best uses, even offline.', icon: Icons.swap_horiz_rounded, page: 7),
      (title: 'Cook With What I Have', subtitle: 'Enter ingredients in your kitchen and find matching meal ideas.', icon: Icons.kitchen_outlined, page: 8),
      (title: 'Backup & Restore', subtitle: 'Make a copy of all saved recipes or restore a previous cookbook.', icon: Icons.settings_backup_restore_rounded, page: 6),
      (title: 'Options', subtitle: 'Settings and private cookbook access.', icon: Icons.settings_outlined, page: 11),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 28), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.primaryContainer,
          border: Border.all(color: theme.colorScheme.primary.withAlpha(120)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('RECIPE HAVEN', style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900, color: theme.colorScheme.onPrimaryContainer)),
          const SizedBox(height: 8),
          Text('Everything you need for the kitchen, all in one place.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
        ]),
      ),
      const SizedBox(height: 22),
      Text('YOUR KITCHEN', style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      ...entries.map((entry) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _navigate(entry.page),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(children: [
                Icon(entry.icon, size: 27, color: theme.colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(entry.subtitle, style: theme.textTheme.bodySmall),
                  ],
                )),
                const SizedBox(width: 10),
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary),
              ]),
            ),
          ),
        ),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      'Kitchen Home', 'Find Recipes', 'My Cookbook', 'Add Recipe',
      'Marijuana Cookbook', 'Find Ingredient', 'Backup & Restore',
      'Ingredient Alternatives', 'Cook With What I Have', 'Shopping List',
      'Babe Quick Recipes', 'Options', 'Private Shopping List',
    ];
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page != 0) _navigate(0);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _page == 0
              ? const Icon(Icons.restaurant_menu_rounded)
              : IconButton(
                  tooltip: 'Back to Kitchen Home',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => _navigate(_page == 12 ? 4 : 0),
                ),
          title: Text(pages[_page], style: const TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          centerTitle: false,
        ),
        body: SafeArea(child: IndexedStack(index: _page, children: [
          _dashboard(),
          _discover(),
          _cookbook(collection: RecipeCollection.general),
          AddRecipeScreen(
            key: ValueKey(_newRecipeCollection + ':' + _shareSerial.toString() + ':' + _privateUnlocked.toString()),
            allowPrivateCollection: _privateUnlocked && _newRecipeCollection == RecipeCollection.marijuana,
            cookbook: widget.cookbook,
            initialUrl: _sharedRecipeUrl,
            initialCollection: _newRecipeCollection,
            onAdded: (collection) {
              setState(() => _page = _privateUnlocked && collection == RecipeCollection.marijuana ? 4 : 2);
              _notice('Recipe added to ${collection == RecipeCollection.marijuana ? 'Marijuana Cookbook' : 'My Cookbook'}');
            },
          ),
          _privateUnlocked ? _cookbook(collection: RecipeCollection.marijuana)
              : const SizedBox.shrink(),
          IngredientFinderScreen(
            key: ValueKey(_prefillFinder),
            initialIngredient: _prefillFinder,
            onFindAlternatives: _findAlternativesFor,
          ),
          _backupPage(),
          IngredientAlternativesScreen(
            key: ValueKey(_prefillAlternatives),
            initialIngredient: _prefillAlternatives,
            onFindNearby: _findStoresFor,
          ),
          PantryCookingScreen(cookbook: widget.cookbook, shopping: widget.shopping),
          ShoppingListScreen(
            shopping: widget.shopping,
            onFindNearby: _findStoresFor,
            onFindAlternative: _findAlternativesFor,
          ),
          BabeStarterRecipesScreen(
            cookbook: widget.cookbook, shopping: widget.shopping,
          ),
          _optionsPage(),
          _privateUnlocked
              ? ShoppingListScreen(
                  shopping: widget.shopping,
                  privateCollectionOnly: true,
                  onFindNearby: _findStoresFor,
                  onFindAlternative: _findAlternativesFor,
                )
              : const SizedBox.shrink(),
        ])),
      ),
    );
  }

  // A full JSON backup includes private collection contents in plain text.
  // Require the private password if such content exists before any export.
  Future<bool> _authorizeFullBackup() async {
    final hasPrivate = widget.cookbook.saved.any(
      (recipe) => recipe.collection == RecipeCollection.marijuana,
    ) || widget.shopping.items.any(
      (item) => item.collection == RecipeCollection.marijuana,
    );
    if (!hasPrivate) return true;
    try {
      if (!await _privatePassword.isConfigured) {
        _notice('Set a private cookbook password under Options before exporting a full backup.');
        return false;
      }
      if (!mounted) return false;
      final result = await _promptPassword(creating: false);
      if (!mounted || result == null) return false;
      if (!await _privatePassword.verify(result.password)) {
        _notice('Incorrect password. Backup was not exported.');
        return false;
      }
      return true;
    } catch (_) {
      _notice('Could not verify the private password. Backup was not exported.');
      return false;
    }
  }

  String _restoreMessage(KitchenImportResult result) {
    final recipes = result.recipesAdded.toString();
    if (result.legacyCookbook) {
      return 'Older cookbook backup loaded: ' + recipes +
          ' recipes added. This file did not contain shopping items.';
    }
    return recipes + ' recipes and ' +
        result.shoppingItemsAdded.toString() +
        ' shopping items added. Your existing data was kept.';
  }

  Future<void> _copyBackup() async {
    if (_fileTransferBusy || !await _authorizeFullBackup() || !mounted) return;
    setState(() => _fileTransferBusy = true);
    try {
      final data = KitchenBackupService.exportData(
        widget.cookbook, widget.shopping);
      await Clipboard.setData(ClipboardData(text: data));
      _notice('Full kitchen backup copied. Save it somewhere private.');
    } on FormatException catch (error) {
      _notice(error.message.toString());
    } catch (_) {
      _notice('Could not copy your backup. Existing data is unchanged.');
    } finally {
      if (mounted) setState(() => _fileTransferBusy = false);
    }
  }

  Future<bool> _confirmRestore() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Restore your kitchen backup?'),
        content: const Text('This imports recipes and shopping items from a '
          'Babe backup file. Existing entries will stay unchanged. '
          'Older recipe-only backups are also accepted. '
          'Choose only files from a source you trust.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  void _restoreError(Object error) {
    if (error is PartialKitchenImportException) {
      _notice(error.recipesAdded.toString() +
          ' recipes added, but shopping items could not be saved. '
          'Retry the same backup safely after fixing storage.');
    } else if (error is FormatException) {
      _notice(error.message.toString());
    } else {
      _notice('Restore failed. Check available storage and try again. '
          'Your existing entries were not deleted.');
    }
  }

  Future<void> _restoreBackup() async {
    if (_fileTransferBusy || !await _confirmRestore() || !mounted) return;
    setState(() => _fileTransferBusy = true);
    try {
      final text = (await Clipboard.getData('text/plain'))?.text;
      if (text == null || text.trim().isEmpty) {
        _notice('Clipboard is empty. Copy a Babe backup first.');
        return;
      }
      final result = await KitchenBackupService.importData(
        text, widget.cookbook, widget.shopping);
      _notice(_restoreMessage(result));
    } catch (error) {
      _restoreError(error);
    } finally {
      if (mounted) setState(() => _fileTransferBusy = false);
    }
  }

  Future<void> _saveBackupFile() async {
    if (_fileTransferBusy || !await _authorizeFullBackup() || !mounted) return;
    setState(() => _fileTransferBusy = true);
    try {
      final saved = await KitchenBackupService.saveFile(
        widget.cookbook, widget.shopping);
      if (saved) {
        _notice('Full kitchen backup saved. Keep this file private.');
      }
    } on FormatException catch (error) {
      _notice(error.message.toString());
    } catch (_) {
      _notice('Could not save the backup file. Nothing was removed.');
    } finally {
      if (mounted) setState(() => _fileTransferBusy = false);
    }
  }

  Future<void> _restoreBackupFile() async {
    if (_fileTransferBusy || !await _confirmRestore() || !mounted) return;
    setState(() => _fileTransferBusy = true);
    try {
      final result = await KitchenBackupService.restoreFile(
        widget.cookbook, widget.shopping);
      if (result != null) _notice(_restoreMessage(result));
    } catch (error) {
      _restoreError(error);
    } finally {
      if (mounted) setState(() => _fileTransferBusy = false);
    }
  }

  Widget _backupPage() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
    children: [
      Text('Protect your whole kitchen',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Text('A full JSON backup includes saved recipes, ingredient '
          'lists, cooking steps and shopping items, including private '
          'entries. The private password is required when protected '
          'entries are included. The exported file is not encrypted.'),
      const SizedBox(height: 12),
      Text(widget.cookbook.saved.where((recipe) => recipe.collection == RecipeCollection.general).length.toString() +
          ' saved recipes  •  ' +
          widget.shopping.items.where((item) => item.collection == RecipeCollection.general).length.toString() + ' shopping items',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _fileTransferBusy ? null : _saveBackupFile,
        icon: const Icon(Icons.save_alt_rounded),
        label: const Text('Save Full Kitchen Backup'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _fileTransferBusy ? null : _restoreBackupFile,
        icon: const Icon(Icons.file_open_rounded),
        label: const Text('Import Kitchen Backup File'),
      ),
      const SizedBox(height: 20),
      Text('Clipboard transfer (smaller backups)',
        style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _fileTransferBusy ? null : _copyBackup,
        icon: const Icon(Icons.copy_all_rounded),
        label: const Text('Copy Full Kitchen Backup'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _fileTransferBusy ? null : _restoreBackup,
        icon: const Icon(Icons.settings_backup_restore_rounded),
        label: const Text('Restore Backup from Clipboard'),
      ),
      const SizedBox(height: 18),
      const Text('Existing saved recipes and grocery items will not be '
          'overwritten. Older Recipe Haven cookbook-only JSON files can '
          'still be imported, but contain no grocery list. To move data to '
          'a different Babe app installation, first export a JSON file in '
          'the old app, then import it in the new one. Both apps have their '
          'own private storage. The backup does not enable cloud sync.'),
      const SizedBox(height: 12),
      Text('Keep backup files private; they can contain personal recipe '
          'notes and sensitive shopping entries.',
          style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  Widget _discover() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    children: [
      Text('What sounds good today?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        onSubmitted: _find,
        decoration: InputDecoration(
          hintText: 'Try chicken Alfredo, tacos, banana bread…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(onPressed: () => _find(_search.text), tooltip: 'Search recipes', icon: const Icon(Icons.arrow_forward)),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 6, children: ['Pasta', 'Chicken', 'Pizza', 'Soup', 'Chocolate cake']
        .map((term) => ActionChip(label: Text(term), onPressed: () => _find(term))).toList()),
      const SizedBox(height: 18),
      if (_loading && _results.isEmpty)
        const Padding(padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()))
      else if (_searched.isEmpty) _empty(Icons.restaurant_menu, 'Search different recipes', 'Browse versions from different recipe sources and save your favourites.')
      else ...[
        Text('${_results.length} results for “$_searched”', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        if (_loading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 5),
          const Text('Showing offline recipes while more sources load...'),
        ],
        const SizedBox(height: 10),
        if (_failed.isNotEmpty) Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Some sources were unavailable: ${_failed.join(', ')}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        if (_results.isEmpty) _empty(Icons.search_off, 'Nothing found in connected sources', 'Try another name, or search more websites below.'),
        ..._results.map((recipe) => RecipeCard(
          key: ValueKey(recipe.id), recipe: recipe,
          isSaved: widget.cookbook.contains(recipe.id),
          onOpen: () => _open(recipe), onToggleSave: () => _toggleSave(recipe),
        )),
      ],
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: () => _navigate(10),
        icon: const Icon(Icons.menu_book_outlined),
        label: const Text('Browse all 18 offline Babe recipes'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () async {
          final query = Uri.encodeQueryComponent(_search.text.trim().isEmpty ? 'recipes' : '${_search.text.trim()} recipe');
          await openExternalUrl('https://www.google.com/search?q=$query', context);
        },
        icon: const Icon(Icons.public), label: const Text('Search the whole web'),
      ),
      const SizedBox(height: 12),
      Text('Browse more cooking sites',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ('Allrecipes', 'allrecipes.com'),
        ('Food Network', 'foodnetwork.com'),
        ('BBC Good Food', 'bbcgoodfood.com'),
        ('Taste of Home', 'tasteofhome.com'),
        ('Serious Eats', 'seriouseats.com'),
      ].map((site) => ActionChip(
        avatar: const Icon(Icons.open_in_new, size: 17),
        label: Text(site.$1),
        onPressed: () => openExternalUrl(
          Uri.https('www.google.com', '/search', {
            'q': 'site:${site.$2} ${_search.text.trim().isEmpty ? 'recipes' : _search.text.trim()} recipe'
          }).toString(),
          context,
        ),
      )).toList()),
      const SizedBox(height: 8),
      Text('These extra websites open in your browser, not inside the search results list. '
        'Use Add Recipe to save a link, or open a listed website recipe and select Import ingredients & steps.',
        textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  Widget _cookbook({required String collection}) {
    final isMarijuana = collection == RecipeCollection.marijuana;
    final filterController = isMarijuana ? _marijuanaFilter : _cookbookFilter;
    final filter = filterController.text.trim().toLowerCase();
    if (isMarijuana && !_privateUnlocked) return const SizedBox.shrink();
    final savedInSection = widget.cookbook.saved.where((recipe) => recipe.collection == collection).toList();
    final found = savedInSection.where((recipe) =>
      recipe.title.toLowerCase().contains(filter) || recipe.source.toLowerCase().contains(filter)).toList();

    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      if (isMarijuana) ...[
        Text('Marijuana Cookbook',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('A separate place for your adult-use cannabis recipes. Keep infused foods clearly labelled and out of reach of children and pets.'),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => setState(() {
            _newRecipeCollection = RecipeCollection.marijuana;
            _page = 3;
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add marijuana recipe'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => openExternalUrl('https://www.google.com/search?q=cannabis+edible+recipes', context),
          icon: const Icon(Icons.public),
          label: const Text('Find recipes on the web'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _navigate(12),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Private Shopping List'),
        ),
        const SizedBox(height: 12),
      ],
      Text('${savedInSection.length} saved recipes', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _navigate(6),
        icon: const Icon(Icons.settings_backup_restore_rounded),
        label: const Text('Backup & Restore'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: filterController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: isMarijuana ? 'Search marijuana cookbook' : 'Find a saved recipe',
        ),
      ),
      const SizedBox(height: 16),
      if (widget.cookbook.readFailure)
        const Text('Your saved cookbook could not be read. Editing is disabled to protect its contents.'),
      if (found.isEmpty) _empty(Icons.book_outlined,
        isMarijuana ? 'Your marijuana cookbook is ready' : 'Your cookbook is ready',
        isMarijuana
          ? 'Use Add marijuana recipe to save your favourite recipes here, separately from My Cookbook.'
          : 'Save recipes from search or add your own to see them here.'),
      ...found.map((recipe) => RecipeCard(
        key: ValueKey(recipe.id), recipe: recipe, isSaved: true,
        onOpen: () => _open(recipe), onToggleSave: () => _confirmRemoval(recipe),
      )),
    ]);
  }

  Future<void> _confirmRemoval(Recipe recipe) async {
    final shouldRemove = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Remove saved recipe?'), content: Text(recipe.title),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove'))],
    ));
    if (shouldRemove == true) await _toggleSave(recipe);
  }

  Widget _empty(IconData icon, String headline, String copy) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 18),
    child: Column(children: [Icon(icon, size: 62, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 12), Text(headline, textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6), Text(copy, textAlign: TextAlign.center)]),
  );
}

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({
    super.key, required this.cookbook, required this.onAdded,
    this.initialCollection = RecipeCollection.general,
    this.initialUrl = '',
    this.allowPrivateCollection = false,
  });
  final CookbookStore cookbook;
  final ValueChanged<String> onAdded;
  final String initialCollection;
  final String initialUrl;
  final bool allowPrivateCollection;

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _ingredients = TextEditingController();
  final _instructions = TextEditingController();
  bool _importing = false;
  bool _manual = false;
  late String _collection;
  @override void initState() {
    super.initState();
    _collection = widget.allowPrivateCollection &&
        widget.initialCollection == RecipeCollection.marijuana
        ? RecipeCollection.marijuana : RecipeCollection.general;
    _url.text = widget.initialUrl;
  }
  @override void dispose() { _url.dispose(); _title.dispose(); _ingredients.dispose(); _instructions.dispose(); super.dispose(); }

  Future<void> _pasteRecipeLink() async {
    try {
      final clipboardText = (await Clipboard.getData('text/plain'))?.text ?? '';
      if (!mounted) return;
      final match = RegExp(r'https://[^\s]+').firstMatch(clipboardText);
      final candidate = match?.group(0)
          ?.replaceAll(RegExp(r'[.,;)\]}>]+$'), '');
      final url = Uri.tryParse(candidate ?? '');
      if (url == null || url.scheme != 'https' || url.host.isEmpty ||
          url.userInfo.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Copy a recipe link from your browser first.'),
        ));
        return;
      }
      setState(() => _url.text = url.toString());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not paste the link. Try entering it manually.'),
        ));
      }
    }
  }

  Future<void> _add() async {
    setState(() => _importing = true);
    try {
      Recipe recipe;
      if (_manual) {
        if (_title.text.trim().isEmpty) throw const FormatException('Give your recipe a title.');
        final identifier = 'manual:${DateTime.now().microsecondsSinceEpoch}';
        recipe = Recipe(id: identifier, title: _title.text.trim(), source: 'My recipes',
          ingredients: _lines(_ingredients.text), steps: _lines(_instructions.text),
          collection: _collection);
      } else {
        recipe = await RecipeImportService().importUrl(_url.text);
      }
      // Keep separate copies when the same online recipe is saved into
      // both collections, without overwriting the everyday cookbook entry.
      recipe = recipe.copyWith(
        collection: _collection,
        id: _collection == RecipeCollection.marijuana
            ? 'marijuana:${recipe.id}' : recipe.id,
      );
      await widget.cookbook.save(recipe);
      if (!mounted) return;
      _url.clear(); _title.clear(); _ingredients.clear(); _instructions.clear();
      widget.onAdded(_collection);
    } catch (e) {
      if (!mounted) return;
      final message = e is FormatException ? e.message.toString() : 'Could not add the recipe. Check the link and try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally { if (mounted) setState(() => _importing = false); }
  }

  List<String> _lines(String input) => input.split(RegExp(r'\r?\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Keep recipes from anywhere', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('Save a link from a cooking website, or write down a family favourite.'),
    const SizedBox(height: 20),
    if (widget.allowPrivateCollection) ...[
      const Text('Save into', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: RecipeCollection.general, label: Text('My Cookbook')),
          ButtonSegment(value: RecipeCollection.marijuana, label: Text('Marijuana')),
        ],
        selected: {_collection},
        onSelectionChanged: (value) => setState(() => _collection = value.first),
      ),
      const SizedBox(height: 18),
    ],
    SegmentedButton<bool>(segments: const [ButtonSegment(value: false, icon: Icon(Icons.link), label: Text('From a link')),
      ButtonSegment(value: true, icon: Icon(Icons.edit_outlined), label: Text('Write my own'))],
      selected: {_manual}, onSelectionChanged: (value) => setState(() => _manual = value.first)),
    const SizedBox(height: 20),
    if (!_manual) ...[
      TextField(controller: _url, keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Recipe website link', hintText: 'https://...')),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _importing ? null : _pasteRecipeLink,
          icon: const Icon(Icons.content_paste_rounded),
          label: const Text('Paste recipe link'),
        ),
      ),
      const SizedBox(height: 10),
      const Text('We try to import ingredients and instructions when the website makes them available. Otherwise the link is saved.'),
    ] else ...[
      TextField(controller: _title, textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Recipe name')),
      const SizedBox(height: 12),
      TextField(controller: _ingredients, maxLines: 6, minLines: 4, textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Ingredients', hintText: 'One ingredient per line')),
      const SizedBox(height: 12),
      TextField(controller: _instructions, maxLines: 8, minLines: 5, textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Instructions', hintText: 'One step per line')),
    ],
    const SizedBox(height: 20),
    FilledButton.icon(onPressed: _importing ? null : _add,
      icon: _importing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bookmark_add_outlined),
      label: Text(_importing ? 'Saving…' :
        _collection == RecipeCollection.marijuana ? 'Save to Marijuana Cookbook' : 'Save to My Cookbook'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54))),
  ]);
}
