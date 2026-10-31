# SPDX-License-Identifier: GPL-3.0-or-later

"""Source-level regression checks for the shared and standalone QML without hardware."""

from pathlib import Path
import re
import unittest


GUI_DIR = Path(__file__).resolve().parents[1]
# The pages both UIs load
SHARED_DIR = GUI_DIR.parent / "kcm" / "ui"


def post_translation_arg_calls(source: str) -> list[str]:
    """Find i18n/i18nc expressions incorrectly formatted after translation."""
    calls = []
    for match in re.finditer(r"\bi18nc?\s*\(", source):
        opening = source.find("(", match.start(), match.end())
        depth = 0
        quote = None
        escaped = False
        closing = None
        for index in range(opening, len(source)):
            char = source[index]
            if quote is not None:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
                continue
            if char in ('"', "'"):
                quote = char
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    closing = index + 1
                    break
        if closing is None:
            raise AssertionError(f"Unclosed KI18n expression near {source[match.start():match.start() + 40]!r}")
        suffix = source[closing:].lstrip()
        if suffix.startswith(".arg("):
            calls.append(source[match.start() : closing])
    return calls


def named_block(source: str, qml_type: str, object_name: str) -> str:
    """Return a QML object block selected by its objectName property."""
    marker = re.search(rf'objectName:\s*"{re.escape(object_name)}"', source)
    if marker is None:
        raise AssertionError(f"Could not find {qml_type} {object_name}")

    opening = source.rfind("{", 0, marker.start())
    header_start = source.rfind("\n", 0, opening) + 1
    header = source[max(header_start - 80, 0) : opening].strip()
    if re.search(rf"(?:^|[\s:]){re.escape(qml_type)}\s*$", header) is None:
        raise AssertionError(f"{object_name} is not a {qml_type}")

    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"Unclosed QML block for {object_name}")


class KI18nArgumentTests(unittest.TestCase):
    def test_qml_arguments_are_passed_to_translation_calls(self) -> None:
        for path in sorted([*GUI_DIR.glob("*.qml"), *SHARED_DIR.glob("*.qml")]):
            with self.subTest(qml_name=path.name, parent=path.parent.name):
                source = path.read_text(encoding="utf-8")
                self.assertEqual(post_translation_arg_calls(source), [])

    def test_formatted_labels_use_the_locale(self) -> None:
        system = (SHARED_DIR / "SystemPage.qml").read_text(encoding="utf-8")
        self.assertIn('Number(p.voltageNow / 1000).toLocaleString(Qt.locale(), "f", 1)', system)
        for path in sorted([*GUI_DIR.glob("*.qml"), *SHARED_DIR.glob("*.qml")]):
            with self.subTest(qml_name=path.name, parent=path.parent.name):
                self.assertNotIn("toFixed(", path.read_text(encoding="utf-8"))


class LocaleFormattingTests(unittest.TestCase):
    def test_overview_weekday_name_uses_locale(self) -> None:
        source = (SHARED_DIR / "OverviewPage.qml").read_text(encoding="utf-8")
        self.assertIn('nextTime.toLocaleString(Qt.locale(), "dddd")', source)
        self.assertNotIn('Qt.formatDateTime(nextTime, "dddd")', source)


class HapticSelectorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.input = (SHARED_DIR / "InputPage.qml").read_text(encoding="utf-8")

    def setting_block(self, setting: str) -> str:
        start = self.input.index(f'setting: "{setting}"')
        return self.input[start : self.input.index("]", start)]

    def test_unset_values_are_display_only(self) -> None:
        for setting in ("hapticIntensity", "clickForce"):
            with self.subTest(setting=setting):
                block = self.setting_block(setting)
                self.assertIn('unsetText: i18n("Not set")', block)
                self.assertNotIn('i18n("Not set")', block.split("model:", 1)[1])


class StalledFanTests(unittest.TestCase):
    def test_thermals_page_prefers_stalled_state_to_rpm(self) -> None:
        thermal = (SHARED_DIR / "ThermalPage.qml").read_text(encoding="utf-8")
        self.assertIn('text: modelData.stalled ? i18n("Stalled") : i18n("%1 RPM", modelData.rpm)', thermal)

    def test_overview_prefers_stalled_state_to_rpm(self) -> None:
        overview = (SHARED_DIR / "OverviewPage.qml").read_text(encoding="utf-8")
        summary = named_block(overview, "QQC2.Label", "overviewFanSummary")
        self.assertIn("backend.fans.map(fan => fan.stalled", summary)
        self.assertIn('i18n("Stalled")', summary)
        self.assertIn('i18n("%1: %2 RPM",', summary)
        self.assertLess(summary.index("fan.stalled"), summary.index("fan.rpm"))


if __name__ == "__main__":
    unittest.main()
