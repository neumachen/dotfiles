# Ruby on Rails Rule: Conventions

When working in a Rails app, follow Rails-the-omakase conventions before reaching for patterns from other frameworks.

If active record queries are involved, also load the `RUBY-03-ACTIVERECORD-EFFICIENCY` rule — efficiency concerns get their own treatment.

## Match the project

- Match the Rails version (`Gemfile`, `config/application.rb`). Rails 7.1, 7.2, 8.0 each have distinct defaults — do not import a Rails-8 pattern into a Rails-6 codebase.
- Match the existing testing framework (RSpec vs Minitest), background job adapter (Sidekiq vs Solid Queue vs GoodJob), and asset pipeline (Sprockets vs Propshaft vs Vite Rails) without mixing.

## File layout

A standard Rails app has, roughly:

- `app/controllers/` — request handlers, thin.
- `app/models/` — Active Record models. Validations, associations, scopes.
- `app/views/` — ERB/HAML templates.
- `app/helpers/` — view helpers only. Do not put domain logic here.
- `app/jobs/` — Active Job classes. One job per file, named `*Job`.
- `app/mailers/` — Action Mailer classes.
- `app/services/` or `app/operations/` — service objects (see below). Project may use either name; match what's already there.
- `app/policies/` — Pundit or similar authorization policies.
- `app/components/` — ViewComponent (if used).
- `lib/` — code reused across projects, or things not yet ready to be promoted to a gem.
- `config/initializers/` — one-shot setup at boot.

## Controllers

- Thin. Controllers parse params, call domain code, render. Anything more belongs in a model, job, service, or query object.
- Use `before_action` for cross-action setup (e.g., loading the current record).
- Strong parameters always. Whitelist the permitted keys explicitly:
  ```ruby
  def user_params
    params.require(:user).permit(:name, :email, :role)
  end
  ```
- Avoid `params.permit!` outside of admin contexts where the consequence is understood.
- For nested attributes, `permit(addresses_attributes: [:id, :street, :city, :_destroy])`.
- Render JSON via serializers (JBuilder, Active Model Serializers, Alba, Blueprinter) — not by hand from controller actions.

## Routes

- RESTful routes by default: `resources :users`. Custom verbs only when REST genuinely does not fit.
- Use `namespace :admin do ... end` for admin sections; use `scope module: :admin` only when the URL should not include `/admin`.
- Constraint blocks for API versioning: `namespace :api do; namespace :v1 do; ...; end; end`.
- Wildcard routes (`get '/*path'`) at the bottom only, and only for SPAs/legacy redirects.

## Models

- Validations first, then associations, then scopes, then callbacks, then class methods, then instance methods.
- Avoid callbacks for cross-aggregate side effects. `after_create :send_welcome_email` is a footgun when you import 10,000 users via `insert_all`. Use service objects or jobs instead.
- Use `enum status: { draft: 0, published: 1, archived: 2 }` for finite state — gets you scopes (`User.published`) and predicate methods (`user.published?`) for free.
- Use `scope :active, -> { where(deleted_at: nil) }` for query reuse. Scopes return relations and chain; class methods may not.
- Concerns are for genuinely cross-cutting reuse (e.g., `Trashable` for soft-delete), not for "this model is getting long, let me extract it." Long models often want **service objects** instead.

## Service objects / operations

Single-responsibility, single-public-method, callable objects:

```ruby
class Users::Register
  Result = Data.define(:user, :errors)

  def self.call(...) = new(...).call

  def initialize(email:, name:, role: 'user')
    @email = email
    @name = name
    @role = role
  end

  def call
    user = User.new(email: @email, name: @name, role: @role)
    return Result.new(user: nil, errors: user.errors) unless user.save
    Notifications::Welcome.deliver_later(user)
    Result.new(user: user, errors: nil)
  end
end
```

- One verb per class. `Users::Register`, `Orders::Charge`, `Reports::Build`.
- Return value is a `Result` (Data class or Dry::Monads), not the model. Callers know what to handle.
- No `ApplicationService` base class with magic shared behaviour — keep them flat.

## Jobs

- One job per file, named `<Verb>Job`: `WelcomeEmailJob`, `RefreshSearchIndexJob`.
- `perform` takes IDs and minimal primitives, not Active Record objects (objects may be deleted by the time the job runs):
  ```ruby
  def perform(user_id)
    user = User.find_by(id: user_id) or return
    ...
  end
  ```
- Idempotent. Run-twice-without-effect is the goal. Use a unique constraint or `Rails.cache.write(..., unless_exist: true)` for guards.
- `retry_on` / `discard_on` with explicit exception classes. No bare `rescue` swallowing.

## Migrations

- One concept per migration. Don't pile `add_column`, `add_index`, and `add_foreign_key` on three different tables into one file.
- Migrations are append-only. Never edit a migration that's been deployed.
- Reversible by default: use `change` with `change_column`/`reversible` blocks. Use `up`/`down` only when truly irreversible.
- For PostgreSQL `add_index :concurrently => true`. Disable migration transactions for that:
  ```ruby
  class AddIndexConcurrently < ActiveRecord::Migration[7.1]
    disable_ddl_transaction!
    def change
      add_index :users, :email, algorithm: :concurrently, unique: true
    end
  end
  ```
- Use `validate_check_constraint` / two-step constraint adds for large tables — don't lock prod for minutes.

## Mailers

- `ApplicationMailer` parent. Use `deliver_later` everywhere; `deliver_now` only in tests or sync workflows.
- Templates under `app/views/<mailer_name>/<action>.{html,text}.erb` with both formats.
- I18n-ready: `t('.subject')` over hardcoded strings.

## Caching

- Use `Rails.cache.fetch(key, expires_in: 5.minutes) { ... }` for memoizing expensive computations.
- Cache keys must include the schema version (`cache_key_with_version`) for Active Record objects.
- Russian-doll caching for fragment caches: `cache [user, posts]`.
- Never cache PII or auth tokens.

## Background jobs vs synchronous

Rule of thumb:

- Send email, SMS, push: job.
- Generate reports, exports, large queries: job.
- Refresh search index, denormalized cache: job.
- Save a record, validate, return the result to the user: synchronous.

## Tooling

- `bin/rails db:prepare` (idempotent setup) in CI before tests.
- `bin/rails zeitwerk:check` on Rails 6+ to catch autoload issues.
- `bundle exec rubocop` and `bundle exec brakeman` clean before commit.
- `bin/rails routes -g <name>` to grep route table.

## Anti-patterns

- Fat controller (anything > ~10 lines per action is suspect).
- God model (1000+ lines of callbacks and concerns).
- Callbacks doing cross-aggregate work (use jobs or services).
- `User.all.each` (use `find_each` or batched processing).
- N+1 (see `RUBY-03-ACTIVERECORD-EFFICIENCY`).
- Calling `params` deep inside a model or service (it's request state — bind it at the boundary).
