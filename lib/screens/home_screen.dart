import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/cookbook_file_service.dart';
import '../models/recipe.dart';
import '../services/cookbook_store.dart';
import '../services/recipe_import_service.dart';
import '../services/recipe_search_service.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';
import 'ingredient_finder_screen.dart';
import 'ingredient_alternatives_screen.dart';
import 'pantry_cooking_screen.dart';
import '../services/incoming_recipe_share.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.cookbook});
  final CookbookStore cookbook;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _page = 0; // Kitchen dashboard; each cooking tool has its own full-screen page.
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
    widget.cookbook.addListener(_refresh);
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
      _newRecipeCollection = RecipeCollection.general;
      _sharedRecipeUrl = url;
      _shareSerial++;
      _page = 3; // Let the user review and choose a collection before saving.
    });
    _notice('Link received from Android Share. Review it, then tap Save.');
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _searchSequence++;
    _search.dispose();
    _cookbookFilter.dispose();
    _marijuanaFilter.dispose();
    _api.dispose();
    widget.cookbook.removeListener(_refresh);
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
    setState(() { _page = 1; _loading = true; _searched = query; _failed = []; });
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

  void _open(Recipe recipe) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
    RecipeDetailScreen(recipe: recipe, cookbook: widget.cookbook)));

  void _navigate(int page) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      // Add Recipe reached from the dashboard defaults to the regular cookbook.
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
      _prefillAlternatives = ingredient;
      _page = 7;
    });
  }

  void _findStoresFor(String ingredient) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _prefillFinder = ingredient;
      _page = 5;
    });
  }

  Widget _dashboard() {
    final theme = Theme.of(context);
    final entries = <({String title, String subtitle, IconData icon, int page})>[
      (title: 'Find Recipes', subtitle: 'Search and compare versions of your favourite dishes.', icon: Icons.search_rounded, page: 1),
      (title: 'My Cookbook', subtitle: 'Read your saved recipes, including offline instructions.', icon: Icons.bookmark_rounded, page: 2),
      (title: 'Add Recipe', subtitle: 'Import a recipe link or write down a family favourite.', icon: Icons.add_circle_outline_rounded, page: 3),
      (title: 'Marijuana Cookbook', subtitle: 'Keep adult-use recipes in a separate collection.', icon: Icons.local_florist_rounded, page: 4),
      (title: 'Find Ingredient', subtitle: 'Find grocery stores within 30 km and open product searches.', icon: Icons.shopping_basket_rounded, page: 5),
      (title: 'Ingredient Alternatives', subtitle: 'Out of something? See substitute amounts and best uses, even offline.', icon: Icons.swap_horiz_rounded, page: 7),
      (title: 'Cook With What I Have', subtitle: 'Enter ingredients in your kitchen and find matching meal ideas.', icon: Icons.kitchen_outlined, page: 8),
      (title: 'Backup & Restore', subtitle: 'Make a copy of all saved recipes or restore a previous cookbook.', icon: Icons.settings_backup_restore_rounded, page: 6),
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
      'Ingredient Alternatives', 'Cook With What I Have',
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
                  onPressed: () => _navigate(0),
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
            key: ValueKey(_newRecipeCollection + ':' + _shareSerial.toString()),
            cookbook: widget.cookbook,
            initialUrl: _sharedRecipeUrl,
            initialCollection: _newRecipeCollection,
            onAdded: (collection) {
              setState(() => _page = collection == RecipeCollection.marijuana ? 4 : 2);
              _notice('Recipe added to ${collection == RecipeCollection.marijuana ? 'Marijuana Cookbook' : 'My Cookbook'}');
            },
          ),
          _cookbook(collection: RecipeCollection.marijuana),
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
          PantryCookingScreen(cookbook: widget.cookbook),
        ])),
      ),
    );
  }

  Future<void> _copyBackup() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.cookbook.exportBackup()));
      _notice('Backup copied. Save it in a private note before switching phones.');
    } catch (_) {
      _notice('Unable to copy your cookbook right now.');
    }
  }

  Future<void> _restoreBackup() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Restore recipes from clipboard?'),
        content: const Text('This merges recipes from a Recipe Haven backup. '
          'Existing saved recipes are never deleted or replaced.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Restore recipes'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      final value = (await Clipboard.getData('text/plain'))?.text;
      if (value == null || value.trim().isEmpty) {
        _notice('Clipboard is empty. Copy a Recipe Haven backup first.');
        return;
      }
      final imported = await widget.cookbook.mergeBackup(value);
      _notice(imported == 0
          ? 'All backup recipes are already saved.'
          : '$imported recipes restored successfully.');
    } on FormatException catch (e) {
      _notice(e.message.toString());
    } catch (_) {
      _notice('Unable to restore backup. Existing recipes are unchanged.');
    }
  }

  Future<void> _saveBackupFile() async {
    if (_fileTransferBusy) return;
    setState(() => _fileTransferBusy = true);
    try {
      final saved = await CookbookFileService.saveBackup(widget.cookbook);
      if (mounted && saved) _notice('Backup saved. Keep your JSON file private.');
    } on FormatException catch (e) {
      _notice(e.message.toString());
    } catch (_) {
      _notice('Could not save JSON file. You can still copy the backup.');
    } finally {
      if (mounted) setState(() => _fileTransferBusy = false);
    }
  }

  Future<void> _restoreBackupFile() async {
    if (_fileTransferBusy) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Import your cookbook?'),
        content: const Text('Select a Recipe Haven JSON backup. '
          'Recipes will be merged and existing recipes will not be deleted. '
          'Only import a file you trust.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Choose JSON file'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _fileTransferBusy = true);
    try {
      final count = await CookbookFileService.restoreBackup(widget.cookbook);
      if (mounted && count != null) {
        _notice(count == 0 ? 'All backup recipes are already saved.'
            : '$count recipes imported. Your existing recipes were kept.');
      }
    } on FormatException catch (e) {
      _notice(e.message.toString());
    } catch (_) {
      _notice('Could not import the backup. Existing recipes were not deleted.');
    } finally {
      if (mounted) setState(() => _fileTransferBusy = false);
    }
  }

  Widget _backupPage() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
    children: [
      Text('Protect your saved recipes',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Text('Back up both My Cookbook and Marijuana Cookbook together. '
        'Saved recipes include ingredients, cooking steps and source links.'),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _fileTransferBusy ? null : _saveBackupFile,
        icon: const Icon(Icons.save_alt_rounded),
        label: const Text('Save cookbook to JSON file'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _fileTransferBusy ? null : _restoreBackupFile,
        icon: const Icon(Icons.file_open_rounded),
        label: const Text('Import cookbook from JSON file'),
      ),
      const SizedBox(height: 22),
      Text('Clipboard transfer (for smaller cookbooks)',
        style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _copyBackup,
        icon: const Icon(Icons.copy_all_rounded),
        label: const Text('Copy cookbook backup'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _restoreBackup,
        icon: const Icon(Icons.settings_backup_restore_rounded),
        label: const Text('Restore from clipboard'),
      ),
      const SizedBox(height: 18),
      const Text('Recommended: save a JSON file and move it to your other phone '
        'using Files, cloud storage or a private message. On the other phone, choose '
        'Import cookbook from JSON file. Clipboard remains available for small transfers. '
        'The JSON file includes any personally saved recipes and should not be shared publicly.'),
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
      if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else if (_searched.isEmpty) _empty(Icons.restaurant_menu, 'Search different recipes', 'Browse versions from different recipe sources and save your favourites.')
      else ...[
        Text('${_results.length} results for “$_searched”', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
  });
  final CookbookStore cookbook;
  final ValueChanged<String> onAdded;
  final String initialCollection;
  final String initialUrl;

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
    _collection = widget.initialCollection == RecipeCollection.marijuana
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
    ...[
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
