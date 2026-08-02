# Contributing Translations to MixStream

Thank you for helping localize MixStream! Our localization system is fully automated. You only need to edit or add translation files—no code changes are required.

## Where to Find Translations
All translation files are located in:
`lib/l10n/`

They are stored as `.arb` files (JSON format).

---

## How to Update an Existing Language
1. Open the file for that language (e.g., `app_hi.arb` for Hindi).
2. Find the text you want to improve.
3. Update the translation value (the text on the right side).
4. Save the file.

---

## How to Add a New Language
To add a completely new language (e.g., Spanish):

1. **Create a new file**: In `lib/l10n/`, create a file named `app_[language_code].arb` (e.g., `app_es.arb` for Spanish).
2. **Add the Identity Key**: At the very top of your new file, you **must** include the native name of the language. This allows the app to display it in the Settings menu automatically:
   ```json
   {
     "@@locale": "es",
     "languageName": "Español",
     ...
   }
   ```
3. **Copy keys**: Open `lib/l10n/app_en.arb` and copy the keys you wish to translate into your new file.
4. **Translate**: Provide the translated values for those keys.

> [!TIP]
> You don't need to translate all keys at once! Any keys you leave out will automatically fall back to the English version so the app remains functional.

---

## For Developers (Applying Changes)
If you are running the app locally and want to see your changes immediately:
1. Open your terminal.
2. Run the localization generator:
   ```bash
   flutter gen-l10n
   ```
3. Restart the app.
4. Go to **Settings > Language** and your new language will appear in the list automatically.

## Rules for Translators
- **Placeholders**: Some strings contain text in curly braces like `{count}` or `{message}`. Do **not** translate the word inside the braces, but you can move its position to fit your language's grammar.
  - *Correct*: `Viendo episodio {count}`
  - *Incorrect*: `Viendo episodio {cuenta}`
- **Native Script**: Always use the native script for the `languageName` (e.g., use "Español" instead of "Spanish" or "ಕನ್ನಡ" instead of "Kannada").
