# -*- coding: utf-8 -*-

require 'stratum'

require_relative '../misc/validator'

module Yabitz
  module Model
    class HwInformation < Stratum::Model
      include Yabitz::Mapper

      table :hwinformations
      field :name, :string, :length => 64
      field :prior, :bool, :default => false
      field :units, :string, :validator => 'check_hwunits', :normalizer => 'normalize_units', :empty => :ok
      fieldex :units, "例: 1U , 1U(FULL) , 2U(HALF)"
      field :calcunits, :string, :validator => 'check_calcunits', :empty => :ok
      fieldex :calcunits, "数値(少数点以下含めて4桁) 例: 2 , 12.5"
      field :virtualized, :bool, :default => false

      def self.instanciate_mapping(fieldname)
        case fieldname
        when :name, :units, :calcunits
          {:method => :new, :class => String}
        when :virtualized
          {:method => :boolparser}
        else
          raise ArgumentError, "unknown field name '#{fieldname}'"
        end
      end

      def <=>(one)
        self.name.downcase <=> one.name.downcase
      end

      def to_s
        self.name
      end

      def self.normalize_units(str)
        return nil if str.nil?
        units = str.tr('ａ-ｚＡ-Ｚ０-９（）　／', 'a-zA-Z0-9() /').upcase.delete(' ')
        if units =~ /\A\d+\Z/
          units += 'U'
        elsif units =~ /\A(\d+U)([A-Z]+)\Z/
          units = $1 + '(' + $2 + ')'
        end
        units
      end

      def check_hwunits(str)
        # あらかじめ normalize_units してから渡してね
        # 1U, 2U(HALF), 1U(1/4) など
        # - 1/4はおあずけで。加えるときは RackUnit も直してね
        # str =~ /\A\d+U(\((FULL|HALF|1\/4)\))?\Z/
        str =~ /\A\d+U(\((FULL|HALF)\))?\Z/
      end

      def check_calcunits(str)
        # DECIMAL(4,2)
        str =~ /\A\d{1,2}(\.\d{1,2})?\Z/
      end

      def unit_height
        self.units =~ /\A(\d+)U/
        $1 ? $1.to_i : 1
      end

      def units_calculated
        unless self.units =~ /\A(\d+)U(\((FULL|HALF)\))?\Z/
          return nil
        end
        units = $1.to_i
        size = $3
        if size.nil? or size == 'FULL'
          units.to_s
        elsif size == 'HALF'
          ((units / 2) + ((units % 2 == 1) ? 0.5 : 0)).to_s
        else
          raise ArgumentError, "illegal size of hardware: #{size} of #{self.units}"
        end
      end

      def self.count_hosts_without_hwinfo(*status_list)
        if status_list.size < 1
          Yabitz::Model::Host.query(:hwinfo => nil, :count => true)
        else
          status_list.inject(0){|a,s| a + Yabitz::Model::Host.query(:hwinfo => nil, :status => s, :count => true)}
        end
      end

      def count_hosts(*status_list)
        if status_list.size < 1
          Yabitz::Model::Host.query(:hwinfo => self, :count => true)
        else
          status_list.inject(0){|a,s| a + Yabitz::Model::Host.query(:hwinfo => self, :status => s, :count => true)}
        end
      end
    end

    class OSInformation < Stratum::Model
      table :osinformations
      field :name, :string, :length => 64, :normalizer => 'normalize_name'
      field :prior, :bool, :default => false

      def <=>(one)
        self.name <=> one.name
      end

      def to_s
        self.name
      end

      def self.normalize_name(str)
        return nil if str.nil?
        str.tr('ａ-ｚＡ-Ｚ０-９（）　／．，', 'a-zA-Z0-9() /.,').strip
      end

      def self.os_in_hosts
        oslist = self.all.map(&:name)
        sql = "SELECT os FROM hosts WHERE head='#{Stratum::Model::BOOL_TRUE}' AND removed='#{Stratum::Model::BOOL_FALSE}' GROUP BY os"
        Stratum.conn do |c|
          c.query(sql).each do |row|
            os = row['os']
            oslist.push(os) if not oslist.include?(os) and not os.nil? and not os.empty?
          end
        end
        return oslist
      end

#       def self.count_hosts_without_os
#         sql = <<EOQ
# SELECT count(*) FROM hosts WHERE (os='' or os IS NULL) AND head='#{Stratum::Model::BOOL_TRUE}' AND removed='#{Stratum::Model::BOOL_FALSE}'
# EOQ
#         Stratum.conn do |c|
#           return c.query(sql).first['count(*)']
#         end
#       end
      def self.count_hosts_without_os(*status_list)
        if status_list.size < 1
          Yabitz::Model::Host.query(:os => nil, :count => true)
        else
          status_list.inject(0){|a,s| a + Yabitz::Model::Host.query(:os => nil, :status => s, :count => true)}
        end
      end

      # def self.count_hosts(name)
      #   sql = "SELECT count(*) FROM hosts WHERE os=? AND head='#{Stratum::Model::BOOL_TRUE}' AND removed='#{Stratum::Model::BOOL_FALSE}'"
      #   Stratum.conn do |c|
      #     return c.query(sql, name).first['count(*)']
      #   end
      # end
      def self.count_hosts(name, *status_list)
        if status_list.size < 1
          Yabitz::Model::Host.query(:os => name, :count => true)
        else
          status_list.inject(0){|a,s| a + Yabitz::Model::Host.query(:os => name, :status => s, :count => true)}
        end
      end
    end
  end
end

