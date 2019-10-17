require "json"
require_relative "./attr_serializer"
require_relative "./attr_serializer_collection"

# class UserSerializer < KeegansAmazingSerializer
#   # This would cache the serialized data in Redis by the User's ID and keys
#   # based on the attributes specified, so it doesn't have to hit the DB for
#   # every attribute
# ​
#   # The cache of properties specified by `#columns` would be invalidated
#   # automatically when the model is saved with new values for these properties,
#   # by checking Rails' built-in `#email_changed?`/`#phone_changed?`/etc. dynamic
#   # methods on save. Allows you to serialize most simple straight-from-the-DB
#   # values without any extra effort
#   columns :email, :phone, :created_at
# ​
#   # If you have a "computed" property in the serializer, you could specify
#   # columns that it depends on, so when any of those columns change it would
#   # similarly invalidate the cache for this serialized property
#   computed :first_name, columns: [:first_name, :last_name] do |user|
#     "#{user.first_name} #{user.last_name}"
#   end
# ​
#   # You could also do it based on an arbitrary lambda returning a boolean,
#   # although you'd have to keep in mind that it would have to run that lambda
#   # on every serialization
#   computed :active_lyft_user, recompute_if: ->(user) { user.lyft? && user.last_logged_in_at > 1.week.ago } do |user|
#     has_recent_sr = user.service_requests.any? { |sr| sr.created_at > 1.week.ago }
#     has_recent_booking = user.offers.any? { |offer| offer.accepted_at > 1.week.ago }
#     has_recent_sr || has_recent_booking
#   end
# ​
#   # You could do it time-based, too, for properties that don't need to be super
#   # up to date
#   computed :revenue_generated, expires_in: 1.week do |user|
#     user.offers.accepted.reduce(0) { |total, offer| total + offer.total_price }
#   end
# end

# class User < ActiveRecord::Base
#   after_commit :update_serializer!, on: :save

#   def update_serializer!
#     Rails.cache.delete(some_attr_serializer.cache_key(self))
#   end
# end

module CachedSerializer
  class Base
    attr_accessor :subject

    @serializers = AttrSerializerCollection.new

    class << self
      def serializers
        @serializers
      end

      # Example (in a UserSerializer):
      #
      #   columns :email, :phone
      #
      # This will call `some_user.email` for the `:email` attribute, and
      # `some_user.phone` for the `:phone` attribute. It will cache the value
      # for each, until the attribute changes on the record.
      #
      def columns(*column_names)
        column_names.each do |column_name|
          serializers << AttrSerializer.new(column_name)
          add_column_changed_cache_invalidator_callback(column_name, column_name)
        end
      end

      # Example (in a UserSerializer):
      #
      #   constant :email, :phone
      #
      # This will call `some_user.email` for the `:email` attribute, and
      # `some_user.phone` for the `:phone` attribute. It will cache the value
      # for each FOREVER, and never recompute it.
      #
      #   volatile :name do |user|
      #     "#{user.first_name} #{user.last_name}"
      #   end
      #
      # This will use the result of the block as the value for the `:name`
      # attribute. It will cache the value FOREVER, and never recompute it.
      #
      def constant(*attr_names, &recompute)
        attr_names.each do |attr_name|
          serializers << AttrSerializer.new(attr_name, &recompute)
        end
      end

      # Example (in a UserSerializer):
      #
      #   volatile :email, :phone
      #
      # This will call `some_user.email` for the `:email` attribute, and
      # `some_user.phone` for the `:phone` attribute. It will ALWAYS recompute
      # the values, EVERY time it serializes a user.
      #
      #   volatile :name do |user|
      #     "#{user.first_name} #{user.last_name}"
      #   end
      #
      # This will use the result of the block as the value for the `:name`
      # attribute. It will ALWAYS recompute the values, EVERY time it serializes
      # a user.
      #
      def volatile(*attr_names, &recompute)
        attr_names.each do |attr_name|
          always_recompute = proc { |_subj| true }
          serializers << AttrSerializer.new(attr_name, always_recompute, &recompute)
        end
      end

      # Example (in a UserSerializer):
      #
      #   computed :name, columns: [:first_name, :last_name] do |user|
      #     "#{user.first_name} #{user.last_name}"
      #   end
      #
      # This will use the result of the block as the value for the `:name`
      # attribute. It will cache the result until either `:first_name` or
      # `:last_name` changes on the user record.
      #
      #   computed :active, recompute_if: ->(u) { u.last_logged_in_at > 1.week.ago } do |user|
      #     user.purchases.where(created_at: 1.week.ago..Time.zone.now).present?
      #   end
      #
      # This will use the result of the block as the value for the `:active`
      # attribute. It will cache the result until the `recompute_if` proc/lambda
      # returns `true`.
      #
      #   computed :purchase_count, expires_in: 1.day do |user|
      #     user.purchases.count
      #   end
      #
      # This will use the result of the block as the value for the
      # `:purchase_count` attribute. It will cache the result for one day after
      # the last time the `:purchase_count` attribute was recomputed.
      #
      #   computed :silly, columns: [:foo, :bar], recompute_if: ->(u) { u.silly? }, expires_in: 10.seconds do |user|
      #     rand(100)
      #   end
      #
      # This will use the result of the block as the value for the `:silly`
      # attribute. It will cache the result until `:foo` changes on the user,
      # `:bar` changes on the user, `u.silly?` at the time of serialization,
      # or it has been more than 10 seconds since the last time the `:silly`
      # attribute was recomputed.
      #
      def computed(attr_name, columns: [], recompute_if: nil, expires_in: nil, &recompute)
        if (columns.empty? && !recompute_if && !expires_in)
          raise ArgumentError, "Must provide :columns, :recompute_if, or :expires_in to a computed attribute setter"
        end
        serializers << AttrSerializer.new(attr_name, recompute_if, expires_in, &recompute)
        columns.each do |column_name|
          add_column_changed_cache_invalidator_callback(attr_name, column_name)
        end
      end

      private

      def subject_class
        @subject_class ||= self.class.to_s.gsub(/[Ss]erializer\z/, '').constantize
      end

      def add_column_changed_cache_invalidator_callback(attr_name, dependent_attr_name)
        @already_added_callback ||= {}
        @already_added_callback[attr_name.to_sym] ||= {}
        return if @already_added_callback[attr_name.to_sym][dependent_attr_name.to_sym]

        subject_class.class_eval do
          after_commit(on: :save) do
            if changes[dependent_attr_name.to_s]
              Rails.cache.delete(CachedSerializer::AttrSerializer.cache_key(subject, attr_name))
            end
          end
        end

        @already_added_callback[attr_name.to_sym][dependent_attr_name.to_sym] = true
      end
    end

    def initialize(subject)
      self.subject = subject
    end

    def to_h
      self.class.serializers.serialize_for(subject)
    end

    def as_json
      to_h
    end

    def to_json
      JSON.generate(as_json)
    end
  end
end
