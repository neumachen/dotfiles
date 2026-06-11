# RSpec Rule: Conventions

When writing RSpec tests, prioritize **clarity of what the test asserts** over brevity. A failing test in CI should tell future-you what broke and why without needing to re-read the code under test.

## File layout

- `spec/<mirror of app>/**/<file>_spec.rb`. A class at `app/models/user.rb` is tested in `spec/models/user_spec.rb`.
- One `<class>_spec.rb` file per production class.
- Shared examples in `spec/support/shared_examples/`, autoloaded via `Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }` in `rails_helper.rb`.
- Test types follow the project's existing directory convention: `spec/requests/` (request specs), `spec/features/` or `spec/system/` (system specs), `spec/models/`, `spec/services/`, `spec/jobs/`.

## Structure

```ruby
RSpec.describe User do
  describe '#full_name' do
    context 'when first and last name are present' do
      let(:user) { build(:user, first_name: 'Alice', last_name: 'Liddell') }

      it 'concatenates them with a space' do
        expect(user.full_name).to eq('Alice Liddell')
      end
    end

    context 'when last name is blank' do
      it 'returns only the first name' do
        expect(build(:user, first_name: 'Cher', last_name: nil).full_name).to eq('Cher')
      end
    end
  end
end
```

Rules:

- Top-level `describe` is the class under test.
- Nested `describe` for the method, prefixed with `#` for instance methods, `.` for class methods: `describe '#save'`, `describe '.find_by_email'`.
- `context` for branch/state. `context 'when X'`, `context 'with Y'`, `context 'without Z'`.
- One assertion concept per `it`. Multiple `expect` calls within one `it` are fine **if they describe one behaviour**; if they describe two, split into two `it`s.

## `let`, `let!`, `before`, `subject`

| Construct | Lazy? | Persists? | Use for |
|---|---|---|---|
| `let(:x) { ... }` | Yes — first access | No (memoized per example) | Inputs that may or may not be used |
| `let!(:x) { ... }` | No — runs before each example | Yes | Records that **must exist** for the example to make sense (e.g., other records in the DB) |
| `before { ... }` | No | Yes | Side effects (stubs, config) that don't produce a value |
| `subject` (implicit/explicit) | Yes | No | The thing under test |

```ruby
describe User do
  let(:user)    { create(:user, role: 'admin') }
  let!(:other)  { create(:user, role: 'user') }      # forces creation so .where_not_self counts it
  subject(:admins) { described_class.admins }

  it 'returns only admin users' do
    expect(admins).to contain_exactly(user)
  end
end
```

- Use `let!` sparingly — it disables the lazy-evaluation that makes `let` cheap. If half the file is `let!`, you probably want `before`.
- Use explicit `subject(:name)` over implicit `subject` when there's more than one thing under test in the file.

## Factories (factory_bot)

- Factory per model: `spec/factories/users.rb`.
- Sensible defaults — every factory generates a valid record without arguments.
- Use **traits** for variation, not separate factories:
  ```ruby
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { 'Default Name' }

    trait :admin do
      role { 'admin' }
    end

    trait :with_posts do
      transient { post_count { 3 } }
      after(:create) { |u, ev| create_list(:post, ev.post_count, user: u) }
    end
  end
  ```
- Prefer `build` to `create` when persistence isn't needed.
- Prefer `build_stubbed` to `build` when you don't need callbacks/validations to run — it's much faster.
- Never call `User.create` directly in a test if a factory exists.

## Assertions

- `expect(x).to eq(y)` — value equality (`==`). Default for primitives.
- `expect(x).to be == y` — same; rarely chosen.
- `expect(x).to be(y)` — object identity (`equal?`). Use for `true`/`false` from predicates.
- `expect(x).to match(...)` — regex or matcher.
- `expect(arr).to contain_exactly(a, b)` — order-independent, exact membership.
- `expect(arr).to match_array([a, b])` — same, less idiomatic.
- `expect(arr).to include(a)` — partial membership.
- `expect(hash).to include(key: value)` — partial key/value match.
- `expect { ... }.to change { count }.by(1)` — state delta.
- `expect { ... }.to raise_error(SpecificError, /message/)` — exception assertions specify the class **and** the message.
- `expect(x).to be_present` / `be_blank` / `be_admin` — predicate-method matchers.

Avoid:

- Bare `expect(x).to be_truthy` when you mean `eq(true)`. Falls in the "what does this assert exactly?" trap.
- `expect { ... }.to raise_error` without specifying which error.
- `expect(x).to be_a(Hash)` *and* `.to include(...)` in the same example — `include` already implies it's a hash.

## Mocking discipline

