# Translations

The KCM and standalone `framework-settings` application use KI18n with the
translation domain `kcm_framework` and follow the user's language. They share
Dutch, German, Spanish and French translations in `po/<lang>/kcm_framework.po`.
These are **machine translations that still need review by native speakers**;
corrections are welcome.

Two things aren't translated through gettext and are edited by hand:

- the System Settings name and description (`Name[xx]` and
  `Description[xx]` in `kcm/kcm_framework.json`)
- the polkit password prompts (`xml:lang` entries in
  `data/io.github.frameworkkcm.policy`)

Error messages that come from the daemon itself stay in English, since a
root system service doesn't know the user's language.

## Updating after changing strings

Re-extract the template and merge it into every language (needs gettext):

```sh
po/update.sh
```

CI warns if `po/` is out of date.

## Adding a language

1. Copy `po/kcm_framework.pot` to `po/<lang>/kcm_framework.po`.
2. Fill in the header (`Language`, `Plural-Forms`, translator) and translate
   the strings.
3. Check it with `msgfmt --check --statistics -o /dev/null po/<lang>/kcm_framework.po`.
4. Add `Name[<lang>]` and `Description[<lang>]` to `kcm/kcm_framework.json`,
   and `xml:lang="<lang>"` entries to the polkit policy.

`ki18n_install(po)` in `CMakeLists.txt` picks up the new language on the
next build.

## Trying a language

```sh
LANGUAGE=de kcmshell6 kcm_framework
```
