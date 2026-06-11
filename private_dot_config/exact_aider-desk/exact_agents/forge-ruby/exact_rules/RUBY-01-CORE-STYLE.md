# Ruby Rule: Core Style

When writing or modifying Ruby code, follow idiomatic Ruby. Defer to the project's `.rubocop.yml` for anything where conventions differ.

## Principles

- Prefer clarity over cleverness. Ruby's expressiveness is a feature only when it makes intent obvious.
- Match the project's existing Ruby version (`.ruby-version`, `Gemfile`). Do not use 3.x-only syntax in a 2.7 codebase.
- Match the project's existing test framework, ORM, and HTTP framework. Do not introduce parallel patterns.

## File header

- Every `.rb` file starts with `# frozen_string_literal: true` unless the project's `.rubocop.yml` explicitly disables it.
- Encoding magic comments are unnecessary on Ruby 2.x+.

## Naming

- Methods and variables in `snake_case`.
- Classes and modules in `CamelCase`.
- Constants in `SCREAMING_SNAKE_CASE`.
- Predicate methods (returning boolean) end in `?`: `empty?`, `valid?`, `admin?`.
- Mutating ("bang") methods end in `!`: `save!`, `compact!`. A bang method either mutates *or* raises; a non-bang sibling that returns nil is the safe form.
- Private setter convention: name with leading underscore only when there's no public sibling.

## Strings

- Single quotes for plain literals; double quotes when interpolating. Both work; pick one per file.
- Heredocs with `<<~` (squiggly) for indented multi-line strings — `<<~SQL` / `<<~MSG` end labels are useful.
- Avoid `String#+` chains for more than two pieces; use `String#format` (`"%s %d" % [name, count]`), `Kernel#format`, or interpolation.

## Blocks

- `{ ... }` for one-line blocks. `do ... end` for multi-line.
- Prefer block-passing forms (`&:upcase`, `&method(:foo)`) when the block is a single method call.
- Use `each_with_object` instead of `inject({})` when accumulating into an object you don't reassign:
  ```ruby
  arr.each_with_object({}) { |item, h| h[item.id] = item.name }
  ```

## Control flow

- Prefer guard clauses over deep nesting:
  ```ruby
  return :ok if condition?
  return :no if other?
  do_work
  ```
- Prefer `if` over `unless` for negated conditions with `else`. `unless x` reads fine; `unless x ... else` does not.
- `case` over chained `if/elsif/elsif/elsif`. Use `in` patterns (Ruby 3.0+) for destructuring.

## Methods

- Keep methods short (≤ ~15 lines). Multi-paragraph methods usually want to be split.
- Use keyword arguments for non-obvious parameters: `def call(user:, force: false)`.
- Use `**` for forwarding unknown keyword args; don't pass `options = {}` style.
- Avoid `define_method` outside of explicit metaprogramming concerns — it hurts grep and stack traces.

## Classes and modules

- Use `attr_reader` / `attr_accessor` for trivial accessors. Defining `def name; @name; end` by hand is noise.
- `private` and `protected` go on their own line; everything below applies until the next visibility line.
- One class per file. Match the file name to the class: `app/models/user.rb` contains `User`.
- Constants at the top of the class, then `include`/`extend`, then `attr_*`, then `initialize`, then public methods, then `private`.

## Hashes

- Symbol keys are the default: `{ name: "alice", age: 30 }`.
- String keys when interfacing with JSON / external data.
- Use `Hash#dig` for nested lookups when absent keys are valid: `payload.dig(:user, :address, :city)`.

## Exceptions

- `raise SomeError, "message"` — never raise strings or generic `StandardError`.
- Rescue specific classes, not bare `rescue`. Bare `rescue` swallows `Interrupt` and `NoMemoryError` and is almost always wrong.
- `ensure` for cleanup that must run; `rescue => e` for "log + continue."
- Define your own error classes inheriting from `StandardError`, grouped under a project namespace: `class App::ValidationError < StandardError`.

## Don't monkey-patch stdlib

- Adding methods to `String`, `Array`, `Hash`, `Object`, etc., is almost always wrong outside of a clearly-namespaced refinement or a project-wide policy.
- If you genuinely need to extend a stdlib type, use `Refinement`s and scope them to the calling module.

## Tooling

- `bundle exec rubocop` clean before commit (or `rubocop -a` for safe autocorrects).
- `bundle exec rubocop --fix-layout` only when the layout drift is intentional.
- `bundle install --frozen` in CI to fail on Gemfile.lock drift.

## Examples

### Good

```ruby
# frozen_string_literal: true

module Reports
  class MonthlyTotals
    DEFAULT_LIMIT = 100

    def initialize(account:, month:)
      @account = account
      @month = month
    end

    def call
      return :no_account unless @account
      return :no_data if entries.empty?

      build_totals
    end

    private

    attr_reader :account, :month

    def entries
      @entries ||= account.entries.for_month(month).limit(DEFAULT_LIMIT)
    end

    def build_totals
      entries.each_with_object({}) do |entry, totals|
        totals[entry.category_id] ||= 0
        totals[entry.category_id] += entry.amount_cents
      end
    end
  end
end
```

### Bad

```ruby
# no frozen literal, bare rescue, deep nesting, monkey-patch:
class Hash
  def total
    values.sum
  end
end

class Reports::MonthlyTotals
  def initialize(account, month)
    @account = account; @month = month
  end

  def call
    if @account
      if @account.entries.for_month(@month).any?
        totals = {}
        @account.entries.for_month(@month).each do |entry|
          if totals[entry.category_id]
            totals[entry.category_id] += entry.amount_cents
          else
            totals[entry.category_id] = entry.amount_cents
          end
        end
        return totals
      else
        return :no_data
      end
    else
      return :no_account
    end
  rescue
    nil
  end
end
```
