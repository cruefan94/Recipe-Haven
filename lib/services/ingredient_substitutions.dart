/// Offline, general-purpose kitchen substitutions.
/// The reference amounts do not automatically scale to a typed quantity.
class SubstituteOption {
  const SubstituteOption({
    required this.name, required this.amount,
    required this.bestFor, required this.note,
  });
  final String name;
  final String amount;
  final String bestFor;
  final String note;
}

class IngredientSubstitution {
  const IngredientSubstitution({
    required this.name, required this.aliases,
    required this.referenceAmount, required this.category,
    required this.caution, required this.options,
  });
  final String name;
  final List<String> aliases;
  final String referenceAmount;
  final String category;
  final String caution;
  final List<SubstituteOption> options;
}

class IngredientSubstitutions {
  static String _clean(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  static const entries = <IngredientSubstitution>[
    IngredientSubstitution(
      name: "Buttermilk",
      aliases: ["cultured buttermilk"],
      referenceAmount: "1 cup",
      category: "Baking",
      caution: "Avoid this substitution in preserved or fermented foods.",
      options: [
        SubstituteOption(name: "Milk with lemon juice or vinegar", amount: "1 tbsp acid, then add milk to make 1 cup", bestFor: "Biscuits, pancakes and cakes", note: "Let stand 5–10 minutes before using."),
        SubstituteOption(name: "Plain unsweetened yogurt", amount: "1 cup, thinned if necessary", bestFor: "Baking and pancakes", note: "The consistency and tang may vary."),
      ],
    ),
    IngredientSubstitution(
      name: "Heavy cream",
      aliases: ["whipping cream", "heavy whipping cream", "double cream"],
      referenceAmount: "1 cup",
      category: "Dairy",
      caution: "These alternatives cannot be whipped into stiff peaks.",
      options: [
        SubstituteOption(name: "Half-and-half", amount: "1 cup", bestFor: "Soups and sauces", note: "Less rich than heavy cream; avoid hard boiling."),
        SubstituteOption(name: "Milk plus melted butter", amount: "3/4 cup milk + 1/4 cup butter", bestFor: "Sauces and some baking", note: "Can separate; not for whipped cream."),
        SubstituteOption(name: "Coconut cream", amount: "1 cup", bestFor: "Creamy sauces", note: "Adds coconut flavor."),
      ],
    ),
    IngredientSubstitution(
      name: "Egg",
      aliases: ["eggs", "large egg", "whole egg"],
      referenceAmount: "1 large egg",
      category: "Baking",
      caution: "Not suitable for meringue, custard, or egg-dependent soufflés.",
      options: [
        SubstituteOption(name: "Ground flaxseed and water", amount: "1 tbsp flaxseed + 3 tbsp water", bestFor: "Cookies and muffins", note: "Rest to gel; makes a denser texture."),
        SubstituteOption(name: "Unsweetened applesauce", amount: "1/4 cup", bestFor: "Quick breads and cakes", note: "Adds moisture and can affect sweetness."),
        SubstituteOption(name: "Commercial egg replacer", amount: "Label equivalent of one egg", bestFor: "Baking", note: "Check that the brand is intended for baking."),
      ],
    ),
    IngredientSubstitution(
      name: "Butter",
      aliases: ["unsalted butter", "salted butter"],
      referenceAmount: "1 cup",
      category: "Baking",
      caution: "Liquid fat does not reproduce the structure of solid butter.",
      options: [
        SubstituteOption(name: "Full-fat plant-based baking butter", amount: "1 cup", bestFor: "Cookies and cakes", note: "Use a baking block, not a low-fat spread."),
        SubstituteOption(name: "Neutral oil", amount: "3/4 cup", bestFor: "Some quick breads and muffins", note: "Not suitable for flaky pastry."),
      ],
    ),
    IngredientSubstitution(
      name: "Milk",
      aliases: ["whole milk", "regular milk", "2 percent milk", "2% milk"],
      referenceAmount: "1 cup",
      category: "Dairy",
      caution: "Do not substitute in infant formula or medically prescribed diets.",
      options: [
        SubstituteOption(name: "Unsweetened soy or oat milk", amount: "1 cup", bestFor: "Everyday cooking and baking", note: "May alter flavor and browning; check allergens."),
        SubstituteOption(name: "Evaporated milk and water", amount: "1/2 cup of each", bestFor: "Sauces and baking", note: "Use unsweetened evaporated milk."),
      ],
    ),
    IngredientSubstitution(
      name: "Sour cream",
      aliases: ["soured cream"],
      referenceAmount: "1 cup",
      category: "Dairy",
      caution: "Use unsweetened dairy products.",
      options: [
        SubstituteOption(name: "Plain Greek yogurt", amount: "1 cup", bestFor: "Dips, cakes and toppings", note: "Usually tangier and less rich."),
        SubstituteOption(name: "Crème fraîche", amount: "1 cup", bestFor: "Sauces and toppings", note: "Richer with a milder flavor."),
      ],
    ),
    IngredientSubstitution(
      name: "Plain yogurt",
      aliases: ["natural yogurt", "greek yogurt"],
      referenceAmount: "1 cup",
      category: "Dairy",
      caution: "Use unsweetened products.",
      options: [
        SubstituteOption(name: "Sour cream", amount: "1 cup", bestFor: "Dips and baking", note: "Richer than plain yogurt."),
        SubstituteOption(name: "Unsweetened dairy-free yogurt", amount: "1 cup", bestFor: "Cold dips and some batters", note: "Thickening and protein content varies."),
      ],
    ),
    IngredientSubstitution(
      name: "Baking powder",
      aliases: ["bp"],
      referenceAmount: "1 teaspoon",
      category: "Baking",
      caution: "Homemade blends may not be double-acting.",
      options: [
        SubstituteOption(name: "Baking soda, cream of tartar and starch", amount: "1/4 tsp baking soda + 1/2 tsp cream of tartar + 1/4 tsp cornstarch", bestFor: "Quick breads and cakes", note: "Mix well and use promptly."),
      ],
    ),
    IngredientSubstitution(
      name: "Baking soda",
      aliases: ["bicarbonate of soda", "sodium bicarbonate"],
      referenceAmount: "1 teaspoon",
      category: "Baking",
      caution: "Not equivalent for pH-dependent recipes such as pretzels.",
      options: [
        SubstituteOption(name: "Baking powder", amount: "3 teaspoons", bestFor: "Some cookies and quick breads", note: "Rise, taste and acidity may change."),
      ],
    ),
    IngredientSubstitution(
      name: "Cornstarch",
      aliases: ["corn starch", "cornflour"],
      referenceAmount: "1 tablespoon",
      category: "Thickening",
      caution: "Comparison is for thickening sauces, not every baking use.",
      options: [
        SubstituteOption(name: "All-purpose flour", amount: "2 tablespoons", bestFor: "Gravy and sauces", note: "Cook until the flour taste is gone."),
        SubstituteOption(name: "Arrowroot starch", amount: "1 tablespoon", bestFor: "Sauces", note: "Can behave differently in dairy sauces."),
      ],
    ),
    IngredientSubstitution(
      name: "Cake flour",
      aliases: ["soft flour"],
      referenceAmount: "1 cup",
      category: "Baking",
      caution: "The resulting cake may have a different crumb.",
      options: [
        SubstituteOption(name: "All-purpose flour", amount: "1 cup less 2 tablespoons", bestFor: "Most home cakes", note: "More protein may make a tougher cake."),
        SubstituteOption(name: "All-purpose flour and cornstarch", amount: "Remove 2 tbsp from 1 cup flour; replace with 2 tbsp cornstarch", bestFor: "Some tender cakes", note: "Sift well; an approximation."),
      ],
    ),
    IngredientSubstitution(
      name: "All-purpose flour",
      aliases: ["plain flour", "white flour", "ap flour"],
      referenceAmount: "1 cup",
      category: "Baking",
      caution: "Not all flours are interchangeable for yeasted bread.",
      options: [
        SubstituteOption(name: "1-to-1 gluten-free baking flour", amount: "1 cup", bestFor: "Many cakes and cookies", note: "Use a blend specifically labeled 1-to-1."),
        SubstituteOption(name: "Bread flour", amount: "1 cup", bestFor: "Sturdy baked goods", note: "Higher protein may make the result chewier."),
      ],
    ),
    IngredientSubstitution(
      name: "Brown sugar",
      aliases: ["light brown sugar", "dark brown sugar"],
      referenceAmount: "1 cup packed",
      category: "Sweeteners",
      caution: "Moisture and texture can change.",
      options: [
        SubstituteOption(name: "White sugar plus molasses", amount: "1 cup white sugar + 1 tbsp molasses", bestFor: "Cookies and baking", note: "Use up to 2 tbsp molasses for darker sugar."),
        SubstituteOption(name: "White sugar", amount: "1 cup", bestFor: "Some simple bakes", note: "Less moisture and molasses flavor."),
      ],
    ),
    IngredientSubstitution(
      name: "Granulated sugar",
      aliases: ["white sugar", "caster sugar", "table sugar"],
      referenceAmount: "1 cup",
      category: "Sweeteners",
      caution: "Liquid sweeteners generally require recipe-specific adjustments.",
      options: [
        SubstituteOption(name: "Superfine sugar", amount: "1 cup", bestFor: "Most baking", note: "Dissolves more quickly."),
        SubstituteOption(name: "Light brown sugar", amount: "1 cup packed", bestFor: "Cookies and cakes", note: "Makes baked goods softer and browner."),
      ],
    ),
    IngredientSubstitution(
      name: "Powdered sugar",
      aliases: ["icing sugar", "confectioners sugar"],
      referenceAmount: "1 cup",
      category: "Sweeteners",
      caution: "Granulated sugar must be finely ground for smooth icing.",
      options: [
        SubstituteOption(name: "Finely ground sugar plus cornstarch", amount: "1 cup sugar + 1 tbsp starch, finely blended", bestFor: "Dusting and some frostings", note: "May not reach store-bought smoothness."),
      ],
    ),
    IngredientSubstitution(
      name: "Honey",
      aliases: ["liquid honey"],
      referenceAmount: "1 cup",
      category: "Sweeteners",
      caution: "Sweeteners change browning, flavor and moisture.",
      options: [
        SubstituteOption(name: "Maple syrup", amount: "1 cup", bestFor: "Glazes and dressings", note: "More maple flavor; slightly thinner."),
        SubstituteOption(name: "Agave syrup", amount: "3/4–1 cup, to taste", bestFor: "Sauces and drinks", note: "Can be sweeter; adjust slowly."),
      ],
    ),
    IngredientSubstitution(
      name: "Maple syrup",
      aliases: ["pure maple syrup"],
      referenceAmount: "1 cup",
      category: "Sweeteners",
      caution: "The specific taste of maple will be lost.",
      options: [
        SubstituteOption(name: "Honey", amount: "1 cup", bestFor: "Dressings and glazes", note: "Not vegan; changes flavor."),
        SubstituteOption(name: "Agave syrup", amount: "3/4–1 cup, to taste", bestFor: "Drinks and sauces", note: "Sweetness varies."),
      ],
    ),
    IngredientSubstitution(
      name: "Lemon juice",
      aliases: ["fresh lemon juice"],
      referenceAmount: "1 tablespoon",
      category: "Acid",
      caution: "Never alter a tested home-canning recipe using these swaps.",
      options: [
        SubstituteOption(name: "Lime juice", amount: "1 tablespoon", bestFor: "Sauces and dressings", note: "Changes the citrus profile."),
        SubstituteOption(name: "White wine vinegar", amount: "1 tablespoon", bestFor: "Dressings", note: "Acidic but no lemon flavor."),
      ],
    ),
    IngredientSubstitution(
      name: "Lime juice",
      aliases: ["fresh lime juice"],
      referenceAmount: "1 tablespoon",
      category: "Acid",
      caution: "Not for tested canning or preservation recipes.",
      options: [
        SubstituteOption(name: "Lemon juice", amount: "1 tablespoon", bestFor: "Dressings and marinades", note: "Different citrus flavor."),
        SubstituteOption(name: "White wine vinegar", amount: "1 tablespoon", bestFor: "Savory sauces", note: "Provides acidity but no lime aroma."),
      ],
    ),
    IngredientSubstitution(
      name: "White vinegar",
      aliases: ["distilled white vinegar", "distilled vinegar"],
      referenceAmount: "1 tablespoon",
      category: "Acid",
      caution: "Only for everyday cooking, never untested home-preserving substitutions.",
      options: [
        SubstituteOption(name: "Apple cider vinegar", amount: "1 tablespoon", bestFor: "Dressings and marinades", note: "Fruitier flavor."),
        SubstituteOption(name: "Lemon juice", amount: "1 tablespoon", bestFor: "Quick dressings", note: "Citrus changes flavor."),
      ],
    ),
    IngredientSubstitution(
      name: "Rice vinegar",
      aliases: ["rice wine vinegar"],
      referenceAmount: "1 tablespoon",
      category: "Acid",
      caution: "Do not apply this swap to home canning.",
      options: [
        SubstituteOption(name: "Apple cider vinegar", amount: "1 tablespoon", bestFor: "Dressings", note: "More assertive flavor."),
        SubstituteOption(name: "White wine vinegar", amount: "1 tablespoon", bestFor: "Savory sauces", note: "Usually sharper than rice vinegar."),
      ],
    ),
    IngredientSubstitution(
      name: "Garlic",
      aliases: ["garlic clove", "garlic cloves", "fresh garlic"],
      referenceAmount: "1 clove",
      category: "Aromatics",
      caution: "Season to taste; clove size varies.",
      options: [
        SubstituteOption(name: "Garlic powder", amount: "1/8 teaspoon", bestFor: "Soups, rubs and sauces", note: "Choose powder without salt."),
        SubstituteOption(name: "Prepared minced garlic", amount: "About 1/2 teaspoon", bestFor: "Cooked dishes", note: "Often milder than fresh."),
      ],
    ),
    IngredientSubstitution(
      name: "Onion",
      aliases: ["onions", "yellow onion", "white onion"],
      referenceAmount: "1 medium",
      category: "Aromatics",
      caution: "No powder substitute preserves the texture of fresh onion.",
      options: [
        SubstituteOption(name: "Shallots", amount: "2–3 medium shallots", bestFor: "Sautéing and sauces", note: "Milder taste."),
        SubstituteOption(name: "Onion powder", amount: "About 1 tablespoon", bestFor: "Stews and sauces", note: "Start with less and adjust."),
      ],
    ),
    IngredientSubstitution(
      name: "Fresh basil",
      aliases: ["basil", "basil leaves"],
      referenceAmount: "1 tablespoon chopped",
      category: "Herbs",
      caution: "Fresh herbs are usually better for raw pesto.",
      options: [
        SubstituteOption(name: "Dried basil", amount: "1 teaspoon", bestFor: "Cooked sauces", note: "Add early to hydrate."),
        SubstituteOption(name: "Fresh parsley", amount: "1 tablespoon", bestFor: "Garnish", note: "Milder and different flavor."),
      ],
    ),
    IngredientSubstitution(
      name: "Fresh parsley",
      aliases: ["parsley"],
      referenceAmount: "1 tablespoon chopped",
      category: "Herbs",
      caution: "Fresh herbs generally give brighter flavor.",
      options: [
        SubstituteOption(name: "Dried parsley", amount: "1 teaspoon", bestFor: "Cooked dishes", note: "Less bright."),
        SubstituteOption(name: "Fresh cilantro", amount: "1 tablespoon", bestFor: "Garnish", note: "Very different flavor; only where appropriate."),
      ],
    ),
    IngredientSubstitution(
      name: "Allspice",
      aliases: ["ground allspice"],
      referenceAmount: "1 teaspoon",
      category: "Spices",
      caution: "Blends may include other ingredients.",
      options: [
        SubstituteOption(name: "Cinnamon and cloves", amount: "1/2 tsp each", bestFor: "Spiced cakes", note: "Not an exact match."),
        SubstituteOption(name: "Pumpkin pie spice", amount: "1 teaspoon", bestFor: "Sweet bakes", note: "Spice ratios vary by brand."),
      ],
    ),
    IngredientSubstitution(
      name: "Tomato paste",
      aliases: ["concentrated tomato paste"],
      referenceAmount: "1 tablespoon",
      category: "Tomato",
      caution: "The alternatives introduce more liquid or sugar.",
      options: [
        SubstituteOption(name: "Tomato sauce", amount: "3 tablespoons", bestFor: "Stews and sauces", note: "Reduce before adding if possible."),
        SubstituteOption(name: "Ketchup", amount: "1 tablespoon", bestFor: "Small sauce quantities", note: "Sweeter and pre-seasoned."),
      ],
    ),
    IngredientSubstitution(
      name: "Tomato sauce",
      aliases: ["tomato puree", "tomato passata"],
      referenceAmount: "1 cup",
      category: "Tomato",
      caution: "The seasoning and thickness will change.",
      options: [
        SubstituteOption(name: "Crushed tomatoes", amount: "1 cup", bestFor: "Pasta sauces", note: "Season and simmer as needed."),
        SubstituteOption(name: "Tomato purée", amount: "1 cup", bestFor: "Braises", note: "Check whether already seasoned."),
      ],
    ),
    IngredientSubstitution(
      name: "Chicken broth",
      aliases: ["chicken stock"],
      referenceAmount: "1 cup",
      category: "Broths",
      caution: "Watch sodium content.",
      options: [
        SubstituteOption(name: "Vegetable broth", amount: "1 cup", bestFor: "Soups and grains", note: "Lighter savory flavor."),
        SubstituteOption(name: "Bouillon mixed with water", amount: "Enough to make 1 cup as directed on label", bestFor: "Braises and soups", note: "Taste before adding salt."),
      ],
    ),
    IngredientSubstitution(
      name: "Beef broth",
      aliases: ["beef stock"],
      referenceAmount: "1 cup",
      category: "Broths",
      caution: "Taste and sodium may differ.",
      options: [
        SubstituteOption(name: "Mushroom broth", amount: "1 cup", bestFor: "Stews and gravies", note: "Adds umami with lighter beef flavor."),
        SubstituteOption(name: "Vegetable broth", amount: "1 cup", bestFor: "Sauces and soups", note: "May need additional seasoning."),
      ],
    ),
    IngredientSubstitution(
      name: "Soy sauce",
      aliases: ["light soy sauce", "regular soy sauce"],
      referenceAmount: "1 tablespoon",
      category: "Sauces",
      caution: "Check wheat, soy and coconut allergies.",
      options: [
        SubstituteOption(name: "Tamari", amount: "1 tablespoon", bestFor: "Stir fries and marinades", note: "Not all tamari is gluten-free; check the label."),
        SubstituteOption(name: "Coconut aminos", amount: "1 tablespoon, adjust salt", bestFor: "Sauces", note: "Often sweeter and less salty."),
      ],
    ),
    IngredientSubstitution(
      name: "Fish sauce",
      aliases: ["nam pla"],
      referenceAmount: "1 tablespoon",
      category: "Sauces",
      caution: "Check shellfish and soy allergies.",
      options: [
        SubstituteOption(name: "Vegan fish sauce", amount: "1 tablespoon", bestFor: "Savory sauces", note: "Flavor and sodium vary."),
        SubstituteOption(name: "Soy sauce", amount: "1 tablespoon, to taste", bestFor: "Cooked dishes", note: "Different flavor and allergens."),
      ],
    ),
    IngredientSubstitution(
      name: "Breadcrumbs",
      aliases: ["bread crumbs", "dry breadcrumbs"],
      referenceAmount: "1 cup",
      category: "Breading",
      caution: "Beware salt and gluten from crackers or panko.",
      options: [
        SubstituteOption(name: "Crushed plain crackers", amount: "1 cup", bestFor: "Meatloaf and coatings", note: "Can be saltier."),
        SubstituteOption(name: "Panko", amount: "1 cup", bestFor: "Crisp coatings", note: "Coarser texture."),
        SubstituteOption(name: "Quick oats", amount: "About 2/3 cup", bestFor: "Meatloaf binder", note: "Not for crunchy breading."),
      ],
    ),
    IngredientSubstitution(
      name: "Parmesan cheese",
      aliases: ["parmesan", "parmigiano"],
      referenceAmount: "1 tablespoon grated",
      category: "Cheese",
      caution: "Melting and saltiness vary.",
      options: [
        SubstituteOption(name: "Pecorino Romano", amount: "1 tablespoon", bestFor: "Pasta toppings", note: "Sharper and saltier."),
        SubstituteOption(name: "Nutritional yeast", amount: "1 tablespoon", bestFor: "Vegan garnish", note: "Savory flavor but does not melt."),
      ],
    ),
    IngredientSubstitution(
      name: "Mozzarella",
      aliases: ["shredded mozzarella", "mozzarella cheese"],
      referenceAmount: "1 cup shredded",
      category: "Cheese",
      caution: "Fresh and low-moisture mozzarella behave differently.",
      options: [
        SubstituteOption(name: "Provolone", amount: "1 cup shredded", bestFor: "Pizza and melts", note: "Sharper flavor."),
        SubstituteOption(name: "Young fontina", amount: "1 cup shredded", bestFor: "Casseroles", note: "Creamier flavor."),
      ],
    ),
    IngredientSubstitution(
      name: "Ricotta",
      aliases: ["ricotta cheese"],
      referenceAmount: "1 cup",
      category: "Cheese",
      caution: "Not interchangeable in every dessert.",
      options: [
        SubstituteOption(name: "Blended cottage cheese", amount: "1 cup", bestFor: "Lasagna", note: "Moist and slightly salty."),
        SubstituteOption(name: "Mascarpone", amount: "1 cup", bestFor: "Rich fillings", note: "Much higher fat."),
      ],
    ),
    IngredientSubstitution(
      name: "Coconut milk",
      aliases: ["full fat coconut milk", "canned coconut milk"],
      referenceAmount: "1 cup",
      category: "Dairy",
      caution: "Unsweetened products only for savory recipes.",
      options: [
        SubstituteOption(name: "Heavy cream", amount: "1 cup", bestFor: "Soups and curries", note: "Adds dairy, loses coconut taste."),
        SubstituteOption(name: "Unsweetened oat cooking cream", amount: "1 cup", bestFor: "Creamy soups", note: "Texture and fat may differ."),
      ],
    ),
    IngredientSubstitution(
      name: "Vanilla extract",
      aliases: ["vanilla essence", "pure vanilla extract"],
      referenceAmount: "1 teaspoon",
      category: "Flavor",
      caution: "Flavor swaps do not precisely reproduce vanilla.",
      options: [
        SubstituteOption(name: "Vanilla paste", amount: "1 teaspoon", bestFor: "Baked desserts", note: "Follow label for strength."),
        SubstituteOption(name: "Maple syrup", amount: "1 teaspoon", bestFor: "Muffins and cakes", note: "Adds sweetness, not vanilla aroma."),
      ],
    ),
    IngredientSubstitution(
      name: "Cream of tartar",
      aliases: ["potassium bitartrate"],
      referenceAmount: "1/2 teaspoon",
      category: "Baking",
      caution: "These substitutes are only for some egg-white recipes, not every leavener.",
      options: [
        SubstituteOption(name: "Lemon juice", amount: "About 1 teaspoon", bestFor: "Whipped egg whites", note: "Results may differ."),
        SubstituteOption(name: "White vinegar", amount: "About 1 teaspoon", bestFor: "Some meringues", note: "May change aroma."),
      ],
    ),
    IngredientSubstitution(
      name: "Vegetable oil",
      aliases: ["canola oil", "neutral oil", "cooking oil"],
      referenceAmount: "1 cup",
      category: "Oils",
      caution: "Use an oil suitable for your recipe’s cooking temperature.",
      options: [
        SubstituteOption(name: "Canola oil", amount: "1 cup", bestFor: "Cakes and sautéing", note: "Neutral flavor."),
        SubstituteOption(name: "Sunflower oil", amount: "1 cup", bestFor: "Baking and sautéing", note: "Check heat rating."),
      ],
    ),
    IngredientSubstitution(
      name: "Olive oil",
      aliases: ["extra virgin olive oil", "evoo"],
      referenceAmount: "1 tablespoon",
      category: "Oils",
      caution: "Neutral oil will not reproduce the flavor of extra virgin olive oil.",
      options: [
        SubstituteOption(name: "Canola oil", amount: "1 tablespoon", bestFor: "Roasting and sautéing", note: "Little added flavor."),
        SubstituteOption(name: "Melted butter", amount: "1 tablespoon", bestFor: "Gentle pan cooking", note: "Adds dairy."),
      ],
    ),
  ];

  /// Exact names and aliases win; otherwise match whole phrases with
  /// longest candidate first ("coconut milk" before "milk").
  /// This also handles ingredients copied from recipe lines with amounts.
  static IngredientSubstitution? lookup(String text) {
    final query = _clean(text);
    if (query.isEmpty) return null;
    for (final entry in entries) {
      if (_clean(entry.name) == query ||
          entry.aliases.any((alias) => _clean(alias) == query)) {
        return entry;
      }
    }
    final haystack = ' ' + query + ' ';
    IngredientSubstitution? best;
    var matchedLength = 0;
    for (final entry in entries) {
      for (final name in [entry.name, ...entry.aliases]) {
        final key = _clean(name);
        if (key.length > matchedLength &&
            haystack.contains(' ' + key + ' ')) {
          best = entry;
          matchedLength = key.length;
        }
      }
    }
    return best;
  }

  static List<IngredientSubstitution> suggestions(String text) {
    final query = _clean(text);
    if (query.isEmpty) return entries;
    final exact = lookup(text);
    return [
      if (exact != null) exact,
      ...entries.where((entry) => !identical(entry, exact) &&
          [entry.name, ...entry.aliases].any((name) =>
              _clean(name).contains(query))),
    ];
  }
}
