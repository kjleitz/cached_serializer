# CachedSerializer

A serializer for Rails models that prevents unnecessary lookups.

## Usage

The following example serializes a `User` model. By using certain macros, the
author can specify what values should be cached or recomputed when serializing
a model record. Serialized data is cached via `Rails.cache` (by the User's `id`
and specified attribute keys) so the serializer doesn't have to hit the DB for
every attribute. This can be desirable when some of the serialized data involves
long-running queries, relationship-heavy calculations, etc.

```rb
class UserSerializer < CachedSerializer::Base
  # Properties specified by `::columns` are called as-is on the model, and
  # invalidated automatically when the model is saved with new values for these
  # properties, by checking Rails' built-in `#email_changed?`/`#phone_changed?`
  # /etc. dynamic methods on save. Allows you to serialize most simple straight-
  # from-the-DB values without any extra effort.
  columns :email, :phone

  # Properties specified by `::constant` are are attributes that should never
  # need to be recomputed. They will be cached ad infinitum (until the cache key
  # is cleared, manually or otherwise).
  #
  # This will call `some_user.id` for the `:id` attribute, and
  # `some_user.created_at` for the `:created_at` attribute. Consider the values
  # for each to be cached FOREVER, and never recomputed.
  constant :id, :created_at

  # Alternatively, you can pass a block to `::constant`. This will use the
  # result of the block as the value for the `:name` attribute. It will cache
  # the value FOREVER, and never recompute it.
  constant :name do |user|
    "#{user.first_name} #{user.last_name}"
  end

  # Properties specified by `::volatile` are attributes that should always be
  # recomputed every time a user is serialized, and will never be cached.
  #
  # This will call `some_user.token` for the `:token` attribute, and
  # `some_user.updated_at` for the `:updated_at` attribute. It will ALWAYS
  # recompute the values, EVERY time it serializes a user.
  volatile :token, :updated_at

  # Alternatively, you can pass a block to `::volatile`. This will use the
  # result of the block as the value for the `:time_on_platform` attribute. It
  # will ALWAYS recompute the value, EVERY time it serializes a user.
  volatile :time_on_platform do |user|
    Time.zone.now.to_i - user.created_at.to_i
  end

  # Properties specified by `::computed` are attributes that should either be
  # recomputed by the given block or drawn from the cache based on rules that
  # you specify.
  #
  # You can specify columns that it depends on, such that when any of the
  # columns change it will invalidate the cache for this serialized property. In
  # this case, `:address` will only be recomputed when any of the supplied
  # attributes (`:address_1`, `:address_2`, `:city`, etc.) change on the user
  # record.
  computed :address, columns: [:address_1, :address_2, :city, :state, :zip] do |user|
    "#{user.address_1} #{user.address_2}, #{user.city}, #{user.state} #{user.zip}"
  end

  # You can also specify a `:recompute_if` proc/lambda. It will run
  # `:recompute_if` every time a model is being recomputed, and if it returns
  # `true` then it will recompute. Otherwise, it will use the cached result.
  computed :active, recompute_if: ->(u) { u.last_logged_in_at > 1.week.ago } do |user|
    user.purchases.where(created_at: 1.week.ago..Time.zone.now).present?
  end

  # Additionally, you can specify an `:expires_in` expiration duration. This
  # will cache the result for one day after the last time the
  # `:revenue_generated` attribute was recomputed.
  computed :revenue_generated, expires_in: 1.week do |user|
    user.offers.accepted.reduce(0) { |total, offer| total + offer.total_price }
  end

  # You can use any number of these cache conditions with `:compute`. For
  # example, this will cache the result until `:foo` changes on the user, `:bar`
  # changes on the user, `u.silly?` is `true` at the time of serialization, or
  # it has been more than 10 seconds since the last time the `:silly` attribute
  # was recomputed.
  computed :silly, columns: [:foo, :bar], recompute_if: ->(u) { u.silly? }, expires_in: 10.seconds do |user|
    rand(100)
  end
end
```

## Installation

Add this line to your application's `Gemfile`:

```ruby
gem 'cached_serializer'
```

Then `cd` into your project's directory and run:

```bash
bundle install
```

## Bug reports

If you encounter a bug, you can report it [here](https://github.com/kjleitz/cached_serializer/issues). Please include the following information, if possible:

- your Ruby version (`ruby --version`; if using multiple Rubies via `rvm` or similar, make sure you're in your project's directory when you run `ruby --version`)
- your Rails version (`cd` into your project's directory, then `bundle exec rails --version`)
- example code (which demonstrates the issue)
- your soul (for eating)

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/kjleitz/cached_serializer](https://github.com/kjleitz/cached_serializer).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
