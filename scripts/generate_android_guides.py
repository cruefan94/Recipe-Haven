#!/usr/bin/env python3
"""Generate matching Recipe Haven Android quick-start Word guides for APK artifacts."""
from pathlib import Path
import sys
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

ACCENT = RGBColor(23, 104, 114)
MUTED = RGBColor(83, 99, 110)
DARK = RGBColor(29, 42, 51)


def add_text(doc, text, *, style=None):
    p = doc.add_paragraph(style=style)
    p.add_run(text)
    return p


def heading(doc, title):
    doc.add_heading(title, level=2)


def steps(doc, items):
    for i, detail in enumerate(items, 1):
        p = doc.add_paragraph(style='Normal')
        p.paragraph_format.left_indent = Inches(0.16)
        p.paragraph_format.first_line_indent = Inches(-0.16)
        p.paragraph_format.space_after = Pt(5)
        lead = p.add_run(f'{i}.  ')
        lead.bold = True
        lead.font.color.rgb = ACCENT
        p.add_run(detail)


def note(doc, title, body):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(7)
    t = p.add_run(title + '  ')
    t.bold = True
    t.font.color.rgb = ACCENT
    p.add_run(body)


def setup(doc, edition):
    sec = doc.sections[0]
    sec.top_margin = Inches(0.65)
    sec.bottom_margin = Inches(0.64)
    sec.left_margin = Inches(0.80)
    sec.right_margin = Inches(0.80)
    sec.header_distance = Inches(0.28)
    sec.footer_distance = Inches(0.3)
    normal = doc.styles['Normal']
    normal.font.name = 'Aptos'
    normal.font.size = Pt(9.4)
    normal.font.color.rgb = DARK
    normal.paragraph_format.space_after = Pt(5)
    normal.paragraph_format.line_spacing = 1.13
    for key, size in [('Title', 20), ('Heading 1', 14), ('Heading 2', 11)]:
        s = doc.styles[key]
        s.font.name = 'Aptos Display'
        s.font.size = Pt(size)
        s.font.bold = True
        s.font.color.rgb = ACCENT
        s.paragraph_format.space_after = Pt(5)
        s.paragraph_format.space_before = Pt(8)
    footer = sec.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = footer.add_run('Recipe Haven ' + edition + '  |  Android test guide  |  Page ')
    run.font.size = Pt(8)
    run.font.color.rgb = MUTED
    fld = OxmlElement('w:fldSimple')
    fld.set(qn('w:instr'), 'PAGE')
    footer._p.append(fld)


