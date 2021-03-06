module Polymorpheus
  module Interface
    class PolymorphicError < ::StandardError; end

    class InvalidTypeError < PolymorphicError
      def initialize(*accepted_classes)
        error = "Invalid type."
        error += " Must be one of {#{accepted_classes.join(', ')}}"
        super(error)
      end
    end

    class AmbiguousTypeError < PolymorphicError
      def initialize
        super("Ambiguous polymorphic interface or object type")
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def belongs_to_polymorphic(*args)
        options = args.extract_options!
        polymorphic_api = options[:as]
        associations = args.collect(&:to_s).collect(&:downcase)
        association_keys = associations.collect{|association| "#{association}_id"}

        # Set belongs_to assocaitions
        associations.each do |associated_model|
          belongs_to associated_model.to_sym
        end

        # Class constant defining the keys
        const_set "#{polymorphic_api}_keys".upcase, association_keys

        # Helper methods and constants
        define_method "#{polymorphic_api}_types" do
          associations
        end

        define_method "#{polymorphic_api}_active_key" do
          keys = association_keys.select { |key| self.send(key).present? }
          keys.first if keys.length == 1
        end

        define_method "#{polymorphic_api}_query_condition" do
          fk = self.send("#{polymorphic_api}_active_key")
          { fk.to_s => self.send(fk) } if fk
        end

        # Getter method
        define_method polymorphic_api do
          if key = self.send("#{polymorphic_api}_active_key")
            # we are connecting to an existing item in the db
            self.send key.gsub(/_id$/,'')
          else
            # we can also link to a new record if we're careful
            objs = associations.map { |association| self.send(association) }.compact
            objs.first if objs.length == 1
           end
        end

        # Setter method
        define_method "#{polymorphic_api}=" do |polymorphic_obj|
          possible_associations = [ polymorphic_obj.class.name.underscore,
                                    polymorphic_obj.class.superclass.name.underscore ]
          match = associations & possible_associations
          if match.blank?
            raise Polymorpheus::Interface::PolymorphicError, associations
          elsif match.length > 1
            raise Polymorpheus::Interface::AmbiguousTypeError
          else
            self.send("#{match[0]}_id=", polymorphic_obj.id)
            (associations - match).each do |association_to_reset|
              self.send("#{association_to_reset}_id=", nil)
            end
          end
        end

        # Private method called as part of validation
        # Validate that there is exactly one associated object
        define_method "polymorphic_#{polymorphic_api}_relationship_is_valid" do
          if !self.send(polymorphic_api)
            self.errors.add(:base,
              "You must specify exactly one of the following: {#{associations.join(', ')}}")
          end
        end
        private "polymorphic_#{polymorphic_api}_relationship_is_valid"

      end

      def validates_polymorph(polymorphic_api)
        validate "polymorphic_#{polymorphic_api}_relationship_is_valid"
      end

    end

  end
end
