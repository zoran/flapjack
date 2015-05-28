#!/usr/bin/env ruby

require 'swagger/blocks'

require 'zermelo/records/redis'

require 'flapjack/data/validators/id_validator'

require 'flapjack/data/check'
require 'flapjack/data/rule'

require 'flapjack/gateways/jsonapi/data/associations'
require 'flapjack/gateways/jsonapi/data/join_descriptor'
require 'flapjack/gateways/jsonapi/data/method_descriptor'

module Flapjack
  module Data
    class Tag

      include Zermelo::Records::Redis
      include ActiveModel::Serializers::JSON
      self.include_root_in_json = false
      include Flapjack::Gateways::JSONAPI::Data::Associations
      include Swagger::Blocks

      define_attributes :name => :string

      has_and_belongs_to_many :checks,
        :class_name => 'Flapjack::Data::Check', :inverse_of => :tags,
        :after_add => :changed_checks, :after_remove => :changed_checks,
        :related_class_names => ['Flapjack::Data::Contact', 'Flapjack::Data::Rule', 'Flapjack::Data::Route']

      def self.changed_checks(tag_id, *ch_ids)
        Flapjack::Data::Check.intersect(:id => ch_ids).each do |check|
          check.recalculate_routes
        end
      end

      has_and_belongs_to_many :rules,
        :class_name => 'Flapjack::Data::Rule', :inverse_of => :tags,
        :after_add => :changed_rules, :after_remove => :changed_rules,
        :related_class_names => ['Flapjack::Data::Check', 'Flapjack::Data::Contact', 'Flapjack::Data::Route']

      def self.changed_rules(tag_id, *r_ids)
        Flapjack::Data::Rule.intersect(:id => r_ids).each do |rule|
          rule.recalculate_routes
        end
      end

      unique_index_by :name

      # can't use before_validation, as the id's autogenerated by then
      alias_method :"original_save!", :"save!"
      def save!
        self.id = self.name if self.id.nil?
        original_save!
      end

      # name must == id
      validates :name, :presence => true,
        :inclusion => { :in => proc {|t| [t.id] }},
        :format => /\A[a-z0-9\-_\.\|]+\z/i

      before_update :update_allowed?
      def update_allowed?
        !self.changed.include?('name')
      end

      def self.jsonapi_type
        self.name.demodulize.underscore
      end

      swagger_schema :Tag do
        key :required, [:id, :type, :name]
        property :id do
          key :type, :string
        end
        property :type do
          key :type, :string
          key :enum, [Flapjack::Data::Tag.jsonapi_type.downcase]
        end
        property :name do
          key :type, :string
        end
        property :links do
          key :"$ref", :TagLinks
        end
      end

      swagger_schema :TagLinks do
        key :required, [:self, :checks, :rules]
        property :self do
          key :type, :string
          key :format, :url
        end
        property :checks do
          key :type, :string
          key :format, :url
        end
        property :rules do
          key :type, :string
          key :format, :url
        end
      end

      swagger_schema :TagCreate do
        key :required, [:type, :name]
        property :type do
          key :type, :string
          key :enum, [Flapjack::Data::Tag.jsonapi_type.downcase]
        end
        property :name do
          key :type, :string
        end
        property :links do
          key :"$ref", :TagChangeLinks
        end
      end

      swagger_schema :TagUpdate do
        key :required, [:id, :type]
        property :id do
          key :type, :string
          key :format, :uuid
        end
        property :type do
          key :type, :string
          key :enum, [Flapjack::Data::Tag.jsonapi_type.downcase]
        end
        property :links do
          key :"$ref", :TagChangeLinks
        end
      end

      swagger_schema :TagChangeLinks do
        property :checks do
          key :"$ref", :jsonapi_ChecksLinkage
        end
        property :rules do
          key :"$ref", :jsonapi_RulesLinkage
        end
      end

      def self.jsonapi_id
        :name
      end

      def self.jsonapi_methods
        @jsonapi_methods ||= {
          :post => Flapjack::Gateways::JSONAPI::Data::MethodDescriptor.new(
            :attributes => [:name]
          ),
          :get => Flapjack::Gateways::JSONAPI::Data::MethodDescriptor.new(
            :attributes => [:name]
          ),
          :patch => Flapjack::Gateways::JSONAPI::Data::MethodDescriptor.new(
            :attributes => []
          ),
          :delete => Flapjack::Gateways::JSONAPI::Data::MethodDescriptor.new(
          )
        }
      end

      def self.jsonapi_associations
        @jsonapi_associations ||= {
          :checks => Flapjack::Gateways::JSONAPI::Data::JoinDescriptor.new(
            :writable => true, :number => :multiple,
            :link => true, :include => true
          ),
          :rules => Flapjack::Gateways::JSONAPI::Data::JoinDescriptor.new(
            :writable => true, :number => :multiple,
            :link => true, :include => true
          )
        }
      end
    end
  end
end
