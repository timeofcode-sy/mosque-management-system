/// Digits stay Latin (0-9) everywhere in Nuzuln: web, apps and print. The v3 guide recommends
/// Arabic-Indic digits in print; the product decision overrides it, so this is a pass-through kept
/// only so every number still goes through one place if the decision ever changes.
///
/// Phone numbers and IDs stay in a left-to-right span; do not rely on this for them.
String nzDigits(Object value) => value.toString();