def generate(output_dir: Path, edition: str):
    is_full = edition == 'Full'
    app_name = 'Recipe Haven Full' if is_full else 'Recipe Haven'
    apk = 'Recipe-Haven-' + edition + '-Android-TEST.apk'
    file = output_dir / ('Recipe-Haven-' + edition + '-Android-Quick-Start.docx')
    doc = Document()
    setup(doc, edition)
    doc.add_paragraph(app_name, style='Title')
    p = doc.add_paragraph('SIMPLE DOWNLOAD, INSTALL & APP GUIDE')
    p.style = 'Subtitle'
    p.runs[0].font.color.rgb = MUTED
    add_text(doc, 'For Android phones  •  This is a test version supplied through the Recipe Haven GitHub project.')
    heading(doc, '1  Download and unzip your files')
    steps(doc, [
        'On the GitHub Actions build page, scroll to Artifacts and tap Recipe-Haven-' + edition + '-Android-TEST. Sign in to GitHub if asked.',
        'Your phone downloads one ZIP file. Open My Files (Samsung phones) or Files / Files by Google (other Android phones).',
        'Open Downloads, select the downloaded ZIP, and tap Extract or Unzip. If asked where to save, choose Downloads or a folder you can find.',
        'Inside the extracted folder, find ' + apk + '. The Word guide you are reading is included alongside it.',
    ])
    note(doc, "Can't unzip the ZIP?", 'Install the free Files by Google app from the Google Play Store (search exactly “Files by Google” and check that the publisher is Google LLC). Open it, tap Browse > Downloads, select the ZIP, then choose Extract. On Samsung, the built-in My Files app can usually extract ZIPs without another download. If this Word guide will not open, install Microsoft Word or Google Docs from the Play Store to read the .docx file.')
    heading(doc, '2  Install the Android APK')
    steps(doc, [
        'In My Files / Files, open your extracted folder and tap ' + apk + '.',
        'If Android says installation is not allowed from this source, tap Settings. Allow “Install unknown apps” for the file-manager app you used (My Files or Files). Some phones show Settings > Apps > Special access > Install unknown apps.',
        'Return to the APK and tap Install. When it finishes, tap Open or find ' + app_name + ' on your home screen.',
        'For safety, turn off “Allow from this source” again after installation. Only install an APK obtained from your own trusted GitHub build; do not disable Play Protect or ignore a harmful-app warning.',
    ])
    note(doc, 'Updating later:', 'The same edition can normally install over an older version when its app ID and signing key match. Professional and Full are separate apps; their saved data does not automatically transfer between them.')

    doc.add_page_break()
    doc.add_heading('Using ' + app_name, level=1)
    add_text(doc, 'Quick steps for the main screens. Start on Kitchen Home; use the bottom navigation or menu cards to open a tool. The back arrow returns to Kitchen Home.')
    heading(doc, '3  Everyday cooking tools')
    steps(doc, [
        'Find Recipes: type a dish or ingredient, search, then open a recipe. If you have no internet, browse Offline Recipes (18 built-in recipes).',
        'My Cookbook: open or search your saved recipes. Choose Add Recipe to write your own, paste a recipe link, or use Android Share from a recipe website.',
        'Shopping List: add groceries manually or from recipes; tap an item to check it off while shopping.',
        'Cook With What I Have: enter ingredients you already own to see recipe ideas. Ingredient Alternatives suggests substitutes.',
        'Find Ingredient: type an ingredient, select 2, 5, 10, 20, 30, or 50 km, then tap Find stores. Allow location access when asked. The store list depends on public directory coverage and may be incomplete.',
        'If store results time out, try 5 or 10 km, use See grocery stores on Google Maps, or tap Look for this ingredient at retailers. Store listings do not guarantee that the ingredient is in stock.',
        'Options > Backup & Restore: save your recipes and shopping list as a JSON backup or restore a previously saved one. Store backup files somewhere safe.',
    ])
    if is_full:
        heading(doc, '4  Full edition: Marijuana Cookbook')
        steps(doc, [
            'The Marijuana Cookbook is hidden from Kitchen Home. Open Options (gear icon) and tap Private Cookbook.',
            'The first time, set a password with at least 8 characters, enter it again to confirm, and keep a private record. The app cannot recover a forgotten password.',
            'On later visits, open Options > Private Cookbook and enter your password to unlock it.',
            'Inside, choose Add marijuana recipe to save an infused recipe, or Private Shopping List for ingredients in that collection.',
            'Leaving the protected collection or putting the app in the background locks access again. Return through Options and enter your password to reopen it.',
        ])
        note(doc, 'Privacy and safety:', 'The password gates access in the app, but exported JSON backup files are not encrypted. Keep backups private. Clearly label infused foods, store them securely away from children and pets, and follow local law.')
    else:
        heading(doc, '4  About this edition')
        add_text(doc, 'Professional includes the everyday cooking tools listed above. It is intended for general-purpose and workplace-friendly use.')
        note(doc, 'Your data:', 'Saved recipes and grocery items stay in this app’s storage on your phone. Back them up before changing phones or uninstalling. JSON backup files are not encrypted.')
    heading(doc, 'Need help?')
    add_text(doc, 'If an APK will not install, check you extracted the ZIP first and tapped the .apk (not the .docx). If the ingredient finder reports an error, verify phone Location and internet, then retry a smaller radius. Report the error message and your edition to the Recipe Haven development chat.')
    doc.save(file)
    print(file)


def main():
    dest = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('release-test')
    dest.mkdir(parents=True, exist_ok=True)
    for edition in ('Professional', 'Full'):
        generate(dest, edition)


if __name__ == '__main__':
    main()
