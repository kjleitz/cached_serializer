module CachedSerializer
  class AttrSerializerCollection
    attr_accessor :collection

    def initialize(collection = [])
      self.collection = collection
    end

    def add(*attr_serializers)
      attr_serializers.each do |attr_serializer|
        existing = collection.find { |serializer| serializer.attr_name == attr_serializer.attr_name }
        if existing
          existing.recompute_ifs.concat(attr_serializer.recompute_ifs)
          existing.recompute = attr_serializer.recompute # shadowed attrs override the blocks of previously-declared ones
          existing.expires_in = attr_serializer.expires_in # shadowed attrs override the expires_in of previously-declared ones
        else
          collection << attr_serializer
        end
      end
    end

    alias_method :push, :add

    def <<(item)
      add(item)
    end

    def concat(items)
      add(*items)
    end

    def method_missing(method, *args, &block)
      collection.send(method, *args, &block)
    end

    def respond_to?(method, *args)
      collection.respond_to?(method, *args)
    end

    def serialize_for(subject)
      collection.reduce({}) do |memo, attr_serializer|
        memo.merge(attr_serializer.serialize_for(subject))
      end
    end
  end
end