- **Mock at the boundary, not inside.** A test for `OrdersController` mocks the payment gateway, not `Order.save`.
- `instance_double(Class, method: value)` — verified double, will fail if the class doesn't actually have the method. Always prefer over plain `double`.
- `allow(...)` for "this is necessary plumbing"; `expect(...).to receive(...)` only when "this call is the behaviour under test."
- Don't mock the system under test. If you find yourself mocking the class you're testing, the test is wrong.
- Don't mock value objects (`Money`, `Date`, etc.) — instantiate them.

```ruby
# GOOD — mock the external gateway:
let(:gateway) { instance_double(Stripe::Gateway, charge!: stripe_response) }
before { allow(Stripe::Gateway).to receive(:new).and_return(gateway) }

it 'charges the gateway' do
  Orders::Charge.call(order: order)
  expect(gateway).to have_received(:charge!).with(amount: 1000, currency: 'usd')
end
```

## Test types

| Type | Speed | Tests |
|---|---|---|
| Unit (`spec/models`, `spec/services`) | fast | One class. Heavy mocking of collaborators. |
| Request (`spec/requests`) | medium | Full Rails stack from `get/post/put/delete` through to JSON response. No JS. |
| System (`spec/system`) | slow | Browser-driven (Capybara + Cuprite or Selenium). Use for JS-driven flows only. |
| Feature (`spec/features`) | deprecated | Use system specs. |

Hierarchy:

- Unit specs cover the **logic**.
- Request specs cover the **integration** of controller + serializer + auth.
- System specs cover the **happy path of multi-step user flows** — sparingly. They are slow and brittle.

Do not write a system spec for something a request spec can cover.

## Hooks

- `before(:each)` (the default) — most setup.
- `before(:all)` — only for genuinely expensive read-only setup. Cleans up nothing automatically — be careful with the DB.
- `around` for wrapping each example in a transaction-like block: `around { |ex| Timecop.travel(2024) { ex.run } }`.
- Hooks in `spec/support/` files via `config.include`/`config.before` apply globally — use sparingly.

## Time and randomness

- Freeze time with `freeze_time` (Active Support) or `Timecop.freeze`. Always restore.
- Stub `SecureRandom.uuid` if your assertion compares UUIDs.
- Tests must be deterministic. If a test ever passes only sometimes, fix the flake immediately or skip it with a tracked issue.

## Database cleanup

- The Rails default (`use_transactional_fixtures = true`) handles 99% of cases.
- For system specs that hit a real browser process, use `database_cleaner-active_record` with strategy `:truncation` (or `:deletion` for tables with FKs).
- Configure once in `rails_helper.rb`; don't sprinkle `DatabaseCleaner.clean` in individual specs.

## Performance

- `--profile` flag in CI to surface slow examples.
- `--fail-fast` for local iteration.
- Use `build_stubbed` over `create` wherever possible.
- Avoid `create` in `let` if the example doesn't need the record persisted.
- Avoid `let!` blocks that run on every example in a file when only some examples need the side effect — push them into the relevant `context`.

## Tooling

- `bin/rspec` (or `bundle exec rspec`) — the runner.
- `bundle exec rspec --tag focus` with `config.filter_run_when_matching(:focus)` for iterating on one test.
- `bundle exec rspec --next-failure` to re-run only the next failing example.
- Shared `spec_helper.rb` (framework-only) is required by `rails_helper.rb` (Rails-aware). Tests that don't need Rails (`spec/lib/...`) require only `spec_helper`.

## Examples

### Good — a service spec

```ruby
require 'rails_helper'

RSpec.describe Users::Register do
  let(:gateway) { instance_double(Notifications::Welcome, deliver_later: true) }

  before { stub_const('Notifications::Welcome', class_double(Notifications::Welcome, deliver_later: true)) }

  describe '.call' do
    context 'with valid params' do
      it 'creates the user and queues the welcome email' do
        result = described_class.call(email: 'alice@example.com', name: 'Alice')

        expect(result.user).to be_persisted
        expect(result.errors).to be_nil
        expect(Notifications::Welcome).to have_received(:deliver_later).with(result.user)
      end
    end

    context 'with invalid email' do
      it 'returns errors and no user' do
        result = described_class.call(email: 'not-an-email', name: 'Alice')

        expect(result.user).to be_nil
        expect(result.errors[:email]).to include(/invalid/)
        expect(Notifications::Welcome).not_to have_received(:deliver_later)
      end
    end
  end
end
```

### Bad

```ruby
# Vague description, multiple unrelated assertions, mocking the system under test:
describe Users::Register do
  it 'works' do
    allow(described_class).to receive(:call).and_return(double(user: double(persisted?: true)))
    result = described_class.call({})
    expect(result.user.persisted?).to eq(true)
    expect(User.count).to be > 0
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end
end
```
