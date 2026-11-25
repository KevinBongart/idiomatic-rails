# Changelog

## Unreleased

### Fixed

- Three cops crashed on a string literal that is not valid UTF-8 — a binary
  payload such as `"\x00\xFF"`, which specs that exercise uploads are full
  of. A cop that *raises* does not produce a false positive, it produces a
  failed run: RuboCop reports the error, prints "no offenses detected" and
  exits 1, leaving nothing to correct and no way out but excluding the file.
  `HandRolledPluralization`, `ManualToSentence` and
  `SpecDaylightSavingAbbreviation` now skip a literal that is not text,
  because every rule that reads a literal's contents is a rule about prose
  a person reads.
- The dead-code check read a symbol passed positionally to a callback macro
  but not one passed as an option value, so `before_save :sync, if:
  :became_spam?` reported `became_spam?` as dead. `if:`, `unless:`, `with:`
  and `by:` are now read, including nested one level in, and `rate_limit`
  joins the dispatcher list. Exemptions written for this are no longer
  needed — and because an unnecessary exemption is itself an error, they
  have to be removed.

### Added

- `IdiomaticRails/DateFormatWithoutExample`: a named date format should
  carry an example of what it renders. Autocorrects by rendering the format
  at 22:04 on 5 November 1955.

## 0.1.0

First release. Extracted from a Rails application where each rule was first
written, argued for, and proven against the commit it would have caught.

- `IdiomaticRails/HandRolledPluralization`
- `IdiomaticRails/InlineStrftime`
- `IdiomaticRails/ManualToSentence`
- `idiomatic-rails-reachability`, a cross-file check for methods and
  constants nothing but the tests reach
