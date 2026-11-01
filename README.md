# idiomatic-rails

Deterministic checks that a Rails application uses Rails, instead of
reimplementing it.

Three RuboCop cops and one cross-file dead-code check. Every rule fires on
a **shape**, not on a smell: it can be decided by reading the syntax tree, it
has a single obvious correction, and it is argued for below with the case it
was extracted from.

That constraint is the point. A style guide is advice that a hurried
contributor — or a coding agent, which is hurried by construction — reads
once and then writes `count == 1 ? "entry" : "entries"` anyway. A check is
not advice.

## Install

```ruby
# Gemfile
gem "idiomatic-rails", require: false
```

```yaml
# .rubocop.yml
plugins:
  - idiomatic-rails
```

And, for the dead-code check, in CI:

```bash
bundle exec idiomatic-rails-dead-code
```

## The cops

### `IdiomaticRails/HandRolledPluralization`

Picking a singular or plural word by branching on a count.

```ruby
# bad
count == 1 ? "entry" : "entries"
"#{count} day#{'s' unless count == 1}"
if count == 1 then " (1 business day)" else " (#{count} business days)" end

# good
"entry".pluralize(count)
" (#{count} #{'business day'.pluralize(count)})"
```

The oracle is **ActiveSupport's own inflector** — the same one the correction
uses, and the same one your `inflections.rb` configures. So the cop cannot
demand a fix the inflector would not make: `count == 1 ? "sheep" : "sheep"`
is not reported, because `.pluralize` would not change it either.

Comparing against `1` is what makes a conditional a *count* branch. Without
that test, `status == :draft ? "draft" : "published"` would be an offense.

The reason to prefer the inflector is not tidiness. A hand-written branch is
correct until someone counts a `person`, an `analysis` or a `datum`.

### `IdiomaticRails/InlineStrftime`

A date format written at the call site.

```ruby
# bad
date.strftime("%b %-d")

# good
Date::DATE_FORMATS[:month_day_short] = "%b %-d"   # once, in an initializer
date.to_fs(:month_day_short)                      # everywhere
```

A format written inline is a format that will be written again, slightly
differently, in the next view — which is how one screen comes to say "Aug 5"
and the next "August 05".

Only a literal is reported: `date.strftime(format)` passes, because the
format is already a value somebody named. The default config excludes
migrations, rake tasks, scripts and specs, where a one-off is usually the
honest answer.

### `IdiomaticRails/ManualToSentence`

Building prose out of a list by hand.

```ruby
# bad
names.join(" and ")
parts.join(", and ")

# good
names.to_sentence
```

`to_sentence` handles the two-item case (no comma), the Oxford comma, the
empty list and the locale. A `join` handles none of them, and each gets
discovered one bug at a time.

Only a separator containing the standalone word "and" is reported.
`join(", ")` is a delimiter, and a delimiter is not prose.

## The dead-code check

`bundle exec idiomatic-rails-dead-code` fails when a method or constant
defined under `app/` or `lib/` is reached from nowhere but your tests.

**The signal is deliberately not coverage.** A dead method keeps its spec, so
it stays covered. The method this was extracted from was exercised by an
example asserting its return value right up to the commit that deleted it,
and the project's coverage floor never moved. What marks code dead is that
*only* the test suite reaches it.

**It parses rather than greps**, with Prism, and that is not a detail. In the
application it came from, a careful word-boundary grep sweep pronounced the
tree clean; the parser then found three more dead methods in it. One was
invisible to grep because `compute_for_member` contains `for_member`. Another
because `total_minutes:` appears as a hash key throughout the app.

Views are compiled with **ActionView's own Erubi subclass** — not plain
Erubi, which cannot compile the `<%= … do %>` block form — and parsed like
any other source, so a helper called only from a template needs no exemption.

### It refuses to be quietly unsound

Two cases abort or fail rather than guess:

- **A name computed at runtime.** `send(route_helper)` can reach anything, so
  each such call site must be recorded with what it actually targets. A new
  one fails the run.
- **An application that will not boot.** Routed actions and callback macros
  are read from the running application, so a failed boot raises. Treating an
  unreadable router as "nothing is routed" would report every action as dead.

### It asks Rails rather than guessing

Two facts come from the booted application, on one `bin/rails runner` call
that needs no database:

- **Which actions are routed**, from `Rails.application.routes.routes`.
  Parsing `config/routes.rb` cannot keep up with the DSL — `patch :publish,
  on: :member`, `member do`, concerns, mounted engines — and every spelling a
  reader misses reports a live action as dead. The expanded table also
  carries the controller, so a dead `show` is not exempted because a
  *different* controller routes a `show`.
- **Which macros name a method with a symbol**, from
  `ActiveRecord::Callbacks::CALLBACKS` and `ActiveRecord::Transactions::ACTIONS`.
  A hardcoded list had `before_validation` and not `before_create`, so one
  callback in a model was understood and the next was reported dead.

### Configuration

Optional, in `.idiomatic-rails.yml` at the application root:

```yaml
dead_code:
  definition_paths: [app, lib]
  reference_paths: [app, lib, config, bin, Rakefile]
  template_paths: [app/views]
  test_paths: [spec, test]
  routes_file: config/routes.rb
  exemptions:
    # Definitions nothing in the repository calls, because something outside
    # it does. Meant to stay empty: an entry is an admission, not a
    # resolution, so name the caller rather than writing "seems used".
    exempt:
      - name: on_if
        reason: RuboCop dispatches on_<node type> by name while walking the AST.
    computed_dispatch:
      - file: app/controllers/concerns/period_navigation.rb
        reason: send(route_helper) targets router-generated path helpers.
```

**Both lists fail in both directions.** An exemption that stops being needed
is as red as a new finding, because a file of forgiven names nobody rechecks
is how this kind of gate rots.

### What it cannot see

- Dead code still called by other dead code. The cluster's entry point is
  reported; the rest surfaces on the next run.
- Anything that is not a method or a constant: unread hash keys, unused
  parameters, unreachable branches.

### Why not debride

[debride](https://github.com/seattlerb/debride) is the established tool and
it works — on the application this was extracted from it found all three dead
methods. Measured there:

| | reports | real |
| --- | --- | --- |
| `debride app lib` | 35 | 3 |
| `debride --rails` | 32 | 3 |
| `debride --rails` with pre-compiled views | 31 | 3 |
| `idiomatic-rails-dead-code` | 3 | 3 |

The noise is structural: debride does not parse ERB, and a Rails app's
helpers and presenters are called almost entirely from templates. Handing it
compiled views does not help — it counts the generated template methods as
dead instead. You would run it behind a thirty-name whitelist, and that
whitelist does not fail when an entry stops being needed.

If this gem ever stops earning its keep, debride plus a whitelist is the
fallback, and it does work.

## Development

```bash
bundle install
bundle exec rake        # specs and rubocop
```

## License

MIT.
