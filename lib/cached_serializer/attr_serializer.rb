module CachedSerializer
  class AttrSerializer
    attr_accessor :attr_name, :recompute_ifs, :expires_in, :recompute

    class << self
      def cache_key(subject, attr_name)
        "cached_serializer:#{subject.class.model_name.name.underscore}:#{subject.id}:#{attr_name}"
      end
    end

    def initialize(attr_name, recompute_ifs = nil, :expires_in = nil, &recompute)
      self.attr_name = attr_name
      self.recompute_ifs = [recompute_ifs].flatten.compact
      self.expires_in = expires_in
      self.recompute = recompute || proc { |subj| subj.send(attr_name.to_sym) }
    end

    def serialize_for(subject)
      { attr_name.to_sym => serialized_value_for(subject) }
    end

    private

    def serialized_value_for(subject)
      should_recompute = recompute_ifs.any? { |recompute_if| recompute_if.call(subject) }
      cache_key = self.class.cache_key(subject, attr_name)
      Rails.cache.fetch(cache_key, expires_in: expires_in, force: should_recompute) do
        attr_serializer.recompute.call(subject)
      end
    end
  end
end
